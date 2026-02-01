import 'dart:async';
import 'dart:convert';

import 'package:claude_sdk/claude_sdk.dart';
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';
import 'package:vide_client/vide_client.dart' as vc;

import 'conversation_state.dart';
import 'vide_agent.dart';
import 'vide_event.dart';
import 'vide_session.dart';

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
/// final session = RemoteVideSession.pending();
/// navigateToExecutionPage(session); // Navigate immediately
///
/// // Later, when server responds:
/// session.completePending(clientSession);
/// ```
class RemoteVideSession implements VideSession {
  String _sessionId;
  vc.Session? _clientSession;
  StreamSubscription<vc.VideEvent>? _eventSubscription;

  final StreamController<VideEvent> _eventController =
      StreamController<VideEvent>.broadcast();

  final ConversationStateManager _conversationStateManager =
      ConversationStateManager();

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

  /// Conversation state per agent.
  final Map<String, Conversation> _conversations = {};

  /// Stream controllers for conversation updates per agent.
  final Map<String, StreamController<Conversation>> _conversationControllers =
      {};

  /// Pending permission completers.
  final Map<String, Completer<PermissionResult>> _pendingPermissions = {};

  /// Current message event IDs per agent (for streaming).
  final Map<String, String> _currentMessageEventIds = {};

  /// Current assistant message ID per agent (for grouping text + tool use + tool result).
  final Map<String, String> _currentAssistantMessageId = {};

  /// Last seq seen, for deduplication.
  int _lastSeq = 0;

  bool _disposed = false;
  bool _connected = false;

  /// Stream controller that emits when connection state changes.
  final StreamController<bool> _connectionStateController =
      StreamController<bool>.broadcast();

