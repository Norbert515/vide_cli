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

enum MessageRole { user, assistant, system }

/// The semantic type of a message, allowing the UI layer to decide
/// how to display or filter different message types.
enum MessageType {
  /// Regular user message
  userMessage,

  /// Regular assistant text response
  assistantText,

  /// Tool invocation by assistant
  toolUse,

  /// Result from a tool execution
  toolResult,

  /// Error response
  error,

  /// Completion/end of turn marker with token usage
  completion,

  /// Status update (processing, ready, etc.)
  status,

  /// Session metadata (conversation ID, project info, etc.)
  meta,

  /// Compact boundary marker (context was compacted)
  compactBoundary,

  /// Compact summary (summarized conversation after compaction)
  compactSummary,

  /// Unknown/unrecognized response type
  unknown,
}

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

  /// The semantic type of this message, allowing UI layer to filter/display appropriately.
  final MessageType messageType;

  /// Whether this message is a compact summary injected after context compaction.
  /// When true, the content contains the summarized conversation history.
  final bool isCompactSummary;

  /// Whether this message is only visible in the transcript file (not sent to the model).
  /// Used for compact summaries and other internal messages.
  final bool isVisibleInTranscriptOnly;

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
    this.messageType = MessageType.assistantText,
    this.isCompactSummary = false,
    this.isVisibleInTranscriptOnly = false,
  });

  factory ConversationMessage.user({
    required String content,
    List<Attachment>? attachments,
    bool isCompactSummary = false,
    bool isVisibleInTranscriptOnly = false,
  }) => ConversationMessage(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    role: MessageRole.user,
    content: content,
    timestamp: DateTime.now(),
    isComplete: true,
    attachments: attachments,
    messageType: isCompactSummary
        ? MessageType.compactSummary
        : MessageType.userMessage,
    isCompactSummary: isCompactSummary,
    isVisibleInTranscriptOnly: isVisibleInTranscriptOnly,
  );

  /// Creates a compact boundary message representing where context was compacted.
  factory ConversationMessage.compactBoundary({
    required String id,
    required DateTime timestamp,
    required String trigger,
    required int preTokens,
  }) {
    return ConversationMessage(
      id: id,
      role: MessageRole.system,
      content: '─────────── Conversation Compacted ($trigger) ───────────',
      timestamp: timestamp,
      isComplete: true,
      messageType: MessageType.compactBoundary,
      responses: [
        CompactBoundaryResponse(
          id: id,
          timestamp: timestamp,
          trigger: trigger,
          preTokens: preTokens,
        ),
      ],
    );
  }

  factory ConversationMessage.assistant({
    required String id,
    required List<ClaudeResponse> responses,
    bool isStreaming = false,
    bool isComplete = false,
  }) {
    // Build content from responses
    // We may receive BOTH streaming deltas (isPartial: true) AND full messages (isPartial: false)
    // To avoid duplicates, prefer using only the deltas (partials) if present,
    // since full messages are cumulative and would duplicate delta content.
    final textResponses = responses.whereType<TextResponse>().toList();
    final hasPartials = textResponses.any((r) => r.isPartial);

    final textBuffer = StringBuffer();
    TokenUsage? usage;

    for (final response in responses) {
      if (response is TextResponse) {
        // If we have partial (delta) responses, only use those to avoid duplicates
        if (hasPartials) {
          if (response.isPartial) {
            textBuffer.write(response.content);
          }
          // Skip non-partial responses when we have partials (they're cumulative)
        } else if (response.isCumulative) {
          // Cumulative responses contain the full text up to that point.
          // Use only the last one by clearing before writing.
          textBuffer.clear();
          textBuffer.write(response.content);
        } else {
          // Sequential (non-cumulative, non-partial) responses should be concatenated
          textBuffer.write(response.content);
        }
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
    MessageType? messageType,
    bool? isCompactSummary,
    bool? isVisibleInTranscriptOnly,
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
      messageType: messageType ?? this.messageType,
      isCompactSummary: isCompactSummary ?? this.isCompactSummary,
      isVisibleInTranscriptOnly:
          isVisibleInTranscriptOnly ?? this.isVisibleInTranscriptOnly,
    );
  }

  /// Creates a status message (e.g., processing, ready).
  factory ConversationMessage.status({
    required String id,
    required DateTime timestamp,
    required ClaudeStatus status,
    String? message,
    required StatusResponse response,
  }) {
    return ConversationMessage(
      id: id,
      role: MessageRole.system,
      content: message ?? status.name,
      timestamp: timestamp,
      isComplete: true,
      messageType: MessageType.status,
      responses: [response],
    );
  }

  /// Creates a meta message containing session metadata.
  factory ConversationMessage.meta({
    required String id,
    required DateTime timestamp,
    String? conversationId,
    required Map<String, dynamic> metadata,
    required MetaResponse response,
  }) {
    return ConversationMessage(
      id: id,
      role: MessageRole.system,
      content: conversationId ?? 'Session metadata',
      timestamp: timestamp,
      isComplete: true,
      messageType: MessageType.meta,
      responses: [response],
    );
  }

  /// Creates a completion message marking end of turn with token usage.
  factory ConversationMessage.completion({
    required String id,
    required DateTime timestamp,
    required CompletionResponse response,
  }) {
    return ConversationMessage(
      id: id,
      role: MessageRole.system,
      content: response.stopReason ?? 'Turn complete',
      timestamp: timestamp,
      isComplete: true,
      messageType: MessageType.completion,
      tokenUsage: TokenUsage(
        inputTokens: response.inputTokens ?? 0,
        outputTokens: response.outputTokens ?? 0,
        cacheReadInputTokens: response.cacheReadInputTokens ?? 0,
        cacheCreationInputTokens: response.cacheCreationInputTokens ?? 0,
      ),
      responses: [response],
    );
  }

  /// Creates an unknown message for unrecognized response types.
  factory ConversationMessage.unknown({
    required String id,
    required DateTime timestamp,
    required UnknownResponse response,
  }) {
    return ConversationMessage(
      id: id,
      role: MessageRole.system,
      content: 'Unknown response',
      timestamp: timestamp,
      isComplete: true,
      messageType: MessageType.unknown,
      responses: [response],
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
      totalInputTokens +
      totalCacheReadInputTokens +
      totalCacheCreationInputTokens;

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
      currentContextCacheCreationTokens:
          currentContextCacheCreationTokens ??
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
