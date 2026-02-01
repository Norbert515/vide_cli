import 'dart:async';
import 'dart:convert';

import 'package:claude_sdk/claude_sdk.dart';
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:vide_core/vide_core.dart';

/// A VideSession that connects to a remote vide_server via WebSocket.
///
/// This enables the TUI to control a session running in the daemon,
/// translating WebSocket events to VideEvents and vice versa.
class RemoteVideSession implements VideSession {
  String _sessionId;
  String? _wsUrl;
  final String? _authToken;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _channelSubscription;

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
  /// All responses during a turn should be added to this message.
  final Map<String, String> _currentAssistantMessageId = {};

  /// Last seq seen, for reconnection.
  int _lastSeq = 0;

  bool _disposed = false;
  bool _connected = false;

  /// Stream controller that emits when connection state changes.
  /// Used by providers to trigger rebuilds when connected.
  final StreamController<bool> _connectionStateController =
      StreamController<bool>.broadcast();

  /// Stream that emits when connection state changes (true = connected).
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  /// Stream controller that emits when agents list changes.
  /// Used by providers to trigger rebuilds when agents are spawned/terminated.
  final StreamController<List<VideAgent>> _agentsController =
      StreamController<List<VideAgent>>.broadcast();

  /// Stream that emits when agents list changes (spawned/terminated).
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
  /// Used to notify the UI to rebuild.
  void Function()? onPendingComplete;

  /// Completer for initial connection.
  final Completer<void> _connectCompleter = Completer<void>();

  /// Standard constructor - session details known upfront.
  RemoteVideSession({
    required String sessionId,
    required String wsUrl,
    String? authToken,
    String? mainAgentId,
  }) : _sessionId = sessionId,
       _wsUrl = wsUrl,
       _authToken = authToken {
    _initWithMainAgent(mainAgentId);
  }

  /// Create a pending session that will be connected once server responds.
  ///
  /// This enables optimistic navigation - we can navigate immediately while
  /// the HTTP call to create the session happens in the background.
  RemoteVideSession.pending({
    String? authToken,
  }) : _sessionId = const Uuid().v4(), // Temporary ID
       _wsUrl = null,
       _authToken = authToken,
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

