import 'dart:async';
import 'package:uuid/uuid.dart';
import '../models/config.dart';
import '../models/message.dart';
import '../models/response.dart';
import '../models/conversation.dart';
import '../mcp/server/mcp_server_base.dart';
import 'claude_client.dart';

class MockClaudeClient implements ClaudeClient {
  final ClaudeConfig config;
  final List<McpServerBase> mcpServers;
  @override
  final String sessionId;

  final _conversationController = StreamController<Conversation>.broadcast();
  final _turnCompleteController = StreamController<void>.broadcast();
  final _statusController = StreamController<ClaudeStatus>.broadcast();
  final _queuedMessageController = StreamController<String?>.broadcast();
  Conversation _currentConversation = Conversation.empty();
  ClaudeStatus _currentStatus = ClaudeStatus.ready;
  String? _queuedMessageText;

  bool _isAborting = false;
  Timer? _activeTimer;

  @override
  bool get isAborting => _isAborting;

  @override
  Stream<void> get onTurnComplete => _turnCompleteController.stream;

  @override
  Stream<ClaudeStatus> get statusStream => _statusController.stream;

  @override
  ClaudeStatus get currentStatus => _currentStatus;

  @override
  Stream<String?> get queuedMessage => _queuedMessageController.stream;

  @override
  String? get currentQueuedMessage => _queuedMessageText;

  @override
  void clearQueuedMessage() {
    _queuedMessageText = null;
    _queuedMessageController.add(null);
  }

  // Mock response templates
  static const List<String> _mockResponses = [
    "I understand you're testing the UI. Here's a helpful response with some interesting content to demonstrate the chat interface.",
    "Let me help you with that. I can provide various types of responses including:\n• Short answers\n• Detailed explanations\n• Code examples\n• Multi-step solutions",
    "That's an interesting question! Let me think about this step by step and provide you with a comprehensive answer.",
    "Here's a code example that might help:\n\n```dart\nvoid main() {\n  print('Hello from mock Claude!');\n}\n```\n\nThis demonstrates how code blocks appear in the chat.",
    "I can also simulate tool usage. Let me search for some information for you...",
  ];

  static const List<String> _mockCodeResponses = [
    "```python\ndef fibonacci(n):\n    if n <= 1:\n        return n\n    return fibonacci(n-1) + fibonacci(n-2)\n\n# Example usage\nfor i in range(10):\n    print(f'F({i}) = {fibonacci(i)}')\n```",
    "```javascript\nconst fetchData = async (url) => {\n  try {\n    const response = await fetch(url);\n    const data = await response.json();\n    return data;\n  } catch (error) {\n    console.error('Error fetching data:', error);\n    throw error;\n  }\n};\n```",
    "```sql\nSELECT \n    u.name,\n    COUNT(o.id) as order_count,\n    SUM(o.total) as total_spent\nFROM users u\nLEFT JOIN orders o ON u.id = o.user_id\nGROP BY u.id, u.name\nORDER BY total_spent DESC\nLIMIT 10;\n```",
  ];

  MockClaudeClient({ClaudeConfig? config, List<McpServerBase>? mcpServers})
    : config = config ?? ClaudeConfig.defaults(),
      mcpServers = mcpServers ?? [],
      sessionId = const Uuid().v4();

  @override
  Stream<Conversation> get conversation => _conversationController.stream;

  @override
  Conversation get currentConversation => _currentConversation;

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
  void sendMessage(Message message) {
    if (message.text.trim().isEmpty) {
      return;
    }

    // Add user message
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

    // Simulate processing delay
    Timer(const Duration(milliseconds: 500), () {
      _updateConversation(
        _currentConversation.withState(ConversationState.receivingResponse),
      );
      _updateStatus(ClaudeStatus.responding);

      // Start streaming mock response
      _streamMockResponse(message.text);
    });
  }

  void _streamMockResponse(String userText) {
    final assistantId = DateTime.now().millisecondsSinceEpoch.toString();
    final responses = <ClaudeResponse>[];

    // Choose response based on user input
    String fullResponse = _selectMockResponse(userText);

    // Check if we should simulate tool usage
    bool simulateToolUse =
        userText.toLowerCase().contains('tool') ||
        userText.toLowerCase().contains('search') ||
        userText.toLowerCase().contains('file') ||
        userText.toLowerCase().contains('read');

    if (simulateToolUse) {
      _simulateToolUse(assistantId, responses, fullResponse);
    } else {
      _simulateTextStreaming(assistantId, responses, fullResponse);
    }
  }

  String _selectMockResponse(String userText) {
    // Select response based on keywords
    if (userText.toLowerCase().contains('code') ||
        userText.toLowerCase().contains('function') ||
        userText.toLowerCase().contains('class')) {
      return _mockCodeResponses[DateTime.now().millisecond %
          _mockCodeResponses.length];
    }

    // Default to regular responses
    return _mockResponses[DateTime.now().millisecond % _mockResponses.length];
  }

