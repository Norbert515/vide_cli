import 'message.dart';
import 'response.dart';
import 'tool_invocation.dart';

enum ConversationState {
  idle,
  sendingMessage,
  receivingResponse,
  processing,
  error,
}

enum MessageRole { user, assistant }

class ConversationMessage {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final List<ClaudeResponse> responses;
  final bool isStreaming;
  final bool isComplete;
  final String? error;
  final TokenUsage? tokenUsage;
  final List<Attachment>? attachments;

  const ConversationMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.responses = const [],
    this.isStreaming = false,
    this.isComplete = false,
    this.error,
    this.tokenUsage,
    this.attachments,
  });

  factory ConversationMessage.user({
    required String content,
    List<Attachment>? attachments,
  }) => ConversationMessage(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    role: MessageRole.user,
    content: content,
    timestamp: DateTime.now(),
    isComplete: true,
    attachments: attachments,
  );

  factory ConversationMessage.assistant({
    required String id,
    required List<ClaudeResponse> responses,
    bool isStreaming = false,
    bool isComplete = false,
  }) {
    // Build content from responses
    final textBuffer = StringBuffer();
    TokenUsage? usage;

    for (final response in responses) {
      if (response is TextResponse) {
        textBuffer.write(response.content);
      } else if (response is CompletionResponse) {
        usage = TokenUsage(
          inputTokens: response.inputTokens ?? 0,
          outputTokens: response.outputTokens ?? 0,
          cacheReadInputTokens: response.cacheReadInputTokens ?? 0,
          cacheCreationInputTokens: response.cacheCreationInputTokens ?? 0,
        );
      }
    }

    return ConversationMessage(
      id: id,
      role: MessageRole.assistant,
      content: textBuffer.toString(),
      timestamp: DateTime.now(),
      responses: responses,
      isStreaming: isStreaming,
      isComplete: isComplete,
      tokenUsage: usage,
    );
  }

  /// Creates a typed ToolInvocation based on the tool name.
  /// This factory method analyzes the tool name and returns the appropriate
  /// typed subclass (WriteToolInvocation, EditToolInvocation, etc.) or
  /// a base ToolInvocation for unknown tools.
  static ToolInvocation createTypedInvocation(
    ToolUseResponse toolCall,
    ToolResultResponse? toolResult, {
    String? sessionId,
    bool isExpanded = false,
  }) {
    final toolName = toolCall.toolName.toLowerCase();

    // Create base invocation first
    final baseInvocation = ToolInvocation(
      toolCall: toolCall,
      toolResult: toolResult,
      sessionId: sessionId,
      isExpanded: isExpanded,
    );

    // Convert to typed invocation based on tool name
    if (toolName == 'write') {
      return WriteToolInvocation.fromToolInvocation(baseInvocation);
    } else if (toolName == 'edit' || toolName == 'multiedit') {
      return EditToolInvocation.fromToolInvocation(baseInvocation);
    } else if (toolName == 'read' || toolName == 'glob' || toolName == 'grep') {
      // Other file operations can use base FileOperationToolInvocation
      return FileOperationToolInvocation.fromToolInvocation(baseInvocation);
    }

    // Return base invocation for unknown tools
    return baseInvocation;
  }

  /// Groups tool calls with their corresponding results into ToolInvocations
  List<ToolInvocation> get toolInvocations {
    final invocations = <ToolInvocation>[];
    final toolCalls = <String, ToolUseResponse>{};

    for (final response in responses) {
      if (response is ToolUseResponse) {
        // Store tool call by its ID
        if (response.toolUseId != null) {
          toolCalls[response.toolUseId!] = response;
        } else {
          // If no ID, create typed invocation immediately
          invocations.add(createTypedInvocation(response, null));
        }
      } else if (response is ToolResultResponse) {
        // Match result with its call
        final call = toolCalls[response.toolUseId];
        if (call != null) {
          invocations.add(createTypedInvocation(call, response));
          toolCalls.remove(response.toolUseId);
        }
      }
    }

    // Add any remaining tool calls without results
    for (final call in toolCalls.values) {
      invocations.add(createTypedInvocation(call, null));
    }

    return invocations;
  }

  /// Gets all text responses
  List<TextResponse> get textResponses {
    return responses.whereType<TextResponse>().toList();
  }

  ConversationMessage copyWith({
    String? id,
    MessageRole? role,
    String? content,
    DateTime? timestamp,
    List<ClaudeResponse>? responses,
    bool? isStreaming,
    bool? isComplete,
    String? error,
    TokenUsage? tokenUsage,
    List<Attachment>? attachments,
  }) {
    return ConversationMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      responses: responses ?? this.responses,
      isStreaming: isStreaming ?? this.isStreaming,
      isComplete: isComplete ?? this.isComplete,
      error: error ?? this.error,
      tokenUsage: tokenUsage ?? this.tokenUsage,
      attachments: attachments ?? this.attachments,
    );
  }
}

class TokenUsage {
  final int inputTokens;
  final int outputTokens;
  final int cacheReadInputTokens;
  final int cacheCreationInputTokens;

