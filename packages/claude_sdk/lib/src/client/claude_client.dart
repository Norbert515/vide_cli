import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:uuid/uuid.dart';

import '../models/config.dart';
import '../models/message.dart';
import '../models/response.dart';
import '../models/conversation.dart';
import '../mcp/server/mcp_server_base.dart';
import '../protocol/json_decoder.dart';
import '../control/control_types.dart';
import '../control/control_protocol.dart';
import '../control/control_responses.dart';
import 'conversation_loader.dart';
import 'process_manager.dart';
import 'response_processor.dart';
import 'process_lifecycle_manager.dart';

abstract class ClaudeClient {
  Stream<Conversation> get conversation;
  Conversation get currentConversation;
  String get sessionId;
  void sendMessage(Message message);
  Future<void> close();
  Future<void> abort();

  String get workingDirectory;

  /// Callback when a MetaResponse (init message) is received
  @Deprecated('Use initDataStream instead')
  abstract void Function(MetaResponse response)? onMetaResponseReceived;

  /// Stream of init data (MetaResponse) from the Claude CLI.
  /// Emits when the init message is received after CLI starts.
  /// Contains MCP servers, tools, skills, model, etc.
  Stream<MetaResponse> get initDataStream;

  /// The most recent init data, or null if not yet received.
  MetaResponse? get initData;

  /// Future that completes when the client has finished initializing.
  /// Use this to wait for the control protocol to be ready before
  /// calling methods like getMcpStatus().
  Future<void> get initialized;

  /// Stream that emits whenever the queued message changes.
  /// Emits the current queued text, or null when queue is cleared.
  Stream<String?> get queuedMessage;

  /// The current queued message text, or null if no message is queued.
  String? get currentQueuedMessage;

  /// Clears any queued message without sending it.
  void clearQueuedMessage();

  /// Clears the conversation history, starting fresh.
  Future<void> clearConversation();

  /// Injects a synthetic tool result into the conversation.
  /// Used to mark a pending tool invocation as failed (e.g., when permission is denied).
  void injectToolResult(ToolResultResponse toolResult);

  /// Emits when a conversation turn completes (assistant finishes responding).
  /// This is the clean way to detect when an agent has finished its work.
  Stream<void> get onTurnComplete;

  /// Stream of Claude's current processing status.
  /// Emits status updates like processing, thinking, responding, completed.
  /// Useful for showing real-time activity indicators in the UI.
  Stream<ClaudeStatus> get statusStream;

  /// The most recent status from Claude.
  ClaudeStatus get currentStatus;

  /// Sets the permission mode for subsequent tool use.
  ///
  /// [mode] - The permission mode to set (e.g., 'acceptEdits', 'plan', 'ask', 'deny').
  /// This is sent as a control request to the Claude CLI.
  Future<void> setPermissionMode(String mode);

  T? getMcpServer<T extends McpServerBase>(String name);

  // ============================================================
  // CONTROL PROTOCOL METHODS
  // These allow querying and controlling the Claude CLI session
  // ============================================================

  /// Get the status of all MCP servers.
  ///
  /// This can be called before sending any user messages to get
  /// information about configured MCP servers.
  ///
  /// Returns [McpStatusResponse] containing status of all MCP servers.
  /// Throws if the control protocol is not yet initialized.
  Future<McpStatusResponse> getMcpStatus();

  /// Set the model for subsequent API calls.
  ///
  /// [model] - Model identifier (e.g., 'sonnet', 'opus', 'haiku',
  /// or full model ID like 'claude-sonnet-4-5-20250929')
  Future<SetModelResponse> setModel(String model);

  /// Set the maximum thinking tokens for extended thinking.
  ///
  /// [maxTokens] - Maximum number of thinking tokens (0 to disable)
  Future<SetMaxThinkingTokensResponse> setMaxThinkingTokens(int maxTokens);

