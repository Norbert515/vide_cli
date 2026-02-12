/// Session routes for Phase 2.5 multiplexed WebSocket streaming.
///
/// This module uses VideSessionManager and VideSession as the single interface
/// for all session management, events, and permissions.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:logging/logging.dart';
import 'package:vide_core/vide_core.dart'
    hide ConnectedEvent, AgentInfo, HistoryEvent, CommandResultEvent;
import '../dto/session_dto.dart';
import '../services/session_broadcaster.dart';

final _log = Logger('SessionRoutes');

/// Create a new session via VideSessionManager
Future<Response> createSession(
  Request request,
  VideSessionManager sessionManager,
  Map<String, VideSession> sessionCache,
) async {
  _log.info('POST /sessions - Creating new session');

  final body = await request.readAsString();

  Map<String, dynamic> json;
  try {
    json = jsonDecode(body) as Map<String, dynamic>;
  } catch (e) {
    _log.warning('Invalid request: malformed JSON - $e');
    return Response.badRequest(
      body: jsonEncode({
        'error': 'Invalid JSON in request body',
        'code': 'INVALID_REQUEST',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  CreateSessionRequest req;
  try {
    req = CreateSessionRequest.fromJson(json);
  } catch (e) {
    _log.warning('Invalid request: missing or invalid fields - $e');
    return Response.badRequest(
      body: jsonEncode({
        'error':
            'Missing required fields. Expected: initial-message, working-directory',
        'code': 'INVALID_REQUEST',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  final messagePreview = req.initialMessage.length > 50
      ? '${req.initialMessage.substring(0, 50)}...'
      : req.initialMessage;
  _log.fine(
    'Request: initialMessage="$messagePreview", workingDirectory="${req.workingDirectory}"',
  );

  // Validate working directory
  if (req.workingDirectory.trim().isEmpty) {
    _log.warning('Invalid request: workingDirectory is empty');
    return Response.badRequest(
      body: jsonEncode({
        'error': 'working-directory is required',
        'code': 'INVALID_REQUEST',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  // Canonicalize and verify directory exists
  final canonicalPath = p.canonicalize(req.workingDirectory);
  final dir = Directory(canonicalPath);
  if (!await dir.exists()) {
    _log.warning(
      'Invalid request: workingDirectory does not exist: $canonicalPath',
    );
    return Response.badRequest(
      body: jsonEncode({
        'error': 'working-directory does not exist: $canonicalPath',
        'code': 'INVALID_WORKING_DIRECTORY',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  // Validate initialMessage is not empty
  if (req.initialMessage.trim().isEmpty) {
    _log.warning('Invalid request: initialMessage is empty');
    return Response.badRequest(
      body: jsonEncode({
        'error': 'initial-message is required',
        'code': 'INVALID_REQUEST',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  // Convert DTO attachments to VideAttachment for the session manager.
  final attachments = req.attachments
      ?.map(
        (a) => VideAttachment(
          type: a.type,
          filePath: a.filePath,
          content: a.content,
          mimeType: a.mimeType,
        ),
      )
      .toList();

  // Create session via session manager
  final session = await sessionManager.createSession(
    workingDirectory: canonicalPath,
    initialMessage: req.initialMessage,
    model: req.model,
    permissionMode: req.permissionMode,
    team: req.team ?? 'enterprise',
    attachments: attachments,
  );

  _log.info('Session created: ${session.state.id}');

  // Register with broadcaster BEFORE emitting the initial user message,
  // so the broadcaster captures it in history for replay to clients.
  SessionBroadcasterRegistry.instance.getOrCreate(session);

  // Now emit the initial user message so it's captured by the broadcaster.
  if (session is LocalVideSession) {
    session.emitInitialUserMessage(
      req.initialMessage,
      attachments: attachments,
    );
  }

  // Cache for WebSocket access
  sessionCache[session.state.id] = session;

  final mainAgent = session.state.mainAgent!;
  final response = CreateSessionResponse(
    sessionId: session.state.id,
    mainAgentId: mainAgent.id,
    createdAt: mainAgent.createdAt,
  );

  _log.info(
    'Response sent: sessionId=${session.state.id}, mainAgentId=${mainAgent.id}',
  );
  return Response.ok(
    response.toJsonString(),
    headers: {'Content-Type': 'application/json'},
  );
}

/// List persisted sessions for a given project directory.
///
/// Query parameters:
/// - `working-directory` (required): The client's project directory to scope
///   the session listing to.
Future<Response> listSessions(
  Request request,
  VideSessionManager sessionManager,
) async {
  final workingDirectory = request.url.queryParameters['working-directory'];
  if (workingDirectory == null || workingDirectory.trim().isEmpty) {
    return Response.badRequest(
      body: jsonEncode({
        'error': 'working-directory query parameter is required',
        'code': 'INVALID_REQUEST',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  final canonicalPath = p.canonicalize(workingDirectory);
  final dir = Directory(canonicalPath);
  if (!await dir.exists()) {
    return Response.badRequest(
      body: jsonEncode({
        'error': 'working-directory does not exist: $canonicalPath',
        'code': 'INVALID_WORKING_DIRECTORY',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  _log.info('GET /sessions?working-directory=$canonicalPath');

  final sessions = await sessionManager.listSessions(
    workingDirectory: canonicalPath,
  );

  final json = sessions.map((s) {
    return {
      'session-id': s.id,
      'goal': s.goal,
      'created-at': s.createdAt.toIso8601String(),
      if (s.lastActiveAt != null)
        'last-active-at': s.lastActiveAt!.toIso8601String(),
      if (s.workingDirectory != null) 'working-directory': s.workingDirectory,
      if (s.team != null) 'team': s.team,
      'agent-count': s.agents.length,
    };
  }).toList();

  return Response.ok(
    jsonEncode({'sessions': json}),
    headers: {'Content-Type': 'application/json'},
  );
}

/// Resume a persisted session by ID.
///
/// The working directory must be provided so the server can find the correct
/// persistence file (scoped per project).
Future<Response> resumeSession(
  Request request,
  String sessionId,
  VideSessionManager sessionManager,
  Map<String, VideSession> sessionCache,
) async {
  _log.info('POST /sessions/$sessionId/resume');

  final body = await request.readAsString();

  Map<String, dynamic> json;
  try {
    json = body.isNotEmpty
        ? jsonDecode(body) as Map<String, dynamic>
        : <String, dynamic>{};
  } catch (e) {
    return Response.badRequest(
      body: jsonEncode({
        'error': 'Invalid JSON in request body',
        'code': 'INVALID_REQUEST',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  final workingDirectory = json['working-directory'] as String?;
  if (workingDirectory == null || workingDirectory.trim().isEmpty) {
    return Response.badRequest(
      body: jsonEncode({
        'error': 'working-directory is required',
        'code': 'INVALID_REQUEST',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  final canonicalPath = p.canonicalize(workingDirectory);

  try {
    final session = await sessionManager.resumeSession(
      sessionId,
      workingDirectory: canonicalPath,
    );

    // Register with broadcaster
    SessionBroadcasterRegistry.instance.getOrCreate(session);

    // Cache for WebSocket access
    sessionCache[session.state.id] = session;

    final sessionState = session.state;
    final mainAgent = sessionState.mainAgent;
    final response = {
      'session-id': sessionState.id,
      if (mainAgent != null) 'main-agent-id': mainAgent.id,
      'working-directory': sessionState.workingDirectory,
    };

    _log.info('Session resumed: ${sessionState.id}');
    return Response.ok(
      jsonEncode(response),
      headers: {'Content-Type': 'application/json'},
    );
  } on ArgumentError catch (e) {
    return Response.notFound(
      jsonEncode({'error': e.message, 'code': 'NOT_FOUND'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

/// Simplified stream handler using VideSession as the single interface.
///
/// Events are stored centrally by SessionBroadcaster. This handler only:
/// 1. Sends history on connect
/// 2. Forwards live events to the WebSocket client
/// 3. Handles client messages (user input, permissions, abort)
class _SimplifiedStreamHandler {
  final VideSession session;
  final WebSocketChannel channel;

  /// Broadcaster that stores events and broadcasts to all clients
  late final SessionBroadcaster _broadcaster;

  /// Function to unregister from broadcaster on cleanup
  void Function()? _unregister;

  _SimplifiedStreamHandler({required this.session, required this.channel}) {
    _broadcaster = SessionBroadcasterRegistry.instance.getOrCreate(session);
  }

  String get sessionId => session.state.id;

  /// Set up the WebSocket stream
  Future<void> setup() async {
    _log.info('[Session $sessionId] Setting up stream');

    // Send connected event
    final sessionState = session.state;
    final agents = sessionState.agents;
    final connectedEvent = ConnectedEvent(
      sessionId: sessionId,
      mainAgentId: sessionState.mainAgent?.id ?? '',
      lastSeq: _broadcaster.history.length,
      agents: agents
          .map((a) => AgentInfo(id: a.id, type: a.type, name: a.name))
          .toList(),
      metadata: {
        'working-directory': sessionState.workingDirectory,
        'goal': sessionState.goal,
        'team': sessionState.team,
      },
    );
    channel.sink.add(connectedEvent.toJsonString());
    _log.info('[Session $sessionId] Sent connected event');

    // Send history
    final historyEvent = HistoryEvent(
      lastSeq: _broadcaster.history.length,
      events: _broadcaster.history,
    );
    channel.sink.add(historyEvent.toJsonString());
    _log.info(
      '[Session $sessionId] Sent history with ${_broadcaster.history.length} events',
    );

    // Register for live events (broadcaster handles storage)
    _unregister = _broadcaster.addClient(_handleBroadcastEvent);

    // Listen for client messages
    channel.stream.listen(
      _handleClientMessage,
      onDone: _cleanup,
      onError: (error) {
        _log.warning('[Session $sessionId] Client stream error: $error');
        _cleanup();
      },
    );
  }

  /// Handle event from broadcaster (already stored, just forward)
  void _handleBroadcastEvent(Map<String, dynamic> event) {
    channel.sink.add(jsonEncode(event));
  }

  /// Handle incoming client message
  void _handleClientMessage(dynamic message) {
    _log.fine('[Session $sessionId] Received client message: $message');

    Map<String, dynamic> json;
    try {
      json = jsonDecode(message as String) as Map<String, dynamic>;
    } catch (e) {
      _log.warning('[Session $sessionId] Invalid JSON from client: $e');
      _sendError('Invalid JSON', code: 'INVALID_REQUEST');
      return;
    }

    ClientMessage clientMsg;
    try {
      clientMsg = ClientMessage.fromJson(json);
    } catch (e) {
      _log.warning(
        '[Session $sessionId] Unknown message type: ${json['type']} - $e',
      );
      _sendError(
        'Unknown message type: ${json['type']}',
        code: 'UNKNOWN_MESSAGE_TYPE',
        originalMessage: json,
      );
      return;
    }

    switch (clientMsg) {
      case UserMessage msg:
        _handleUserMessage(msg);
      case PermissionResponse msg:
        _handlePermissionResponse(msg);
      case AskUserQuestionResponseMessage msg:
        _handleAskUserQuestionResponse(msg);
      case PlanApprovalResponseMessage msg:
        _handlePlanApprovalResponse(msg);
      case SessionCommandMessage msg:
        unawaited(_handleSessionCommand(msg));
      case AbortMessage _:
        _handleAbort();
    }
  }

  void _handleUserMessage(UserMessage msg) {
    _log.info(
      '[Session $sessionId] User message: ${msg.content} (agent=${msg.agentId ?? "main"})',
    );
    final attachments = msg.attachments
        ?.map(
          (a) => VideAttachment(
            type: a.type,
            filePath: a.filePath,
            content: a.content,
            mimeType: a.mimeType,
          ),
        )
        .toList();
    session.sendMessage(
      VideMessage(text: msg.content, attachments: attachments),
      agentId: msg.agentId,
    );
  }

  void _handlePermissionResponse(PermissionResponse msg) {
    _log.info(
      '[Session $sessionId] Permission response: ${msg.requestId} = ${msg.allow}',
    );

    session.respondToPermission(
      msg.requestId,
      allow: msg.allow,
      message: msg.message,
      remember: msg.remember,
      patternOverride: msg.patternOverride,
    );
  }

  void _handleAskUserQuestionResponse(AskUserQuestionResponseMessage msg) {
    _log.info(
      '[Session $sessionId] AskUserQuestion response: ${msg.requestId} (${msg.answers.length} answers)',
    );

    session.respondToAskUserQuestion(msg.requestId, answers: msg.answers);
  }

  void _handlePlanApprovalResponse(PlanApprovalResponseMessage msg) {
    _log.info(
      '[Session $sessionId] Plan approval response: ${msg.requestId} = ${msg.action}',
    );

    session.respondToPlanApproval(
      msg.requestId,
      action: msg.action,
      feedback: msg.feedback,
    );
  }

  Future<void> _handleSessionCommand(SessionCommandMessage msg) async {
    _log.info('[Session $sessionId] Session command: ${msg.command}');

    try {
      final result = await _executeSessionCommand(msg.command, msg.data);
      _sendCommandResult(
        CommandResultEvent(
          requestId: msg.requestId,
          command: msg.command,
          success: true,
          result: result,
        ),
      );
    } catch (e) {
      _log.warning(
        '[Session $sessionId] Session command failed: ${msg.command} - $e',
      );
      _sendCommandResult(
        CommandResultEvent(
          requestId: msg.requestId,
          command: msg.command,
          success: false,
          errorMessage: e.toString(),
          errorCode: 'COMMAND_FAILED',
        ),
      );
    }
  }

  Future<Map<String, dynamic>?> _executeSessionCommand(
    String command,
    Map<String, dynamic> data,
  ) async {
    switch (command) {
      case 'abort-agent':
        final agentId = data['agent-id'] as String?;
        if (agentId == null || agentId.isEmpty) {
          throw ArgumentError('Missing required field: agent-id');
        }
        await session.abortAgent(agentId);
        return null;

      case 'clear-conversation':
        await session.clearConversation(agentId: data['agent-id'] as String?);
        return null;

      case 'set-worktree-path':
        await session.setWorktreePath(data['path'] as String?);
        return {'working-directory': session.state.workingDirectory};

      case 'terminate-agent':
        final agentId = data['agent-id'] as String?;
        final terminatedBy = data['terminated-by'] as String?;
        if (agentId == null || agentId.isEmpty) {
          throw ArgumentError('Missing required field: agent-id');
        }
        if (terminatedBy == null || terminatedBy.isEmpty) {
          throw ArgumentError('Missing required field: terminated-by');
        }
        await session.terminateAgent(
          agentId,
          terminatedBy: terminatedBy,
          reason: data['reason'] as String?,
        );
        return null;

      case 'fork-agent':
        final agentId = data['agent-id'] as String?;
        if (agentId == null || agentId.isEmpty) {
          throw ArgumentError('Missing required field: agent-id');
        }
        final newAgentId = await session.forkAgent(
          agentId,
          name: data['name'] as String?,
        );
        return {'agent-id': newAgentId};

      case 'spawn-agent':
        final agentType = data['agent-type'] as String?;
        final name = data['name'] as String?;
        final initialPrompt = data['initial-prompt'] as String?;
        final spawnedBy = data['spawned-by'] as String?;
        if (agentType == null || agentType.isEmpty) {
          throw ArgumentError('Missing required field: agent-type');
        }
        if (name == null || name.isEmpty) {
          throw ArgumentError('Missing required field: name');
        }
        if (initialPrompt == null || initialPrompt.isEmpty) {
          throw ArgumentError('Missing required field: initial-prompt');
        }
        if (spawnedBy == null || spawnedBy.isEmpty) {
          throw ArgumentError('Missing required field: spawned-by');
        }

        final newAgentId = await session.spawnAgent(
          agentType: agentType,
          name: name,
          initialPrompt: initialPrompt,
          spawnedBy: spawnedBy,
        );
        return {'agent-id': newAgentId};

      case 'get-queued-message':
        final agentId = data['agent-id'] as String?;
        if (agentId == null || agentId.isEmpty) {
          throw ArgumentError('Missing required field: agent-id');
        }
        return {'message': await session.getQueuedMessage(agentId)};

      case 'clear-queued-message':
        final agentId = data['agent-id'] as String?;
        if (agentId == null || agentId.isEmpty) {
          throw ArgumentError('Missing required field: agent-id');
        }
        await session.clearQueuedMessage(agentId);
        return null;

      case 'get-model':
        final agentId = data['agent-id'] as String?;
        if (agentId == null || agentId.isEmpty) {
          throw ArgumentError('Missing required field: agent-id');
        }
        return {'model': await session.getModel(agentId)};

      case 'add-session-permission-pattern':
        final pattern = data['pattern'] as String?;
        if (pattern == null || pattern.isEmpty) {
          throw ArgumentError('Missing required field: pattern');
        }
        await session.addSessionPermissionPattern(pattern);
        return null;

      case 'is-allowed-by-session-cache':
        final toolName = data['tool-name'] as String?;
        final input = data['input'] as Map<String, dynamic>?;
        if (toolName == null || toolName.isEmpty) {
          throw ArgumentError('Missing required field: tool-name');
        }
        if (input == null) {
          throw ArgumentError('Missing required field: input');
        }
        return {
          'allowed': await session.isAllowedBySessionCache(toolName, input),
        };

      case 'clear-session-permission-cache':
        await session.clearSessionPermissionCache();
        return null;

      default:
        throw ArgumentError('Unknown session command: $command');
    }
  }

  void _sendCommandResult(CommandResultEvent event) {
    channel.sink.add(event.toJsonString());
  }

  void _handleAbort() {
    _log.info('[Session $sessionId] Abort requested');
    session.abort();
    // Abort events will come through the broadcaster
  }

  void _sendError(
    String message, {
    String? code,
    Map<String, dynamic>? originalMessage,
  }) {
    // Server errors go directly to this client only
    channel.sink.add(
      jsonEncode({
        'type': 'error',
        'agent-id': 'server',
        'agent-type': 'system',
        'data': {
          'message': message,
          if (code != null) 'code': code,
          if (originalMessage != null) 'original-message': originalMessage,
        },
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );
  }

  void _cleanup() {
    _log.info('[Session $sessionId] Cleaning up');
    _unregister?.call();
  }
}

/// Keepalive ping interval for WebSocket connections.
const _keepalivePingInterval = Duration(seconds: 20);

/// Stream session events via WebSocket (Phase 2.5 multiplexed endpoint)
Handler streamSessionWebSocket(
  String sessionId,
  Map<String, VideSession> sessionCache,
) {
  return webSocketHandler((WebSocketChannel channel, String? protocol) {
    _log.info('[WebSocket] Client connected for session=$sessionId');

    // Get session from cache
    final session = sessionCache[sessionId];
    if (session == null) {
      _log.warning('[WebSocket] Session not found: $sessionId');
      channel.sink.add(
        jsonEncode({
          'type': 'error',
          'data': {'message': 'Session not found', 'code': 'NOT_FOUND'},
        }),
      );
      channel.sink.close();
      return;
    }

    final handler = _SimplifiedStreamHandler(
      session: session,
      channel: channel,
    );

    handler.setup().catchError((error, stack) {
      _log.severe('[WebSocket] Setup error: $error', error, stack);
      channel.sink.add(
        jsonEncode({
          'type': 'error',
          'data': {'message': 'Failed to setup stream: $error'},
        }),
      );
      channel.sink.close();
    });
  }, pingInterval: _keepalivePingInterval);
}
