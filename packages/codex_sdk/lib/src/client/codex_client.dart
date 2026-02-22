import 'dart:async';
import 'dart:io';

import 'package:claude_sdk/claude_sdk.dart';
import 'package:uuid/uuid.dart';

import '../config/codex_config.dart';
import '../config/codex_mcp_registry.dart';
import '../protocol/codex_approval.dart';
import '../protocol/codex_event.dart';
import '../protocol/codex_event_mapper.dart';
import '../protocol/codex_event_parser.dart';
import '../protocol/json_rpc_message.dart';
import '../transport/codex_transport.dart';

/// Standalone client backed by Codex CLI (`codex app-server`).
///
/// Uses a persistent subprocess communicating via JSON-RPC over stdin/stdout.
/// The transport layer handles message framing and request correlation.
/// Notifications are parsed into [CodexEvent]s, mapped to [ClaudeResponse]
/// objects, and fed through [ResponseProcessor] so the entire downstream
/// pipeline (Conversation, TUI, vide_server) works unchanged.
class CodexClient {
  final CodexConfig codexConfig;
  final List<McpServerBase> mcpServers;
  final ResponseProcessor _responseProcessor = ResponseProcessor();
  final CodexEventParser _parser = CodexEventParser();
  final CodexEventMapper _mapper = CodexEventMapper();

  final CodexTransport _transport = CodexTransport();

  String? _threadId;
  bool _isInitialized = false;
  bool _isClosed = false;
  final Completer<void> _initializedCompleter = Completer<void>();

  /// Queue for messages sent before init completes (via createSync path).
  final List<Message> _pendingMessages = [];

  final String _sessionId;
  final String _workingDirectory;

  // Stream controllers
  final _conversationController = StreamController<Conversation>.broadcast();
  final _turnCompleteController = StreamController<void>.broadcast();
  final _statusController = StreamController<ClaudeStatus>.broadcast();
  final _initDataController = StreamController<MetaResponse>.broadcast();
  final _queuedMessageController = StreamController<String?>.broadcast();
  final _approvalRequestController =
      StreamController<CodexApprovalRequest>.broadcast();

  Conversation _currentConversation = Conversation.empty();
  ClaudeStatus _currentStatus = ClaudeStatus.ready;
  MetaResponse? _initData;

  String? _queuedMessageText;
  List<Attachment>? _queuedAttachments;

  void Function(MetaResponse response)? onMetaResponseReceived;

  CodexClient({required this.codexConfig, List<McpServerBase>? mcpServers})
    : mcpServers = mcpServers ?? [],
      _sessionId = codexConfig.sessionId ?? const Uuid().v4(),
      _workingDirectory =
          codexConfig.workingDirectory ?? Directory.current.path {
    // Auto-flush queued messages when turn completes
    _turnCompleteController.stream.listen((_) {
      _flushQueuedMessage();
    });
  }

  /// Initialize the client: start MCP servers, launch app-server, handshake,
  /// start a thread, and wait for MCP startup to complete.
  Future<void> init() async {
    if (_isInitialized) return;

    // Start MCP servers
    for (final server in mcpServers) {
      if (!server.isRunning) {
        await server.start();
      }
    }

    // Write MCP config before starting the app-server
    if (mcpServers.isNotEmpty) {
      await CodexMcpRegistry.writeConfig(
        mcpServers: mcpServers,
        workingDirectory: _workingDirectory,
      );
    }

    // Start the persistent subprocess
    await _transport.start(workingDirectory: _workingDirectory);

    // Subscribe to notifications → event pipeline
    _transport.notifications.listen(_onNotification);

    // Subscribe to server requests → approval pipeline
    _transport.serverRequests.listen(_onServerRequest);

    // Initialize handshake
    final initResponse = await _transport.sendRequest('initialize', {
      'clientInfo': {
        'name': 'vide',
        'version': '0.1.0',
        'title': 'Vide',
      },
      'capabilities': {'experimentalApi': true},
    });

    if (initResponse.isError) {
      throw StateError(
        'Codex initialize failed: ${initResponse.error?.message}',
      );
    }

    // Send initialized notification
    _transport.sendNotification('initialized');

    // Start a thread
    final threadResponse = await _transport.sendRequest(
      'thread/start',
      codexConfig.toThreadStartParams(),
    );

    if (threadResponse.isError) {
      throw StateError(
        'Codex thread/start failed: ${threadResponse.error?.message}',
      );
    }

    final threadResult = threadResponse.result ?? {};
    final thread = threadResult['thread'] as Map<String, dynamic>? ?? {};
    _threadId = thread['id'] as String?;

    // Wait for mcp_startup_complete notification
    if (mcpServers.isNotEmpty) {
      await _transport.notifications
          .where((n) => n.method == 'codex/event/mcp_startup_complete')
          .first
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException(
              'Timed out waiting for MCP startup to complete',
            ),
          );
    }