  /// Configure MCP servers dynamically.
  ///
  /// [servers] - List of MCP server configurations to add/update
  /// [replace] - If true, replaces all existing servers. If false, merges.
  Future<void> setMcpServers(
    List<McpServerConfig> servers, {
    bool replace = false,
  });

  /// Interrupt the current execution.
  Future<void> interrupt();

  /// Rewind files to a previous state.
  ///
  /// [userMessageId] - The message ID to rewind to
  Future<void> rewindFiles(String userMessageId);

  /// Creates and fully initializes a client.
  /// Awaits initialization before returning.
  static Future<ClaudeClient> create({
    ClaudeConfig? config,
    List<McpServerBase>? mcpServers,
    Map<HookEvent, List<HookMatcher>>? hooks,
    CanUseToolCallback? canUseTool,
    void Function(MetaResponse response)? onMetaResponseReceived,
  }) async {
    final client = ClaudeClientImpl(
      config: config ?? ClaudeConfig.defaults(),
      mcpServers: mcpServers,
      hooks: hooks,
      canUseTool: canUseTool,
    );
    // Set callback BEFORE init so it's available when init message arrives
    client.onMetaResponseReceived = onMetaResponseReceived;
    await client.init();
    return client;
  }

  /// Creates a client that initializes in the background.
  /// Returns immediately - the client will be usable but messages sent before
  /// init completes will be queued and sent once initialization finishes.
  ///
  /// [initialConversation] - Optional pre-loaded conversation for forked agents.
  /// When set, the client starts with this conversation instead of loading from disk.
  static ClaudeClient createNonBlocking({
    ClaudeConfig? config,
    List<McpServerBase>? mcpServers,
    Map<HookEvent, List<HookMatcher>>? hooks,
    CanUseToolCallback? canUseTool,
    void Function(MetaResponse response)? onMetaResponseReceived,
    Conversation? initialConversation,
  }) {
    final client = ClaudeClientImpl(
      config: config ?? ClaudeConfig.defaults(),
      mcpServers: mcpServers,
      hooks: hooks,
      canUseTool: canUseTool,
      initialConversation: initialConversation,
    );
    // Set callback BEFORE init so it's available when init message arrives
    client.onMetaResponseReceived = onMetaResponseReceived;
    // Initialize in background - don't await
    client.init();
    return client;
  }
}

class ClaudeClientImpl implements ClaudeClient {
  ClaudeConfig config;
  final List<McpServerBase> mcpServers;
  @override
  String get sessionId => config.sessionId!;
  final JsonDecoder _decoder = JsonDecoder();

  /// Hook configuration for control protocol
  final Map<HookEvent, List<HookMatcher>>? hooks;

  /// Permission callback for control protocol
  final CanUseToolCallback? canUseTool;

  @override
  void Function(MetaResponse response)? onMetaResponseReceived;

  /// Response processor for handling Claude responses
  final ResponseProcessor _responseProcessor = ResponseProcessor();

  /// Process lifecycle manager for process management
  final ProcessLifecycleManager _lifecycleManager = ProcessLifecycleManager();

  bool _isInitialized = false;
  final Completer<void> _initializedCompleter = Completer<void>();

  @override
  Future<void> get initialized => _initializedCompleter.future;

  /// Tracks whether this is the first message in the session.
  /// Used to determine whether to use --session-id (new) or --resume (existing).
  bool _isFirstMessage = true;

  /// Queue for messages sent before init completes
  final List<Message> _pendingMessages = [];

  /// Tracks in-progress control protocol startup to prevent duplicate subscriptions.
  /// When not null, a _startControlProtocol() call is in progress.
  Future<void>? _startingControlProtocol;

  // Conversation state management - persistent across process invocations
  final _conversationController = StreamController<Conversation>.broadcast();
  final _turnCompleteController = StreamController<void>.broadcast();
  final _statusController = StreamController<ClaudeStatus>.broadcast();
  final _initDataController = StreamController<MetaResponse>.broadcast();
  Conversation
  _currentConversation; // Initialized in constructor (may be pre-loaded for forks)
  ClaudeStatus _currentStatus = ClaudeStatus.ready;
  MetaResponse? _initData;

