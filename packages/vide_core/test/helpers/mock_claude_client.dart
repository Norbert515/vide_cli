import 'dart:async';
import 'package:claude_api/claude_api.dart';

/// A mock ClaudeClient for testing that doesn't spawn real processes.
class MockClaudeClient implements ClaudeClient {
  MockClaudeClient({
    String? sessionId,
    this.workingDirectory = '/mock/working/dir',
  }) : sessionId = sessionId ?? 'mock-session-${DateTime.now().microsecondsSinceEpoch}';

  @override
  final String sessionId;

  @override
  final String workingDirectory;

  final List<Message> sentMessages = [];
  final _conversationController = StreamController<Conversation>.broadcast();
  final _turnCompleteController = StreamController<void>.broadcast();
  Conversation _currentConversation = Conversation.empty();
  bool _isAborted = false;
  bool _isClosed = false;

  bool get isAborted => _isAborted;
  bool get isClosed => _isClosed;

  @override
  Stream<Conversation> get conversation => _conversationController.stream;

  @override
  Stream<void> get onTurnComplete => _turnCompleteController.stream;

  @override
  Conversation get currentConversation => _currentConversation;

  @override
  bool get isAborting => _isAborted;

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
  Future<void> close() async {
    _isClosed = true;
    await _conversationController.close();
    await _turnCompleteController.close();
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

  /// Reset the mock for reuse
  void reset() {
    sentMessages.clear();
    _currentConversation = Conversation.empty();
    _isAborted = false;
    _isClosed = false;
  }
}

/// A mock factory for creating MockClaudeClients
class MockClaudeClientFactory {
  final Map<String, MockClaudeClient> _clients = {};

  /// Get or create a client for the given agent ID
  MockClaudeClient getClient(String agentId) {
    return _clients.putIfAbsent(agentId, () => MockClaudeClient(sessionId: agentId));
  }

  /// Check if a client exists
  bool hasClient(String agentId) => _clients.containsKey(agentId);

  /// Get all created clients
  Map<String, MockClaudeClient> get clients => Map.unmodifiable(_clients);

  /// Clear all clients
  void clear() => _clients.clear();
}