  void _simulateToolUse(
    String assistantId,
    List<ClaudeResponse> responses,
    String finalResponse,
  ) {
    // Add tool use response
    final toolUseId = const Uuid().v4();
    final toolUse = ToolUseResponse(
      id: const Uuid().v4(),
      timestamp: DateTime.now(),
      toolName: 'WebSearch',
      parameters: {'query': 'relevant information', 'maxResults': 5},
      toolUseId: toolUseId,
    );
    responses.add(toolUse);

    // Update conversation with tool use
    _updateConversation(
      _currentConversation.updateLastMessage(
        ConversationMessage.assistant(
          id: assistantId,
          responses: responses,
          isStreaming: true,
        ),
      ),
    );

    // Simulate tool result after delay
    Timer(const Duration(seconds: 1), () {
      final toolResult = ToolResultResponse(
        id: const Uuid().v4(),
        timestamp: DateTime.now(),
        toolUseId: toolUseId,
        content:
            'Found 5 relevant results:\n1. First result\n2. Second result\n3. Third result',
        isError: false,
      );
      responses.add(toolResult);

      // Update with tool result
      _updateConversation(
        _currentConversation.updateLastMessage(
          ConversationMessage.assistant(
            id: assistantId,
            responses: responses,
            isStreaming: true,
          ),
        ),
      );

      // Then stream the text response
      _simulateTextStreaming(assistantId, responses, finalResponse);
    });
  }

  void _simulateTextStreaming(
    String assistantId,
    List<ClaudeResponse> responses,
    String fullResponse,
  ) {
    // Split response into chunks for streaming effect
    final words = fullResponse.split(' ');
    int currentIndex = 0;
    final buffer = StringBuffer();

    // Start streaming timer
    _activeTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      // Check if aborting
      if (_isAborting) {
        timer.cancel();
        _activeTimer = null;
        return;
      }

      if (currentIndex >= words.length) {
        timer.cancel();
        _activeTimer = null;

        // Add completion response
        final completion = CompletionResponse(
          id: const Uuid().v4(),
          timestamp: DateTime.now(),
          stopReason: 'stop_sequence',
          inputTokens: 150 + (fullResponse.length ~/ 4),
          outputTokens: fullResponse.length ~/ 4,
        );
        responses.add(completion);

        // Final update with complete message
        _updateConversation(
          _currentConversation
              .updateLastMessage(
                ConversationMessage.assistant(
                  id: assistantId,
                  responses: responses,
                  isStreaming: false,
                  isComplete: true,
                ),
              )
              .withState(ConversationState.idle)
              .copyWith(
                totalInputTokens:
                    _currentConversation.totalInputTokens +
                    (completion.inputTokens ?? 0),
                totalOutputTokens:
                    _currentConversation.totalOutputTokens +
                    (completion.outputTokens ?? 0),
              ),
        );

        // Update status to completed/ready
        _updateStatus(ClaudeStatus.ready);

        // Notify that turn is complete
        _turnCompleteController.add(null);
        return;
      }

      // Add next word(s)
      final wordsToAdd = (currentIndex == 0) ? 3 : 2; // Start with more words
      for (int i = 0; i < wordsToAdd && currentIndex < words.length; i++) {
        if (buffer.isNotEmpty) buffer.write(' ');
        buffer.write(words[currentIndex]);
        currentIndex++;
      }

      // Create text response
      final textResponse = TextResponse(
        id: const Uuid().v4(),
        timestamp: DateTime.now(),
        content: buffer.toString(),
        isPartial: true,
        role: 'assistant',
      );

      // Replace last text response or add new one
      if (responses.isNotEmpty && responses.last is TextResponse) {
        responses[responses.length - 1] = textResponse;
      } else {
        responses.add(textResponse);
      }

      // Update conversation with streaming message
      if (currentIndex == wordsToAdd) {
        // First update - add message
        _updateConversation(
          _currentConversation.addMessage(
            ConversationMessage.assistant(
              id: assistantId,
              responses: responses,
              isStreaming: true,
            ),
          ),
        );
      } else {
        // Subsequent updates - update last message
        _updateConversation(
          _currentConversation.updateLastMessage(
            ConversationMessage.assistant(
              id: assistantId,
              responses: responses,
              isStreaming: true,
            ),
          ),
        );
      }
    });
  }

  @override
  Future<void> clearConversation() async {
    _updateConversation(Conversation.empty());
  }

  @override
  Future<void> abort() async {
    print('[MockClaudeClient] Aborting mock conversation');
    _isAborting = true;

    // Cancel active timer if running
    _activeTimer?.cancel();
    _activeTimer = null;

    // Add synthetic abort message
    final assistantId = DateTime.now().millisecondsSinceEpoch.toString();
    final abortMessage = ConversationMessage.assistant(
      id: assistantId,
      responses: [
        ErrorResponse(
          id: assistantId,
          timestamp: DateTime.now(),
          error: 'Interrupted by user',
          details: 'Mock conversation stopped by user (Ctrl+C)',
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

    _isAborting = false;
  }

  @override
  Future<void> close() async {
    _activeTimer?.cancel();
    await _conversationController.close();
    await _turnCompleteController.close();
    await _statusController.close();
    await _queuedMessageController.close();
  }

  Future<void> restart() async {
    await clearConversation();
  }

  // Factory method to match the ClaudeClient interface
  static Future<MockClaudeClient> create({
    ClaudeConfig? config,
    List<McpServerBase>? mcpServers,
    Conversation? initialConversation,
  }) async {
    final client = MockClaudeClient(config: config, mcpServers: mcpServers);
    if (initialConversation != null) {
      client._currentConversation = initialConversation;
      client._conversationController.add(initialConversation);
    }
    return client;
  }

  @override
  String get workingDirectory => config.workingDirectory!;

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
}
