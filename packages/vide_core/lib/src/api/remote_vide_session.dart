import 'dart:async';
import 'dart:convert';

import 'package:claude_sdk/claude_sdk.dart';
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';
import 'package:vide_client/vide_client.dart' as vc;

import 'conversation_state.dart';
import 'remote_conversation_builder.dart';
import 'session_event_hub.dart';
import 'vide_agent.dart';
import 'vide_event.dart';
import 'vide_session.dart';

/// Handle for an optimistic remote session that is still connecting.
///
/// This keeps pending-session lifecycle operations in vide_core so UI/service
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
  void completeWithClientSession(vc.Session clientSession) {
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
  void Function()? onReady,
}) {
  final session = RemoteVideSession.pending();
  if (initialMessage != null && initialMessage.isNotEmpty) {
    session.addPendingUserMessage(initialMessage);
  }
  session.onPendingComplete = onReady;
  return PendingRemoteVideSession._(session);
}

/// Adapt a transport-level [vc.Session] into the unified [VideSession] API.
VideSession createRemoteVideSessionFromClientSession(
  vc.Session clientSession, {
  String? mainAgentId,
}) {
  return RemoteVideSession.fromClientSession(
    clientSession,
    mainAgentId: mainAgentId,
  );
}

/// A VideSession that connects to a remote vide_server via WebSocket.
///
/// This implementation composes with [vc.Session] from vide_client,
/// which handles the wire protocol. RemoteVideSession adds:
/// - Conversation state management
/// - Agent tracking
/// - Event adaptation from wire format to business events
///
/// ## Composability
///
/// The architecture provides two levels of access:
///
/// 1. **vide_client.Session** - Thin wire protocol wrapper
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
  vc.Session? _clientSession;
  StreamSubscription<vc.VideEvent>? _eventSubscription;

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

  /// Controller for goal changes.
  final StreamController<String> _goalController =
      StreamController<String>.broadcast();

  /// Team name for this session.
  String _team = 'vide';

  /// Pending permission completers.
  final Map<String, Completer<PermissionResult>> _pendingPermissions = {};

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

  bool _disposed = false;
  bool _connected = false;

  /// Stream controller that emits when connection state changes.
  final StreamController<bool> _connectionStateController =
      StreamController<bool>.broadcast();

  /// Stream that emits when connection state changes (true = connected).
  @override
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  /// Stream controller that emits when agents list changes.
  final StreamController<List<VideAgent>> _agentsController =
      StreamController<List<VideAgent>>.broadcast();

  @override
  Stream<List<VideAgent>> get agentsStream => _agentsController.stream;

  /// Whether the WebSocket is connected and ready.
  bool get isConnected => _connected;

  /// Whether this session is still being created on the server.
  bool _isPending = false;
  bool get isPending => _isPending;

  /// Pending placeholder agent ID to migrate when connected event arrives.
  /// This is set during completePending() and consumed in _handleConnected().
  String? _pendingAgentIdToMigrate;

  /// Error that occurred during session creation (if any).
  String? _creationError;
  String? get creationError => _creationError;

  /// Callback invoked when pending session completes (success or failure).
  void Function()? onPendingComplete;

  /// Completer for initial connection.
  final Completer<void> _connectCompleter = Completer<void>();

  /// Create a RemoteVideSession from an existing vide_client.Session.
  ///
  /// This is the preferred constructor when you already have a client session.
  RemoteVideSession.fromClientSession(
    vc.Session clientSession, {
    String? mainAgentId,
  }) : _sessionId = clientSession.id,
       _clientSession = clientSession {
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
  void completePending(vc.Session clientSession) {
    if (!_isPending) return;

    // Save placeholder agent ID for conversation migration when ConnectedEvent arrives
    if (_mainAgentId != null) {
      _pendingAgentIdToMigrate = _mainAgentId;
      _agents.remove(_mainAgentId);
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
  void addPendingUserMessage(String content) {
    final agentId = _mainAgentId;
    if (agentId == null) return;

    final agentInfo = _agents[agentId];

    _conversationBuilder.addUserMessage(agentId, content);

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
        if (!_disposed) {
          _connected = false;
          _connectionStateController.add(false);
        }
      },
    );
  }

  /// Handle an event from the vide_client session.
  ///
  /// This adapts wire-format events to business events.
  /// If [skipSeqCheck] is true, deduplication is skipped (for history replay).
  /// If [isHistoryReplay] is true, messages are treated as complete (not accumulated).
  void _handleClientEvent(
    vc.VideEvent event, {
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
      case vc.ConnectedEvent():
        _handleConnected(event);
      case vc.HistoryEvent():
        _handleHistory(event);
      case vc.MessageEvent():
        _handleMessage(event, isHistoryReplay: isHistoryReplay);
      case vc.ToolUseEvent():
        _handleToolUse(event);
      case vc.ToolResultEvent():
        _handleToolResult(event);
      case vc.StatusEvent():
        _handleStatus(event);
      case vc.DoneEvent():
        _handleDone(event);
      case vc.ErrorEvent():
        _handleError(event);
      case vc.AgentSpawnedEvent():
        _handleAgentSpawned(event);
      case vc.AgentTerminatedEvent():
        _handleAgentTerminated(event);
      case vc.PermissionRequestEvent():
        _handlePermissionRequest(event);
      case vc.AskUserQuestionEvent():
        _handleAskUserQuestion(event);
      case vc.TaskNameChangedEvent():
        _handleTaskNameChanged(event);
      case vc.PermissionTimeoutEvent():
        _handlePermissionTimeout(event);
      case vc.AbortedEvent():
        _handleAborted(event);
      case vc.CommandResultEvent():
        // Command results are handled inside vide_client.Session.
        break;
      case vc.UnknownEvent():
        // Ignore unknown events
        break;
    }
  }

  /// Handles a raw WebSocket message (for testing).
  ///
  /// This parses the JSON and routes to the appropriate handler,
  /// simulating what vide_client.Session would do.
  @visibleForTesting
  void handleWebSocketMessage(dynamic message) {
    if (message is! String) return;

    final json = jsonDecode(message) as Map<String, dynamic>;
    final event = vc.VideEvent.fromJson(json);
    _handleClientEvent(event);
  }

  /// Resolve agent type from local cache, falling back to the wire event.
  String _resolveAgentType(String agentId, vc.VideEvent event) {
    return _agents[agentId]?.type ?? event.agent?.type ?? 'unknown';
  }

  /// Resolve agent name from local cache, falling back to the wire event.
  String? _resolveAgentName(String agentId, vc.VideEvent event) {
    return _agents[agentId]?.name ?? event.agent?.name;
  }

  void _handleConnected(vc.ConnectedEvent event) {
    _mainAgentId = event.mainAgentId;
    _lastSeq = event.lastSeq;
    _applyConnectedMetadata(event.metadata);

    // Parse agents list from connected event
    for (final agent in event.agents) {
      _agents[agent.id] = _RemoteAgentInfo(
        id: agent.id,
        type: agent.type,
        name: agent.name,
      );
      _agentStatuses[agent.id] = VideAgentStatus.idle;
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

    // Notify listeners that agents list changed (important for reconnection)
    _agentsController.add(agents);

    _connected = true;
    _connectionStateController.add(true);
    if (!_connectCompleter.isCompleted) {
      _connectCompleter.complete();
    }
  }

  void _handleHistory(vc.HistoryEvent event) {
    // Consolidate message events by eventId to avoid duplication from streaming chunks.
    // The server stores every streaming partial, so we need to take only the final
    // version of each message (either the non-partial one, or the last partial with
    // accumulated content).
    final consolidatedEvents = _consolidateHistoryMessages(event.events);

    // Process consolidated history events without seq filtering
    // Mark as history replay so messages don't get accumulated
    for (final parsed in consolidatedEvents) {
      _handleClientEvent(parsed, skipSeqCheck: true, isHistoryReplay: true);
    }
    _lastSeq = event.lastSeq;
  }

  /// Consolidate streaming message events in history by eventId.
  ///
  /// The server stores every streaming partial as a separate event. For history
  /// replay we merge chunks sharing an eventId into a single message, then sort
  /// everything by seq.
  List<vc.VideEvent> _consolidateHistoryMessages(List<dynamic> rawEvents) {
    final result = <vc.VideEvent>[];
    final messagesByEventId = <String, List<vc.MessageEvent>>{};

    for (final rawEvent in rawEvents) {
      if (rawEvent is! Map<String, dynamic>) continue;
      final parsed = vc.VideEvent.fromJson(rawEvent);

      if (parsed is vc.MessageEvent && parsed.eventId != null) {
        messagesByEventId.putIfAbsent(parsed.eventId!, () => []).add(parsed);
      } else {
        result.add(parsed);
      }
    }

    for (final messages in messagesByEventId.values) {
      final partials = messages.where((m) => m.isPartial).toList();
      final hasFinal = messages.any((m) => !m.isPartial);
      final representative = messages.last;

      // Partial chunks carry streaming content; the final marker is empty.
      // For non-streamed messages (single non-partial) use the content directly.
      final content = partials.isNotEmpty
          ? partials.map((m) => m.content).join()
          : representative.content;

      result.add(
        vc.MessageEvent(
          seq: representative.seq,
          eventId: representative.eventId,
          timestamp: representative.timestamp,
          agent: representative.agent,
          role: representative.role,
          content: content,
          isPartial: !hasFinal,
        ),
      );
    }

    result.sort((a, b) => (a.seq ?? 0).compareTo(b.seq ?? 0));
    return result;
  }

  void _handleMessage(vc.MessageEvent event, {bool isHistoryReplay = false}) {
    final agentId = event.agent?.id ?? '';
    final eventId = event.eventId ?? const Uuid().v4();
    final role = event.role == vc.MessageRole.user ? 'user' : 'assistant';

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
        taskName: event.agent?.taskName,
        eventId: eventId,
        role: role,
        content: event.content,
        isPartial: event.isPartial,
      ),
    );
  }

  void _handleToolUse(vc.ToolUseEvent event) {
    final agentId = event.agent?.id ?? '';

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
        taskName: event.agent?.taskName,
        toolUseId: event.toolUseId,
        toolName: event.toolName,
        toolInput: event.toolInput,
      ),
    );
  }

  void _handleToolResult(vc.ToolResultEvent event) {
    final agentId = event.agent?.id ?? '';
    final result = event.result;
    final resultStr = result is String ? result : (result?.toString() ?? '');

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
        taskName: event.agent?.taskName,
        toolUseId: event.toolUseId,
        toolName: event.toolName,
        result: resultStr,
        isError: event.isError,
      ),
    );
  }

  void _handleStatus(vc.StatusEvent event) {
    final agentId = event.agent?.id ?? '';

    final status = switch (event.status) {
      vc.AgentStatus.working => VideAgentStatus.working,
      vc.AgentStatus.waitingForAgent => VideAgentStatus.waitingForAgent,
      vc.AgentStatus.waitingForUser => VideAgentStatus.waitingForUser,
      vc.AgentStatus.idle => VideAgentStatus.idle,
    };
    _agentStatuses[agentId] = status;
    _refreshQueuedMessage(agentId);
    _refreshModel(agentId);

    _hub.emit(
      StatusEvent(
        agentId: agentId,
        agentType: _resolveAgentType(agentId, event),
        agentName: _resolveAgentName(agentId, event),
        taskName: event.agent?.taskName,
        status: status,
      ),
    );
  }

  void _handleDone(vc.DoneEvent event) {
    final agentId = event.agent?.id ?? '';
    _agentStatuses[agentId] = VideAgentStatus.idle;
    _refreshQueuedMessage(agentId);

    _conversationBuilder.markAssistantTurnComplete(agentId);

    _hub.emit(
      TurnCompleteEvent(
        agentId: agentId,
        agentType: _resolveAgentType(agentId, event),
        agentName: _resolveAgentName(agentId, event),
        taskName: event.agent?.taskName,
        reason: event.reason,
      ),
    );
  }

  void _handleError(vc.ErrorEvent event) {
    final agentId = event.agent?.id ?? '';

    _hub.emit(
      ErrorEvent(
        agentId: agentId,
        agentType: _resolveAgentType(agentId, event),
        agentName: _resolveAgentName(agentId, event),
        taskName: event.agent?.taskName,
        message: event.message,
        code: event.code,
      ),
    );
  }

  void _handleAgentSpawned(vc.AgentSpawnedEvent event) {
    final agentId = event.agent?.id ?? '';

    _agents[agentId] = _RemoteAgentInfo(
      id: agentId,
      type: event.agent?.type ?? 'unknown',
      name: event.agent?.name,
    );
    _agentStatuses[agentId] = VideAgentStatus.idle;
    _refreshModel(agentId);
    _refreshQueuedMessage(agentId);

    _agentsController.add(agents);

    _hub.emit(
      AgentSpawnedEvent(
        agentId: agentId,
        agentType: _resolveAgentType(agentId, event),
        agentName: _resolveAgentName(agentId, event),
        taskName: event.agent?.taskName,
        spawnedBy: event.spawnedBy,
      ),
    );
  }

  void _handleAgentTerminated(vc.AgentTerminatedEvent event) {
    final agentId = event.agent?.id ?? '';
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

    _agentsController.add(agents);

    _hub.emit(
      AgentTerminatedEvent(
        agentId: agentId,
        agentType: agentType,
        agentName: agentName,
        taskName: event.agent?.taskName,
        reason: event.reason,
        terminatedBy: event.terminatedBy,
      ),
    );
  }

  void _handlePermissionRequest(vc.PermissionRequestEvent event) {
    final agentId = event.agent?.id ?? '';

    _hub.emit(
      PermissionRequestEvent(
        agentId: agentId,
        agentType: _resolveAgentType(agentId, event),
        agentName: _resolveAgentName(agentId, event),
        taskName: event.agent?.taskName,
        requestId: event.requestId,
        toolName: event.toolName,
        toolInput: event.tool['input'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  void _handleAskUserQuestion(vc.AskUserQuestionEvent event) {
    final agentId = event.agent?.id ?? '';

    final questions = event.questions.map((q) {
      final options = (q['options'] as List<dynamic>? ?? const []).map((o) {
        final option = Map<String, dynamic>.from(o as Map);
        return AskUserQuestionOptionData(
          label: option['label']?.toString() ?? '',
          description: option['description']?.toString() ?? '',
        );
      }).toList();

      return AskUserQuestionData(
        question: q['question']?.toString() ?? '',
        header: q['header']?.toString(),
        multiSelect: q['multi-select'] as bool? ?? false,
        options: options,
      );
    }).toList();

    _hub.emit(
      AskUserQuestionEvent(
        agentId: agentId,
        agentType: _resolveAgentType(agentId, event),
        agentName: _resolveAgentName(agentId, event),
        taskName: event.agent?.taskName,
        requestId: event.requestId,
        questions: questions,
      ),
    );
  }

  void _handleTaskNameChanged(vc.TaskNameChangedEvent event) {
    final agentId = event.agent?.id ?? _mainAgentId ?? '';
    final previousGoal = _goal;
    _goal = event.newGoal;
    _goalController.add(_goal);

    _hub.emit(
      TaskNameChangedEvent(
        agentId: agentId,
        agentType: _resolveAgentType(agentId, event),
        agentName: _resolveAgentName(agentId, event),
        taskName: event.agent?.taskName,
        newGoal: event.newGoal,
        previousGoal: event.previousGoal ?? previousGoal,
      ),
    );
  }

  void _handlePermissionTimeout(vc.PermissionTimeoutEvent event) {
    final completer = _pendingPermissions.remove(event.requestId);
    completer?.complete(
      const PermissionResultDeny(message: 'Permission request timed out'),
    );
  }

  void _handleAborted(vc.AbortedEvent event) {
    final agentId = event.agent?.id ?? '';
    _agentStatuses[agentId] = VideAgentStatus.idle;
    _refreshQueuedMessage(agentId);

    _hub.emit(
      TurnCompleteEvent(
        agentId: agentId,
        agentType: _resolveAgentType(agentId, event),
        agentName: _resolveAgentName(agentId, event),
        taskName: event.agent?.taskName,
        reason: 'aborted',
      ),
    );
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
    required Future<T?> Function(vc.Session, String) fetch,
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
      _goalController.add(goal);
    }
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
  Stream<VideEvent> get events => _hub.events;

  @override
  List<VideAgent> get agents {
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

  @override
  VideAgent? get mainAgent {
    if (_mainAgentId == null) return null;
    final info = _agents[_mainAgentId];
    if (info == null) return null;
    return VideAgent(
      id: info.id,
      name: info.name ?? info.type,
      type: info.type,
      status: _agentStatuses[info.id] ?? VideAgentStatus.idle,
      createdAt: DateTime.now(),
    );
  }

  @override
  List<String> get agentIds => _agents.keys.toList();

  @override
  bool get isProcessing =>
      _agentStatuses.values.any((status) => status != VideAgentStatus.idle);

  @override
  String get workingDirectory => _workingDirectory;

  @override
  String get goal => _goal;

  @override
  Stream<String> get goalStream => _goalController.stream;

  @override
  String get team => _team;

  @override
  void sendMessage(Message message, {String? agentId}) {
    _checkNotDisposed();
    final targetAgentId = agentId ?? _mainAgentId;
    _clientSession?.sendMessage(message.text, agentId: targetAgentId);

    // Optimistically add the user message for immediate display.
    // The server will echo it back as a MessageEvent; the conversation
    // builder deduplicates by content so it won't appear twice.
    if (targetAgentId != null) {
      _conversationBuilder.addUserMessage(targetAgentId, message.text);
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
  }) {
    _checkNotDisposed();
    _clientSession?.respondToPermission(
      requestId: requestId,
      allow: allow,
      message: message,
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
    _disposed = true;

    await _eventSubscription?.cancel();
    await _clientSession?.close();
    _clientSession = null;

    // Complete pending permissions
    for (final completer in _pendingPermissions.values) {
      if (!completer.isCompleted) {
        completer.complete(
          const PermissionResultDeny(message: 'Session disposed'),
        );
      }
    }
    _pendingPermissions.clear();

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
    await _agentsController.close();
    await _goalController.close();

    _models.clear();
    _queuedMessages.clear();
    _agentStatuses.clear();
    _modelRefreshInFlight.clear();
    _queuedRefreshInFlight.clear();
  }

  void _checkNotDisposed() {
    if (_disposed) {
      throw StateError('Session has been disposed');
    }
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

    if (targetAgentId != null) {
      _conversationBuilder.clearConversation(targetAgentId);
    }
  }

  @override
  Future<void> setWorktreePath(String? path) async {
    _checkNotDisposed();
    final session = _clientSession;
    if (session == null) return;
    final result = await session.setWorktreePath(path);
    _workingDirectory =
        result?['working-directory'] as String? ?? _workingDirectory;
  }

  @override
  Conversation? getConversation(String agentId) {
    return _conversationBuilder.getConversation(agentId);
  }

  @override
  Stream<Conversation> conversationStream(String agentId) {
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
  CanUseToolCallback createPermissionCallback({
    required String agentId,
    required String? agentName,
    required String? agentType,
    required String cwd,
    String? permissionMode,
  }) {
    // Remote sessions execute permission checks server-side.
    // If this callback is invoked unexpectedly, fail closed instead of throwing.
    return (
      String toolName,
      Map<String, dynamic> input,
      ToolPermissionContext context,
    ) async {
      return const PermissionResultDeny(
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

  _RemoteAgentInfo({required this.id, required this.type, this.name});
}