  // Message queue for messages sent while processing
  String? _queuedMessageText;
  List<Attachment>? _queuedAttachments;
  final _queuedMessageController = StreamController<String?>.broadcast();

  @override
  Stream<Conversation> get conversation => _conversationController.stream;

  @override
  Stream<void> get onTurnComplete => _turnCompleteController.stream;

  @override
  Stream<String?> get queuedMessage => _queuedMessageController.stream;

  @override
  String? get currentQueuedMessage => _queuedMessageText;

  @override
  Stream<ClaudeStatus> get statusStream => _statusController.stream;

  @override
  ClaudeStatus get currentStatus => _currentStatus;

  @override
  Stream<MetaResponse> get initDataStream => _initDataController.stream;

  @override
  MetaResponse? get initData => _initData;

  @override
  Conversation get currentConversation => _currentConversation;

  ClaudeClientImpl({
    ClaudeConfig? config,
    List<McpServerBase>? mcpServers,
    this.hooks,
    this.canUseTool,
    Conversation? initialConversation,
  }) : config = config ?? ClaudeConfig.defaults(),
       mcpServers = mcpServers ?? [],
       _currentConversation = initialConversation ?? Conversation.empty() {
    // Ensure config has a session ID
    if (this.config.sessionId == null) {
      this.config = this.config.copyWith(sessionId: const Uuid().v4());
    }
    if (this.config.workingDirectory == null) {
      this.config = this.config.copyWith(
        workingDirectory: Directory.current.path,
      );
    }

    // If we have an initial conversation (e.g., from forking), emit it immediately
    if (initialConversation != null) {
      _conversationController.add(_currentConversation);
    }

    // Auto-flush queued messages when turn completes
    _turnCompleteController.stream.listen((_) {
      _flushQueuedMessage();
    });
  }

  Future<void> init() async {
    if (_isInitialized) {
      return;
    }

    if (await ConversationLoader.hasConversation(
      sessionId,
      config.workingDirectory!,
    )) {
      final conversation = await ConversationLoader.loadHistoryForDisplay(
        sessionId,
        config.workingDirectory!,
      );
      _currentConversation = conversation;
      _conversationController.add(conversation);
      // Existing conversation means we should use --resume for subsequent messages
      _isFirstMessage = false;
    }

    _isInitialized = true;

    // For resumed sessions (existing conversation loaded from disk),
    // defer starting MCP servers and the Claude process until the user
    // sends a message. This avoids unnecessary processing when just
    // viewing history.
    if (_isFirstMessage) {
      // New session — start everything eagerly
      for (int i = 0; i < mcpServers.length; i++) {
        final server = mcpServers[i];
        if (server.isRunning) continue;
        await server.start();
      }

      await _startControlProtocol();
    }

    // Signal that initialization is complete
    if (!_initializedCompleter.isCompleted) {
      _initializedCompleter.complete();
    }

    // Flush any messages that were queued before init completed
    _flushPendingMessages();
  }

  /// Send any messages that were queued before init completed
  void _flushPendingMessages() {
    if (_pendingMessages.isEmpty) return;

    final controlProtocol = _lifecycleManager.controlProtocol;
    if (controlProtocol == null) return;

    // Update status to processing so triggers can detect when agent becomes idle
    _updateStatus(ClaudeStatus.processing);

    for (final message in _pendingMessages) {
      _sendMessageViaProtocol(message, controlProtocol);
    }
    _pendingMessages.clear();
  }

