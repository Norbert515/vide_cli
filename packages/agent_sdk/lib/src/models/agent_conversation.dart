import 'agent_message.dart';
import 'agent_response.dart';
import 'token_usage.dart';

/// The state of a conversation with an agent.
enum AgentConversationState {
  idle,
  sendingMessage,
  receivingResponse,
  processing,
  error,
}

/// The role of a message in the conversation.
enum AgentMessageRole { user, assistant, system }

/// The semantic type of a message, for UI filtering and display.
enum AgentMessageType {
  userMessage,
  assistantText,
  toolUse,
  toolResult,
  error,
  completion,
  contextCompacted,
  unknown,
}

/// A paired tool call and its result.
class AgentToolInvocation {
  /// The tool call that was made.
  final AgentToolUseResponse toolCall;

  /// The result, or null if the tool hasn't completed yet.
  final AgentToolResultResponse? toolResult;

  const AgentToolInvocation({required this.toolCall, this.toolResult});

  bool get hasResult => toolResult != null;
  bool get isComplete => toolResult != null;
  bool get isError => toolResult?.isError ?? false;
  String get toolName => toolCall.toolName;
  Map<String, dynamic> get parameters => toolCall.parameters;
  String? get resultContent => toolResult?.content;
}

/// A single message in an agent conversation.
class AgentConversationMessage {
  final String id;
  final AgentMessageRole role;
  final String content;
  final DateTime timestamp;
  final List<AgentResponse> responses;
  final bool isStreaming;
  final bool isComplete;
  final String? error;
  final TokenUsage? tokenUsage;
  final List<AgentAttachment>? attachments;
  final AgentMessageType messageType;

  const AgentConversationMessage({
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
    this.messageType = AgentMessageType.assistantText,
  });

  /// Creates a user message.
  factory AgentConversationMessage.user({
    required String content,
    List<AgentAttachment>? attachments,
  }) => AgentConversationMessage(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    role: AgentMessageRole.user,
    content: content,
    timestamp: DateTime.now(),
    isComplete: true,
    attachments: attachments,
    messageType: AgentMessageType.userMessage,
  );

  /// Creates an assistant message from a list of responses.
  factory AgentConversationMessage.assistant({
    required String id,
    required List<AgentResponse> responses,
    bool isStreaming = false,
    bool isComplete = false,
  }) {
    final textResponses = responses.whereType<AgentTextResponse>().toList();
    final hasPartials = textResponses.any((r) => r.isPartial);

    final textBuffer = StringBuffer();
    TokenUsage? usage;

    for (final response in responses) {
      if (response is AgentTextResponse) {
        if (hasPartials) {
          if (response.isPartial) {
            textBuffer.write(response.content);
          }
        } else if (response.isCumulative) {
          textBuffer.clear();
          textBuffer.write(response.content);
        } else {
          textBuffer.write(response.content);
        }
      } else if (response is AgentCompletionResponse) {
        usage = TokenUsage(
          inputTokens: response.inputTokens ?? 0,
          outputTokens: response.outputTokens ?? 0,
          cacheReadInputTokens: response.cacheReadInputTokens ?? 0,
          cacheCreationInputTokens: response.cacheCreationInputTokens ?? 0,
        );
      }
    }

    return AgentConversationMessage(
      id: id,
      role: AgentMessageRole.assistant,
      content: textBuffer.toString(),
      timestamp: DateTime.now(),
      responses: responses,
      isStreaming: isStreaming,
      isComplete: isComplete,
      tokenUsage: usage,
    );
  }

  /// Creates a context compacted marker message.
  factory AgentConversationMessage.contextCompacted({
    required String id,
    required DateTime timestamp,
    required String trigger,
    required int preTokens,
  }) {
    return AgentConversationMessage(
      id: id,
      role: AgentMessageRole.system,
      content: '─────────── Conversation Compacted ($trigger) ───────────',
      timestamp: timestamp,
      isComplete: true,
      messageType: AgentMessageType.contextCompacted,
      responses: [
        AgentContextCompactedResponse(
          id: id,
          timestamp: timestamp,
          trigger: trigger,
          preTokens: preTokens,
        ),
      ],
    );
  }

  /// Creates an unknown message for unrecognized response types.
  factory AgentConversationMessage.unknown({
    required String id,
    required DateTime timestamp,
    required AgentUnknownResponse response,
  }) {
    return AgentConversationMessage(
      id: id,
      role: AgentMessageRole.system,
      content: 'Unknown response',
      timestamp: timestamp,
      isComplete: true,
      messageType: AgentMessageType.unknown,
      responses: [response],
    );
  }