  /// Complete a pending session with actual server details.
  void completePending({
    required String sessionId,
    required String wsUrl,
    required String mainAgentId,
  }) {
    if (!_isPending) return;

    // Remove placeholder agent
    final oldMainId = _mainAgentId;
    if (oldMainId != null) {
      _agents.remove(oldMainId);
    }

    // Update with real details
    _sessionId = sessionId;
    _wsUrl = wsUrl;
    _isPending = false;

    // Add real main agent
    _mainAgentId = mainAgentId;
    _agents[mainAgentId] = _RemoteAgentInfo(
      id: mainAgentId,
      type: 'main',
      name: 'Main',
    );

    // Start connecting
    connectInBackground();

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
  void addPendingUserMessage(String content) {
    final agentId = _mainAgentId;
    if (agentId == null) return;

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
  }

  void _initWithMainAgent(String? mainAgentId) {
    // Pre-populate main agent if provided (avoids "No agents" flash)
    if (mainAgentId != null) {
      _mainAgentId = mainAgentId;
      _agents[mainAgentId] = _RemoteAgentInfo(
        id: mainAgentId,
        type: 'main',
        name: 'Main', // Will be updated when connected event arrives
      );
    }

    // Subscribe to our own events to update conversation state
    _eventController.stream.listen((event) {
      _conversationStateManager.handleEvent(event);
    });
  }

  /// Whether the WebSocket connection has been started.
  bool _connectionStarted = false;

  /// Connect to the remote session and wait for connection to complete.
  ///
  /// This is the blocking version - use [connectInBackground] for non-blocking.
  Future<void> connect() async {
    _startConnection();
    await waitForConnection();
  }

  /// Start connecting in the background without waiting.
  ///
  /// This allows immediate navigation to the execution page while
  /// the WebSocket connection is established. Events will start
  /// streaming once connected.
  void connectInBackground() {
    _startConnection();
  }

  /// Wait for the connection to complete.
  ///
  /// Call this after [connectInBackground] if you need to ensure connection.
  Future<void> waitForConnection() async {
    await _connectCompleter.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw StateError(
          'Timeout waiting for connection to session $_sessionId',
        );
      },
    );
  }

  /// Internal method to start the WebSocket connection.
  void _startConnection() {
    if (_connectionStarted) return;
    if (_wsUrl == null) return; // Can't connect without URL (pending session)
    _connectionStarted = true;

    final uri = _authToken != null
        ? Uri.parse('$_wsUrl?token=$_authToken')
        : Uri.parse(_wsUrl!);

    _channel = WebSocketChannel.connect(uri);

    _channelSubscription = _channel!.stream.listen(
      _handleWebSocketMessage,
      onError: (error) {
        _eventController.addError(error);
        if (!_connectCompleter.isCompleted) {
          _connectCompleter.completeError(error);
        }
      },
      onDone: () {
        if (!_disposed) {
          // Connection closed unexpectedly - could trigger reconnect
          _connected = false;
          _connectionStateController.add(false);
        }
      },
    );
  }

  /// Handles a WebSocket message. Exposed for testing.
  @visibleForTesting
  void handleWebSocketMessage(dynamic message) => _handleWebSocketMessage(message);

  void _handleWebSocketMessage(dynamic message) {
    if (message is! String) return;

    try {
      final json = jsonDecode(message) as Map<String, dynamic>;
      final type = json['type'] as String?;

      switch (type) {
        case 'connected':
          _handleConnected(json);
        case 'history':
          _handleHistory(json);
        case 'message':
          _handleMessage(json);
        case 'tool-use':
          _handleToolUse(json);
        case 'tool-result':
          _handleToolResult(json);
        case 'status':
          _handleStatus(json);
        case 'done':
          _handleDone(json);
        case 'error':
          _handleError(json);
        case 'agent-spawned':
          _handleAgentSpawned(json);
        case 'agent-terminated':
          _handleAgentTerminated(json);
        case 'permission-request':
          _handlePermissionRequest(json);
        case 'permission-timeout':
          _handlePermissionTimeout(json);
        case 'aborted':
          _handleAborted(json);
      }
    } catch (e) {
      // Log but don't crash on malformed messages
      print('[RemoteVideSession] Error parsing message: $e');
    }
  }

  void _handleConnected(Map<String, dynamic> json) {
    _mainAgentId = json['main-agent-id'] as String?;
    _lastSeq = json['last-seq'] as int? ?? 0;

    // Parse metadata
    final metadata = json['metadata'] as Map<String, dynamic>? ?? {};
    _workingDirectory = metadata['working-directory'] as String? ?? '';

    // Parse agents list
    final agentsList = json['agents'] as List<dynamic>? ?? [];
    for (final agentJson in agentsList) {
      final agent = agentJson as Map<String, dynamic>;
      final id = agent['id'] as String;
      _agents[id] = _RemoteAgentInfo(
        id: id,
        type: agent['type'] as String? ?? 'unknown',
        name: agent['name'] as String?,
      );
    }

    _connected = true;
    _connectionStateController.add(true);
    if (!_connectCompleter.isCompleted) {
      _connectCompleter.complete();
    }
  }

  void _handleHistory(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final events = data['events'] as List<dynamic>? ?? [];

    // Process history events without seq filtering
    // (they're replayed history, not duplicates)
    for (final eventJson in events) {
      final event = eventJson as Map<String, dynamic>;
      _processEvent(event, skipSeqCheck: true);
    }

    _lastSeq = json['last-seq'] as int? ?? _lastSeq;
  }

  /// Process a single event, optionally skipping seq check (for history replay).
  void _processEvent(Map<String, dynamic> json, {bool skipSeqCheck = false}) {
    final type = json['type'] as String?;
    switch (type) {
      case 'message':
        _handleMessage(json, skipSeqCheck: skipSeqCheck);
      case 'tool-use':
        _handleToolUse(json, skipSeqCheck: skipSeqCheck);
      case 'tool-result':
        _handleToolResult(json, skipSeqCheck: skipSeqCheck);
      case 'status':
        _handleStatus(json, skipSeqCheck: skipSeqCheck);
      case 'done':
        _handleDone(json, skipSeqCheck: skipSeqCheck);
      case 'error':
        _handleError(json, skipSeqCheck: skipSeqCheck);
      case 'agent-spawned':
        _handleAgentSpawned(json, skipSeqCheck: skipSeqCheck);
      case 'agent-terminated':
        _handleAgentTerminated(json, skipSeqCheck: skipSeqCheck);
      case 'permission-request':
        _handlePermissionRequest(json, skipSeqCheck: skipSeqCheck);
      case 'aborted':
        _handleAborted(json, skipSeqCheck: skipSeqCheck);
    }
  }

  void _handleMessage(Map<String, dynamic> json, {bool skipSeqCheck = false}) {
    final seq = json['seq'] as int? ?? 0;
    if (!skipSeqCheck && seq <= _lastSeq) return; // Duplicate
    if (!skipSeqCheck) _lastSeq = seq;

    final agentId = json['agent-id'] as String;
    final agentInfo = _agents[agentId];
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final isPartial = json['is-partial'] as bool? ?? true;

    // Use or create event ID for streaming
    final eventId = json['event-id'] as String? ?? const Uuid().v4();
    if (isPartial) {
      _currentMessageEventIds[agentId] = eventId;
    } else {
      _currentMessageEventIds.remove(agentId);
    }

    final role = data['role'] as String? ?? 'assistant';
    final content = data['content'] as String? ?? '';

    // Update conversation state
    _updateConversation(
      agentId: agentId,
      eventId: eventId,
      role: role,
      content: content,
      isPartial: isPartial,
    );

    _eventController.add(
      MessageEvent(
        agentId: agentId,
        agentType:
            agentInfo?.type ?? json['agent-type'] as String? ?? 'unknown',
        agentName: agentInfo?.name ?? json['agent-name'] as String?,
        taskName: json['task-name'] as String?,
        eventId: eventId,
        role: role,
        content: content,
        isPartial: isPartial,
      ),
    );
  }

  /// Updates conversation state from a message event.
  ///
  /// For user messages, creates a new message.
  /// For assistant messages, adds to the current assistant message (or creates one).
  void _updateConversation({
    required String agentId,
    required String eventId,
    required String role,
    required String content,
    required bool isPartial,
  }) {
    var conversation = _conversations[agentId] ?? Conversation.empty();
    final messages = List<ConversationMessage>.from(conversation.messages);

    if (role == 'user') {
      // User messages are always new messages
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
      // Clear any current assistant message tracking since user started new turn
      _currentAssistantMessageId.remove(agentId);
    } else {
      // Assistant message - add to current assistant message
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

    final state =
        isPartial ? ConversationState.receivingResponse : ConversationState.idle;

    conversation = conversation.copyWith(messages: messages, state: state);
    _conversations[agentId] = conversation;

    // Notify listeners
    _getOrCreateConversationController(agentId).add(conversation);
  }

  /// Updates conversation state with a tool use event.
  ///
  /// Adds ToolUseResponse to the current assistant message.
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

  /// Updates conversation state with a tool result event.
  ///
  /// Adds ToolResultResponse to the current assistant message.
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
        isStreaming: true, // Still streaming until turn completes
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

  StreamController<Conversation> _getOrCreateConversationController(
    String agentId,
  ) {
    return _conversationControllers.putIfAbsent(
      agentId,
      () => StreamController<Conversation>.broadcast(),
    );
  }

  void _handleToolUse(Map<String, dynamic> json, {bool skipSeqCheck = false}) {
    final seq = json['seq'] as int? ?? 0;
    if (!skipSeqCheck && seq <= _lastSeq) return;
    if (!skipSeqCheck) _lastSeq = seq;

    final agentId = json['agent-id'] as String;
    final agentInfo = _agents[agentId];
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final toolUseId = data['tool-use-id'] as String? ?? const Uuid().v4();
    final toolName = data['tool-name'] as String? ?? 'unknown';
    final toolInput = data['tool-input'] as Map<String, dynamic>? ?? {};

    // Update conversation state with tool use
    _updateConversationWithToolUse(
      agentId: agentId,
      toolUseId: toolUseId,
      toolName: toolName,
      toolInput: toolInput,
    );

    _eventController.add(
      ToolUseEvent(
        agentId: agentId,
        agentType:
            agentInfo?.type ?? json['agent-type'] as String? ?? 'unknown',
        agentName: agentInfo?.name ?? json['agent-name'] as String?,
        taskName: json['task-name'] as String?,
        toolUseId: toolUseId,
        toolName: toolName,
        toolInput: toolInput,
      ),
    );
  }

  void _handleToolResult(Map<String, dynamic> json, {bool skipSeqCheck = false}) {
    final seq = json['seq'] as int? ?? 0;
    if (!skipSeqCheck && seq <= _lastSeq) return;
    if (!skipSeqCheck) _lastSeq = seq;

    final agentId = json['agent-id'] as String;
    final agentInfo = _agents[agentId];
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final toolUseId = data['tool-use-id'] as String? ?? '';
    final toolName = data['tool-name'] as String? ?? 'unknown';
    final result = data['result'];
    final isError = data['is-error'] as bool? ?? false;

    // Update conversation state with tool result
    _updateConversationWithToolResult(
      agentId: agentId,
      toolUseId: toolUseId,
      result: result is String ? result : (result?.toString() ?? ''),
      isError: isError,
    );

    _eventController.add(
      ToolResultEvent(
        agentId: agentId,
        agentType:
            agentInfo?.type ?? json['agent-type'] as String? ?? 'unknown',
        agentName: agentInfo?.name ?? json['agent-name'] as String?,
        taskName: json['task-name'] as String?,
        toolUseId: toolUseId,
        toolName: toolName,
        result: result,
        isError: isError,
      ),
    );
  }

  void _handleStatus(Map<String, dynamic> json, {bool skipSeqCheck = false}) {
    final seq = json['seq'] as int? ?? 0;
    if (!skipSeqCheck && seq <= _lastSeq) return;
    if (!skipSeqCheck) _lastSeq = seq;

    final agentId = json['agent-id'] as String;
    final agentInfo = _agents[agentId];
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final statusStr = data['status'] as String? ?? 'idle';

    final status = switch (statusStr) {
      'working' => VideAgentStatus.working,
      'waiting-for-agent' => VideAgentStatus.waitingForAgent,
      'waiting-for-user' => VideAgentStatus.waitingForUser,
      _ => VideAgentStatus.idle,
    };

    _eventController.add(
      StatusEvent(
        agentId: agentId,
        agentType:
            agentInfo?.type ?? json['agent-type'] as String? ?? 'unknown',
        agentName: agentInfo?.name ?? json['agent-name'] as String?,
        taskName: json['task-name'] as String?,
        status: status,
      ),
    );
  }

  void _handleDone(Map<String, dynamic> json, {bool skipSeqCheck = false}) {
    final seq = json['seq'] as int? ?? 0;
    if (!skipSeqCheck && seq <= _lastSeq) return;
    if (!skipSeqCheck) _lastSeq = seq;

    final agentId = json['agent-id'] as String;
    final agentInfo = _agents[agentId];
    final data = json['data'] as Map<String, dynamic>? ?? {};

    // Mark the current assistant message as complete
    _markAssistantTurnComplete(agentId);

    _eventController.add(
      TurnCompleteEvent(
        agentId: agentId,
        agentType:
            agentInfo?.type ?? json['agent-type'] as String? ?? 'unknown',
        agentName: agentInfo?.name ?? json['agent-name'] as String?,
        taskName: json['task-name'] as String?,
        reason: data['reason'] as String? ?? 'complete',
      ),
    );
  }

  /// Marks the current assistant message as complete.
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

  void _handleError(Map<String, dynamic> json, {bool skipSeqCheck = false}) {
    final seq = json['seq'] as int? ?? 0;
    if (!skipSeqCheck && seq <= _lastSeq) return;
    if (!skipSeqCheck) _lastSeq = seq;

    final agentId = json['agent-id'] as String;
    final agentInfo = _agents[agentId];
    final data = json['data'] as Map<String, dynamic>? ?? {};

    _eventController.add(
      ErrorEvent(
        agentId: agentId,
        agentType:
            agentInfo?.type ?? json['agent-type'] as String? ?? 'unknown',
        agentName: agentInfo?.name ?? json['agent-name'] as String?,
        taskName: json['task-name'] as String?,
        message: data['message'] as String? ?? 'Unknown error',
      ),
    );
  }

  void _handleAgentSpawned(Map<String, dynamic> json, {bool skipSeqCheck = false}) {
    final seq = json['seq'] as int? ?? 0;
    if (!skipSeqCheck && seq <= _lastSeq) return;
    if (!skipSeqCheck) _lastSeq = seq;

    final agentId = json['agent-id'] as String;
    final agentType = json['agent-type'] as String? ?? 'unknown';
    final agentName = json['agent-name'] as String?;
    final data = json['data'] as Map<String, dynamic>? ?? {};

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
        taskName: json['task-name'] as String?,
        spawnedBy: data['spawned-by'] as String? ?? 'unknown',
      ),
    );
  }

  void _handleAgentTerminated(Map<String, dynamic> json, {bool skipSeqCheck = false}) {
    final seq = json['seq'] as int? ?? 0;
    if (!skipSeqCheck && seq <= _lastSeq) return;
    if (!skipSeqCheck) _lastSeq = seq;

    final agentId = json['agent-id'] as String;
    final agentInfo = _agents.remove(agentId);

    // Notify listeners that agents list changed
    _agentsController.add(agents);

    _eventController.add(
      AgentTerminatedEvent(
        agentId: agentId,
        agentType:
            agentInfo?.type ?? json['agent-type'] as String? ?? 'unknown',
        agentName: agentInfo?.name ?? json['agent-name'] as String?,
        taskName: json['task-name'] as String?,
      ),
    );
  }

  void _handlePermissionRequest(Map<String, dynamic> json, {bool skipSeqCheck = false}) {
    final seq = json['seq'] as int? ?? 0;
    if (!skipSeqCheck && seq <= _lastSeq) return;
    if (!skipSeqCheck) _lastSeq = seq;

    final agentId = json['agent-id'] as String;
    final agentInfo = _agents[agentId];
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final tool = data['tool'] as Map<String, dynamic>? ?? {};

    _eventController.add(
      PermissionRequestEvent(
        agentId: agentId,
        agentType:
            agentInfo?.type ?? json['agent-type'] as String? ?? 'unknown',
        agentName: agentInfo?.name ?? json['agent-name'] as String?,
        taskName: json['task-name'] as String?,
        requestId: data['request-id'] as String? ?? const Uuid().v4(),
        toolName: tool['name'] as String? ?? 'unknown',
        toolInput: tool['input'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  void _handlePermissionTimeout(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final requestId = data['request-id'] as String?;
    if (requestId != null) {
      final completer = _pendingPermissions.remove(requestId);
      completer?.complete(
        const PermissionResultDeny(message: 'Permission request timed out'),
      );
    }
  }

  void _handleAborted(Map<String, dynamic> json, {bool skipSeqCheck = false}) {
    final seq = json['seq'] as int? ?? 0;
    if (!skipSeqCheck && seq <= _lastSeq) return;
    if (!skipSeqCheck) _lastSeq = seq;

    final agentId = json['agent-id'] as String;
    final agentInfo = _agents[agentId];

    _eventController.add(
      TurnCompleteEvent(
        agentId: agentId,
        agentType:
            agentInfo?.type ?? json['agent-type'] as String? ?? 'unknown',
        agentName: agentInfo?.name ?? json['agent-name'] as String?,
        taskName: json['task-name'] as String?,
        reason: 'aborted',
      ),
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
            status: VideAgentStatus.idle, // TODO: Track status
            createdAt: DateTime.now(), // Remote doesn't track this
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
  bool get isProcessing => false; // TODO: Track from status events

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
    _channel?.sink.add(
      jsonEncode({
        'type': 'user-message',
        'content': message.text,
        if (agentId != null) 'agent-id': agentId,
      }),
    );
  }

  @override
  void respondToPermission(
    String requestId, {
    required bool allow,
    String? message,
  }) {
    _checkNotDisposed();
    _channel?.sink.add(
      jsonEncode({
        'type': 'permission-response',
        'request-id': requestId,
        'allow': allow,
        if (message != null) 'message': message,
      }),
    );
  }

  @override
  Future<void> abort() async {
    _checkNotDisposed();
    _channel?.sink.add(jsonEncode({'type': 'abort'}));
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

    await _channelSubscription?.cancel();
    await _channel?.sink.close();
    _channel = null;

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
  // Stub implementations for methods not supported in remote mode
  // ============================================================

  @override
  Future<void> clearConversation({String? agentId}) async {
    // Not supported in remote mode
  }

  @override
  T? getMcpServer<T extends McpServerBase>(String agentId, String serverName) {
    return null; // Not available in remote mode
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
    // Permissions are handled via WebSocket events in remote mode
    throw UnimplementedError(
      'createPermissionCallback not used in remote mode',
    );
  }

  @override
  void respondToAskUserQuestion(
    String requestId, {
    required Map<String, String> answers,
  }) {
    // AskUserQuestion responses are handled via WebSocket in remote mode
    _checkNotDisposed();
    _channel?.sink.add(
      jsonEncode({
        'type': 'ask-user-question-response',
        'request-id': requestId,
        'answers': answers,
      }),
    );
  }

  @override
  void addSessionPermissionPattern(String pattern) {
    // Session patterns are managed server-side in remote mode
  }

  @override
  bool isAllowedBySessionCache(String toolName, Map<String, dynamic> input) {
    // Session cache is managed server-side in remote mode
    return false;
  }

  @override
  void clearSessionPermissionCache() {
    // Session cache is managed server-side in remote mode
  }
}

/// Tracks info about a remote agent.
class _RemoteAgentInfo {
  final String id;
  final String type;
  final String? name;

  _RemoteAgentInfo({required this.id, required this.type, this.name});
}
