/// Session routes for Phase 2.5 multiplexed WebSocket streaming.
///
/// This module uses VideCore and VideSession as the single interface for
/// all session management, events, and permissions.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:logging/logging.dart';
import 'package:vide_core/vide_core.dart';
import '../dto/session_dto.dart';
import '../services/session_event_store.dart';
import '../services/server_config.dart';

final _log = Logger('SessionRoutes');

/// Create a new session via VideCore
Future<Response> createSession(
  Request request,
  VideCore videCore,
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

  // Create session via VideCore - the single interface
  final session = await videCore.startSession(VideSessionConfig(
    workingDirectory: canonicalPath,
    initialMessage: req.initialMessage,
    model: req.model,
    permissionMode: req.permissionMode,
  ));

  _log.info('Session created: ${session.id}');

  // Cache for WebSocket access
  sessionCache[session.id] = session;

  final mainAgent = session.mainAgent!;
  final response = CreateSessionResponse(
    sessionId: session.id,
    mainAgentId: mainAgent.id,
    createdAt: mainAgent.createdAt,
  );

  _log.info(
    'Response sent: sessionId=${session.id}, mainAgentId=${mainAgent.id}',
  );
  return Response.ok(
    response.toJsonString(),
    headers: {'Content-Type': 'application/json'},
  );
}

/// Simplified stream handler using VideSession as the single interface.
///
/// This replaces the complex _SessionStreamManager class by:
/// 1. Subscribing to session.events (single stream for all agents)
/// 2. Mapping VideEvent -> SessionEvent for the WebSocket protocol
/// 3. Using session.respondToPermission() for permission handling
/// 4. Using session.sendMessage() for user messages
class _SimplifiedStreamHandler {
  final VideSession session;
  final WebSocketChannel channel;
  final ServerConfig serverConfig;

  /// Event store for persistence across reconnects
  final SessionEventStore _eventStore = SessionEventStore.instance;

  /// Subscription to session events
  StreamSubscription<VideEvent>? _eventSubscription;

  /// Permission timeout timers
  final Map<String, Timer> _permissionTimers = {};

  _SimplifiedStreamHandler({
    required this.session,
    required this.channel,
    required this.serverConfig,
  });

  String get sessionId => session.id;

  /// Get the next sequence number for this session
  int _nextSeq() => _eventStore.nextSeq(sessionId);