  /// Stream that emits when connection state changes (true = connected).
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
  })  : _sessionId = clientSession.id,
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

    // Subscribe to our own events to update conversation state
    _eventController.stream.listen((event) {
      _conversationStateManager.handleEvent(event);
    });
  }

  /// Complete a pending session with an actual client session.
  void completePending(vc.Session clientSession) {
    if (!_isPending) return;

    // Remove placeholder agent
    final oldMainId = _mainAgentId;
    if (oldMainId != null) {
      _agents.remove(oldMainId);
    }

    // Update with real details
    _sessionId = clientSession.id;
    _clientSession = clientSession;
    _isPending = false;

    // Set up event listening
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

    var conversation = _conversations[agentId] ?? Conversation.empty();
    final messages = List<ConversationMessage>.from(conversation.messages);

    messages.add(
      ConversationMessage(
        id: const Uuid().v4(),
        role: MessageRole.user,
        content: content,
        timestamp: DateTime.now(),
        responses: [],
        isStreaming: false,
        isComplete: true,
        messageType: MessageType.userMessage,
      ),
    );

    conversation = conversation.copyWith(
      messages: messages,
      state: ConversationState.sendingMessage,
    );
    _conversations[agentId] = conversation;

    // Notify listeners
    _getOrCreateConversationController(agentId).add(conversation);

    // Emit optimistic status event so UI shows the agent as working
    _eventController.add(
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

    // Subscribe to our own events to update conversation state
    _eventController.stream.listen((event) {
      _conversationStateManager.handleEvent(event);
    });
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
      case vc.PermissionTimeoutEvent():
        _handlePermissionTimeout(event);
      case vc.AbortedEvent():
        _handleAborted(event);
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

  void _handleConnected(vc.ConnectedEvent event) {
    _mainAgentId = event.mainAgentId;
    _lastSeq = event.lastSeq;

    // Parse agents list from connected event
    for (final agent in event.agents) {
      _agents[agent.id] = _RemoteAgentInfo(
        id: agent.id,
        type: agent.type,
        name: agent.name,
      );
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
    print('[DEBUG] _handleHistory: ${event.events.length} raw events');
    final consolidatedEvents = _consolidateHistoryMessages(event.events);
    print('[DEBUG] _handleHistory: ${consolidatedEvents.length} consolidated events');

    // Process consolidated history events without seq filtering
    // Mark as history replay so messages don't get accumulated
    for (final parsed in consolidatedEvents) {
      if (parsed is vc.MessageEvent) {
        print('[DEBUG] Processing history message: role=${parsed.role}, content="${parsed.content.substring(0, parsed.content.length.clamp(0, 50))}", isPartial=${parsed.isPartial}');
      }
      _handleClientEvent(parsed, skipSeqCheck: true, isHistoryReplay: true);
    }
    _lastSeq = event.lastSeq;
  }

  /// Consolidate streaming message events in history by eventId.
  ///
  /// When a message is streamed, the server stores each partial chunk as a separate
  /// event. For history replay, we need to consolidate these into single messages
  /// to avoid re-accumulating content that causes duplication.
  ///
  /// For messages with the same eventId:
  /// - If there's a non-partial (final) event, use that
  /// - Otherwise, accumulate content from all partials
  List<vc.VideEvent> _consolidateHistoryMessages(List<dynamic> rawEvents) {
    final result = <vc.VideEvent>[];
    // Track message events by eventId for consolidation
    final messagesByEventId = <String, List<vc.MessageEvent>>{};
    // Track positions for message events to maintain order
    final eventIdPositions = <String, int>{};

    print('[DEBUG] _consolidateHistoryMessages: rawEvents types = ${rawEvents.map((e) => e.runtimeType).toSet()}');

    // First pass: parse all events and group messages by eventId
    for (int i = 0; i < rawEvents.length; i++) {
      final rawEvent = rawEvents[i];
      if (rawEvent is! Map<String, dynamic>) continue;

      final parsed = vc.VideEvent.fromJson(rawEvent);

      if (parsed is vc.MessageEvent && parsed.eventId != null) {
        final eventId = parsed.eventId!;
        messagesByEventId.putIfAbsent(eventId, () => []).add(parsed);
        eventIdPositions.putIfAbsent(eventId, () => i);
      } else {
        // Non-message events go directly to result
        result.add(parsed);
      }
    }

    // Second pass: consolidate message events
    final consolidatedMessages = <int, vc.VideEvent>{};
    for (final entry in messagesByEventId.entries) {
      final eventId = entry.key;
      final messages = entry.value;
      final position = eventIdPositions[eventId]!;

      if (messages.length == 1) {
        // Only one event for this eventId, use as-is
        consolidatedMessages[position] = messages.first;
      } else {
        // Multiple events - find the final one or accumulate content
        final finalMessage = messages.where((m) => !m.isPartial).firstOrNull;
        if (finalMessage != null) {
          // Use the final non-partial message (it should have full content)
          // But server sends empty content for final, so accumulate from partials
          final accumulatedContent =
              messages.where((m) => m.isPartial).map((m) => m.content).join();
          consolidatedMessages[position] = vc.MessageEvent(
            seq: finalMessage.seq,
            eventId: finalMessage.eventId,
            timestamp: finalMessage.timestamp,
            agent: finalMessage.agent,
            role: finalMessage.role,
            content: accumulatedContent,
            isPartial: false,
          );
        } else {
          // All partials - accumulate content
          final last = messages.last;
          final accumulatedContent = messages.map((m) => m.content).join();
          consolidatedMessages[position] = vc.MessageEvent(
            seq: last.seq,
            eventId: last.eventId,
            timestamp: last.timestamp,
            agent: last.agent,
            role: last.role,
            content: accumulatedContent,
            isPartial: true,
          );
        }
      }
    }

    // Insert consolidated messages at their original positions
    final sortedPositions = consolidatedMessages.keys.toList()..sort();
    for (final position in sortedPositions) {
      result.insert(
        result.length.clamp(0, position),
        consolidatedMessages[position]!,
      );
    }

    // Sort by seq to maintain proper order
    result.sort((a, b) => (a.seq ?? 0).compareTo(b.seq ?? 0));

    return result;
  }

  void _handleMessage(vc.MessageEvent event, {bool isHistoryReplay = false}) {
    final agentId = event.agent?.id ?? '';
    final agentInfo = _agents[agentId];
    final eventId = event.eventId ?? const Uuid().v4();

    // Track streaming state (skip for history replay - messages are already complete)
    if (!isHistoryReplay) {
      if (event.isPartial) {
        _currentMessageEventIds[agentId] = eventId;
      } else {
        _currentMessageEventIds.remove(agentId);
      }
    }

    final role = event.role == vc.MessageRole.user ? 'user' : 'assistant';

    // Update conversation state
    // For history replay, messages should not be accumulated
    _updateConversation(
      agentId: agentId,
      eventId: eventId,
      role: role,
      content: event.content,
      isPartial: event.isPartial,
      isHistoryReplay: isHistoryReplay,
    );

    _eventController.add(
      MessageEvent(
        agentId: agentId,
        agentType: agentInfo?.type ?? event.agent?.type ?? 'unknown',
        agentName: agentInfo?.name ?? event.agent?.name,
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
    final agentInfo = _agents[agentId];

    // Update conversation state with tool use
    _updateConversationWithToolUse(
      agentId: agentId,
      toolUseId: event.toolUseId,
      toolName: event.toolName,
      toolInput: event.toolInput,
    );

    _eventController.add(
      ToolUseEvent(
        agentId: agentId,
        agentType: agentInfo?.type ?? event.agent?.type ?? 'unknown',
        agentName: agentInfo?.name ?? event.agent?.name,
        taskName: event.agent?.taskName,
        toolUseId: event.toolUseId,
        toolName: event.toolName,
        toolInput: event.toolInput,
      ),
    );
  }

  void _handleToolResult(vc.ToolResultEvent event) {
    final agentId = event.agent?.id ?? '';
    final agentInfo = _agents[agentId];
    final result = event.result;
    final resultStr = result is String ? result : (result?.toString() ?? '');

    // Update conversation state with tool result
    _updateConversationWithToolResult(
      agentId: agentId,
      toolUseId: event.toolUseId,
      result: resultStr,
      isError: event.isError,
    );

    _eventController.add(
      ToolResultEvent(
        agentId: agentId,
        agentType: agentInfo?.type ?? event.agent?.type ?? 'unknown',
        agentName: agentInfo?.name ?? event.agent?.name,
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
    final agentInfo = _agents[agentId];

    final status = switch (event.status) {
      vc.AgentStatus.working => VideAgentStatus.working,
      vc.AgentStatus.waitingForAgent => VideAgentStatus.waitingForAgent,
      vc.AgentStatus.waitingForUser => VideAgentStatus.waitingForUser,
      vc.AgentStatus.idle => VideAgentStatus.idle,
    };

    _eventController.add(
      StatusEvent(
        agentId: agentId,
        agentType: agentInfo?.type ?? event.agent?.type ?? 'unknown',
        agentName: agentInfo?.name ?? event.agent?.name,
        taskName: event.agent?.taskName,
        status: status,
      ),
    );
  }

  void _handleDone(vc.DoneEvent event) {
    final agentId = event.agent?.id ?? '';
    final agentInfo = _agents[agentId];

    // Mark the current assistant message as complete
    _markAssistantTurnComplete(agentId);

    _eventController.add(
      TurnCompleteEvent(
        agentId: agentId,
        agentType: agentInfo?.type ?? event.agent?.type ?? 'unknown',
        agentName: agentInfo?.name ?? event.agent?.name,
        taskName: event.agent?.taskName,
        reason: event.reason,
      ),
    );
  }

  void _handleError(vc.ErrorEvent event) {
    final agentId = event.agent?.id ?? '';
    final agentInfo = _agents[agentId];

    _eventController.add(
      ErrorEvent(
        agentId: agentId,
        agentType: agentInfo?.type ?? event.agent?.type ?? 'unknown',
        agentName: agentInfo?.name ?? event.agent?.name,
        taskName: event.agent?.taskName,
        message: event.message,
        code: event.code,
      ),
    );
  }

  void _handleAgentSpawned(vc.AgentSpawnedEvent event) {
    final agentId = event.agent?.id ?? '';
    final agentType = event.agent?.type ?? 'unknown';
    final agentName = event.agent?.name;

    _agents[agentId] = _RemoteAgentInfo(
      id: agentId,
      type: agentType,
      name: agentName,
    );

    // Notify listeners that agents list changed
    _agentsController.add(agents);

    _eventController.add(
      AgentSpawnedEvent(
        agentId: agentId,
        agentType: agentType,
        agentName: agentName,
        taskName: event.agent?.taskName,
        spawnedBy: event.spawnedBy,
      ),
    );
  }

  void _handleAgentTerminated(vc.AgentTerminatedEvent event) {
    final agentId = event.agent?.id ?? '';
    final agentInfo = _agents.remove(agentId);

    // Notify listeners that agents list changed
    _agentsController.add(agents);

    _eventController.add(
      AgentTerminatedEvent(
        agentId: agentId,
        agentType: agentInfo?.type ?? event.agent?.type ?? 'unknown',
        agentName: agentInfo?.name ?? event.agent?.name,
        taskName: event.agent?.taskName,
        reason: event.reason,
        terminatedBy: event.terminatedBy,
      ),
    );
  }

  void _handlePermissionRequest(vc.PermissionRequestEvent event) {
    final agentId = event.agent?.id ?? '';
    final agentInfo = _agents[agentId];

    _eventController.add(
      PermissionRequestEvent(
        agentId: agentId,
        agentType: agentInfo?.type ?? event.agent?.type ?? 'unknown',
        agentName: agentInfo?.name ?? event.agent?.name,
        taskName: event.agent?.taskName,
        requestId: event.requestId,
        toolName: event.toolName,
        toolInput: event.tool['input'] as Map<String, dynamic>? ?? {},
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
    final agentInfo = _agents[agentId];

    _eventController.add(
      TurnCompleteEvent(
        agentId: agentId,
        agentType: agentInfo?.type ?? event.agent?.type ?? 'unknown',
        agentName: agentInfo?.name ?? event.agent?.name,
        taskName: event.agent?.taskName,
        reason: 'aborted',
      ),
    );
  }

  // ============================================================
  // Conversation state management
  // ============================================================

  void _updateConversation({
    required String agentId,
    required String eventId,
    required String role,
    required String content,
    required bool isPartial,
    bool isHistoryReplay = false,
  }) {
    var conversation = _conversations[agentId] ?? Conversation.empty();
    final messages = List<ConversationMessage>.from(conversation.messages);

    if (role == 'user') {
      // Check if this user message already exists (from optimistic add)
      // We compare by content since IDs may differ between optimistic and server events
      final isDuplicate = messages.isNotEmpty &&
          messages.last.role == MessageRole.user &&
          messages.last.content == content;

      if (!isDuplicate) {
        messages.add(
          ConversationMessage(
            id: eventId,
            role: MessageRole.user,
            content: content,
            timestamp: DateTime.now(),
            responses: [],
            isStreaming: false,
            isComplete: true,
            messageType: MessageType.userMessage,
          ),
        );
      }
      // Clear any current assistant message tracking since user started new turn
      _currentAssistantMessageId.remove(agentId);
    } else {
      // Assistant message handling
      //
      // For history replay: messages are already consolidated, so just add them
      // without accumulating. This prevents duplication from replaying streaming chunks.
      //
      // For live streaming: accumulate chunks into current message by ID.
      if (isHistoryReplay) {
        // History replay - add message directly without accumulation
        // Check for duplicate by eventId first
        final existingIndex = messages.indexWhere((m) => m.id == eventId);
        if (existingIndex >= 0) {
          // Update existing message (shouldn't happen with proper consolidation)
          final existing = messages[existingIndex];
          messages[existingIndex] = ConversationMessage(
            id: existing.id,
            role: MessageRole.assistant,
            content: content,
            timestamp: existing.timestamp,
            responses: [
              if (content.isNotEmpty)
                TextResponse(
                  id: const Uuid().v4(),
                  timestamp: DateTime.now(),
                  content: content,
                  isPartial: false,
                ),
            ],
            isStreaming: false,
            isComplete: true,
            messageType: MessageType.assistantText,
          );
        } else {
          // Add new message
          messages.add(
            ConversationMessage(
              id: eventId,
              role: MessageRole.assistant,
              content: content,
              timestamp: DateTime.now(),
              responses: [
                if (content.isNotEmpty)
                  TextResponse(
                    id: const Uuid().v4(),
                    timestamp: DateTime.now(),
                    content: content,
                    isPartial: false,
                  ),
              ],
              isStreaming: false,
              isComplete: true,
              messageType: MessageType.assistantText,
            ),
          );
        }
      } else {
        // Live streaming - accumulate chunks into current message
        final currentMsgId = _currentAssistantMessageId[agentId];
        final existingIndex = currentMsgId != null
            ? messages.indexWhere((m) => m.id == currentMsgId)
            : -1;

        if (existingIndex >= 0) {
          // Add text to existing assistant message
          final existing = messages[existingIndex];
          final newContent = existing.content + content;
          final responses = List<ClaudeResponse>.from(existing.responses);

          if (content.isNotEmpty) {
            responses.add(
              TextResponse(
                id: const Uuid().v4(),
                timestamp: DateTime.now(),
                content: content,
                isPartial: true,
              ),
            );
          }

          messages[existingIndex] = ConversationMessage(
            id: existing.id,
            role: MessageRole.assistant,
            content: newContent,
            timestamp: existing.timestamp,
            responses: responses,
            isStreaming: isPartial,
            isComplete: !isPartial,
            messageType: MessageType.assistantText,
          );
        } else {
          // Create new assistant message
          final newMsgId = eventId;
          _currentAssistantMessageId[agentId] = newMsgId;

          final responses = <ClaudeResponse>[];
          if (content.isNotEmpty) {
            responses.add(
              TextResponse(
                id: const Uuid().v4(),
                timestamp: DateTime.now(),
                content: content,
                isPartial: true,
              ),
            );
          }

          messages.add(
            ConversationMessage(
              id: newMsgId,
              role: MessageRole.assistant,
              content: content,
              timestamp: DateTime.now(),
              responses: responses,
              isStreaming: isPartial,
              isComplete: !isPartial,
              messageType: MessageType.assistantText,
            ),
          );
        }

        // Clear tracking when turn completes
        if (!isPartial) {
          _currentAssistantMessageId.remove(agentId);
        }
      }
    }

    final state = isPartial
        ? ConversationState.receivingResponse
        : ConversationState.idle;

    conversation = conversation.copyWith(messages: messages, state: state);
    _conversations[agentId] = conversation;

    // Notify listeners
    _getOrCreateConversationController(agentId).add(conversation);
  }

  void _updateConversationWithToolUse({
    required String agentId,
    required String toolUseId,
    required String toolName,
    required Map<String, dynamic> toolInput,
  }) {
    var conversation = _conversations[agentId] ?? Conversation.empty();
    final messages = List<ConversationMessage>.from(conversation.messages);

    // Find or create the current assistant message
    var currentMsgId = _currentAssistantMessageId[agentId];
    var existingIndex = currentMsgId != null
        ? messages.indexWhere((m) => m.id == currentMsgId)
        : -1;

    if (existingIndex < 0) {
      // No current assistant message - create one
      currentMsgId = const Uuid().v4();
      _currentAssistantMessageId[agentId] = currentMsgId;
      messages.add(
        ConversationMessage(
          id: currentMsgId,
          role: MessageRole.assistant,
          content: '',
          timestamp: DateTime.now(),
          responses: [],
          isStreaming: true,
          isComplete: false,
          messageType: MessageType.assistantText,
        ),
      );
      existingIndex = messages.length - 1;
    }

    // Add ToolUseResponse to the current assistant message
    final existing = messages[existingIndex];
    final responses = List<ClaudeResponse>.from(existing.responses);
    responses.add(
      ToolUseResponse(
        id: toolUseId,
        timestamp: DateTime.now(),
        toolName: toolName,
        parameters: toolInput,
        toolUseId: toolUseId,
      ),
    );

    messages[existingIndex] = ConversationMessage(
      id: existing.id,
      role: MessageRole.assistant,
      content: existing.content,
      timestamp: existing.timestamp,
      responses: responses,
      isStreaming: true,
      isComplete: false,
      messageType: MessageType.assistantText,
    );

    conversation = conversation.copyWith(
      messages: messages,
      state: ConversationState.processing,
    );
    _conversations[agentId] = conversation;

    // Notify listeners
    _getOrCreateConversationController(agentId).add(conversation);
  }

  void _updateConversationWithToolResult({
    required String agentId,
    required String toolUseId,
    required String result,
    required bool isError,
  }) {
    var conversation = _conversations[agentId] ?? Conversation.empty();
    final messages = List<ConversationMessage>.from(conversation.messages);

    // Find the current assistant message
    final currentMsgId = _currentAssistantMessageId[agentId];
    final existingIndex = currentMsgId != null
        ? messages.indexWhere((m) => m.id == currentMsgId)
        : -1;

    if (existingIndex >= 0) {
      // Add ToolResultResponse to the current assistant message
      final existing = messages[existingIndex];
      final responses = List<ClaudeResponse>.from(existing.responses);
      responses.add(
        ToolResultResponse(
          id: '${toolUseId}_result',
          timestamp: DateTime.now(),
          toolUseId: toolUseId,
          content: result,
          isError: isError,
        ),
      );

      messages[existingIndex] = ConversationMessage(
        id: existing.id,
        role: MessageRole.assistant,
        content: existing.content,
        timestamp: existing.timestamp,
        responses: responses,
        isStreaming: true,
        isComplete: false,
        messageType: MessageType.assistantText,
      );
    }

    conversation = conversation.copyWith(
      messages: messages,
      state: ConversationState.processing,
    );
    _conversations[agentId] = conversation;

    // Notify listeners
    _getOrCreateConversationController(agentId).add(conversation);
  }

  void _markAssistantTurnComplete(String agentId) {
    final currentMsgId = _currentAssistantMessageId.remove(agentId);
    if (currentMsgId == null) return;

    var conversation = _conversations[agentId];
    if (conversation == null) return;

    final messages = List<ConversationMessage>.from(conversation.messages);
    final existingIndex = messages.indexWhere((m) => m.id == currentMsgId);

    if (existingIndex >= 0) {
      final existing = messages[existingIndex];
      messages[existingIndex] = ConversationMessage(
        id: existing.id,
        role: existing.role,
        content: existing.content,
        timestamp: existing.timestamp,
        responses: existing.responses,
        isStreaming: false,
        isComplete: true,
        messageType: existing.messageType,
      );

      conversation = conversation.copyWith(
        messages: messages,
        state: ConversationState.idle,
      );
      _conversations[agentId] = conversation;

      // Notify listeners
      _getOrCreateConversationController(agentId).add(conversation);
    }
  }

  StreamController<Conversation> _getOrCreateConversationController(
    String agentId,
  ) {
    return _conversationControllers.putIfAbsent(
      agentId,
      () => StreamController<Conversation>.broadcast(),
    );
  }

  // ============================================================
  // VideSession interface implementation
  // ============================================================

  @override
  String get id => _sessionId;

  @override
  ConversationStateManager get conversationState => _conversationStateManager;

  @override
  Stream<VideEvent> get events => _eventController.stream;

  @override
  List<VideAgent> get agents {
    return _agents.values
        .map(
          (a) => VideAgent(
            id: a.id,
            name: a.name ?? a.type,
            type: a.type,
            status: VideAgentStatus.idle,
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
      status: VideAgentStatus.idle,
      createdAt: DateTime.now(),
    );
  }

  @override
  List<String> get agentIds => _agents.keys.toList();

  @override
  bool get isProcessing => false;

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
    _clientSession?.sendMessage(message.text);
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
    // Remote protocol doesn't support per-agent abort yet
    await abort();
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

    _conversationStateManager.dispose();

    // Close conversation stream controllers
    for (final controller in _conversationControllers.values) {
      await controller.close();
    }
    _conversationControllers.clear();

    await _connectionStateController.close();
    await _agentsController.close();
    await _goalController.close();
    await _eventController.close();
  }

  void _checkNotDisposed() {
    if (_disposed) {
      throw StateError('Session has been disposed');
    }
  }

  // ============================================================
  // Methods not supported in remote mode
  // ============================================================

  @override
  Future<void> clearConversation({String? agentId}) async {
    // Not supported in remote mode
  }

  @override
  T? getMcpServer<T extends McpServerBase>(String agentId, String serverName) {
    return null;
  }

  @override
  Future<void> setWorktreePath(String? path) async {
    // Not supported in remote mode
  }

  @override
  Conversation? getConversation(String agentId) {
    return _conversations[agentId];
  }

  @override
  Stream<Conversation> conversationStream(String agentId) {
    return _getOrCreateConversationController(agentId).stream;
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
    // Not supported in remote mode yet
  }

  @override
  Future<String> forkAgent(String agentId, {String? name}) async {
    throw UnimplementedError('Fork not supported in remote mode');
  }

  @override
  Future<String> spawnAgent({
    required String agentType,
    required String name,
    required String initialPrompt,
    required String spawnedBy,
  }) async {
    throw UnimplementedError('Spawn not supported in remote mode');
  }

  @override
  String? getQueuedMessage(String agentId) => null;

  @override
  Stream<String?> queuedMessageStream(String agentId) => const Stream.empty();

  @override
  void clearQueuedMessage(String agentId) {}

  @override
  String? getModel(String agentId) => null;

  @override
  Stream<String?> modelStream(String agentId) => const Stream.empty();

  @override
  CanUseToolCallback createPermissionCallback({
    required String agentId,
    required String? agentName,
    required String? agentType,
    required String cwd,
  }) {
    throw UnimplementedError(
      'createPermissionCallback not used in remote mode',
    );
  }

  @override
  void respondToAskUserQuestion(
    String requestId, {
    required Map<String, String> answers,
  }) {
    // Would need protocol extension
  }

  @override
  void addSessionPermissionPattern(String pattern) {
    // Session patterns are managed server-side
  }

  @override
  bool isAllowedBySessionCache(String toolName, Map<String, dynamic> input) {
    return false;
  }

  @override
  void clearSessionPermissionCache() {
    // Session cache is managed server-side
  }
}

/// Tracks info about a remote agent.
class _RemoteAgentInfo {
  final String id;
  final String type;
  final String? name;

  _RemoteAgentInfo({required this.id, required this.type, this.name});
}
