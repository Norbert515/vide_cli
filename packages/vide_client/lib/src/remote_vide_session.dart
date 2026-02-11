import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';
import 'package:vide_interface/vide_interface.dart';

import 'remote_conversation_builder.dart';
import 'session.dart';

/// Handle for an optimistic remote session that is still connecting.
///
/// This keeps pending-session lifecycle operations so UI/service
/// layers do not need to depend on [RemoteVideSession] internals.
class PendingRemoteVideSession {
  final RemoteVideSession _session;

  PendingRemoteVideSession._(this._session);

  /// The session to use immediately (for optimistic navigation/rendering).
  VideSession get session => _session;

  /// Session identifier (stable across pending/connected transitions).
  String get id => _session.id;

  /// Whether the session is still pending.
  bool get isPending => _session.isPending;

  /// Creation error if the pending session failed.
  String? get creationError => _session.creationError;

  /// Callback invoked when pending session completes (success or failure).
  set onReady(void Function()? callback) {
    _session.onPendingComplete = callback;
  }

  /// Resolve the pending session with a connected transport session.
  void completeWithClientSession(Session clientSession) {
    _session.completePending(clientSession);
  }

  /// Mark the pending session as failed.
  void fail(String error) {
    _session.failPending(error);
  }
}

/// Create a pending remote session handle for optimistic UI flows.
PendingRemoteVideSession createPendingRemoteVideSession({
  String? initialMessage,
  List<VideAttachment>? attachments,
  void Function()? onReady,
}) {
  final session = RemoteVideSession.pending();
  if (initialMessage != null && initialMessage.isNotEmpty) {
    session.addPendingUserMessage(initialMessage, attachments: attachments);
  }
  session.onPendingComplete = onReady;
  return PendingRemoteVideSession._(session);
}

/// Adapt a transport-level [Session] into the unified [VideSession] API.
VideSession createRemoteVideSessionFromClientSession(
  Session clientSession, {
  String? mainAgentId,
}) {
  return RemoteVideSession.fromClientSession(
    clientSession,
    mainAgentId: mainAgentId,
  );
}

/// A VideSession that connects to a remote vide_server via WebSocket.
///
/// This implementation composes with [Session] from vide_client,
/// which handles the wire protocol. RemoteVideSession adds:
/// - Conversation state management
/// - Agent tracking
/// - Event adaptation from wire format to business events
///
/// ## Composability
///
/// The architecture provides two levels of access:
///
/// 1. **Session** - Thin wire protocol wrapper
/// 2. **RemoteVideSession** - Full [VideSession] interface with state management
///
/// ## Usage
///
/// ```dart
/// // Using VideClient to create session
/// final client = VideClient(port: 8080);
/// final clientSession = await client.createSession(...);
/// final session = RemoteVideSession.fromClientSession(clientSession);
///
/// // Listen to business events
/// session.events.listen((event) {
///   switch (event) {
///     case MessageEvent(:final content): print(content);
///     case ToolUseEvent(:final toolName): print('Using: $toolName');
///   }
/// });
/// ```
///
/// ## Optimistic Navigation (Pending Sessions)
///
/// For UIs that want to navigate before the session is created:
///
/// ```dart
/// final pending = createPendingRemoteVideSession(initialMessage: 'Build this');
/// navigateToExecutionPage(pending.session); // Navigate immediately
///
/// // Later, when server responds:
/// pending.completeWithClientSession(clientSession);
/// ```
class RemoteVideSession implements VideSession {
  String _sessionId;
  Session? _clientSession;
  StreamSubscription<VideEvent>? _eventSubscription;

  final SessionEventHub _hub = SessionEventHub();
  final RemoteConversationBuilder _conversationBuilder =
      RemoteConversationBuilder();

  /// Tracks agent info from connected/spawn events.
  final Map<String, _RemoteAgentInfo> _agents = {};

  /// Main agent ID (from connected event).
  String? _mainAgentId;

  /// Working directory (from connected event metadata).
  String _workingDirectory = '';

  /// Session goal/task name.
  String _goal = 'Session';

  /// Team name for this session.
  String _team = 'enterprise';

  /// Pending permission completers.
  final Map<String, Completer<VidePermissionResult>> _pendingPermissions = {};

  /// Current pending permission request (survives across UI lifecycle).
  PermissionRequestEvent? _pendingPermissionRequest;

  /// Current pending permission request, if any.
  PermissionRequestEvent? get pendingPermissionRequest =>
      _pendingPermissionRequest;

  /// Cached queued messages by agent.
  final Map<String, String?> _queuedMessages = {};

  /// Stream controllers for queued message updates.
  final Map<String, StreamController<String?>> _queuedMessageControllers = {};
  final Set<String> _queuedRefreshInFlight = {};

