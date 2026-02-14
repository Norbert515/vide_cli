import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:claude_sdk/claude_sdk.dart';
import 'package:uuid/uuid.dart';

import '../config/codex_config.dart';
import '../config/codex_mcp_registry.dart';
import '../protocol/codex_event.dart';
import '../protocol/codex_event_mapper.dart';
import '../protocol/codex_event_parser.dart';

/// Standalone client backed by Codex CLI (`codex exec --json`).
///
/// Each turn spawns a new `codex exec` process (or `codex exec resume <threadId>`
/// for multi-turn). The JSONL events are parsed, mapped to [ClaudeResponse]
/// objects, and fed through [ResponseProcessor] so the entire downstream
/// pipeline (Conversation, TUI, vide_server) works unchanged.
class CodexClient {
  final CodexConfig codexConfig;
  final List<McpServerBase> mcpServers;
  final ResponseProcessor _responseProcessor = ResponseProcessor();
  final CodexEventParser _parser = CodexEventParser();
  final CodexEventMapper _mapper = CodexEventMapper();

  String? _threadId;
  Process? _activeProcess;
  bool _isInitialized = false;
  bool _isClosed = false;
  bool _turnFinished = false;
  int _turnId = 0;
  final Completer<void> _initializedCompleter = Completer<void>();

  final String _sessionId;
  final String _workingDirectory;

  // Stream controllers
  final _conversationController = StreamController<Conversation>.broadcast();
  final _turnCompleteController = StreamController<void>.broadcast();
  final _statusController = StreamController<ClaudeStatus>.broadcast();
  final _initDataController = StreamController<MetaResponse>.broadcast();
  final _queuedMessageController = StreamController<String?>.broadcast();

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

  /// Initialize the client: start MCP servers and mark as ready.
  Future<void> init() async {
    if (_isInitialized) return;

    // Start MCP servers
    for (final server in mcpServers) {
      if (!server.isRunning) {
        await server.start();
      }
    }

    _isInitialized = true;
    if (!_initializedCompleter.isCompleted) {
      _initializedCompleter.complete();
    }
  }

  // ============================================================
  // Public API
  // ============================================================

  String get sessionId => _sessionId;

  String get workingDirectory => _workingDirectory;

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

  void clearQueuedMessage() {
    _queuedMessageText = null;
    _queuedAttachments = null;
    _queuedMessageController.add(null);
  }

  void sendMessage(Message message) {
    if (message.text.trim().isEmpty && (message.attachments?.isEmpty ?? true)) {
      return;
    }

    // If currently processing, queue the message
    if (_currentConversation.isProcessing) {
      _queueMessage(message);
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

    // Spawn codex exec process
    _runCodexExec(message.text);
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
    _activeProcess?.kill(ProcessSignal.sigint);
    _activeProcess = null;
    _updateStatus(ClaudeStatus.ready);
  }

  Future<void> close() async {
    _isClosed = true;
    _activeProcess?.kill(ProcessSignal.sigterm);
    _activeProcess = null;

    for (final server in mcpServers) {
      await server.stop();
    }

    await CodexMcpRegistry.cleanUp(workingDirectory: _workingDirectory);

    await _conversationController.close();
    await _turnCompleteController.close();
    await _statusController.close();
    await _initDataController.close();
    await _queuedMessageController.close();

    _isInitialized = false;
  }

  Future<void> clearConversation() async {
    _updateConversation(Conversation.empty());
    _threadId = null;
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

  Future<void> _runCodexExec(String prompt) async {
    _turnFinished = false;
    final currentTurnId = ++_turnId;
    final isResume = _threadId != null;

    final args = codexConfig.toCliArgs(
      isResume: isResume,
      resumeThreadId: _threadId,
    );

    // Write MCP config if we have servers
    if (mcpServers.isNotEmpty) {
      await CodexMcpRegistry.writeConfig(
        mcpServers: mcpServers,
        workingDirectory: _workingDirectory,
      );
    }

    // Prompt is always a positional argument.
    // For non-resume: codex exec [FLAGS] <prompt>
    // For resume:     codex exec [FLAGS] resume <threadId> <prompt>
    args.add(prompt);

    try {
      final process = await Process.start(
        'codex',
        args,
        workingDirectory: _workingDirectory,
        environment: {
          ...Platform.environment,
          // Ensure JSON output even if config doesn't set it
          'CODEX_OUTPUT_FORMAT': 'json',
        },
      );

      _activeProcess = process;

      // Process stdout (JSONL events)
      final stdoutBuffer = StringBuffer();
      process.stdout
          .transform(utf8.decoder)
          .listen(
            (chunk) {
              if (_turnId != currentTurnId) return;
              stdoutBuffer.write(chunk);
              _processChunk(stdoutBuffer);
            },
            onDone: () {
              if (_turnId != currentTurnId) return;
              // Process any remaining data in buffer
              _processRemainingBuffer(stdoutBuffer);
              _onProcessDone();
            },
            onError: (error) {
              if (_turnId != currentTurnId) return;
              _handleProcessError('stdout error: $error');
            },
          );

      // Capture stderr for error reporting
      final stderrBuffer = StringBuffer();
      process.stderr.transform(utf8.decoder).listen((chunk) {
        stderrBuffer.write(chunk);
      });

      // Handle process exit
      process.exitCode.then((exitCode) {
        if (_turnId != currentTurnId) return;
        _activeProcess = null;
        if (_turnFinished) return;
        if (exitCode != 0 && stderrBuffer.isNotEmpty) {
          _handleProcessError(
            'Codex exited with code $exitCode: ${stderrBuffer.toString()}',
          );
        }
      });
    } catch (e) {
      _handleProcessError('Failed to start codex: $e');
    }
  }

  void _processChunk(StringBuffer buffer) {
    // Extract complete lines from the buffer
    final content = buffer.toString();
    final lines = content.split('\n');

    // Keep the last incomplete line in the buffer
    buffer.clear();
    if (!content.endsWith('\n') && lines.isNotEmpty) {
      buffer.write(lines.removeLast());
    } else if (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      final event = _parser.parseLine(line);
      if (event == null) continue;

      _handleEvent(event);
    }
  }

  void _processRemainingBuffer(StringBuffer buffer) {
    final remaining = buffer.toString().trim();
    if (remaining.isEmpty) return;

    final event = _parser.parseLine(remaining);
    if (event != null) {
      _handleEvent(event);
    }
    buffer.clear();
  }

  void _handleEvent(CodexEvent event) {
    // Capture thread ID from thread.started
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

  void _onProcessDone() {
    if (_turnFinished || _isClosed) return;
    _turnFinished = true;
    // If we never got a completion event, emit one now
    if (_currentConversation.isProcessing) {
      final completionResponse = CompletionResponse(
        id: 'codex_done_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        stopReason: 'completed',
      );

      final result = _responseProcessor.processResponse(
        completionResponse,
        _currentConversation,
      );
      _updateConversation(result.updatedConversation);
      _updateStatus(ClaudeStatus.ready);
      if (!_isClosed) _turnCompleteController.add(null);
    }
  }

  void _handleProcessError(String error) {
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
}