  /// Start a persistent process with control protocol.
  ///
  /// This method is idempotent - concurrent calls will await the same startup
  /// to prevent duplicate subscriptions.
  Future<void> _startControlProtocol() async {
    // If already starting, await the in-progress startup
    if (_startingControlProtocol != null) {
      await _startingControlProtocol;
      return;
    }

    // If already running, nothing to do
    if (_lifecycleManager.controlProtocol != null) {
      return;
    }

    // Mark startup as in-progress
    final completer = Completer<void>();
    _startingControlProtocol = completer.future;

    try {
      // Ensure MCP servers are started before getting their configs
      // This handles the case where sendMessage is called before init completes
      for (final server in mcpServers) {
        if (!server.isRunning) {
          await server.start();
        }
      }

      final processManager = ProcessManager(
        config: config,
        mcpServers: mcpServers,
      );
      final args = config.toCliArgs(
        isFirstMessage: _isFirstMessage,
        hasPermissionCallback: canUseTool != null,
      );

      final mcpArgs = await processManager.getMcpArgs();
      if (mcpArgs.isNotEmpty) {
        args.insertAll(0, mcpArgs);
      }

      // Delegate process start to lifecycle manager
      final controlProtocol = await _lifecycleManager.startProcess(
        config: config,
        args: args,
        hooks: hooks,
        canUseTool: canUseTool,
      );

      // Listen to messages from control protocol
      controlProtocol.messages.listen(_handleControlProtocolMessage);

      // After successful start, subsequent messages should use --resume
      _isFirstMessage = false;

      // If this was a fork operation, clear fork settings so subsequent messages
      // use the new session ID instead of trying to fork again
      if (config.forkSession && config.resumeSessionId != null) {
        config = config.copyWith(resumeSessionId: null, forkSession: false);
      }

      completer.complete();
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _startingControlProtocol = null;
    }
  }

  /// Handle messages from the control protocol
  void _handleControlProtocolMessage(Map<String, dynamic> json) {
    final jsonStr = jsonEncode(json);

    // Use decodeMultiple to handle interleaved assistant content
    final responses = _decoder.decodeMultiple(jsonStr);
    if (responses.isEmpty) return;

    // Process each response (usually just one, but can be multiple for interleaved content)
    var conversation = _currentConversation;
    var turnComplete = false;

    for (final response in responses) {
      // Extract and emit status updates
      if (response is StatusResponse) {
        _updateStatus(response.status);
      }

      // Store and emit init data when MetaResponse is received
      if (response is MetaResponse) {
        _initData = response;
        _initDataController.add(response);

        // If we forked a session, Claude returns the new session ID in the response
        // Update our config to use that session ID for subsequent messages
        if (response.sessionId != null &&
            response.sessionId != config.sessionId) {
          config = config.copyWith(sessionId: response.sessionId);
        }

        // Also call legacy callback for backwards compatibility
        // ignore: deprecated_member_use_from_same_package
        onMetaResponseReceived?.call(response);
      }

      // Delegate response processing to ResponseProcessor
      final result = _responseProcessor.processResponse(response, conversation);
      conversation = result.updatedConversation;
      turnComplete = turnComplete || result.turnComplete;
    }

    _updateConversation(conversation);

    if (turnComplete) {
      // When turn completes, update status to ready (idle)
      // This enables trigger systems to detect when agents are done
      _updateStatus(ClaudeStatus.ready);
      _turnCompleteController.add(null);
    }
  }

  @override
  T? getMcpServer<T extends McpServerBase>(String name) {
    try {
      return mcpServers.whereType<T>().firstWhere((s) => s.name == name);
    } catch (_) {
      return null;
    }
  }

  void _updateConversation(Conversation newConversation) {
    _currentConversation = newConversation;
    _conversationController.add(_currentConversation);
  }

  void _updateStatus(ClaudeStatus status) {
    if (_currentStatus != status) {
      _currentStatus = status;
      _statusController.add(status);
    }
  }