  /// Cached model names by agent.
  final Map<String, String?> _models = {};

  /// Stream controllers for model updates.
  final Map<String, StreamController<String?>> _modelControllers = {};
  final Set<String> _modelRefreshInFlight = {};

  /// Current status per agent.
  final Map<String, VideAgentStatus> _agentStatuses = {};

  /// Last seq seen, for deduplication.
  int _lastSeq = 0;

  bool _connected = false;

  /// Stream controller that emits when connection state changes.
  final StreamController<bool> _connectionStateController =
      StreamController<bool>.broadcast();

  /// Stream that emits when connection state changes (true = connected).
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  /// Whether the WebSocket is connected and ready.
  bool get isConnected => _connected;

  /// Whether this session is still being created on the server.
  bool _isPending = false;
  bool get isPending => _isPending;

  /// Pending placeholder agent ID to migrate when connected event arrives.
  /// This is set during completePending() and consumed in _handleConnected().
  String? _pendingAgentIdToMigrate;

  /// Whether the pending session had an initial message.
  /// When true, the main agent should be set to "working" on connect
  /// instead of "idle", since the server is already processing that message.
  bool _hadInitialMessage = false;

  /// Error that occurred during session creation (if any).
  String? _creationError;
  String? get creationError => _creationError;

  /// Callback invoked when pending session completes (success or failure).
  void Function()? onPendingComplete;

  /// Completer for initial connection.
  final Completer<void> _connectCompleter = Completer<void>();

  /// Create a RemoteVideSession from an existing Session.
  ///
  /// This is the preferred constructor when you already have a client session.
  RemoteVideSession.fromClientSession(
    Session clientSession, {
    String? mainAgentId,
  }) : _sessionId = clientSession.id,
       _clientSession = clientSession {
    _hub.setStateBuilder(_buildState);
    _initWithMainAgent(mainAgentId);
    _setupEventListening();
  }

  /// Create a pending session that will be connected once server responds.
  ///
  /// This enables optimistic navigation - we can navigate immediately while
  /// the HTTP call to create the session happens in the background.
  RemoteVideSession.pending()
    : _sessionId = const Uuid().v4(),
      _isPending = true {
    _hub.setStateBuilder(_buildState);
    // Pre-populate with a placeholder main agent
    final placeholderId = const Uuid().v4();
    _mainAgentId = placeholderId;
    _agents[placeholderId] = _RemoteAgentInfo(
      id: placeholderId,
      type: 'main',
      name: 'Connecting...',
    );
  }

  /// Complete a pending session with an actual client session.
  void completePending(Session clientSession) {
    if (!_isPending) return;

    // Save placeholder agent ID for conversation migration when ConnectedEvent arrives.
    // Keep the placeholder in _agents so the UI continues to show it until
    // the ConnectedEvent arrives with the real agent list (avoids a brief
    // empty-agents flash).
    if (_mainAgentId != null) {
      _pendingAgentIdToMigrate = _mainAgentId;
    }

    // Update with real details
    _sessionId = clientSession.id;
    _clientSession = clientSession;
    _isPending = false;

    // Set up event listening (ConnectedEvent will set _mainAgentId and migrate conversation)
    _setupEventListening();

    // Notify listeners
    onPendingComplete?.call();
  }

  /// Mark the pending session as failed.
  void failPending(String error) {
    if (!_isPending) return;
    _creationError = error;
    _isPending = false;

    // Update placeholder agent to show error
    if (_mainAgentId != null) {
      _agents[_mainAgentId!] = _RemoteAgentInfo(
        id: _mainAgentId!,
        type: 'main',
        name: 'Error',
      );
    }

    // Notify listeners
    onPendingComplete?.call();
  }

  /// Adds a user message to the conversation for immediate display.
  ///
  /// This is called during optimistic navigation so the user sees their
  /// message immediately, before the server responds.
  ///
  /// Also emits a status event showing the agent as "working" so the UI
  /// displays activity immediately.
  void addPendingUserMessage(
    String content, {
    List<VideAttachment>? attachments,
  }) {
    final agentId = _mainAgentId;
    if (agentId == null) return;

    final agentInfo = _agents[agentId];

    _conversationBuilder.addUserMessage(
      agentId,
      content,
      attachments: attachments,
    );

    _hadInitialMessage = true;

    // Emit optimistic status event so UI shows the agent as working
    _hub.emit(
      StatusEvent(
        agentId: agentId,
        agentType: agentInfo?.type ?? 'main',
        agentName: agentInfo?.name,
        taskName: null,
        status: VideAgentStatus.working,
      ),
    );
  }