  /// Set up the WebSocket stream
  Future<void> setup() async {
    _log.info('[Session $sessionId] Setting up stream via VideSession');

    // Send connected event (server protocol event, not VideSession event)
    final agents = session.agents;
    final connectedEvent = ConnectedEvent(
      sessionId: sessionId,
      mainAgentId: session.mainAgent?.id ?? '',
      lastSeq: _eventStore.getLastSeq(sessionId),
      agents: agents.map((a) => AgentInfo(id: a.id, type: a.type, name: a.name)).toList(),
      metadata: {'working-directory': session.workingDirectory},
    );
    channel.sink.add(connectedEvent.toJsonString());
    _log.info('[Session $sessionId] Sent connected event');

    // Send history event (for reconnection support)
    final historyEvent = HistoryEvent(
      lastSeq: _eventStore.getLastSeq(sessionId),
      events: _eventStore.getEvents(sessionId),
    );
    channel.sink.add(historyEvent.toJsonString());
    _log.info('[Session $sessionId] Sent history with ${historyEvent.events.length} events');

    // Subscribe to VideSession events and map to SessionEvent
    _eventSubscription = session.events.listen(
      _handleVideEvent,
      onError: (error) {
        _log.warning('[Session $sessionId] Event stream error: $error');
        _sendError(error.toString());
      },
      onDone: () {
        _log.info('[Session $sessionId] Event stream closed');
      },
    );

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

  /// Map VideEvent to SessionEvent and send to client
  void _handleVideEvent(VideEvent event) {
    final sessionEvent = _mapVideEventToSessionEvent(event);
    if (sessionEvent == null) return;

    // Start permission timeout for permission requests
    if (event is PermissionRequestEvent) {
      _startPermissionTimeout(event);
    }

    // Store and send
    _eventStore.storeEvent(sessionId, sessionEvent.seq, sessionEvent.toJson());
    channel.sink.add(sessionEvent.toJsonString());
  }

  /// Map VideEvent to SessionEvent (returns null if event should be skipped)
  SessionEvent? _mapVideEventToSessionEvent(VideEvent event) {
    switch (event) {
      case MessageEvent e:
        return SessionEvent.message(
          seq: _nextSeq(),
          eventId: e.eventId,
          agentId: e.agentId,
          agentType: e.agentType,
          agentName: e.agentName,
          taskName: e.taskName,
          role: e.role,
          content: e.content,
          isPartial: e.isPartial,
        );

      case ToolUseEvent e:
        return SessionEvent.toolUse(
          seq: _nextSeq(),
          agentId: e.agentId,
          agentType: e.agentType,
          agentName: e.agentName,
          taskName: e.taskName,
          toolUseId: e.toolUseId,
          toolName: e.toolName,
          toolInput: e.toolInput,
        );

      case ToolResultEvent e:
        return SessionEvent.toolResult(
          seq: _nextSeq(),
          agentId: e.agentId,
          agentType: e.agentType,
          agentName: e.agentName,
          taskName: e.taskName,
          toolUseId: e.toolUseId,
          toolName: e.toolName,
          result: e.result,
          isError: e.isError,
        );

      case StatusEvent e:
        return SessionEvent.status(
          seq: _nextSeq(),
          agentId: e.agentId,
          agentType: e.agentType,
          agentName: e.agentName,
          taskName: e.taskName,
          status: _mapAgentStatus(e.status),
        );

      case TurnCompleteEvent e:
        return SessionEvent.done(
          seq: _nextSeq(),
          agentId: e.agentId,
          agentType: e.agentType,
          agentName: e.agentName,
          taskName: e.taskName,
        );

      case AgentSpawnedEvent e:
        return SessionEvent.agentSpawned(
          seq: _nextSeq(),
          agentId: e.agentId,
          agentType: e.agentType,
          agentName: e.agentName,
          spawnedBy: e.spawnedBy,
        );

      case AgentTerminatedEvent e:
        return SessionEvent.agentTerminated(
          seq: _nextSeq(),
          agentId: e.agentId,
          agentType: e.agentType,
          agentName: e.agentName,
          taskName: e.taskName,
          terminatedBy: 'unknown',
        );

      case PermissionRequestEvent e:
        return SessionEvent.permissionRequest(
          seq: _nextSeq(),
          agentId: e.agentId,
          agentType: e.agentType,
          agentName: e.agentName,
          taskName: e.taskName,
          requestId: e.requestId,
          tool: {
            'name': e.toolName,
            'input': e.toolInput,
            if (e.inferredPattern != null)
              'permission-suggestions': [e.inferredPattern],
          },
        );

      case AskUserQuestionEvent e:
        // Map to permission request for now (client can handle specially)
        return SessionEvent.askUserQuestion(
          seq: _nextSeq(),
          agentId: e.agentId,
          agentType: e.agentType,
          agentName: e.agentName,
          taskName: e.taskName,
          requestId: e.requestId,
          questions: e.questions.map((q) => {
            'question': q.question,
            'header': q.header,
            'multi-select': q.multiSelect,
            'options': q.options.map((o) => {
              'label': o.label,
              'description': o.description,
            }).toList(),
          }).toList(),
        );

      case ErrorEvent e:
        return SessionEvent.error(
          seq: _nextSeq(),
          agentId: e.agentId,
          agentType: e.agentType,
          agentName: e.agentName,
          taskName: e.taskName,
          message: e.message,
        );

      case TaskNameChangedEvent _:
        // Internal event, not sent to WebSocket clients
        return null;
    }
  }

  /// Map VideAgentStatus enum to kebab-case string for JSON
  String _mapAgentStatus(VideAgentStatus status) {
    switch (status) {
      case VideAgentStatus.working:
        return 'working';
      case VideAgentStatus.waitingForAgent:
        return 'waiting-for-agent';
      case VideAgentStatus.waitingForUser:
        return 'waiting-for-user';
      case VideAgentStatus.idle:
        return 'idle';
    }
  }

  /// Start permission timeout timer
  void _startPermissionTimeout(PermissionRequestEvent event) {
    final timeoutSeconds = serverConfig.permissionTimeoutSeconds;
    if (timeoutSeconds <= 0) return; // No timeout configured

    _permissionTimers[event.requestId] = Timer(
      Duration(seconds: timeoutSeconds),
      () {
        _log.info('[Session $sessionId] Permission timeout: ${event.requestId}');
        _permissionTimers.remove(event.requestId);

        // Auto-deny on timeout
        session.respondToPermission(event.requestId, allow: false, message: 'Permission timed out');

        // Send timeout event
        final timeoutEvent = SessionEvent.permissionTimeout(
          seq: _nextSeq(),
          agentId: event.agentId,
          agentType: event.agentType,
          agentName: event.agentName,
          taskName: event.taskName,
          requestId: event.requestId,
        );
        _eventStore.storeEvent(sessionId, timeoutEvent.seq, timeoutEvent.toJson());
        channel.sink.add(timeoutEvent.toJsonString());
      },
    );
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
      _log.warning('[Session $sessionId] Unknown message type: ${json['type']} - $e');
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
      case AbortMessage _:
        _handleAbort();
    }
  }

