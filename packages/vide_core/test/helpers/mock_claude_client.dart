import 'dart:async';
import 'package:claude_sdk/claude_sdk.dart';

/// A mock ClaudeClient for testing that doesn't spawn real processes.
class MockClaudeClient implements ClaudeClient {
  MockClaudeClient({
    String? sessionId,
    this.workingDirectory = '/mock/working/dir',
  }) : sessionId =
           sessionId ?? 'mock-session-${DateTime.now().microsecondsSinceEpoch}';

  @override
  final String sessionId;

  @override
  final String workingDirectory;

  @override
  void Function(MetaResponse response)? onMetaResponseReceived;

  final List<Message> sentMessages = [];
  final _conversationController = StreamController<Conversation>.broadcast();
  final _turnCompleteController = StreamController<void>.broadcast();
  final _statusController = StreamController<ClaudeStatus>.broadcast();
  final _queuedMessageController = StreamController<String?>.broadcast();
  final _initDataController = StreamController<MetaResponse>.broadcast();
  Conversation _currentConversation = Conversation.empty();
  String? _queuedMessageText;
  ClaudeStatus _currentStatus = ClaudeStatus.ready;
  MetaResponse? _initData;
  bool _isAborted = false;
  bool _isClosed = false;

  bool get isAborted => _isAborted;
  bool get isClosed => _isClosed;

  @override
  Stream<Conversation> get conversation => _conversationController.stream;

  @override
  Stream<void> get onTurnComplete => _turnCompleteController.stream;

  @override
  Stream<ClaudeStatus> get statusStream => _statusController.stream;

  @override
  ClaudeStatus get currentStatus => _currentStatus;

  @override
  Stream<MetaResponse> get initDataStream => _initDataController.stream;

  @override
  MetaResponse? get initData => _initData;

  @override
  Future<void> get initialized => Future.value();

  @override
  Conversation get currentConversation => _currentConversation;

  @override
  Stream<String?> get queuedMessage => _queuedMessageController.stream;

  @override
  String? get currentQueuedMessage => _queuedMessageText;

  @override
  void clearQueuedMessage() {
    _queuedMessageText = null;
    _queuedMessageController.add(null);
  }

  @override
  void sendMessage(Message message) {
    if (message.text.trim().isEmpty) return;

    // Match real ClaudeClient behavior: queue if processing
    if (_currentConversation.isProcessing) {
      if (_queuedMessageText == null) {
        _queuedMessageText = message.text;
      } else {
        _queuedMessageText = '$_queuedMessageText\n${message.text}';
      }
      _queuedMessageController.add(_queuedMessageText);
      return;
    }

    sentMessages.add(message);

    // Simulate adding the message to conversation
    final userMessage = ConversationMessage.user(content: message.text);
    _currentConversation = _currentConversation.addMessage(userMessage);
    _conversationController.add(_currentConversation);
  }

  @override
  Future<void> abort() async {
    _isAborted = true;
  }

  @override
  Future<void> setPermissionMode(String mode) async {
    // Mock implementation - no-op
  }

  @override
  Future<McpStatusResponse> getMcpStatus() async {
    return const McpStatusResponse(servers: []);
  }

  @override
  Future<SetModelResponse> setModel(String model) async {
    return SetModelResponse(model: model);
  }

  @override
  Future<SetMaxThinkingTokensResponse> setMaxThinkingTokens(
    int maxTokens,
  ) async {
    return SetMaxThinkingTokensResponse(maxThinkingTokens: maxTokens);
  }

  @override
  Future<void> setMcpServers(
    List<McpServerConfig> servers, {
    bool replace = false,
  }) async {
    // Mock implementation - no-op
  }

  @override
  Future<void> interrupt() async {
    await abort();
  }

  @override
  Future<void> rewindFiles(String userMessageId) async {
    // Mock implementation - no-op
  }

  @override
  Future<void> close() async {
    _isClosed = true;
    await _conversationController.close();
    await _turnCompleteController.close();
    await _statusController.close();
    await _initDataController.close();
    await _queuedMessageController.close();
  }

  @override
  Future<void> clearConversation() async {
    _currentConversation = Conversation.empty();
    _conversationController.add(_currentConversation);
  }

  @override
  T? getMcpServer<T extends McpServerBase>(String name) => null;

  /// Simulate receiving an assistant text response
  void simulateTextResponse(String text) {
    final assistantMessage = ConversationMessage.assistant(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      responses: [
        TextResponse(
          id: 'text-${DateTime.now().microsecondsSinceEpoch}',
          timestamp: DateTime.now(),
          content: text,
        ),
      ],
      isComplete: true,
    );
    _currentConversation = _currentConversation.addMessage(assistantMessage);
    _conversationController.add(_currentConversation);
  }

  /// Simulate a turn completion
  void simulateTurnComplete() {
    _turnCompleteController.add(null);
  }

  /// Emit a status change (for testing status sync)
  void emitStatus(ClaudeStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }

  /// Set the conversation state (e.g. to simulate processing)
  void setConversationState(ConversationState state) {
    _currentConversation = _currentConversation.withState(state);
    _conversationController.add(_currentConversation);
  }