  void _initWithMainAgent(String? mainAgentId) {
    // Pre-populate main agent if provided (avoids "No agents" flash)
    if (mainAgentId != null) {
      _mainAgentId = mainAgentId;
      _agents[mainAgentId] = _RemoteAgentInfo(
        id: mainAgentId,
        type: 'main',
        name: 'Main',
      );
    }
  }

  /// Set up listening to the client session's event stream.
  void _setupEventListening() {
    final session = _clientSession;
    if (session == null) return;

    _eventSubscription = session.events.listen(
      _handleClientEvent,
      onError: (error) {
        _hub.emitError(error);
        if (!_connectCompleter.isCompleted) {
          _connectCompleter.completeError(error);
        }
      },
      onDone: () {
        if (!_hub.isDisposed) {
          _connected = false;
          _connectionStateController.add(false);
        }
      },
    );
  }

  /// Handle an event from the client session.
  ///
  /// If [skipSeqCheck] is true, deduplication is skipped (for history replay).
  /// If [isHistoryReplay] is true, messages are treated as complete (not accumulated).
  void _handleClientEvent(
    VideEvent event, {
    bool skipSeqCheck = false,
    bool isHistoryReplay = false,
  }) {
    // Deduplicate by seq (skip for history replay)
    if (!skipSeqCheck) {
      final seq = event.seq ?? 0;
      if (seq > 0 && seq <= _lastSeq) return;
      if (seq > 0) _lastSeq = seq;
    }

    switch (event) {
      case ConnectedEvent():
        _handleConnected(event);
      case HistoryEvent():
        _handleHistory(event);
      case MessageEvent():
        _handleMessage(event, isHistoryReplay: isHistoryReplay);
      case ToolUseEvent():
        _handleToolUse(event);
      case ToolResultEvent():
        _handleToolResult(event);
      case StatusEvent():
        _handleStatus(event);
      case TurnCompleteEvent():
        _handleDone(event);
      case ErrorEvent():
        _handleError(event);
      case AgentSpawnedEvent():
        _handleAgentSpawned(event);
      case AgentTerminatedEvent():
        _handleAgentTerminated(event);
      case PermissionRequestEvent():
        _handlePermissionRequest(event);
      case AskUserQuestionEvent():
        _handleAskUserQuestion(event);
      case TaskNameChangedEvent():
        _handleTaskNameChanged(event);
      case PermissionResolvedEvent():
        _handlePermissionResolved(event);
      case PlanApprovalRequestEvent():
        _handlePlanApprovalRequest(event);
      case PlanApprovalResolvedEvent():
        _handlePlanApprovalResolved(event);
      case AbortedEvent():
        _handleAborted(event);
      case CommandResultEvent():
        // Command results are handled inside Session.
        break;
      case UnknownEvent():
        // Ignore unknown events
        break;
    }
  }

  /// Handles a raw WebSocket message (for testing).
  ///
  /// This parses the JSON and routes to the appropriate handler,
  /// simulating what Session would do.
  @visibleForTesting
  void handleWebSocketMessage(dynamic message) {
    if (message is! String) return;

    final json = jsonDecode(message) as Map<String, dynamic>;
    final event = VideEvent.fromJson(json);
    _handleClientEvent(event);
  }

  /// Resolve agent type from local cache, falling back to the wire event.
  String _resolveAgentType(String agentId, VideEvent event) {
    return _agents[agentId]?.type ?? event.agentType;
  }

  /// Resolve agent name from local cache, falling back to the wire event.
  String? _resolveAgentName(String agentId, VideEvent event) {
    return _agents[agentId]?.name ?? event.agentName;
  }

  void _handleConnected(ConnectedEvent event) {
    _mainAgentId = event.mainAgentId;
    _lastSeq = event.lastSeq;
    _applyConnectedMetadata(event.metadata);

    // Remove stale placeholder agent (if any) before populating with real data.
    if (_pendingAgentIdToMigrate != null) {
      _agents.remove(_pendingAgentIdToMigrate);
    }

    // Parse agents list from connected event
    for (final agent in event.agents) {
      _agents[agent.id] = _RemoteAgentInfo(
        id: agent.id,
        type: agent.type,
        name: agent.name,
      );
      // If this session was created with an initial message, the main agent
      // is already processing it server-side. Set it to "working" so the
      // loading indicator appears immediately instead of briefly showing idle.
      final isMainWithInitialMessage =
          _hadInitialMessage && agent.id == event.mainAgentId;
      _agentStatuses[agent.id] = isMainWithInitialMessage
          ? VideAgentStatus.working
          : VideAgentStatus.idle;
      _refreshModel(agent.id);
      _refreshQueuedMessage(agent.id);
    }

    // Migrate pending conversation from placeholder to real main agent
    if (_pendingAgentIdToMigrate != null && _mainAgentId != null) {
      _conversationBuilder.migrateConversation(
        fromAgentId: _pendingAgentIdToMigrate!,
        toAgentId: _mainAgentId!,
      );
      _pendingAgentIdToMigrate = null;
    }

    _connected = true;
    _connectionStateController.add(true);
    _hub.emitState();
    if (!_connectCompleter.isCompleted) {
      _connectCompleter.complete();
    }
  }