  const TokenUsage({
    required this.inputTokens,
    required this.outputTokens,
    this.cacheReadInputTokens = 0,
    this.cacheCreationInputTokens = 0,
  });

  int get totalTokens => inputTokens + outputTokens;

  /// Total context tokens (input + cache read + cache creation).
  /// This represents the actual context window usage.
  int get totalContextTokens =>
      inputTokens + cacheReadInputTokens + cacheCreationInputTokens;

  TokenUsage operator +(TokenUsage other) {
    return TokenUsage(
      inputTokens: inputTokens + other.inputTokens,
      outputTokens: outputTokens + other.outputTokens,
      cacheReadInputTokens: cacheReadInputTokens + other.cacheReadInputTokens,
      cacheCreationInputTokens:
          cacheCreationInputTokens + other.cacheCreationInputTokens,
    );
  }
}

class Conversation {
  final List<ConversationMessage> messages;
  final ConversationState state;
  final String? currentError;

  // Accumulated totals across all turns (for billing/stats)
  final int totalInputTokens;
  final int totalOutputTokens;
  final int totalCacheReadInputTokens;
  final int totalCacheCreationInputTokens;
  final double totalCostUsd;

  // Current context window usage (from latest turn, for context % display)
  // These are REPLACED each turn, not accumulated.
  final int currentContextInputTokens;
  final int currentContextCacheReadTokens;
  final int currentContextCacheCreationTokens;

  const Conversation({
    required this.messages,
    required this.state,
    this.currentError,
    this.totalInputTokens = 0,
    this.totalOutputTokens = 0,
    this.totalCacheReadInputTokens = 0,
    this.totalCacheCreationInputTokens = 0,
    this.totalCostUsd = 0.0,
    this.currentContextInputTokens = 0,
    this.currentContextCacheReadTokens = 0,
    this.currentContextCacheCreationTokens = 0,
  });

  factory Conversation.empty() =>
      const Conversation(messages: [], state: ConversationState.idle);

  // Helper methods
  int get totalTokens => totalInputTokens + totalOutputTokens;

  /// Total context tokens accumulated across all turns.
  /// Note: This is for billing/stats, NOT for context window percentage.
  int get totalContextTokens =>
      totalInputTokens + totalCacheReadInputTokens + totalCacheCreationInputTokens;

  /// Current context window usage (from the latest turn).
  /// This is what should be used for context window percentage display.
  int get currentContextWindowTokens =>
      currentContextInputTokens +
      currentContextCacheReadTokens +
      currentContextCacheCreationTokens;

  bool get isProcessing =>
      state == ConversationState.sendingMessage ||
      state == ConversationState.receivingResponse ||
      state == ConversationState.processing;

  ConversationMessage? get lastMessage =>
      messages.isNotEmpty ? messages.last : null;

  ConversationMessage? get lastUserMessage {
    try {
      return messages.lastWhere((m) => m.role == MessageRole.user);
    } catch (_) {
      return null;
    }
  }

  ConversationMessage? get lastAssistantMessage {
    try {
      return messages.lastWhere((m) => m.role == MessageRole.assistant);
    } catch (_) {
      return null;
    }
  }

  Conversation copyWith({
    List<ConversationMessage>? messages,
    ConversationState? state,
    String? currentError,
    int? totalInputTokens,
    int? totalOutputTokens,
    int? totalCacheReadInputTokens,
    int? totalCacheCreationInputTokens,
    double? totalCostUsd,
    int? currentContextInputTokens,
    int? currentContextCacheReadTokens,
    int? currentContextCacheCreationTokens,
  }) {
    return Conversation(
      messages: messages ?? this.messages,
      state: state ?? this.state,
      currentError: currentError ?? this.currentError,
      totalInputTokens: totalInputTokens ?? this.totalInputTokens,
      totalOutputTokens: totalOutputTokens ?? this.totalOutputTokens,
      totalCacheReadInputTokens:
          totalCacheReadInputTokens ?? this.totalCacheReadInputTokens,
      totalCacheCreationInputTokens:
          totalCacheCreationInputTokens ?? this.totalCacheCreationInputTokens,
      totalCostUsd: totalCostUsd ?? this.totalCostUsd,
      currentContextInputTokens:
          currentContextInputTokens ?? this.currentContextInputTokens,
      currentContextCacheReadTokens:
          currentContextCacheReadTokens ?? this.currentContextCacheReadTokens,
      currentContextCacheCreationTokens: currentContextCacheCreationTokens ??
          this.currentContextCacheCreationTokens,
    );
  }

  Conversation addMessage(ConversationMessage message) {
    return copyWith(messages: [...messages, message]);
  }

  Conversation updateLastMessage(ConversationMessage message) {
    if (messages.isEmpty) {
      return addMessage(message);
    }

    final updatedMessages = [...messages];
    updatedMessages[updatedMessages.length - 1] = message;

    return copyWith(messages: updatedMessages);
  }

  Conversation withState(ConversationState state) {
    return copyWith(state: state);
  }

  Conversation withError(String? error) {
    return copyWith(
      state: error != null ? ConversationState.error : state,
      currentError: error,
    );
  }

  Conversation clearError() {
    return copyWith(state: ConversationState.idle, currentError: null);
  }
}
