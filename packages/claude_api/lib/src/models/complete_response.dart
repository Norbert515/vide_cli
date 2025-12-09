import 'response.dart';

class CompleteResponse {
  final String fullText;
  final List<ToolUseResponse> toolUses;
  final List<ToolResultResponse> toolResults;
  final CompletionResponse? completion;
  final ErrorResponse? error;
  final List<ClaudeResponse> allResponses;
  final Duration elapsed;

  const CompleteResponse({
    required this.fullText,
    required this.toolUses,
    required this.toolResults,
    this.completion,
    this.error,
    required this.allResponses,
    required this.elapsed,
  });

  bool get hasError => error != null;
  bool get isComplete => completion != null;
  bool get hasToolUses => toolUses.isNotEmpty;

  int? get inputTokens => completion?.inputTokens;
  int? get outputTokens => completion?.outputTokens;
  String? get stopReason => completion?.stopReason;
}