  void _handleHistory(HistoryEvent event) {
    // Consolidate message events by eventId to avoid duplication from streaming chunks.
    final consolidatedEvents = _consolidateHistoryMessages(event.events);

    // Process consolidated history events without seq filtering
    for (final parsed in consolidatedEvents) {
      _handleClientEvent(parsed, skipSeqCheck: true, isHistoryReplay: true);
    }
    _lastSeq = event.lastSeq;
  }

  /// Consolidate streaming message events in history by eventId.
  List<VideEvent> _consolidateHistoryMessages(List<dynamic> rawEvents) {
    final result = <VideEvent>[];
    final messagesByEventId = <String, List<MessageEvent>>{};

    for (final rawEvent in rawEvents) {
      if (rawEvent is! Map<String, dynamic>) continue;
      final parsed = VideEvent.fromJson(rawEvent);

      if (parsed is MessageEvent) {
        messagesByEventId.putIfAbsent(parsed.eventId, () => []).add(parsed);
      } else {
        result.add(parsed);
      }
    }

    for (final messages in messagesByEventId.values) {
      final partials = messages.where((m) => m.isPartial).toList();
      final hasFinal = messages.any((m) => !m.isPartial);
      final representative = messages.last;

      final content = partials.isNotEmpty
          ? partials.map((m) => m.content).join()
          : representative.content;

      result.add(
        MessageEvent(
          seq: representative.seq,
          agentId: representative.agentId,
          agentType: representative.agentType,
          agentName: representative.agentName,
          taskName: representative.taskName,
          eventId: representative.eventId,
          timestamp: representative.timestamp,
          role: representative.role,
          content: content,
          isPartial: !hasFinal,
        ),
      );
    }

    result.sort((a, b) => (a.seq ?? 0).compareTo(b.seq ?? 0));
    return result;
  }

  void _handleMessage(MessageEvent event, {bool isHistoryReplay = false}) {
    final agentId = event.agentId;
    final eventId = event.eventId;
    final role = event.role == 'user' ? 'user' : 'assistant';

    _conversationBuilder.handleMessage(
      agentId: agentId,
      eventId: eventId,
      role: role,
      content: event.content,
      isPartial: event.isPartial,
      isHistoryReplay: isHistoryReplay,
    );

    _hub.emit(
      MessageEvent(
        agentId: agentId,
        agentType: _resolveAgentType(agentId, event),
        agentName: _resolveAgentName(agentId, event),
        taskName: event.taskName,
        eventId: eventId,
        role: role,
        content: event.content,
        isPartial: event.isPartial,
      ),
    );
  }

  void _handleToolUse(ToolUseEvent event) {
    final agentId = event.agentId;

    _conversationBuilder.handleToolUse(
      agentId: agentId,
      toolUseId: event.toolUseId,
      toolName: event.toolName,
      toolInput: event.toolInput,
    );

    _hub.emit(
      ToolUseEvent(
        agentId: agentId,
        agentType: _resolveAgentType(agentId, event),
        agentName: _resolveAgentName(agentId, event),
        taskName: event.taskName,
        toolUseId: event.toolUseId,
        toolName: event.toolName,
        toolInput: event.toolInput,
      ),
    );
  }

  void _handleToolResult(ToolResultEvent event) {
    final agentId = event.agentId;
    final resultStr = event.result;

    _conversationBuilder.handleToolResult(
      agentId: agentId,
      toolUseId: event.toolUseId,
      result: resultStr,
      isError: event.isError,
    );

    _hub.emit(
      ToolResultEvent(
        agentId: agentId,
        agentType: _resolveAgentType(agentId, event),
        agentName: _resolveAgentName(agentId, event),
        taskName: event.taskName,
        toolUseId: event.toolUseId,
        toolName: event.toolName,
        result: resultStr,
        isError: event.isError,
      ),
    );
  }

  void _handleStatus(StatusEvent event) {
    final agentId = event.agentId;

    _agentStatuses[agentId] = event.status;
    _refreshQueuedMessage(agentId);
    _refreshModel(agentId);

    _hub.emit(
      StatusEvent(
        agentId: agentId,
        agentType: _resolveAgentType(agentId, event),
        agentName: _resolveAgentName(agentId, event),
        taskName: event.taskName,
        status: event.status,
      ),
    );
    _hub.emitState();
  }