  @override
  void injectToolResult(ToolResultResponse toolResult) {
    // Find the last assistant message and add the tool result to it
    if (_currentConversation.messages.isEmpty) return;

    final lastIndex = _currentConversation.messages.length - 1;
    final lastMessage = _currentConversation.messages[lastIndex];

    if (lastMessage.role != MessageRole.assistant) return;

    // Add the tool result to the responses
    final updatedMessage = lastMessage.copyWith(
      responses: [...lastMessage.responses, toolResult],
    );

    final updatedMessages = [..._currentConversation.messages];
    updatedMessages[lastIndex] = updatedMessage;

    _updateConversation(
      _currentConversation.copyWith(messages: updatedMessages),
    );
  }

  @override
  void sendMessage(Message message) {
    if (message.text.trim().isEmpty && (message.attachments?.isEmpty ?? true)) {
      return;
    }

    // If currently processing, queue the message instead of sending
    if (_currentConversation.isProcessing) {
      _queueMessage(message);
      return;
    }

    // If not initialized or protocol was aborted, queue the message and restart
    final controlProtocol = _lifecycleManager.controlProtocol;
    if (controlProtocol == null) {
      _pendingMessages.add(message);
      // Update conversation optimistically so UI shows the message
      final userMessage = ConversationMessage.user(
        content: message.text,
        attachments: message.attachments,
      );
      _updateConversation(
        _currentConversation
            .addMessage(userMessage)
            .withState(ConversationState.sendingMessage),
      );

      // Restart the control protocol since it was aborted or not yet initialized
      // Use unawaited async to avoid blocking, but ensure messages are flushed
      () async {
        try {
          await _startControlProtocol();
          _flushPendingMessages();
        } catch (e) {
          // If protocol startup fails, reset state so user can retry
          _updateConversation(
            _currentConversation.withState(ConversationState.idle),
          );
        }
      }();
      return;
    }

    // Add user message to conversation
    final userMessage = ConversationMessage.user(
      content: message.text,
      attachments: message.attachments,
    );
    _updateConversation(
      _currentConversation
          .addMessage(userMessage)
          .withState(ConversationState.sendingMessage),
    );

    // Update status to processing so triggers can detect when agent becomes idle
    _updateStatus(ClaudeStatus.processing);

    // Send via control protocol
    _sendMessageViaProtocol(message, controlProtocol);
  }

  void _sendMessageViaProtocol(
    Message message,
    ControlProtocol controlProtocol,
  ) {
    if (message.attachments != null && message.attachments!.isNotEmpty) {
      // Build content array with attachments
      final content = <Map<String, dynamic>>[
        {'type': 'text', 'text': message.text},
        ...message.attachments!.map((a) => a.toClaudeJson()),
      ];
      controlProtocol.sendUserMessageWithContent(content);
    } else {
      controlProtocol.sendUserMessage(message.text);
    }
  }

  void _queueMessage(Message message) {
    if (_queuedMessageText == null) {
      _queuedMessageText = message.text;
      _queuedAttachments = message.attachments;
    } else {
      // Append with newline
      _queuedMessageText = '$_queuedMessageText\n${message.text}';
      if (message.attachments != null) {
        _queuedAttachments = [
          ...(_queuedAttachments ?? []),
          ...message.attachments!,
        ];
      }
    }
    _queuedMessageController.add(_queuedMessageText);
  }

  void _flushQueuedMessage() {
    if (_queuedMessageText == null) {
      return;
    }

    final text = _queuedMessageText!;
    final attachments = _queuedAttachments;

    // Clear queue first
    _queuedMessageText = null;
    _queuedAttachments = null;
    _queuedMessageController.add(null);

    // Send the queued message
    sendMessage(Message(text: text, attachments: attachments));
  }

  @override
  void clearQueuedMessage() {
    _queuedMessageText = null;
    _queuedAttachments = null;
    _queuedMessageController.add(null);
  }

