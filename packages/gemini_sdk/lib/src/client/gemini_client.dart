import 'dart:async';
import 'dart:io';

import 'package:agent_sdk/agent_sdk.dart';
import 'package:uuid/uuid.dart';

import '../config/gemini_config.dart';
import '../protocol/gemini_event.dart';
import '../transport/gemini_transport.dart';

/// Client for the Gemini CLI, communicating via subprocess with
/// `--output-format stream-json`.
///
/// Works natively with `agent_sdk` types — no intermediate type hierarchy.
/// Multi-turn sessions work via `--resume <session-id>`: after the first turn,
/// [GeminiInitEvent] provides a session ID that is passed to subsequent turns.
class GeminiClient {
  final GeminiConfig config;
  final GeminiTransport _transport = GeminiTransport();

  // Stream controllers (matching AgentClient surface)
  final _conversationController =
      StreamController<AgentConversation>.broadcast();
  final _turnCompleteController = StreamController<void>.broadcast();
  final _statusController = StreamController<AgentProcessingStatus>.broadcast();
  final _initDataController = StreamController<AgentInitData>.broadcast();
  final _queuedMessageController = StreamController<String?>.broadcast();

  AgentConversation _currentConversation = AgentConversation.empty();
  AgentProcessingStatus _currentStatus = AgentProcessingStatus.ready;
  AgentInitData? _initData;

  final String _sessionId;
  final String _workingDirectory;

  /// Gemini session ID from the CLI (for --resume). Different from our
  /// internal _sessionId which is a UUID for this client instance.
  String? _geminiSessionId;

  bool _isClosed = false;
  bool _isInitialized = false;
  final Completer<void> _initializedCompleter = Completer<void>();

  // Message queueing
  String? _queuedMessageText;
  List<AgentAttachment>? _queuedAttachments;

  GeminiClient({required this.config})
    : _sessionId = config.sessionId ?? const Uuid().v4(),
      _workingDirectory = config.workingDirectory ?? Directory.current.path {
    // Auto-flush queued messages when turn completes
    _turnCompleteController.stream.listen((_) {
      _flushQueuedMessage();
    });
  }