  void _handleDone(TurnCompleteEvent event) {
    final agentId = event.agentId;
    _agentStatuses[agentId] = VideAgentStatus.idle;
    _refreshQueuedMessage(agentId);

    _conversationBuilder.markAssistantTurnComplete(agentId);

    _hub.emit(
      TurnCompleteEvent(
        agentId: agentId,
        agentType: _resolveAgentType(agentId, event),
        agentName: _resolveAgentName(agentId, event),
        taskName: event.taskName,
        reason: event.reason,
      ),
    );
    _hub.emitState();
  }

  void _handleError(ErrorEvent event) {
    final agentId = event.agentId;

    _hub.emit(
      ErrorEvent(
        agentId: agentId,
        agentType: _resolveAgentType(agentId, event),
        agentName: _resolveAgentName(agentId, event),
        taskName: event.taskName,
        message: event.message,
        code: event.code,
      ),
    );
  }

  void _handleAgentSpawned(AgentSpawnedEvent event) {
    final agentId = event.agentId;

    // Skip if agent already exists (e.g. from ConnectedEvent before history replay).
    if (_agents.containsKey(agentId)) return;

    _agents[agentId] = _RemoteAgentInfo(
      id: agentId,
      type: event.agentType,
      name: event.agentName,
    );
    _agentStatuses[agentId] = VideAgentStatus.idle;
    _refreshModel(agentId);
    _refreshQueuedMessage(agentId);

    _hub.emit(
      AgentSpawnedEvent(
        agentId: agentId,
        agentType: _resolveAgentType(agentId, event),
        agentName: _resolveAgentName(agentId, event),
        taskName: event.taskName,
        spawnedBy: event.spawnedBy,
      ),
    );
    _hub.emitState();
  }

  void _handleAgentTerminated(AgentTerminatedEvent event) {
    final agentId = event.agentId;
    // Resolve before removing from cache.
    final agentType = _resolveAgentType(agentId, event);
    final agentName = _resolveAgentName(agentId, event);

    _agents.remove(agentId);
    _agentStatuses.remove(agentId);
    _models.remove(agentId);
    _queuedMessages.remove(agentId);
    _modelRefreshInFlight.remove(agentId);
    _queuedRefreshInFlight.remove(agentId);
    unawaited(_modelControllers.remove(agentId)?.close());
    unawaited(_queuedMessageControllers.remove(agentId)?.close());
    _conversationBuilder.removeAgent(agentId);

    _hub.emit(
      AgentTerminatedEvent(
        agentId: agentId,
        agentType: agentType,
        agentName: agentName,
        taskName: event.taskName,
        reason: event.reason,
        terminatedBy: event.terminatedBy,
      ),
    );
    _hub.emitState();
  }

  void _handlePermissionRequest(PermissionRequestEvent event) {
    final agentId = event.agentId;

    // Store pending permission so it survives across UI lifecycle
    final enrichedEvent = PermissionRequestEvent(
      agentId: agentId,
      agentType: _resolveAgentType(agentId, event),
      agentName: _resolveAgentName(agentId, event),
      taskName: event.taskName,
      requestId: event.requestId,
      toolName: event.toolName,
      toolInput: event.toolInput,
      inferredPattern: event.inferredPattern,
    );
    _pendingPermissionRequest = enrichedEvent;

    _hub.emit(enrichedEvent);
  }

  void _handleAskUserQuestion(AskUserQuestionEvent event) {
    final agentId = event.agentId;

    _hub.emit(
      AskUserQuestionEvent(
        agentId: agentId,
        agentType: _resolveAgentType(agentId, event),
        agentName: _resolveAgentName(agentId, event),
        taskName: event.taskName,
        requestId: event.requestId,
        questions: event.questions,
      ),
    );
  }

  void _handleTaskNameChanged(TaskNameChangedEvent event) {
    final agentId = event.agentId.isNotEmpty
        ? event.agentId
        : (_mainAgentId ?? '');
    final previousGoal = _goal;
    _goal = event.newGoal;

    _hub.emit(
      TaskNameChangedEvent(
        agentId: agentId,
        agentType: _resolveAgentType(agentId, event),
        agentName: _resolveAgentName(agentId, event),
        taskName: event.taskName,
        newGoal: event.newGoal,
        previousGoal: event.previousGoal ?? previousGoal,
      ),
    );
    _hub.emitState();
  }

  void _handlePermissionResolved(PermissionResolvedEvent event) {
    // Clean up any local pending state
    _pendingPermissions.remove(event.requestId);

    // Clear stored pending permission if it matches
    if (_pendingPermissionRequest?.requestId == event.requestId) {
      _pendingPermissionRequest = null;
    }

    // Re-emit so UI consumers (mobile app) can dismiss stale permission dialogs
    _hub.emit(
      PermissionResolvedEvent(
        agentId: event.agentId,
        agentType: _resolveAgentType(event.agentId, event),
        agentName: _resolveAgentName(event.agentId, event),
        taskName: event.taskName,
        requestId: event.requestId,
        allow: event.allow,
        message: event.message,
      ),
    );
  }