  void _handleUserMessage(UserMessage msg) {
    _log.info('[Session $sessionId] User message: ${msg.content}');
    session.sendMessage(Message.text(msg.content));
  }

  void _handlePermissionResponse(PermissionResponse msg) {
    _log.info('[Session $sessionId] Permission response: ${msg.requestId} = ${msg.allow}');

    // Cancel timeout timer
    _permissionTimers.remove(msg.requestId)?.cancel();

    // Forward to session
    session.respondToPermission(
      msg.requestId,
      allow: msg.allow,
      message: msg.message,
    );
  }

  void _handleAbort() {
    _log.info('[Session $sessionId] Abort requested');
    session.abort();

    // Send aborted event for all agents
    for (final agent in session.agents) {
      final event = SessionEvent.aborted(
        seq: _nextSeq(),
        agentId: agent.id,
        agentType: agent.type,
        agentName: agent.name,
        taskName: agent.taskName,
      );
      _eventStore.storeEvent(sessionId, event.seq, event.toJson());
      channel.sink.add(event.toJsonString());
    }
  }

  void _sendError(
    String message, {
    String? code,
    Map<String, dynamic>? originalMessage,
  }) {
    final event = SessionEvent.error(
      seq: _nextSeq(),
      agentId: 'server',
      agentType: 'system',
      message: message,
      code: code,
      originalMessage: originalMessage,
    );
    _eventStore.storeEvent(sessionId, event.seq, event.toJson());
    channel.sink.add(event.toJsonString());
  }

  void _cleanup() {
    _log.info('[Session $sessionId] Cleaning up');
    _eventSubscription?.cancel();
    for (final timer in _permissionTimers.values) {
      timer.cancel();
    }
    _permissionTimers.clear();
  }
}

/// Keepalive ping interval for WebSocket connections.
const _keepalivePingInterval = Duration(seconds: 20);

/// Stream session events via WebSocket (Phase 2.5 multiplexed endpoint)
Handler streamSessionWebSocket(
  String sessionId,
  VideCore videCore,
  Map<String, VideSession> sessionCache,
  ServerConfig serverConfig,
) {
  return webSocketHandler((WebSocketChannel channel, String? protocol) {
    _log.info('[WebSocket] Client connected for session=$sessionId');

    // Get session from cache
    final session = sessionCache[sessionId];
    if (session == null) {
      _log.warning('[WebSocket] Session not found: $sessionId');
      channel.sink.add(jsonEncode({
        'type': 'error',
        'data': {'message': 'Session not found', 'code': 'NOT_FOUND'},
      }));
      channel.sink.close();
      return;
    }

    final handler = _SimplifiedStreamHandler(
      session: session,
      channel: channel,
      serverConfig: serverConfig,
    );

    handler.setup().catchError((error, stack) {
      _log.severe('[WebSocket] Setup error: $error', error, stack);
      channel.sink.add(jsonEncode({
        'type': 'error',
        'data': {'message': 'Failed to setup stream: $error'},
      }));
      channel.sink.close();
    });
  }, pingInterval: _keepalivePingInterval);
}