  /// Initialize the client.
  ///
  /// Verifies that the `gemini` CLI is available on the PATH.
  Future<void> init() async {
    if (_isInitialized) return;

    // Verify gemini CLI is available
    try {
      final result = await Process.run('gemini', ['--version']);
      if (result.exitCode != 0) {
        throw StateError(
          'gemini CLI returned exit code ${result.exitCode}. '
          'Install with: npm install -g @google/gemini-cli',
        );
      }
    } on ProcessException {
      throw StateError(
        'gemini CLI not found on PATH. '
        'Install with: npm install -g @google/gemini-cli',
      );
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

  /// The Gemini CLI session ID (for --resume). Available after first turn.
  String? get geminiSessionId => _geminiSessionId;

  Stream<AgentConversation> get conversation => _conversationController.stream;

  AgentConversation get currentConversation => _currentConversation;

  Future<void> get initialized => _initializedCompleter.future;

  Stream<AgentInitData> get initDataStream => _initDataController.stream;

  AgentInitData? get initData => _initData;

  Stream<void> get onTurnComplete => _turnCompleteController.stream;

  Stream<AgentProcessingStatus> get statusStream => _statusController.stream;

  AgentProcessingStatus get currentStatus => _currentStatus;

  Stream<String?> get queuedMessage => _queuedMessageController.stream;

  String? get currentQueuedMessage => _queuedMessageText;

  void clearQueuedMessage() {
    _queuedMessageText = null;
    _queuedAttachments = null;
    if (!_isClosed) _queuedMessageController.add(null);
  }

  void sendMessage(AgentMessage message) {
    if (message.text.trim().isEmpty && (message.attachments?.isEmpty ?? true)) {
      return;
    }

    // If currently processing, queue the message
    if (_currentConversation.isProcessing) {
      _queueMessage(message);
      return;
    }

    // Add user message to conversation optimistically
    final userMessage = AgentConversationMessage.user(content: message.text);
    _updateConversation(
      _currentConversation
          .addMessage(userMessage)
          .withState(AgentConversationState.sendingMessage),
    );

    _updateStatus(AgentProcessingStatus.processing);

    _startTurn(message.text);
  }

  void injectToolResult(AgentToolResultResponse toolResult) {
    // Gemini CLI manages its own tool execution; this is a no-op.
    // We still update the conversation for UI consistency.
    if (_currentConversation.messages.isEmpty) return;

    final lastIndex = _currentConversation.messages.length - 1;
    final lastMessage = _currentConversation.messages[lastIndex];
    if (lastMessage.role != AgentMessageRole.assistant) return;

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
    _transport.kill();
    _updateStatus(AgentProcessingStatus.ready);
  }

  Future<void> close() async {
    _isClosed = true;

    _transport.close();

    await _conversationController.close();
    await _turnCompleteController.close();
    await _statusController.close();
    await _initDataController.close();
    await _queuedMessageController.close();

    _isInitialized = false;
  }

  Future<void> clearConversation() async {
    _geminiSessionId = null;
    _updateConversation(AgentConversation.empty());
  }

  // ============================================================
  // Private implementation
  // ============================================================

  void _startTurn(String prompt) {
    // Build config with the current Gemini session ID for --resume
    final turnConfig = _geminiSessionId != null
        ? config.copyWith(
            sessionId: _geminiSessionId,
            workingDirectory: _workingDirectory,
          )
        : config.copyWith(workingDirectory: _workingDirectory);

    // Current assistant message being built
    final assistantId = 'gemini_${DateTime.now().millisecondsSinceEpoch}';
    var assistantResponses = <AgentResponse>[];
    var assistantText = StringBuffer();

    _transport
        .runTurn(prompt: prompt, config: turnConfig)
        .listen(
          (event) {
            if (_isClosed) return;
            _handleEvent(
              event,
              assistantId: assistantId,
              assistantResponses: assistantResponses,
              assistantText: assistantText,
            );
          },
          onDone: () {
            if (_isClosed) return;

            // Finalize the assistant message if we have responses
            if (assistantResponses.isNotEmpty) {
              _finalizeAssistantMessage(
                assistantId: assistantId,
                responses: assistantResponses,
              );
            }

            _updateStatus(AgentProcessingStatus.ready);
            if (!_isClosed) _turnCompleteController.add(null);
          },
          onError: (Object error) {
            if (_isClosed) return;
            _handleError(error.toString());
          },
        );
  }

  void _handleEvent(
    GeminiEvent event, {
    required String assistantId,
    required List<AgentResponse> assistantResponses,
    required StringBuffer assistantText,
  }) {
    switch (event) {
      case GeminiInitEvent():
        _geminiSessionId = event.sessionId;
        _initData = AgentInitData(
          model: event.model,
          sessionId: event.sessionId,
          cwd: _workingDirectory,
          metadata: event.data,
        );
        if (!_isClosed) _initDataController.add(_initData!);
        _updateStatus(AgentProcessingStatus.responding);

      case GeminiMessageEvent():
        if (event.isDelta) {
          assistantText.write(event.content);
          final textResponse = AgentTextResponse(
            id: '${assistantId}_text_${assistantResponses.length}',
            timestamp: event.timestamp,
            content: event.content,
            isPartial: true,
          );
          assistantResponses.add(textResponse);
        } else {
          // Full message (non-delta)
          assistantText.clear();
          assistantText.write(event.content);
          final textResponse = AgentTextResponse(
            id: '${assistantId}_text_${assistantResponses.length}',
            timestamp: event.timestamp,
            content: event.content,
          );
          assistantResponses.add(textResponse);
        }

        // Update conversation with current state of assistant message
        final assistantMessage = AgentConversationMessage(
          id: assistantId,
          role: AgentMessageRole.assistant,
          content: assistantText.toString(),
          timestamp: DateTime.now(),
          responses: List.of(assistantResponses),
          isStreaming: true,
        );
        _updateConversation(
          _currentConversation
              .updateLastMessage(assistantMessage)
              .withState(AgentConversationState.receivingResponse),
        );

        // If the last message is a user message, we need to add instead
        if (_currentConversation.lastMessage?.role == AgentMessageRole.user) {
          _updateConversation(
            _currentConversation
                .addMessage(assistantMessage)
                .withState(AgentConversationState.receivingResponse),
          );
        }

      case GeminiToolUseEvent():
        final toolUse = AgentToolUseResponse(
          id: '${assistantId}_tool_${event.toolId}',
          timestamp: event.timestamp,
          toolName: event.toolName,
          parameters: event.parameters,
          toolUseId: event.toolId,
        );
        assistantResponses.add(toolUse);
        _updateAssistantMessage(
          assistantId: assistantId,
          content: assistantText.toString(),
          responses: assistantResponses,
          isStreaming: true,
        );

      case GeminiToolResultEvent():
        final toolResult = AgentToolResultResponse(
          id: '${assistantId}_result_${event.toolId}',
          timestamp: event.timestamp,
          toolUseId: event.toolId,
          content: event.output,
          isError: event.status != 'success',
        );
        assistantResponses.add(toolResult);
        _updateAssistantMessage(
          assistantId: assistantId,
          content: assistantText.toString(),
          responses: assistantResponses,
          isStreaming: true,
        );

      case GeminiErrorEvent():
        final errorResponse = AgentErrorResponse(
          id: '${assistantId}_error_${assistantResponses.length}',
          timestamp: event.timestamp,
          error: event.message,
          rawData: event.details,
        );
        assistantResponses.add(errorResponse);
        _updateAssistantMessage(
          assistantId: assistantId,
          content: assistantText.toString(),
          responses: assistantResponses,
          isStreaming: true,
        );

      case GeminiResultEvent():
        // Turn completion with stats
        if (event.stats != null) {
          final completion = AgentCompletionResponse(
            id: '${assistantId}_completion',
            timestamp: event.timestamp,
            stopReason: event.status,
            inputTokens: event.stats!.inputTokens,
            outputTokens: event.stats!.outputTokens,
          );
          assistantResponses.add(completion);

          // Update conversation token totals
          _updateConversation(
            _currentConversation.copyWith(
              totalInputTokens:
                  _currentConversation.totalInputTokens +
                  event.stats!.inputTokens,
              totalOutputTokens:
                  _currentConversation.totalOutputTokens +
                  event.stats!.outputTokens,
              currentContextInputTokens: event.stats!.inputTokens,
            ),
          );
        }

      case GeminiUnknownEvent():
        // Silently ignore unknown events
        break;
    }
  }

  void _finalizeAssistantMessage({
    required String assistantId,
    required List<AgentResponse> responses,
  }) {
    // Build the final text from all text responses
    final textBuffer = StringBuffer();
    for (final response in responses) {
      if (response is AgentTextResponse) {
        if (response.isPartial) {
          textBuffer.write(response.content);
        } else {
          textBuffer.clear();
          textBuffer.write(response.content);
        }
      }
    }

    _updateAssistantMessage(
      assistantId: assistantId,
      content: textBuffer.toString(),
      responses: responses,
      isStreaming: false,
      isComplete: true,
    );
  }

  void _updateAssistantMessage({
    required String assistantId,
    required String content,
    required List<AgentResponse> responses,
    required bool isStreaming,
    bool isComplete = false,
  }) {
    final assistantMessage = AgentConversationMessage(
      id: assistantId,
      role: AgentMessageRole.assistant,
      content: content,
      timestamp: DateTime.now(),
      responses: List.of(responses),
      isStreaming: isStreaming,
      isComplete: isComplete,
    );

    // Check if we need to add or update the message
    final lastMessage = _currentConversation.lastMessage;
    if (lastMessage != null && lastMessage.id == assistantId) {
      _updateConversation(
        _currentConversation
            .updateLastMessage(assistantMessage)
            .withState(
              isComplete
                  ? AgentConversationState.idle
                  : AgentConversationState.receivingResponse,
            ),
      );
    } else {
      _updateConversation(
        _currentConversation
            .addMessage(assistantMessage)
            .withState(
              isComplete
                  ? AgentConversationState.idle
                  : AgentConversationState.receivingResponse,
            ),
      );
    }
  }

  void _handleError(String error) {
    if (_isClosed) return;
    _updateConversation(_currentConversation.withError(error));
    _updateStatus(AgentProcessingStatus.ready);
    if (!_isClosed) _turnCompleteController.add(null);
  }

  void _updateConversation(AgentConversation newConversation) {
    if (_isClosed) return;
    _currentConversation = newConversation;
    _conversationController.add(_currentConversation);
  }

  void _updateStatus(AgentProcessingStatus status) {
    if (_isClosed) return;
    if (_currentStatus != status) {
      _currentStatus = status;
      _statusController.add(status);
    }
  }

  void _queueMessage(AgentMessage message) {
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
    if (!_isClosed) _queuedMessageController.add(_queuedMessageText);
  }

  void _flushQueuedMessage() {
    if (_queuedMessageText == null) return;

    final text = _queuedMessageText!;
    _queuedMessageText = null;
    _queuedAttachments = null;
    if (!_isClosed) _queuedMessageController.add(null);

    sendMessage(AgentMessage.text(text));
  }
}