  void _handlePlanApprovalRequest(PlanApprovalRequestEvent event) {
    final agentId = event.agentId;

    _hub.emit(
      PlanApprovalRequestEvent(
        agentId: agentId,
        agentType: _resolveAgentType(agentId, event),
        agentName: _resolveAgentName(agentId, event),
        taskName: event.taskName,
        requestId: event.requestId,
        planContent: event.planContent,
        allowedPrompts: event.allowedPrompts,
      ),
    );
  }

  void _handlePlanApprovalResolved(PlanApprovalResolvedEvent event) {
    _hub.emit(
      PlanApprovalResolvedEvent(
        agentId: event.agentId,
        agentType: _resolveAgentType(event.agentId, event),
        agentName: _resolveAgentName(event.agentId, event),
        taskName: event.taskName,
        requestId: event.requestId,
        action: event.action,
        feedback: event.feedback,
      ),
    );
  }

  void _handleAborted(AbortedEvent event) {
    final agentId = event.agentId;
    _agentStatuses[agentId] = VideAgentStatus.idle;
    _refreshQueuedMessage(agentId);

    _hub.emit(
      TurnCompleteEvent(
        agentId: agentId,
        agentType: _resolveAgentType(agentId, event),
        agentName: _resolveAgentName(agentId, event),
        taskName: event.taskName,
        reason: 'aborted',
      ),
    );
    _hub.emitState();
  }

  StreamController<String?> _getOrCreateQueuedMessageController(
    String agentId,
  ) {
    return _queuedMessageControllers.putIfAbsent(
      agentId,
      () => StreamController<String?>.broadcast(),
    );
  }

  StreamController<String?> _getOrCreateModelController(String agentId) {
    return _modelControllers.putIfAbsent(
      agentId,
      () => StreamController<String?>.broadcast(),
    );
  }

  /// Best-effort refresh of a cached per-agent value.
  void _refreshCached<T>({
    required String agentId,
    required Map<String, T?> cache,
    required Set<String> inFlight,
    required StreamController<T?> Function(String) getController,
    required Future<T?> Function(Session, String) fetch,
  }) {
    final session = _clientSession;
    if (session == null) return;
    if (!inFlight.add(agentId)) return;
    unawaited(() async {
      try {
        final value = await fetch(session, agentId);
        if (_hub.isDisposed) return;
        if (cache[agentId] != value) {
          cache[agentId] = value;
          getController(agentId).add(value);
        }
      } catch (_) {
        // Best-effort cache refresh.
      } finally {
        inFlight.remove(agentId);
      }
    }());
  }

  void _refreshQueuedMessage(String agentId) => _refreshCached(
    agentId: agentId,
    cache: _queuedMessages,
    inFlight: _queuedRefreshInFlight,
    getController: _getOrCreateQueuedMessageController,
    fetch: (s, id) => s.getQueuedMessage(id),
  );

  void _refreshModel(String agentId) => _refreshCached(
    agentId: agentId,
    cache: _models,
    inFlight: _modelRefreshInFlight,
    getController: _getOrCreateModelController,
    fetch: (s, id) => s.getModel(id),
  );

  void _applyConnectedMetadata(Map<String, dynamic> metadata) {
    final workingDirectory = metadata['working-directory'] as String?;
    if (workingDirectory != null && workingDirectory.isNotEmpty) {
      _workingDirectory = workingDirectory;
    }

    final team = metadata['team'] as String?;
    if (team != null && team.isNotEmpty) {
      _team = team;
    }

    final goal = metadata['goal'] as String?;
    if (goal != null && goal.isNotEmpty && goal != _goal) {
      _goal = goal;
    }
  }

  // ============================================================
  // State management
  // ============================================================

  /// Build the current list of agents from internal tracking maps.
  List<VideAgent> _buildAgents() {
    return _agents.values
        .map(
          (a) => VideAgent(
            id: a.id,
            name: a.name ?? a.type,
            type: a.type,
            status: _agentStatuses[a.id] ?? VideAgentStatus.idle,
            createdAt: DateTime.now(),
          ),
        )
        .toList();
  }

  /// Build the current immutable state snapshot.
  VideState _buildState() {
    return VideState(
      id: _sessionId,
      agents: _buildAgents(),
      agentConversationStates: _hub.agentConversationStateSnapshot,
      team: _team,
      goal: _goal,
      workingDirectory: _workingDirectory,
      isProcessing: _agentStatuses.values.any((s) => s != VideAgentStatus.idle),
    );
  }

