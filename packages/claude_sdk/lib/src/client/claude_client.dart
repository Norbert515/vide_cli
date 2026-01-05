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
  bool get isAborting;

  String get workingDirectory;

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

  T? getMcpServer<T extends McpServerBase>(String name);

  /// Creates and fully initializes a client.
  /// Awaits initialization before returning.
  static Future<ClaudeClient> create({
    ClaudeConfig? config,
    List<McpServerBase>? mcpServers,
    Map<HookEvent, List<HookMatcher>>? hooks,
    CanUseToolCallback? canUseTool,
  }) async {
    final client = ClaudeClientImpl(
      config: config ?? ClaudeConfig.defaults(),
      mcpServers: mcpServers,
      hooks: hooks,
      canUseTool: canUseTool,
    );
    await client.init();
    return client;
  }

  /// Creates a client that initializes in the background.
  /// Returns immediately - the client will be usable but messages sent before
  /// init completes will be queued and sent once initialization finishes.
  static ClaudeClient createNonBlocking({
    ClaudeConfig? config,
    List<McpServerBase>? mcpServers,
    Map<HookEvent, List<HookMatcher>>? hooks,
    CanUseToolCallback? canUseTool,
  }) {
    final client = ClaudeClientImpl(
      config: config ?? ClaudeConfig.defaults(),
      mcpServers: mcpServers,
      hooks: hooks,
      canUseTool: canUseTool,
    );
    // Initialize in background - don't await
    client.init();
    return client;
  }
}

class ClaudeClientImpl implements ClaudeClient {
  ClaudeConfig config;
  final List<McpServerBase> mcpServers;
  @override
  final String sessionId;
  final JsonDecoder _decoder = JsonDecoder();

  /// Hook configuration for control protocol
  final Map<HookEvent, List<HookMatcher>>? hooks;

  /// Permission callback for control protocol
  final CanUseToolCallback? canUseTool;

  /// Response processor for handling Claude responses
  final ResponseProcessor _responseProcessor = ResponseProcessor();

  /// Process lifecycle manager for process management
  final ProcessLifecycleManager _lifecycleManager = ProcessLifecycleManager();

  bool _isInitialized = false;

  /// Tracks whether this is the first message in the session.
  /// Used to determine whether to use --session-id (new) or --resume (existing).
  bool _isFirstMessage = true;

  /// Queue for messages sent before init completes
  final List<Message> _pendingMessages = [];

  /// Tracks in-progress control protocol startup to prevent duplicate subscriptions.
  /// When not null, a _startControlProtocol() call is in progress.
  Future<void>? _startingControlProtocol;

  @override
  bool get isAborting => _lifecycleManager.isAborting;

  // Conversation state management - persistent across process invocations
  final _conversationController = StreamController<Conversation>.broadcast();
  final _turnCompleteController = StreamController<void>.broadcast();
  final _statusController = StreamController<ClaudeStatus>.broadcast();
  Conversation _currentConversation = Conversation.empty();
  ClaudeStatus _currentStatus = ClaudeStatus.ready;

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
  Conversation get currentConversation => _currentConversation;

  ClaudeClientImpl({
    ClaudeConfig? config,
    List<McpServerBase>? mcpServers,
    this.hooks,
    this.canUseTool,
  }) : config = config ?? ClaudeConfig.defaults(),
       mcpServers = mcpServers ?? [],
       sessionId = config?.sessionId ?? const Uuid().v4() {
    // Update config with session ID if not already set
    if (this.config.sessionId == null) {
      this.config = this.config.copyWith(sessionId: sessionId);
    }
    if (this.config.workingDirectory == null) {
      this.config = this.config.copyWith(
        workingDirectory: Directory.current.path,
      );
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

    // Start MCP servers
    for (int i = 0; i < mcpServers.length; i++) {
      final server = mcpServers[i];
      // Skip if server is already running (e.g., shared servers between agents)
      if (server.isRunning) {
        continue;
      }

      await server.start();
    }

    // Control protocol is always required
    await _startControlProtocol();

    // Flush any messages that were queued before init completed
    _flushPendingMessages();
  }

  /// Send any messages that were queued before init completed
  void _flushPendingMessages() {
    if (_pendingMessages.isEmpty) return;

    final controlProtocol = _lifecycleManager.controlProtocol;
    if (controlProtocol == null) return;

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
    // Use decodeMultiple to handle interleaved assistant content
    final responses = _decoder.decodeMultiple(jsonEncode(json));
    if (responses.isEmpty) return;

    // Process each response (usually just one, but can be multiple for interleaved content)
    var conversation = _currentConversation;
    var turnComplete = false;

    for (final response in responses) {
      // Extract and emit status updates
      if (response is StatusResponse) {
        _updateStatus(response.status);
      }

      // Delegate response processing to ResponseProcessor
      final result = _responseProcessor.processResponse(response, conversation);
      conversation = result.updatedConversation;
      turnComplete = turnComplete || result.turnComplete;
    }

    _updateConversation(conversation);

    if (turnComplete) {
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
    if (_queuedMessageText == null) return;

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
    if (!_lifecycleManager.isRunning) {
      // Still need to reset state if we're showing as processing
      if (_currentConversation.isProcessing) {
        _updateConversation(
          _currentConversation.withState(ConversationState.idle),
        );
      }
      return;
    }

    try {
      // Delegate abort to lifecycle manager
      await _lifecycleManager.abort();

      // Add synthetic abort message to conversation
      final assistantId = DateTime.now().millisecondsSinceEpoch.toString();
      final abortMessage = ConversationMessage.assistant(
        id: assistantId,
        responses: [
          ErrorResponse(
            id: assistantId,
            timestamp: DateTime.now(),
            error: 'Interrupted by user',
            details: 'Process stopped by user (Ctrl+C)',
          ),
        ],
        isStreaming: false,
        isComplete: true,
      );

      // Update conversation state
      _updateConversation(
        _currentConversation
            .addMessage(abortMessage)
            .withState(ConversationState.idle),
      );
    } catch (e) {
      _updateConversation(
        _currentConversation.withError('Failed to abort: $e'),
      );
    }
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