  @override
  Future<void> abort() async {
    final controlProtocol = _lifecycleManager.controlProtocol;
    if (controlProtocol == null) {
      // Not initialized yet, nothing to abort
      return;
    }

    try {
      // Use control protocol interrupt for graceful stop
      await controlProtocol.interrupt();
    } catch (e) {
      _updateConversation(
        _currentConversation.withError('Failed to abort: $e'),
      );
    }
  }

  @override
  Future<void> setPermissionMode(String mode) async {
    final controlProtocol = _lifecycleManager.controlProtocol;
    if (controlProtocol == null) {
      // Client not initialized yet - this will take effect when it starts
      // via the config's permissionMode field
      return;
    }
    await controlProtocol.setPermissionMode(mode);
  }

  @override
  Future<McpStatusResponse> getMcpStatus() async {
    final controlProtocol = _lifecycleManager.controlProtocol;
    if (controlProtocol == null) {
      throw StateError('Client not initialized - cannot query MCP status');
    }
    return await controlProtocol.getMcpStatus();
  }

  @override
  Future<SetModelResponse> setModel(String model) async {
    // Wait for initialization if not ready yet
    await initialized;
    final controlProtocol = _lifecycleManager.controlProtocol;
    if (controlProtocol == null) {
      throw StateError('Client not initialized - cannot set model');
    }
    return await controlProtocol.setModel(model);
  }

  @override
  Future<SetMaxThinkingTokensResponse> setMaxThinkingTokens(
    int maxTokens,
  ) async {
    final controlProtocol = _lifecycleManager.controlProtocol;
    if (controlProtocol == null) {
      throw StateError(
        'Client not initialized - cannot set max thinking tokens',
      );
    }
    return await controlProtocol.setMaxThinkingTokens(maxTokens);
  }

  @override
  Future<void> setMcpServers(
    List<McpServerConfig> servers, {
    bool replace = false,
  }) async {
    final controlProtocol = _lifecycleManager.controlProtocol;
    if (controlProtocol == null) {
      throw StateError('Client not initialized - cannot set MCP servers');
    }
    await controlProtocol.setMcpServers(servers, replace: replace);
  }

  @override
  Future<void> interrupt() async {
    final controlProtocol = _lifecycleManager.controlProtocol;
    if (controlProtocol == null) {
      // No active session to interrupt
      return;
    }
    await controlProtocol.interrupt();

    // Mark the last assistant message as complete (not streaming) so that
    // subsequent responses create a new message instead of appending to it
    final messages = _currentConversation.messages;
    if (messages.isNotEmpty) {
      final lastMessage = messages.last;
      if (lastMessage.role == MessageRole.assistant &&
          lastMessage.isStreaming) {
        final updatedMessage = lastMessage.copyWith(
          isStreaming: false,
          isComplete: true,
        );
        final updatedMessages = [...messages];
        updatedMessages[updatedMessages.length - 1] = updatedMessage;
        _updateConversation(
          _currentConversation
              .copyWith(messages: updatedMessages)
              .withState(ConversationState.idle),
        );
      }
    }
  }

  @override
  Future<void> rewindFiles(String userMessageId) async {
    final controlProtocol = _lifecycleManager.controlProtocol;
    if (controlProtocol == null) {
      throw StateError('Client not initialized - cannot rewind files');
    }
    await controlProtocol.rewindFiles(userMessageId);
  }

  @override
  Future<void> clearConversation() async {
    _updateConversation(Conversation.empty());
    _isFirstMessage = true;
  }

  @override
  Future<void> close() async {
    // Delegate process cleanup to lifecycle manager
    await _lifecycleManager.close();

    // Stop all MCP servers
    for (final server in mcpServers) {
      await server.stop();
    }

    // Close streams
    await _conversationController.close();
    await _turnCompleteController.close();
    await _statusController.close();
    await _initDataController.close();
    await _queuedMessageController.close();

    _isInitialized = false;
  }

  Future<void> restart() async {
    await close();
    _isFirstMessage = true;
  }

  @override
  String get workingDirectory => config.workingDirectory!;
}