  // ============================================================
  // VideSession interface implementation
  // ============================================================

  @override
  String get id => _sessionId;

  @override
  ConversationStateManager get conversationState =>
      _hub.conversationStateManager;

  @override
  VideState get state => _hub.state;

  @override
  Stream<VideState> get stateStream => _hub.stateStream;

  @override
  Stream<VideEvent> get events => _hub.events;

  @override
  void sendMessage(VideMessage message, {String? agentId}) {
    _hub.checkNotDisposed();
    final targetAgentId = agentId ?? _mainAgentId;
    _clientSession?.sendMessage(
      message.text,
      agentId: targetAgentId,
      attachments: message.attachments,
    );

    // Optimistically add the user message for immediate display.
    if (targetAgentId != null) {
      _conversationBuilder.addUserMessage(
        targetAgentId,
        message.text,
        attachments: message.attachments,
      );
    }

    // Optimistically set agent status to working so loading indicators
    // appear immediately, before the server sends back a StatusEvent.
    if (targetAgentId != null &&
        _agentStatuses[targetAgentId] == VideAgentStatus.idle) {
      _agentStatuses[targetAgentId] = VideAgentStatus.working;
      _hub.emitState();
    }

    // Optimistically reflect queued message when agent is already busy.
    if (targetAgentId != null &&
        (_agentStatuses[targetAgentId] == VideAgentStatus.working ||
            _agentStatuses[targetAgentId] == VideAgentStatus.waitingForAgent ||
            _agentStatuses[targetAgentId] == VideAgentStatus.waitingForUser)) {
      _queuedMessages[targetAgentId] = message.text;
      _getOrCreateQueuedMessageController(targetAgentId).add(message.text);
    }
  }

  @override
  void respondToPermission(
    String requestId, {
    required bool allow,
    String? message,
    bool remember = false,
    String? patternOverride,
  }) {
    _hub.checkNotDisposed();
    _clientSession?.respondToPermission(
      requestId: requestId,
      allow: allow,
      message: message,
      remember: remember,
      patternOverride: patternOverride,
    );
  }

  @override
  Future<void> abort() async {
    _hub.checkNotDisposed();
    _clientSession?.abort();
  }

  @override
  Future<void> abortAgent(String agentId) async {
    _hub.checkNotDisposed();
    final session = _clientSession;
    if (session == null) return;
    await session.abortAgent(agentId);
  }

  @override
  Future<void> dispose({bool fireEndTrigger = true}) async {
    if (_hub.isDisposed) return;

    await _eventSubscription?.cancel();
    await _clientSession?.close();
    _clientSession = null;

    // Complete pending permissions
    for (final completer in _pendingPermissions.values) {
      if (!completer.isCompleted) {
        completer.complete(
          const VidePermissionDeny(message: 'Session disposed'),
        );
      }
    }
    _pendingPermissions.clear();

    // Dispose hub (also closes _stateController and sets _disposed)
    _hub.dispose();
    _conversationBuilder.dispose();

    for (final controller in _queuedMessageControllers.values) {
      await controller.close();
    }
    _queuedMessageControllers.clear();

    for (final controller in _modelControllers.values) {
      await controller.close();
    }
    _modelControllers.clear();

    await _connectionStateController.close();

    _models.clear();
    _queuedMessages.clear();
    _agentStatuses.clear();
    _modelRefreshInFlight.clear();
    _queuedRefreshInFlight.clear();
  }

  // ============================================================
  // Methods with remote transport-specific behavior
  // ============================================================

  @override
  Future<void> clearConversation({String? agentId}) async {
    _hub.checkNotDisposed();
    final session = _clientSession;
    if (session == null) return;

    final targetAgentId = agentId ?? _mainAgentId;
    await session.clearConversation(agentId: targetAgentId);

    if (targetAgentId != null) {
      _conversationBuilder.clearConversation(targetAgentId);
    }
  }

  @override
  Future<void> setWorktreePath(String? path) async {
    _hub.checkNotDisposed();
    final session = _clientSession;
    if (session == null) return;
    final result = await session.setWorktreePath(path);
    final newDir = result?['working-directory'] as String? ?? _workingDirectory;
    if (newDir != _workingDirectory) {
      _workingDirectory = newDir;
      _hub.emitState();
    }
  }

  @override
  VideConversation? getConversation(String agentId) {
    return _conversationBuilder.getConversation(agentId);
  }

  @override
  Stream<VideConversation> conversationStream(String agentId) {
    return _conversationBuilder.conversationStream(agentId);
  }