  /// Simulate an assistant message with tool use and result responses.
  ///
  /// This creates a complete assistant turn with text, tool call, and tool result
  /// all in one message - matching how claude_sdk delivers tool interactions.
  void simulateAssistantWithToolCall({
    required String text,
    required String toolName,
    required Map<String, dynamic> toolInput,
    required String toolResult,
    String? toolUseId,
    bool isError = false,
  }) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final useId = toolUseId ?? 'tool-use-$id';
    final now = DateTime.now();

    final assistantMessage = ConversationMessage.assistant(
      id: id,
      responses: [
        TextResponse(id: 'text-$id', timestamp: now, content: text),
        ToolUseResponse(
          id: 'tooluse-$id',
          timestamp: now,
          toolName: toolName,
          parameters: toolInput,
          toolUseId: useId,
        ),
        ToolResultResponse(
          id: 'toolresult-$id',
          timestamp: now,
          toolUseId: useId,
          content: toolResult,
          isError: isError,
        ),
      ],
      isComplete: true,
    );
    _currentConversation = _currentConversation.addMessage(assistantMessage);
    _conversationController.add(_currentConversation);
  }

  /// Simulate streaming text by updating the last assistant message's content.
  ///
  /// If there's no assistant message yet, creates one. Otherwise, appends text
  /// to the last assistant message to simulate streaming deltas.
  void simulateStreamingText(String text, {bool createNew = false}) {
    if (_currentConversation.messages.isEmpty || createNew) {
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      final assistantMessage = ConversationMessage.assistant(
        id: id,
        responses: [
          TextResponse(
            id: 'text-$id',
            timestamp: DateTime.now(),
            content: text,
          ),
        ],
        isStreaming: true,
      );
      _currentConversation = _currentConversation
          .addMessage(assistantMessage)
          .withState(ConversationState.receivingResponse);
      _conversationController.add(_currentConversation);
      return;
    }

    final lastIndex = _currentConversation.messages.length - 1;
    final lastMessage = _currentConversation.messages[lastIndex];

    if (lastMessage.role != MessageRole.assistant) {
      simulateStreamingText(text, createNew: true);
      return;
    }

    // Append text to existing assistant message content
    final newContent = lastMessage.content + text;
    final updatedMessage = lastMessage.copyWith(
      content: newContent,
      responses: [
        TextResponse(
          id: 'text-${DateTime.now().microsecondsSinceEpoch}',
          timestamp: DateTime.now(),
          content: newContent,
        ),
      ],
    );

    final updatedMessages = [..._currentConversation.messages];
    updatedMessages[lastIndex] = updatedMessage;
    _currentConversation = _currentConversation.copyWith(
      messages: updatedMessages,
    );
    _conversationController.add(_currentConversation);
  }

  /// Simulate adding a tool use response to the last assistant message.
  ///
  /// Used to test tool event ordering when tools arrive after text.
  void simulateToolUseOnLastMessage({
    required String toolName,
    required Map<String, dynamic> parameters,
    String? toolUseId,
  }) {
    if (_currentConversation.messages.isEmpty) return;
    final lastIndex = _currentConversation.messages.length - 1;
    final lastMessage = _currentConversation.messages[lastIndex];
    if (lastMessage.role != MessageRole.assistant) return;

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final updatedMessage = lastMessage.copyWith(
      responses: [
        ...lastMessage.responses,
        ToolUseResponse(
          id: 'tooluse-$id',
          timestamp: DateTime.now(),
          toolName: toolName,
          parameters: parameters,
          toolUseId: toolUseId ?? 'tool-use-$id',
        ),
      ],
    );

    final updatedMessages = [..._currentConversation.messages];
    updatedMessages[lastIndex] = updatedMessage;
    _currentConversation = _currentConversation.copyWith(
      messages: updatedMessages,
    );
    _conversationController.add(_currentConversation);
  }

  /// Set the conversation error state
  void simulateError(String error) {
    _currentConversation = _currentConversation.withError(error);
    _conversationController.add(_currentConversation);
  }

  /// Simulate the conversation going idle after processing
  void simulateIdle() {
    _currentConversation = _currentConversation.withState(
      ConversationState.idle,
    );
    _conversationController.add(_currentConversation);
  }

  /// Set the init data (for model testing)
  void setInitData(MetaResponse data) {
    _initData = data;
    _initDataController.add(data);
  }

  /// Reset the mock for reuse
  void reset() {
    sentMessages.clear();
    _currentConversation = Conversation.empty();
    _isAborted = false;
    _isClosed = false;
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

    _currentConversation = _currentConversation.copyWith(
      messages: updatedMessages,
    );
    _conversationController.add(_currentConversation);
  }
}

/// A mock factory for creating MockClaudeClients
class MockClaudeClientFactory {
  final Map<String, MockClaudeClient> _clients = {};

  /// Get or create a client for the given agent ID
  MockClaudeClient getClient(String agentId) {
    return _clients.putIfAbsent(
      agentId,
      () => MockClaudeClient(sessionId: agentId),
    );
  }

  /// Check if a client exists
  bool hasClient(String agentId) => _clients.containsKey(agentId);

  /// Get all created clients
  Map<String, MockClaudeClient> get clients => Map.unmodifiable(_clients);

  /// Clear all clients
  void clear() => _clients.clear();
}