  /// Groups tool calls with their corresponding results.
  List<AgentToolInvocation> get toolInvocations {
    final invocations = <AgentToolInvocation>[];
    final toolCalls = <String, AgentToolUseResponse>{};

    for (final response in responses) {
      if (response is AgentToolUseResponse) {
        if (response.toolUseId != null) {
          toolCalls[response.toolUseId!] = response;
        } else {
          invocations.add(AgentToolInvocation(toolCall: response));
        }
      } else if (response is AgentToolResultResponse) {
        final call = toolCalls[response.toolUseId];
        if (call != null) {
          invocations.add(
            AgentToolInvocation(toolCall: call, toolResult: response),
          );
          toolCalls.remove(response.toolUseId);
        }
      }
    }

    // Add remaining tool calls without results
    for (final call in toolCalls.values) {
      invocations.add(AgentToolInvocation(toolCall: call));
    }

    return invocations;
  }

  /// Gets all text responses.
  List<AgentTextResponse> get textResponses {
    return responses.whereType<AgentTextResponse>().toList();
  }

  AgentConversationMessage copyWith({
    String? id,
    AgentMessageRole? role,
    String? content,
    DateTime? timestamp,
    List<AgentResponse>? responses,
    bool? isStreaming,
    bool? isComplete,
    String? error,
    TokenUsage? tokenUsage,
    List<AgentAttachment>? attachments,
    AgentMessageType? messageType,
  }) {
    return AgentConversationMessage(
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
      messageType: messageType ?? this.messageType,
    );
  }
}

/// The full state of a conversation with an agent.
class AgentConversation {
  final List<AgentConversationMessage> messages;
  final AgentConversationState state;
  final String? currentError;

  // Accumulated totals across all turns (for billing/stats)
  final int totalInputTokens;
  final int totalOutputTokens;
  final int totalCacheReadInputTokens;
  final int totalCacheCreationInputTokens;
  final double totalCostUsd;

  // Current context window usage (from latest turn, for context % display)
  final int currentContextInputTokens;
  final int currentContextCacheReadTokens;
  final int currentContextCacheCreationTokens;

  const AgentConversation({
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

  factory AgentConversation.empty() =>
      const AgentConversation(messages: [], state: AgentConversationState.idle);

  int get totalTokens => totalInputTokens + totalOutputTokens;

  /// Total context tokens accumulated across all turns.
  int get totalContextTokens =>
      totalInputTokens +
      totalCacheReadInputTokens +
      totalCacheCreationInputTokens;

  /// Current context window usage (from the latest turn).
  int get currentContextWindowTokens =>
      currentContextInputTokens +
      currentContextCacheReadTokens +
      currentContextCacheCreationTokens;

  bool get isProcessing =>
      state == AgentConversationState.sendingMessage ||
      state == AgentConversationState.receivingResponse ||
      state == AgentConversationState.processing;

  AgentConversationMessage? get lastMessage =>
      messages.isNotEmpty ? messages.last : null;

  AgentConversationMessage? get lastUserMessage {
    for (int i = messages.length - 1; i >= 0; i--) {
      if (messages[i].role == AgentMessageRole.user) return messages[i];
    }
    return null;
  }

  AgentConversationMessage? get lastAssistantMessage {
    for (int i = messages.length - 1; i >= 0; i--) {
      if (messages[i].role == AgentMessageRole.assistant) return messages[i];
    }
    return null;
  }

  AgentConversation copyWith({
    List<AgentConversationMessage>? messages,
    AgentConversationState? state,
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
    return AgentConversation(
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
      currentContextCacheCreationTokens:
          currentContextCacheCreationTokens ??
          this.currentContextCacheCreationTokens,
    );
  }

  AgentConversation addMessage(AgentConversationMessage message) {
    return copyWith(messages: [...messages, message]);
  }

  AgentConversation updateLastMessage(AgentConversationMessage message) {
    if (messages.isEmpty) {
      return addMessage(message);
    }
    final updatedMessages = [...messages];
    updatedMessages[updatedMessages.length - 1] = message;
    return copyWith(messages: updatedMessages);
  }

  AgentConversation withState(AgentConversationState state) {
    return copyWith(state: state);
  }

  AgentConversation withError(String? error) {
    return copyWith(
      state: error != null ? AgentConversationState.error : state,
      currentError: error,
    );
  }

  AgentConversation clearError() {
    return copyWith(state: AgentConversationState.idle, currentError: null);
  }
}