  @override
  void updateAgentTokenStats(
    String agentId, {
    required int totalInputTokens,
    required int totalOutputTokens,
    required int totalCacheReadInputTokens,
    required int totalCacheCreationInputTokens,
    required double totalCostUsd,
  }) {
    // Stats are tracked server-side
  }

  @override
  Future<void> terminateAgent(
    String agentId, {
    required String terminatedBy,
    String? reason,
  }) async {
    _hub.checkNotDisposed();
    final session = _clientSession;
    if (session == null) return;
    await session.terminateAgent(
      agentId: agentId,
      terminatedBy: terminatedBy,
      reason: reason,
    );
  }

  @override
  Future<String> forkAgent(String agentId, {String? name}) async {
    _hub.checkNotDisposed();
    final session = _clientSession;
    if (session == null) {
      throw StateError('Remote session is not connected');
    }
    return await session.forkAgent(agentId, name: name);
  }

  @override
  Future<String> spawnAgent({
    required String agentType,
    required String name,
    required String initialPrompt,
    required String spawnedBy,
  }) async {
    _hub.checkNotDisposed();
    final session = _clientSession;
    if (session == null) {
      throw StateError('Remote session is not connected');
    }
    return await session.spawnAgent(
      agentType: agentType,
      name: name,
      initialPrompt: initialPrompt,
      spawnedBy: spawnedBy,
    );
  }

  @override
  Future<String?> getQueuedMessage(String agentId) async {
    _hub.checkNotDisposed();
    final session = _clientSession;
    if (session == null) return _queuedMessages[agentId];

    final queuedMessage = await session.getQueuedMessage(agentId);
    if (_queuedMessages[agentId] != queuedMessage) {
      _queuedMessages[agentId] = queuedMessage;
      _getOrCreateQueuedMessageController(agentId).add(queuedMessage);
    }
    return queuedMessage;
  }

  @override
  Stream<String?> queuedMessageStream(String agentId) {
    _refreshQueuedMessage(agentId);
    return _getOrCreateQueuedMessageController(agentId).stream;
  }

  @override
  Future<void> clearQueuedMessage(String agentId) async {
    _hub.checkNotDisposed();
    final session = _clientSession;
    if (session == null) return;
    await session.clearQueuedMessage(agentId);
    _queuedMessages[agentId] = null;
    _getOrCreateQueuedMessageController(agentId).add(null);
  }

  @override
  Future<String?> getModel(String agentId) async {
    _hub.checkNotDisposed();
    final session = _clientSession;
    if (session == null) return _models[agentId];

    final model = await session.getModel(agentId);
    if (_models[agentId] != model) {
      _models[agentId] = model;
      _getOrCreateModelController(agentId).add(model);
    }
    return model;
  }

  @override
  Stream<String?> modelStream(String agentId) {
    _refreshModel(agentId);
    return _getOrCreateModelController(agentId).stream;
  }

  @override
  VideCanUseToolCallback createPermissionCallback({
    required String agentId,
    required String? agentName,
    required String? agentType,
    required String cwd,
    String? permissionMode,
  }) {
    // Remote sessions execute permission checks server-side.
    return (
      String toolName,
      Map<String, dynamic> input,
      VidePermissionContext context,
    ) async {
      return const VidePermissionDeny(
        message:
            'Local permission callback is unavailable for transport-backed sessions',
      );
    };
  }

  @override
  void respondToAskUserQuestion(
    String requestId, {
    required Map<String, String> answers,
  }) {
    _hub.checkNotDisposed();
    _clientSession?.respondToAskUserQuestion(
      requestId: requestId,
      answers: answers,
    );
  }

  @override
  void respondToPlanApproval(
    String requestId, {
    required String action,
    String? feedback,
  }) {
    _hub.checkNotDisposed();
    _clientSession?.respondToPlanApproval(
      requestId: requestId,
      action: action,
      feedback: feedback,
    );
  }

  @override
  Future<void> addSessionPermissionPattern(String pattern) async {
    _hub.checkNotDisposed();
    final session = _clientSession;
    if (session == null) return;
    await session.addSessionPermissionPattern(pattern);
  }

  @override
  Future<bool> isAllowedBySessionCache(
    String toolName,
    Map<String, dynamic> input,
  ) async {
    _hub.checkNotDisposed();
    final session = _clientSession;
    if (session == null) return false;
    return await session.isAllowedBySessionCache(toolName, input);
  }

  @override
  Future<void> clearSessionPermissionCache() async {
    _hub.checkNotDisposed();
    final session = _clientSession;
    if (session == null) return;
    await session.clearSessionPermissionCache();
  }
}

/// Tracks info about a remote agent.
class _RemoteAgentInfo {
  final String id;
  final String type;
  final String? name;

  _RemoteAgentInfo({required this.id, required this.type, this.name});
}
