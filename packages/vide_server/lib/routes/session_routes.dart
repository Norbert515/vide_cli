/// Session routes for Phase 2.5 multiplexed WebSocket streaming.
///
/// This replaces the per-agent WebSocket endpoint with a single session-level
/// multiplexed stream that includes events from ALL agents in the session.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:riverpod/riverpod.dart';
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';
import 'package:vide_core/models/agent_metadata.dart';
import 'package:vide_core/models/agent_status.dart';
import 'package:vide_core/services/agent_network_manager.dart';
import 'package:vide_core/services/claude_manager.dart';
import 'package:vide_core/state/agent_status_manager.dart';
import 'package:claude_sdk/claude_sdk.dart';
import '../dto/session_dto.dart';
import '../services/network_cache_manager.dart';
import '../services/session_event_store.dart';
import '../services/session_permission_manager.dart';

final _log = Logger('SessionRoutes');

/// Create a new session (Phase 2.5 terminology)
Future<Response> createSession(
  Request request,
  ProviderContainer container,
  NetworkCacheManager cacheManager,
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
        'error': 'Missing required fields. Expected: initial-message, working-directory',
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

  // Create the network immediately (like TUI does)
  final manager = container.read(agentNetworkManagerProvider.notifier);
  final network = await manager.startNew(
    Message.text(req.initialMessage),
    workingDirectory: canonicalPath,
    model: req.model,
    permissionMode: req.permissionMode,
  );

  _log.info('Session created: ${network.id}');

  // Cache the network for later retrieval
  cacheManager.cacheNetwork(network);

  final mainAgent = network.agents.first;
  final response = CreateSessionResponse(
    sessionId: network.id,
    mainAgentId: mainAgent.id,
    createdAt: network.createdAt,
  );

  _log.info(
    'Response sent: sessionId=${network.id}, mainAgentId=${mainAgent.id}',
  );
  return Response.ok(
    response.toJsonString(),
    headers: {'Content-Type': 'application/json'},
  );
}

/// Manages streaming for a single session with all its agents
class _SessionStreamManager {
  final String sessionId;
  final ProviderContainer container;
  final NetworkCacheManager cacheManager;
  final WebSocketChannel channel;

  /// Event store for persistence across reconnects
  final SessionEventStore _eventStore = SessionEventStore.instance;

  /// Tracks which agents we're subscribed to
  final Map<String, _AgentSubscription> _agentSubscriptions = {};

  /// Subscription to network state changes (for agent spawn/terminate)
  ProviderSubscription<AgentNetworkState>? _networkSubscription;

  /// Buffered events during setup (for atomic subscribe-then-history pattern)
  final List<SessionEvent> _bufferedEvents = [];
  bool _isBuffering = true;

  /// Current message event ID for streaming (shared across chunks)
  final Map<String, String> _currentMessageEventIds = {};

  _SessionStreamManager({
    required this.sessionId,
    required this.container,
    required this.cacheManager,
    required this.channel,
  });

  /// Get the next sequence number for this session
  int _nextSeq() => _eventStore.nextSeq(sessionId);

