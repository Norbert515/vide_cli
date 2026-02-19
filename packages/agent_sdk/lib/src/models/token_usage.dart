/// Token usage statistics for an agent turn or conversation.
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
  /// Represents the actual context window usage.
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