    _isInitialized = true;
    if (!_initializedCompleter.isCompleted) {
      _initializedCompleter.complete();
    }

    // Flush any messages that were queued before init completed
    _flushPendingMessages();
  }

  // ============================================================
  // Public API
  // ============================================================

  String get sessionId => _sessionId;

  String get workingDirectory => _workingDirectory;

  String? get threadId => _threadId;

  Stream<Conversation> get conversation => _conversationController.stream;

  Conversation get currentConversation => _currentConversation;

  Future<void> get initialized => _initializedCompleter.future;

  Stream<MetaResponse> get initDataStream => _initDataController.stream;

  MetaResponse? get initData => _initData;

  Stream<void> get onTurnComplete => _turnCompleteController.stream;

  Stream<ClaudeStatus> get statusStream => _statusController.stream;

  ClaudeStatus get currentStatus => _currentStatus;

  Stream<String?> get queuedMessage => _queuedMessageController.stream;

  String? get currentQueuedMessage => _queuedMessageText;

  /// Approval requests from the server.
  Stream<CodexApprovalRequest> get approvalRequests =>
      _approvalRequestController.stream;

  void clearQueuedMessage() {
    _queuedMessageText = null;
    _queuedAttachments = null;
    _queuedMessageController.add(null);
  }

  void sendMessage(Message message) {
    if (message.text.trim().isEmpty &&
        (message.attachments?.isEmpty ?? true)) {
      return;
    }

    // If currently processing, queue the message
    if (_currentConversation.isProcessing) {
      _queueMessage(message);
      return;
    }

    // If not yet initialized (createSync path), queue and flush after init
    if (!_isInitialized) {
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
      _updateStatus(ClaudeStatus.processing);
      return;
    }

    // Add user message to conversation optimistically
    final userMessage = ConversationMessage.user(
      content: message.text,
      attachments: message.attachments,
    );
    _updateConversation(
      _currentConversation
          .addMessage(userMessage)
          .withState(ConversationState.sendingMessage),
    );

    _updateStatus(ClaudeStatus.processing);

    _startTurn(message.text);
  }

  /// Respond to a server approval request.
  void respondToApproval(
    dynamic requestId,
    CodexApprovalDecision decision,
  ) {
    _transport.respondToRequest(requestId, {'decision': decision.toJson()});
  }

  void injectToolResult(ToolResultResponse toolResult) {
    // Codex manages its own tool execution; this is a no-op.
    // We still update the conversation for UI consistency.
    if (_currentConversation.messages.isEmpty) return;

    final lastIndex = _currentConversation.messages.length - 1;
    final lastMessage = _currentConversation.messages[lastIndex];
    if (lastMessage.role != MessageRole.assistant) return;

    final updatedMessage = lastMessage.copyWith(
      responses: [...lastMessage.responses, toolResult],
    );
    final updatedMessages = [..._currentConversation.messages];
    updatedMessages[lastIndex] = updatedMessage;
    _updateConversation(
      _currentConversation.copyWith(messages: updatedMessages),
    );
  }

  Future<void> abort() async {
    if (!_transport.isRunning || _threadId == null) return;
    await _transport.sendRequest('turn/interrupt', {
      'threadId': _threadId,
    });
    _updateStatus(ClaudeStatus.ready);
  }

  Future<void> close() async {
    _isClosed = true;

    await _transport.close();

    for (final server in mcpServers) {
      await server.stop();
    }

    await CodexMcpRegistry.cleanUp(workingDirectory: _workingDirectory);

    await _conversationController.close();
    await _turnCompleteController.close();
    await _statusController.close();
    await _initDataController.close();
    await _queuedMessageController.close();
    await _approvalRequestController.close();

    _isInitialized = false;
  }

  Future<void> clearConversation() async {
    _updateConversation(Conversation.empty());

    // Start a new thread on the same persistent server
    final threadResponse = await _transport.sendRequest(
      'thread/start',
      codexConfig.toThreadStartParams(),
    );

    if (!threadResponse.isError) {
      final threadResult = threadResponse.result ?? {};
      final thread = threadResult['thread'] as Map<String, dynamic>? ?? {};
      _threadId = thread['id'] as String?;
    }
  }

  T? getMcpServer<T extends McpServerBase>(String name) {
    try {
      return mcpServers.whereType<T>().firstWhere((s) => s.name == name);
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // Private implementation
  // ============================================================

  Future<void> _startTurn(String prompt) async {
    final turnResponse = await _transport.sendRequest('turn/start', {
      'threadId': _threadId,
      'input': [
        {'type': 'text', 'text': prompt},
      ],
    });

    if (turnResponse.isError) {
      _handleError(
        'turn/start failed: ${turnResponse.error?.message ?? 'unknown'}',
      );
    }
  }

  void _onNotification(JsonRpcNotification notification) {
    if (_isClosed) return;

    final event = _parser.parseNotification(notification);
    _handleEvent(event);
  }

  void _onServerRequest(JsonRpcRequest request) {
    if (_isClosed) return;

    switch (request.method) {
      case 'item/commandExecution/requestApproval':
        final approval = CodexApprovalRequest.commandExecution(
          requestId: request.id,
          params: request.params,
        );
        _approvalRequestController.add(approval);
      case 'item/fileChange/requestApproval':
        final approval = CodexApprovalRequest.fileChange(
          requestId: request.id,
          params: request.params,
        );
        _approvalRequestController.add(approval);
      case 'item/tool/requestUserInput':
        final approval = CodexApprovalRequest.userInput(
          requestId: request.id,
          params: request.params,
        );
        _approvalRequestController.add(approval);
    }
  }

  void _handleEvent(CodexEvent event) {
    // Capture thread ID from thread/started notification
    if (event is ThreadStartedEvent) {
      _threadId = event.threadId;
    }

    // Map to ClaudeResponse objects
    final responses = _mapper.mapEvent(event);

    var conversation = _currentConversation;
    var turnComplete = false;

    for (final response in responses) {
      // Handle status updates
      if (response is StatusResponse) {
        _updateStatus(response.status);
      }

      // Handle init data (MetaResponse)
      if (response is MetaResponse) {
        _initData = response;
        if (!_isClosed) _initDataController.add(response);
        onMetaResponseReceived?.call(response);
      }

      // Process through ResponseProcessor
      final result =
          _responseProcessor.processResponse(response, conversation);
      conversation = result.updatedConversation;
      turnComplete = turnComplete || result.turnComplete;
    }

    _updateConversation(conversation);

    if (turnComplete) {
      _updateStatus(ClaudeStatus.ready);
      if (!_isClosed) _turnCompleteController.add(null);
    }
  }

  void _handleError(String error) {
    if (_isClosed) return;
    final errorResponse = ErrorResponse(
      id: 'codex_error_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      error: error,
    );

    final result = _responseProcessor.processResponse(
      errorResponse,
      _currentConversation,
    );
    _updateConversation(result.updatedConversation);
    _updateStatus(ClaudeStatus.ready);
    if (!_isClosed) _turnCompleteController.add(null);
  }

  void _updateConversation(Conversation newConversation) {
    if (_isClosed) return;
    _currentConversation = newConversation;
    _conversationController.add(_currentConversation);
  }

  void _updateStatus(ClaudeStatus status) {
    if (_isClosed) return;
    if (_currentStatus != status) {
      _currentStatus = status;
      _statusController.add(status);
    }
  }

  void _queueMessage(Message message) {
    if (_queuedMessageText == null) {
      _queuedMessageText = message.text;
      _queuedAttachments = message.attachments;
    } else {
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

    _queuedMessageText = null;
    _queuedAttachments = null;
    _queuedMessageController.add(null);

    sendMessage(Message(text: text, attachments: attachments));
  }

  /// Flush messages that were queued before [init] completed.
  void _flushPendingMessages() {
    if (_pendingMessages.isEmpty) return;

    final messages = List<Message>.of(_pendingMessages);
    _pendingMessages.clear();

    for (final message in messages) {
      // Conversation already updated optimistically when queued,
      // so just start the turn directly.
      _startTurn(message.text);
    }
  }
}
