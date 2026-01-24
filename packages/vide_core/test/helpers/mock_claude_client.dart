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
  Future<SetMaxThinkingTokensResponse> setMaxThinkingTokens(int maxTokens) async {
    return SetMaxThinkingTokensResponse(maxThinkingTokens: maxTokens);
  }

  @override
  Future<void> setMcpServers(List<McpServerConfig> servers, {bool replace = false}) async {
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