  /// Set up the session stream
  Future<void> setup() async {
    _log.info('[Session $sessionId] Setting up stream');

    // Load network
    final network = await cacheManager.getNetwork(sessionId);
    if (network == null) {
      _log.warning('[Session $sessionId] Network not found');
      _sendError('Session not found', code: 'NOT_FOUND');
      await channel.sink.close();
      return;
    }

    // Resume network if not already active
    final manager = container.read(agentNetworkManagerProvider.notifier);
    final currentNetwork = container
        .read(agentNetworkManagerProvider)
        .currentNetwork;
    if (currentNetwork?.id != network.id) {
      await manager.resume(network);
      _log.info('[Session $sessionId] Network resumed');
    }

    // Register with permission manager to receive permission requests
    _registerWithPermissionManager();

    // Subscribe to network state changes FIRST (atomic pattern)
    _subscribeToNetworkChanges();

    // Subscribe to all existing agents
    for (final agent in network.agents) {
      _subscribeToAgent(agent);
    }

    // Send connected event
    final connectedEvent = ConnectedEvent(
      sessionId: network.id,
      mainAgentId: network.agents.first.id,
      lastSeq: _eventStore.getLastSeq(sessionId),
      agents: network.agents
          .map((a) => AgentInfo(id: a.id, type: a.type, name: a.name))
          .toList(),
      metadata: {'working-directory': network.worktreePath ?? ''},
    );
    channel.sink.add(connectedEvent.toJsonString());
    _log.info('[Session $sessionId] Sent connected event');

    // Send history event (empty for new sessions, contains events for reconnects)
    final historyEvent = HistoryEvent(
      lastSeq: _eventStore.getLastSeq(sessionId),
      events: _eventStore.getEvents(sessionId),
    );
    channel.sink.add(historyEvent.toJsonString());
    _log.info('[Session $sessionId] Sent history event with ${historyEvent.events.length} events');

    // Flush buffered events
    _isBuffering = false;
    for (final event in _bufferedEvents) {
      _sendEvent(event);
    }
    _bufferedEvents.clear();

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

  void _registerWithPermissionManager() {
    SessionPermissionManager.instance.registerSession(
      sessionId: sessionId,
      onPermissionRequest:
          (
            requestId,
            toolName,
            toolInput,
            inferredPattern,
            agentId,
            agentType,
            agentName,
            taskName,
          ) {
            final event = SessionEvent.permissionRequest(
              seq: _nextSeq(),
              agentId: agentId,
              agentType: agentType,
              agentName: agentName,
              taskName: taskName,
              requestId: requestId,
              tool: {
                'name': toolName,
                'input': toolInput,
                if (inferredPattern != null)
                  'permission-suggestions': [inferredPattern],
              },
            );
            _emitEvent(event);
          },
      onPermissionTimeout:
          (
            requestId,
            toolName,
            timeoutSeconds,
            agentId,
            agentType,
            agentName,
            taskName,
          ) {
            final event = SessionEvent.permissionTimeout(
              seq: _nextSeq(),
              agentId: agentId,
              agentType: agentType,
              agentName: agentName,
              taskName: taskName,
              requestId: requestId,
            );
            _emitEvent(event);
          },
    );
    _log.info('[Session $sessionId] Registered with permission manager');
  }

  void _subscribeToNetworkChanges() {
    // Use container.listen to get notified of state changes
    _networkSubscription = container.listen(agentNetworkManagerProvider, (
      previous,
      next,
    ) {
      if (next.currentNetwork?.id != sessionId) return;

      final prevAgentIds =
          previous?.currentNetwork?.agents.map((a) => a.id).toSet() ?? {};
      final nextAgentIds =
          next.currentNetwork?.agents.map((a) => a.id).toSet() ?? {};

      // Check for new agents (spawned)
      for (final agentId in nextAgentIds.difference(prevAgentIds)) {
        final agent = next.currentNetwork!.agents.firstWhere(
          (a) => a.id == agentId,
        );
        _log.info('[Session $sessionId] Agent spawned: ${agent.name}');

        // Send agent-spawned event
        final event = SessionEvent.agentSpawned(
          seq: _nextSeq(),
          agentId: agent.id,
          agentType: agent.type,
          agentName: agent.name,
          spawnedBy: agent.spawnedBy ?? 'unknown',
        );
        _emitEvent(event);

        // Subscribe to the new agent
        _subscribeToAgent(agent);
      }

      // Check for removed agents (terminated)
      for (final agentId in prevAgentIds.difference(nextAgentIds)) {
        final agent = previous!.currentNetwork!.agents.firstWhere(
          (a) => a.id == agentId,
        );
        _log.info('[Session $sessionId] Agent terminated: ${agent.name}');

        // Send agent-terminated event
        final event = SessionEvent.agentTerminated(
          seq: _nextSeq(),
          agentId: agent.id,
          agentType: agent.type,
          agentName: agent.name,
          taskName: agent.taskName,
          terminatedBy: 'unknown', // TODO: Track who terminated
        );
        _emitEvent(event);

        // Unsubscribe from the terminated agent
        _unsubscribeFromAgent(agentId);
      }
    }, fireImmediately: false);
  }

  void _subscribeToAgent(AgentMetadata agent) {
    if (_agentSubscriptions.containsKey(agent.id)) return;

    final claudeClient = container.read(claudeProvider(agent.id));
    if (claudeClient == null) {
      _log.warning(
        '[Session $sessionId] No ClaudeClient for agent ${agent.id}',
      );
      return;
    }

    final subscription = _AgentSubscription(
      agentId: agent.id,
      agentType: agent.type,
      agentName: agent.name,
      taskName: agent.taskName,
    );

    // Subscribe to conversation updates
    subscription.conversationSubscription = claudeClient.conversation.listen(
      (conversation) {
        _handleConversationUpdate(conversation, subscription);
      },
      onError: (error) {
        _log.warning(
          '[Session $sessionId] Conversation error for ${agent.id}: $error',
        );
        final event = SessionEvent.error(
          seq: _nextSeq(),
          agentId: agent.id,
          agentType: agent.type,
          agentName: agent.name,
          taskName: subscription.taskName,
          message: error.toString(),
        );
        _emitEvent(event);
      },
    );

    // Subscribe to turn complete events
    subscription.turnCompleteSubscription = claudeClient.onTurnComplete.listen((
      _,
    ) {
      _log.info('[Session $sessionId] Turn complete for ${agent.id}');

      // Finalize any in-progress message
      final eventId = _currentMessageEventIds[agent.id];
      if (eventId != null) {
        final finalEvent = SessionEvent.message(
          seq: _nextSeq(),
          eventId: eventId,
          agentId: agent.id,
          agentType: agent.type,
          agentName: agent.name,
          taskName: subscription.taskName,
          role: 'assistant',
          content: '',
          isPartial: false,
        );
        _emitEvent(finalEvent);
        _currentMessageEventIds.remove(agent.id);
      }

      final event = SessionEvent.done(
        seq: _nextSeq(),
        agentId: agent.id,
        agentType: agent.type,
        agentName: agent.name,
        taskName: subscription.taskName,
      );
      _emitEvent(event);
    });

    // Send initial status event (not stored in event history - it's handshake state sync)
    final initialStatus = container.read(agentStatusProvider(agent.id));
    final initialStatusEvent = SessionEvent.status(
      seq: 0, // Use seq=0 for handshake events (not stored)
      agentId: agent.id,
      agentType: agent.type,
      agentName: agent.name,
      taskName: subscription.taskName,
      status: _mapAgentStatus(initialStatus),
    );
    channel.sink.add(initialStatusEvent.toJsonString());

    // Subscribe to agent status changes (only fires on actual changes)
    subscription.statusSubscription = container.listen<AgentStatus>(
      agentStatusProvider(agent.id),
      (previous, next) {
        if (previous != null && previous != next) {
          _log.fine('[Session $sessionId] Agent ${agent.id} status: $previous -> $next');
          final event = SessionEvent.status(
            seq: _nextSeq(),
            agentId: agent.id,
            agentType: agent.type,
            agentName: agent.name,
            taskName: subscription.taskName,
            status: _mapAgentStatus(next),
          );
          _emitEvent(event);
        }
      },
      fireImmediately: false,
    );

    _agentSubscriptions[agent.id] = subscription;
    _log.fine('[Session $sessionId] Subscribed to agent ${agent.id}');
  }

  /// Maps AgentStatus enum to kebab-case string for JSON
  String _mapAgentStatus(AgentStatus status) {
    switch (status) {
      case AgentStatus.working:
        return 'working';
      case AgentStatus.waitingForAgent:
        return 'waiting-for-agent';
      case AgentStatus.waitingForUser:
        return 'waiting-for-user';
      case AgentStatus.idle:
        return 'idle';
    }
  }

  void _unsubscribeFromAgent(String agentId) {
    final subscription = _agentSubscriptions.remove(agentId);
    subscription?.cancel();
    _currentMessageEventIds.remove(agentId);
    _log.fine('[Session $sessionId] Unsubscribed from agent $agentId');
  }

  void _handleConversationUpdate(
    Conversation conversation,
    _AgentSubscription subscription,
  ) {
    if (conversation.messages.isEmpty) return;

    final currentMessageCount = conversation.messages.length;
    final latestMessage = conversation.messages.last;
    final currentContentLength = latestMessage.content.length;

    // New message started
    if (currentMessageCount > subscription.lastMessageCount) {
      // Reset response count for the new message
      subscription.lastResponseCount = 0;

      // Generate new event ID for this message
      final eventId = const Uuid().v4();
      _currentMessageEventIds[subscription.agentId] = eventId;

      if (latestMessage.content.isNotEmpty) {
        final event = SessionEvent.message(
          seq: _nextSeq(),
          eventId: eventId,
          agentId: subscription.agentId,
          agentType: subscription.agentType,
          agentName: subscription.agentName,
          taskName: subscription.taskName,
          role: latestMessage.role == MessageRole.user ? 'user' : 'assistant',
          content: latestMessage.content,
          isPartial: true,
        );
        _emitEvent(event);
      }

      subscription.lastMessageCount = currentMessageCount;
      subscription.lastContentLength = currentContentLength;
    }
    // Same message, content grew (streaming delta)
    else if (currentContentLength > subscription.lastContentLength) {
      final delta = latestMessage.content.substring(
        subscription.lastContentLength,
      );
      if (delta.isNotEmpty) {
        final eventId =
            _currentMessageEventIds[subscription.agentId] ?? const Uuid().v4();
        final event = SessionEvent.message(
          seq: _nextSeq(),
          eventId: eventId,
          agentId: subscription.agentId,
          agentType: subscription.agentType,
          agentName: subscription.agentName,
          taskName: subscription.taskName,
          role: latestMessage.role == MessageRole.user ? 'user' : 'assistant',
          content: delta,
          isPartial: true,
        );
        _emitEvent(event);
      }
      subscription.lastContentLength = currentContentLength;
    }

    // Always check for new tool events (handles both new messages and
    // tool results being added to existing messages)
    _sendToolEvents(latestMessage, subscription);

    // Check for errors
    if (conversation.currentError != null) {
      final event = SessionEvent.error(
        seq: _nextSeq(),
        agentId: subscription.agentId,
        agentType: subscription.agentType,
        agentName: subscription.agentName,
        taskName: subscription.taskName,
        message: conversation.currentError!,
      );
      _emitEvent(event);
    }
  }

  void _sendToolEvents(
    ConversationMessage message,
    _AgentSubscription subscription,
  ) {
    final responses = message.responses;
    final startIndex = subscription.lastResponseCount;

    // Only process new responses (those after lastResponseCount)
    for (int i = startIndex; i < responses.length; i++) {
      final response = responses[i];
      if (response is ToolUseResponse) {
        subscription.toolNamesByUseId[response.toolUseId ?? ''] =
            response.toolName;
        final event = SessionEvent.toolUse(
          seq: _nextSeq(),
          agentId: subscription.agentId,
          agentType: subscription.agentType,
          agentName: subscription.agentName,
          taskName: subscription.taskName,
          toolUseId: response.toolUseId ?? const Uuid().v4(),
          toolName: response.toolName,
          toolInput: response.parameters,
        );
        _emitEvent(event);
      } else if (response is ToolResultResponse) {
        final toolName =
            subscription.toolNamesByUseId[response.toolUseId] ?? 'unknown';
        final event = SessionEvent.toolResult(
          seq: _nextSeq(),
          agentId: subscription.agentId,
          agentType: subscription.agentType,
          agentName: subscription.agentName,
          taskName: subscription.taskName,
          toolUseId: response.toolUseId,
          toolName: toolName,
          result: response.content,
          isError: response.isError,
        );
        _emitEvent(event);
      }
    }

    // Update the count to mark all responses as processed
    subscription.lastResponseCount = responses.length;
  }

  void _handleClientMessage(dynamic message) {
    _log.fine('[Session $sessionId] Received client message: $message');

    Map<String, dynamic> json;
    try {
      json = jsonDecode(message as String) as Map<String, dynamic>;
    } catch (e) {
      _sendError('Invalid JSON', code: 'INVALID_REQUEST');
      return;
    }

    ClientMessage clientMsg;
    try {
      clientMsg = ClientMessage.fromJson(json);
    } catch (e) {
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

  Future<void> _handleUserMessage(UserMessage msg) async {
    _log.info('[Session $sessionId] User message: ${msg.content}');

    final network = container.read(agentNetworkManagerProvider).currentNetwork;
    if (network == null || network.id != sessionId) {
      _sendError('Session not active', code: 'NOT_FOUND');
      return;
    }

    // Get main agent's ClaudeClient
    final mainAgentId = network.agents.first.id;
    final claudeClient = container.read(claudeProvider(mainAgentId));

    // Set permission mode if specified in the message
    if (msg.permissionMode != null && claudeClient != null) {
      try {
        await claudeClient.setPermissionMode(msg.permissionMode!);
        _log.fine('[Session $sessionId] Permission mode set to: ${msg.permissionMode}');
      } catch (e) {
        _log.warning('[Session $sessionId] Failed to set permission mode: $e');
        _sendError(
          'Failed to set permission mode: $e',
          code: 'INTERNAL_ERROR',
        );
        return;
      }
    }

    // Note: Model cannot be changed mid-conversation with current Claude SDK.
    // Model is set at session creation time via CreateSessionRequest.
    if (msg.model != null) {
      _log.fine('[Session $sessionId] Model override requested but not supported mid-conversation');
    }

    // Send to main agent
    final manager = container.read(agentNetworkManagerProvider.notifier);
    manager.sendMessage(mainAgentId, Message.text(msg.content));
  }

  void _handlePermissionResponse(PermissionResponse msg) {
    _log.info(
      '[Session $sessionId] Permission response: ${msg.requestId} = ${msg.allow}',
    );
    final handled = SessionPermissionManager.instance.handlePermissionResponse(
      requestId: msg.requestId,
      allow: msg.allow,
      message: msg.message,
    );
    if (!handled) {
      _log.warning(
        '[Session $sessionId] No pending permission request for: ${msg.requestId}',
      );
    }
  }

  void _handleAbort() {
    _log.info('[Session $sessionId] Abort requested');

    final network = container.read(agentNetworkManagerProvider).currentNetwork;
    if (network == null || network.id != sessionId) return;

    // Abort all agents
    final claudeClients = container.read(claudeManagerProvider);
    for (final agent in network.agents) {
      final client = claudeClients[agent.id];
      if (client != null) {
        client.abort();
        final event = SessionEvent.aborted(
          seq: _nextSeq(),
          agentId: agent.id,
          agentType: agent.type,
          agentName: agent.name,
          taskName: agent.taskName,
        );
        _emitEvent(event);
      }
    }
  }

  void _emitEvent(SessionEvent event) {
    // Store in persistent event store for reconnects
    final json = event.toJson();
    _eventStore.storeEvent(sessionId, event.seq, json);

    if (_isBuffering) {
      _bufferedEvents.add(event);
    } else {
      _sendEvent(event);
    }
  }

  void _sendEvent(SessionEvent event) {
    channel.sink.add(event.toJsonString());
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
    _emitEvent(event);
  }

  void _cleanup() {
    _log.info('[Session $sessionId] Cleaning up');
    SessionPermissionManager.instance.unregisterSession(sessionId);
    _networkSubscription?.close();
    for (final subscription in _agentSubscriptions.values) {
      subscription.cancel();
    }
    _agentSubscriptions.clear();
  }
}

/// Tracks subscription state for a single agent
class _AgentSubscription {
  final String agentId;
  final String agentType;
  final String? agentName;
  String? taskName;

  StreamSubscription<Conversation>? conversationSubscription;
  StreamSubscription<void>? turnCompleteSubscription;
  ProviderSubscription<AgentStatus>? statusSubscription;

  int lastMessageCount = 0;
  int lastContentLength = 0;
  int lastResponseCount = 0;

  final Map<String, String> toolNamesByUseId = {};

  _AgentSubscription({
    required this.agentId,
    required this.agentType,
    this.agentName,
    this.taskName,
  });

  void cancel() {
    conversationSubscription?.cancel();
    turnCompleteSubscription?.cancel();
    statusSubscription?.close();
  }
}

/// Keepalive ping interval for WebSocket connections.
/// Server sends ping every 20 seconds; if no pong received within 20s,
/// connection is closed with code 1001 (Going Away).
const _keepalivePingInterval = Duration(seconds: 20);

/// Stream session events via WebSocket (Phase 2.5 multiplexed endpoint)
Handler streamSessionWebSocket(
  String sessionId,
  ProviderContainer container,
  NetworkCacheManager cacheManager,
) {
  return webSocketHandler(
    (WebSocketChannel channel, String? protocol) {
      _log.info('[WebSocket] Client connected for session=$sessionId');

    final manager = _SessionStreamManager(
      sessionId: sessionId,
      container: container,
      cacheManager: cacheManager,
      channel: channel,
    );

    manager.setup().catchError((error, stack) {
      _log.severe('[WebSocket] Setup error: $error', error, stack);
      channel.sink.add(
        jsonEncode({
          'type': 'error',
          'data': {'message': 'Failed to setup stream: $error'},
        }),
      );
      channel.sink.close();
    });
    },
    pingInterval: _keepalivePingInterval,
  );
}
