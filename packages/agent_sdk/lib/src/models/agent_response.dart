/// Base class for all response types from an AI coding agent.
///
/// This sealed hierarchy defines the generic event model that
/// any coding agent (Claude, Codex, etc.) maps into.
sealed class AgentResponse {
  /// Unique identifier for this response.
  final String id;

  /// When this response was received.
  final DateTime timestamp;

  /// Raw protocol data from the underlying agent (for debugging).
  final Map<String, dynamic>? rawData;

  const AgentResponse({
    required this.id,
    required this.timestamp,
    this.rawData,
  });
}

/// Streaming or complete text content from the agent.
class AgentTextResponse extends AgentResponse {
  /// The text content.
  final String content;

  /// Whether this is a partial streaming delta (more text coming).
  final bool isPartial;

  /// Whether this contains cumulative content (full text up to this point)
  /// rather than a sequential delta.
  final bool isCumulative;

  const AgentTextResponse({
    required super.id,
    required super.timestamp,
    required this.content,
    this.isPartial = false,
    this.isCumulative = false,
    super.rawData,
  });
}

/// The agent is invoking a tool.
class AgentToolUseResponse extends AgentResponse {
  /// Name of the tool being invoked (e.g., 'Bash', 'Read', 'Edit').
  final String toolName;

  /// Parameters passed to the tool.
  final Map<String, dynamic> parameters;

  /// Unique ID for this tool invocation (used to match with results).
  final String? toolUseId;

  const AgentToolUseResponse({
    required super.id,
    required super.timestamp,
    required this.toolName,
    required this.parameters,
    this.toolUseId,
    super.rawData,
  });
}

/// Result from a tool execution.
class AgentToolResultResponse extends AgentResponse {
  /// ID of the tool invocation this result corresponds to.
  final String toolUseId;

  /// The result content.
  final String content;

  /// Whether the tool execution resulted in an error.
  final bool isError;

  /// Standard output from the tool (if available).
  final String? stdout;

  /// Standard error from the tool (if available).
  final String? stderr;

  /// Whether the tool execution was interrupted.
  final bool? interrupted;

  /// Whether the result contains image data.
  final bool? isImage;

  const AgentToolResultResponse({
    required super.id,
    required super.timestamp,
    required this.toolUseId,
    required this.content,
    this.isError = false,
    this.stdout,
    this.stderr,
    this.interrupted,
    this.isImage,
    super.rawData,
  });

  /// Whether the tool execution was interrupted.
  bool get wasInterrupted => interrupted ?? false;

  /// Whether the result contains image data.
  bool get hasImage => isImage ?? false;
}

/// End-of-turn marker with token usage and billing information.
class AgentCompletionResponse extends AgentResponse {
  /// Why the turn ended (e.g., 'end_turn', 'tool_use', 'error').
  final String? stopReason;

  /// Input tokens consumed.
  final int? inputTokens;

  /// Output tokens generated.
  final int? outputTokens;

  /// Tokens read from cache.
  final int? cacheReadInputTokens;

  /// Tokens written to cache.
  final int? cacheCreationInputTokens;

  /// Total cost in USD for this turn.
  final double? totalCostUsd;

  /// Duration of API calls in milliseconds.
  final int? durationApiMs;

  const AgentCompletionResponse({
    required super.id,
    required super.timestamp,
    this.stopReason,
    this.inputTokens,
    this.outputTokens,
    this.cacheReadInputTokens,
    this.cacheCreationInputTokens,
    this.totalCostUsd,
    this.durationApiMs,
    super.rawData,
  });

  /// Total context tokens (input + cache read + cache creation).
  int get totalContextTokens =>
      (inputTokens ?? 0) +
      (cacheReadInputTokens ?? 0) +
      (cacheCreationInputTokens ?? 0);
}

/// An error from the agent.
class AgentErrorResponse extends AgentResponse {
  /// The error message.
  final String error;

  /// Additional error details.
  final String? details;

  /// Error code.
  final String? code;

  const AgentErrorResponse({
    required super.id,
    required super.timestamp,
    required this.error,
    this.details,
    this.code,
    super.rawData,
  });
}

/// A transient API error (rate limit, overload, etc.) that may be retried.
class AgentApiErrorResponse extends AgentResponse {
  /// Error severity level (e.g., 'error', 'warning').
  final String level;

  /// Human-readable error message.
  final String message;

  /// Error type (e.g., 'rate_limit_error', 'overloaded_error').
  final String? errorType;

  /// Milliseconds before retry (if retrying).
  final double? retryInMs;

  /// Current retry attempt number.
  final int? retryAttempt;

  /// Maximum number of retries configured.
  final int? maxRetries;

  const AgentApiErrorResponse({
    required super.id,
    required super.timestamp,
    required this.level,
    required this.message,
    this.errorType,
    this.retryInMs,
    this.retryAttempt,
    this.maxRetries,
    super.rawData,
  });

  /// Whether this error will be automatically retried.
  bool get willRetry => retryInMs != null && retryInMs! > 0;
}

/// The agent's context was compacted (compressed) at this point.
///
/// Any coding agent with context limits may emit this when the
/// conversation history is summarized to free up context space.
class AgentContextCompactedResponse extends AgentResponse {
  /// What triggered the compaction: 'manual' or 'auto'.
  final String trigger;

  /// Token count before compaction.
  final int preTokens;

  const AgentContextCompactedResponse({
    required super.id,
    required super.timestamp,
    required this.trigger,
    required this.preTokens,
    super.rawData,
  });
}

/// A user message from the streaming transcript.
class AgentUserMessageResponse extends AgentResponse {
  /// The message content.
  final String content;

  /// Whether this is a replay of a previous message.
  final bool isReplay;

  const AgentUserMessageResponse({
    required super.id,
    required super.timestamp,
    required this.content,
    this.isReplay = false,
    super.rawData,
  });
}

/// Reasoning/thinking content from the model.
///
/// This represents internal chain-of-thought text that is separate from
/// the actual response content. UI layers can render this differently
/// (e.g., collapsed, dimmed, or in an expandable section).
class AgentThinkingResponse extends AgentResponse {
  /// The thinking/reasoning text.
  final String content;

  /// Whether this contains cumulative content (full text up to this point).
  final bool isCumulative;

  const AgentThinkingResponse({
    required super.id,
    required super.timestamp,
    required this.content,
    this.isCumulative = false,
    super.rawData,
  });
}

/// An unrecognized response type (forward compatibility).
class AgentUnknownResponse extends AgentResponse {
  const AgentUnknownResponse({
    required super.id,
    required super.timestamp,
    super.rawData,
  });
}
