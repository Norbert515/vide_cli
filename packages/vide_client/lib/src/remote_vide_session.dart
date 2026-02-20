import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';
import 'package:vide_interface/vide_interface.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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

  /// Resolve the pending session with a connected WebSocket transport.
  void completeWithConnection({
    required String sessionId,
    required WebSocketChannel channel,
  }) {
    _session.completePending(TransportSession(id: sessionId, channel: channel));
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

/// Create a [VideSession] from a WebSocket connection.
VideSession createRemoteVideSession({
  required String sessionId,
  required WebSocketChannel channel,
  String? mainAgentId,
}) {
  return RemoteVideSession.fromConnection(
    sessionId: sessionId,
    channel: channel,
    mainAgentId: mainAgentId,
  );
}

/// A VideSession that connects to a remote vide_server via WebSocket.
///
/// Wraps an internal transport layer and adds:
/// - Conversation state management (accumulates streaming message deltas)
/// - Agent tracking
/// - Event adaptation from wire format to business events
///
/// ## Usage
///
/// ```dart
/// final client = VideClient(port: 8080);
/// final session = await client.createSession(
///   initialMessage: 'Hello',
///   workingDirectory: '/path/to/project',
/// );
///
/// // Listen to accumulated conversation state
/// final agentId = session.state.agents.first.id;
/// session.conversationStream(agentId).listen((agentState) {
///   for (final entry in agentState.messages) {
///     print(entry.text); // Full accumulated text, not deltas
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
/// pending.completeWithConnection(sessionId: id, channel: channel);
/// ```
class RemoteVideSession implements VideSession {
  String _sessionId;
  TransportSession? _clientSession;
  StreamSubscription<VideEvent>? _eventSubscription;

  /// Direct event pipeline (replaces SessionEventHub).
  final StreamController<VideEvent> _eventController =
      StreamController<VideEvent>.broadcast(sync: true);
  final ConversationStateManager _conversationState =
      ConversationStateManager();
  final StreamController<VideState> _stateController =
      StreamController<VideState>.broadcast();
  bool _disposed = false;

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

  /// Agents that have optimistic "working" status from a client-side sendMessage.
  ///
  /// When the client sends a message, it optimistically sets the agent to
  /// "working" before the server confirms. During this window, stale
  /// `StatusEvent(idle)` from the server (emitted before the server processed
  /// the user's message) must be ignored to prevent a brief loading flicker.
  ///
  /// The flag is cleared when:
  /// - A non-idle `StatusEvent` arrives (server confirmed processing)
  /// - A `TurnCompleteEvent` arrives (turn genuinely completed)
  final Set<String> _optimisticWorking = {};

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

  /// Create a RemoteVideSession from a WebSocket connection.
  RemoteVideSession.fromConnection({
    required String sessionId,
    required WebSocketChannel channel,
    String? mainAgentId,
  }) : _sessionId = sessionId,
       _clientSession = TransportSession(id: sessionId, channel: channel) {
    _eventController.stream.listen(_conversationState.handleEvent);
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
    _eventController.stream.listen(_conversationState.handleEvent);
    // Pre-populate with a placeholder main agent shown while connecting.
    final placeholderId = const Uuid().v4();
    _mainAgentId = placeholderId;
    _agents[placeholderId] = _RemoteAgentInfo(
      id: placeholderId,
      type: 'main',
      name: 'Main',
    );
    _agentStatuses[placeholderId] = VideAgentStatus.working;
  }

  /// Complete a pending session with an actual transport session.
  void completePending(TransportSession clientSession) {
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
        name: 'Connection failed',
      );
      _agentStatuses[_mainAgentId!] = VideAgentStatus.idle;
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

    // Emit a user message event so ConversationStateManager picks it up
    _emit(
      MessageEvent(
        agentId: agentId,
        agentType: agentInfo?.type ?? 'main',
        agentName: agentInfo?.name,
        eventId: const Uuid().v4(),
        role: 'user',
        content: content,
        isPartial: false,
        attachments: attachments,
      ),
    );

    _hadInitialMessage = true;

    // Set optimistic working status so _buildState().isProcessing is true
    // immediately (not just after the server's ConnectedEvent arrives).
    _agentStatuses[agentId] = VideAgentStatus.working;

    // Emit optimistic status event so ConversationStateManager also picks it up
    _emit(
      StatusEvent(
        agentId: agentId,
        agentType: agentInfo?.type ?? 'main',
        agentName: agentInfo?.name,
        taskName: null,
        status: VideAgentStatus.working,
      ),
    );

    _emitState();
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
        _eventController.addError(error);
        if (!_connectCompleter.isCompleted) {
          _connectCompleter.completeError(error);
        }
      },
      onDone: () {
        if (!_disposed) {
          _connected = false;
          _connectionStateController.add(false);
        }
      },
    );
  }

  /// Reconnect this session with a new WebSocket transport.
  ///
  /// This swaps the underlying transport without creating a new
  /// [RemoteVideSession] instance, so all UI references, event subscriptions,
  /// and conversation state are preserved. The new transport's
  /// ConnectedEvent + HistoryEvent will update agent list, statuses, and
  /// replay any events that were missed during the disconnect.
  void reconnect({
    required String sessionId,
    required WebSocketChannel channel,
  }) {
    if (_disposed) return;

    // Tear down old transport
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _clientSession?.close();

    // Swap transport
    _clientSession = TransportSession(id: sessionId, channel: channel);
    _connected = false;

    // Set up event listening on the new transport.
    // ConnectedEvent will restore agent list/statuses, and HistoryEvent
    // will replay any missed events.
    _setupEventListening();
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
      case AskUserQuestionResolvedEvent():
        _handleAskUserQuestionResolved(event);
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

    // Clear any optimistic working guards — history replay will reconstruct
    // the correct status from authoritative server events.
    _optimisticWorking.clear();

    // Remove stale placeholder agent (if any) before populating with real data.
    if (_pendingAgentIdToMigrate != null) {
      _agents.remove(_pendingAgentIdToMigrate);
    }

    // Parse agents list from connected event.
    // All agents start as idle; history replay will set the correct final
    // status by replaying all StatusEvents/TurnCompleteEvents in order.
    for (final agent in event.agents) {
      _agents[agent.id] = _RemoteAgentInfo(
        id: agent.id,
        type: agent.type,
        name: agent.name,
        spawnedBy: agent.spawnedBy,
      );

      final isMainWithInitialMessage =
          _hadInitialMessage && agent.id == event.mainAgentId;
      _agentStatuses[agent.id] = isMainWithInitialMessage
          ? VideAgentStatus.working
          : VideAgentStatus.idle;
      _refreshModel(agent.id);
      _refreshQueuedMessage(agent.id);
    }

    _pendingAgentIdToMigrate = null;

    _connected = true;
    _connectionStateController.add(true);
    _emitState();
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

    _emit(
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

    _emit(
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

    _emit(
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

    // During the optimistic working window, ignore idle status events from the
    // server — they are stale events from before the server processed the
    // client's message. Any non-idle status clears the guard since it proves
    // the server is actively processing.
    if (_optimisticWorking.contains(agentId)) {
      if (event.status == VideAgentStatus.idle) {
        return;
      }
      _optimisticWorking.remove(agentId);
    }

    _agentStatuses[agentId] = event.status;
    _refreshQueuedMessage(agentId);
    _refreshModel(agentId);

    _emit(
      StatusEvent(
        agentId: agentId,
        agentType: _resolveAgentType(agentId, event),
        agentName: _resolveAgentName(agentId, event),
        taskName: event.taskName,
        status: event.status,
      ),
    );
    _emitState();
  }

  void _handleDone(TurnCompleteEvent event) {
    final agentId = event.agentId;

    // Turn genuinely completed — clear optimistic guard if any.
    _optimisticWorking.remove(agentId);

    _agentStatuses[agentId] = VideAgentStatus.idle;
    _refreshQueuedMessage(agentId);

    _emit(
      TurnCompleteEvent(
        agentId: agentId,
        agentType: _resolveAgentType(agentId, event),
        agentName: _resolveAgentName(agentId, event),
        taskName: event.taskName,
        reason: event.reason,
      ),
    );
    _emitState();
  }

  void _handleError(ErrorEvent event) {
    final agentId = event.agentId;

    _emit(
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

    // If agent already exists (e.g. from ConnectedEvent before history replay),
    // update spawnedBy if it was missing (ConnectedEvent doesn't carry it).
    if (_agents.containsKey(agentId)) {
      final existing = _agents[agentId]!;
      if (existing.spawnedBy == null && event.spawnedBy.isNotEmpty) {
        _agents[agentId] = _RemoteAgentInfo(
          id: existing.id,
          type: existing.type,
          name: existing.name,
          spawnedBy: event.spawnedBy,
        );
        _emitState();
      }
      return;
    }

    _agents[agentId] = _RemoteAgentInfo(
      id: agentId,
      type: event.agentType,
      name: event.agentName,
      spawnedBy: event.spawnedBy.isNotEmpty ? event.spawnedBy : null,
    );
    _agentStatuses[agentId] = VideAgentStatus.idle;
    _refreshModel(agentId);
    _refreshQueuedMessage(agentId);

    _emit(
      AgentSpawnedEvent(
        agentId: agentId,
        agentType: _resolveAgentType(agentId, event),
        agentName: _resolveAgentName(agentId, event),
        taskName: event.taskName,
        spawnedBy: event.spawnedBy,
      ),
    );
    _emitState();
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
    _emit(
      AgentTerminatedEvent(
        agentId: agentId,
        agentType: agentType,
        agentName: agentName,
        taskName: event.taskName,
        reason: event.reason,
        terminatedBy: event.terminatedBy,
      ),
    );
    _emitState();
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

    _emit(enrichedEvent);
  }

  void _handleAskUserQuestion(AskUserQuestionEvent event) {
    final agentId = event.agentId;

    _emit(
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

  void _handleAskUserQuestionResolved(AskUserQuestionResolvedEvent event) {
    _emit(
      AskUserQuestionResolvedEvent(
        agentId: event.agentId,
        agentType: _resolveAgentType(event.agentId, event),
        agentName: _resolveAgentName(event.agentId, event),
        taskName: event.taskName,
        requestId: event.requestId,
        answers: event.answers,
      ),
    );
  }

  void _handleTaskNameChanged(TaskNameChangedEvent event) {
    final agentId = event.agentId.isNotEmpty
        ? event.agentId
        : (_mainAgentId ?? '');
    final previousGoal = _goal;
    _goal = event.newGoal;

    _emit(
      TaskNameChangedEvent(
        agentId: agentId,
        agentType: _resolveAgentType(agentId, event),
        agentName: _resolveAgentName(agentId, event),
        taskName: event.taskName,
        newGoal: event.newGoal,
        previousGoal: event.previousGoal ?? previousGoal,
      ),
    );
    _emitState();
  }

  void _handlePermissionResolved(PermissionResolvedEvent event) {
    // Clean up any local pending state
    _pendingPermissions.remove(event.requestId);

    // Clear stored pending permission if it matches
    if (_pendingPermissionRequest?.requestId == event.requestId) {
      _pendingPermissionRequest = null;
    }

    // Re-emit so UI consumers (mobile app) can dismiss stale permission dialogs
    _emit(
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

    _emit(
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
    _emit(
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

    // Abort is authoritative — clear optimistic guard.
    _optimisticWorking.remove(agentId);

    _agentStatuses[agentId] = VideAgentStatus.idle;
    _refreshQueuedMessage(agentId);

    _emit(
      TurnCompleteEvent(
        agentId: agentId,
        agentType: _resolveAgentType(agentId, event),
        agentName: _resolveAgentName(agentId, event),
        taskName: event.taskName,
        reason: 'aborted',
      ),
    );
    _emitState();
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
    required Future<T?> Function(TransportSession, String) fetch,
  }) {
    final session = _clientSession;
    if (session == null) return;
    if (!inFlight.add(agentId)) return;
    unawaited(() async {
      try {
        final value = await fetch(session, agentId);
        if (_disposed) return;
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
            spawnedBy: a.spawnedBy,
          ),
        )
        .toList();
  }

  /// Build a snapshot of per-agent conversation states.
  List<AgentConversationState> get _agentConversationStateSnapshot {
    return _conversationState.agentIds
        .map((id) => _conversationState.getAgentState(id))
        .whereType<AgentConversationState>()
        .toList();
  }

  /// Build the current immutable state snapshot.
  VideState _buildState() {
    return VideState(
      id: _sessionId,
      agents: _buildAgents(),
      agentConversationStates: _agentConversationStateSnapshot,
      team: _team,
      goal: _goal,
      workingDirectory: _workingDirectory,
      isProcessing: _agentStatuses.values.any((s) => s != VideAgentStatus.idle),
    );
  }

  void _emit(VideEvent event) => _eventController.add(event);

  void _emitState() {
    if (!_disposed) {
      _stateController.add(_buildState());
    }
  }

  void _checkNotDisposed() {
    if (_disposed) {
      throw StateError('Session has been disposed');
    }
  }

  // ============================================================
  // VideSession interface implementation
  // ============================================================

  @override
  String get id => _sessionId;

  @override
  ConversationStateManager get conversationState => _conversationState;

  @override
  VideState get state => _buildState();

  @override
  Stream<VideState> get stateStream => _stateController.stream;

  @override
  Stream<VideEvent> get events => _eventController.stream;

  @override
  List<VideEvent> get eventHistory => _conversationState.eventHistory;

  @override
  void sendMessage(VideMessage message, {String? agentId}) {
    _checkNotDisposed();
    final targetAgentId = agentId ?? _mainAgentId;
    _clientSession?.sendMessage(
      message.text,
      agentId: targetAgentId,
      attachments: message.attachments,
    );

    if (targetAgentId == null) return;

    final isIdle = _agentStatuses[targetAgentId] == VideAgentStatus.idle;

    if (isIdle) {
      // Agent is idle — message will be processed immediately.
      // Optimistically show the user message and set status to working.
      _emit(
        MessageEvent(
          agentId: targetAgentId,
          agentType: _agents[targetAgentId]?.type ?? 'unknown',
          agentName: _agents[targetAgentId]?.name,
          eventId: const Uuid().v4(),
          role: 'user',
          content: message.text,
          isPartial: false,
          attachments: message.attachments,
        ),
      );
      _agentStatuses[targetAgentId] = VideAgentStatus.working;
      _optimisticWorking.add(targetAgentId);
      _emitState();
    } else {
      // Agent is busy — message will be queued server-side.
      // Don't add it to the conversation yet; the server will emit the user
      // message event when the queue is flushed and the message is processed.
      // Only update the queued message indicator.
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
    _checkNotDisposed();
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
    _checkNotDisposed();
    _clientSession?.abort();
  }

  @override
  Future<void> abortAgent(String agentId) async {
    _checkNotDisposed();
    final session = _clientSession;
    if (session == null) return;
    await session.abortAgent(agentId);
  }

  @override
  Future<void> dispose({bool fireEndTrigger = true}) async {
    if (_disposed) return;

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

    // Dispose resources
    _disposed = true;
    _conversationState.dispose();
    _eventController.close();
    _stateController.close();

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
    _checkNotDisposed();
    final session = _clientSession;
    if (session == null) return;

    final targetAgentId = agentId ?? _mainAgentId;
    await session.clearConversation(agentId: targetAgentId);

    // ConversationStateManager doesn't have per-agent clear, but the server
    // handles the actual clear. A fresh conversation will be built from new events.
  }

  @override
  Future<void> setWorktreePath(String? path) async {
    _checkNotDisposed();
    final session = _clientSession;
    if (session == null) return;
    final result = await session.setWorktreePath(path);
    final newDir = result?['working-directory'] as String? ?? _workingDirectory;
    if (newDir != _workingDirectory) {
      _workingDirectory = newDir;
      _emitState();
    }
  }

  @override
  AgentConversationState? getConversation(String agentId) {
    return _conversationState.getAgentState(agentId);
  }

  @override
  Stream<AgentConversationState> conversationStream(String agentId) {
    return _conversationState.agentStream(agentId);
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
    _checkNotDisposed();
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
    _checkNotDisposed();
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
    _checkNotDisposed();
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
    _checkNotDisposed();
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
    _checkNotDisposed();
    final session = _clientSession;
    if (session == null) return;
    await session.clearQueuedMessage(agentId);
    _queuedMessages[agentId] = null;
    _getOrCreateQueuedMessageController(agentId).add(null);
  }

  @override
  Future<String?> getModel(String agentId) async {
    _checkNotDisposed();
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
    _checkNotDisposed();
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
    _checkNotDisposed();
    _clientSession?.respondToPlanApproval(
      requestId: requestId,
      action: action,
      feedback: feedback,
    );
  }

  @override
  Future<void> addSessionPermissionPattern(String pattern) async {
    _checkNotDisposed();
    final session = _clientSession;
    if (session == null) return;
    await session.addSessionPermissionPattern(pattern);
  }

  @override
  Future<bool> isAllowedBySessionCache(
    String toolName,
    Map<String, dynamic> input,
  ) async {
    _checkNotDisposed();
    final session = _clientSession;
    if (session == null) return false;
    return await session.isAllowedBySessionCache(toolName, input);
  }

  @override
  Future<void> clearSessionPermissionCache() async {
    _checkNotDisposed();
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
  final String? spawnedBy;

  _RemoteAgentInfo({
    required this.id,
    required this.type,
    this.name,
    this.spawnedBy,
  });
}
