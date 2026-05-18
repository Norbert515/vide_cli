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
  final CodexLogCallback? _log;
  final ResponseProcessor _responseProcessor = ResponseProcessor();
  final CodexEventParser _parser = CodexEventParser();
  final CodexEventMapper _mapper = CodexEventMapper();

  final CodexTransport _transport;

  String? _threadId;
  bool _isInitialized = false;
  bool _isClosed = false;
  bool _aborting = false;
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

  CodexClient({
    required this.codexConfig,
    List<McpServerBase>? mcpServers,
    CodexLogCallback? log,
  }) : mcpServers = mcpServers ?? [],
       _log = log,
       _transport = CodexTransport(log: log),
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

    _log?.call(
      'info',
      'CodexClient',
      'Initializing CodexClient (session=$_sessionId, cwd=$_workingDirectory)',
    );

    // Start MCP servers
    for (final server in mcpServers) {
      if (!server.isRunning) {
        await server.start();
      }
    }

    // Build -c CLI args so codex app-server discovers our MCP servers.
    // Codex only reads ~/.codex/config.toml — project-level config is ignored.
    final mcpArgs = CodexMcpRegistry.buildArgs(mcpServers: mcpServers);

    // Start the persistent subprocess
    await _transport.start(
      workingDirectory: _workingDirectory,
      extraArgs: mcpArgs,
    );

    // Subscribe to notifications → event pipeline
    _transport.notifications.listen(_onNotification);

    // Subscribe to server requests → approval pipeline
    _transport.serverRequests.listen(_onServerRequest);

    // Subscribe to unexpected process exit
    _transport.onProcessExit.listen(_onProcessExit);

    // Initialize handshake
    final initResponse = await _transport.sendRequest('initialize', {
      'clientInfo': {'name': 'vide', 'version': '0.1.0', 'title': 'Vide'},
      'capabilities': {'experimentalApi': true},
    });

    if (initResponse.isError) {
      throw StateError(
        'Codex initialize failed: ${initResponse.error?.message}',
      );
    }

    _log?.call('info', 'CodexClient', 'Handshake complete');

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
    _log?.call('info', 'CodexClient', 'Thread started: $_threadId');

    // Wait for mcp_startup_complete notification
    if (mcpServers.isNotEmpty) {
      _log?.call('info', 'CodexClient', 'Waiting for MCP startup...');
      await _transport.notifications
          .where((n) => n.method == 'codex/event/mcp_startup_complete')
          .first
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException(
              'Timed out waiting for MCP startup to complete',
            ),
          );
      _log?.call('info', 'CodexClient', 'MCP startup complete');
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
    if (message.text.trim().isEmpty && (message.attachments?.isEmpty ?? true)) {
      return;
    }

    if (_isClosed) {
      _log?.call('warn', 'CodexClient', 'Ignoring message — client is closed');
      return;
    }

    // If currently processing, queue the message
    if (_currentConversation.isProcessing) {
      _log?.call('info', 'CodexClient', 'Queuing message (processing)');
      _queueMessage(message);
      return;
    }

    // If not yet initialized (createSync path), queue and flush after init
    if (!_isInitialized) {
      _log?.call('info', 'CodexClient', 'Queuing message (not initialized)');
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

    _log?.call(
      'info',
      'CodexClient',
      'Sending message (len=${message.text.length})',
    );
    _startTurn(message.text);
  }

  /// Respond to a server approval request.
  void respondToApproval(dynamic requestId, CodexApprovalDecision decision) {
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
    _log?.call('info', 'CodexClient', 'Aborting turn on thread $_threadId');
    _aborting = true;
    await _transport.sendRequest('turn/interrupt', {'threadId': _threadId});
    _updateStatus(ClaudeStatus.ready);
  }

  Future<void> close() async {
    _log?.call('info', 'CodexClient', 'Closing CodexClient');
    _isClosed = true;

    await _transport.close();

    for (final server in mcpServers) {
      await server.stop();
    }

    await _conversationController.close();
    await _turnCompleteController.close();
    await _statusController.close();
    await _initDataController.close();
    await _queuedMessageController.close();
    await _approvalRequestController.close();

    _isInitialized = false;
  }

  Future<void> clearConversation() async {
    _log?.call(
      'info',
      'CodexClient',
      'Clearing conversation, starting new thread',
    );
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
    _aborting = false;
    _log?.call('debug', 'CodexClient', 'Starting turn on thread $_threadId');
    try {
      final turnResponse = await _transport.sendRequest('turn/start', {
        'threadId': _threadId,
        'input': [
          {'type': 'text', 'text': prompt},
        ],
      });

      if (turnResponse.isError) {
        _log?.call(
          'error',
          'CodexClient',
          'turn/start failed: ${turnResponse.error?.message ?? 'unknown'}',
        );
        _handleError(
          'turn/start failed: ${turnResponse.error?.message ?? 'unknown'}',
        );
      }
    } catch (e) {
      _handleError('Failed to start turn: $e');
    }
  }

  void _onNotification(JsonRpcNotification notification) {
    if (_isClosed) return;

    _log?.call('debug', 'CodexClient', 'Notification: ${notification.method}');
    final event = _parser.parseNotification(notification);
    _handleEvent(event);
  }

  void _onProcessExit(String stderr) {
    if (_isClosed) return;

    final errorMsg =
        'Codex process exited unexpectedly'
        '${stderr.isNotEmpty ? ': $stderr' : ''}';

    _log?.call('error', 'CodexClient', errorMsg);

    // Complete the initialized completer with error if still pending
    if (!_initializedCompleter.isCompleted) {
      _initializedCompleter.completeError(
        StateError(
          'codex app-server process exited before initialization completed',
        ),
      );
    }

    // Report the error to the conversation BEFORE marking closed,
    // so _handleError / _updateConversation / _updateStatus are not
    // short-circuited by the _isClosed guard.
    _handleError(errorMsg);

    // Mark closed AFTER error handling so the UI sees the error.
    _isClosed = true;
  }

  void _onServerRequest(JsonRpcRequest request) {
    if (_isClosed) return;

    switch (request.method) {
      case 'item/commandExecution/requestApproval':
        final approval = CodexApprovalRequest.commandExecution(
          requestId: request.id,
          params: request.params,
        );
        if (_approvalRequestController.hasListener) {
          _approvalRequestController.add(approval);
        } else {
          _log?.call(
            'info',
            'CodexClient',
            'Auto-approving command: ${approval.command}',
          );
          respondToApproval(request.id, CodexApprovalDecision.accept);
        }
      case 'item/fileChange/requestApproval':
        final approval = CodexApprovalRequest.fileChange(
          requestId: request.id,
          params: request.params,
        );
        if (_approvalRequestController.hasListener) {
          _approvalRequestController.add(approval);
        } else {
          _log?.call('info', 'CodexClient', 'Auto-approving file change');
          respondToApproval(request.id, CodexApprovalDecision.accept);
        }
      case 'item/tool/requestUserInput':
        final approval = CodexApprovalRequest.userInput(
          requestId: request.id,
          params: request.params,
        );
        if (_approvalRequestController.hasListener) {
          _approvalRequestController.add(approval);
        } else {
          _log?.call(
            'warn',
            'CodexClient',
            'User input requested but no handler — cancelling to unblock server',
          );
          respondToApproval(request.id, CodexApprovalDecision.cancel);
        }
      default:
        _log?.call(
          'warn',
          'CodexClient',
          'Unknown server request method: ${request.method} — ignoring',
        );
    }
  }

  void _handleEvent(CodexEvent event) {
    // Capture thread ID from thread/started notification
    if (event is ThreadStartedEvent) {
      _threadId = event.threadId;
    }

    // Skip turn-complete events that arrive after an abort
    if (_aborting && event is TurnCompletedEvent) {
      _aborting = false;
      return;
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
      final result = _responseProcessor.processResponse(response, conversation);
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
    _log?.call('error', 'CodexClient', 'Error: $error');
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

    _log?.call(
      'info',
      'CodexClient',
      'Flushing ${_pendingMessages.length} pending messages',
    );
    final messages = List<Message>.of(_pendingMessages);
    _pendingMessages.clear();

    for (final message in messages) {
      // Conversation already updated optimistically when queued,
      // so just start the turn directly.
      _startTurn(message.text);
    }
  }
}
