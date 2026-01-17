/// Types for AskUserQuestion MCP tool
///
/// This matches the Claude Code AskUserQuestion schema with some adaptations.

/// A single question option
class AskUserQuestionOption {
  final String label;
  final String description;

  const AskUserQuestionOption({required this.label, required this.description});

  factory AskUserQuestionOption.fromJson(Map<String, dynamic> json) {
    return AskUserQuestionOption(
      label: json['label'] as String,
      description: json['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'label': label, 'description': description};
}

/// A single question with its options
class AskUserQuestion {
  final String question;
  final String? header;
  final bool multiSelect;
  final List<AskUserQuestionOption> options;

  const AskUserQuestion({
    required this.question,
    this.header,
    this.multiSelect = false,
    required this.options,
  });

  factory AskUserQuestion.fromJson(Map<String, dynamic> json) {
    final optionsList = json['options'] as List<dynamic>;
    return AskUserQuestion(
      question: json['question'] as String,
      header: json['header'] as String?,
      multiSelect: json['multiSelect'] as bool? ?? false,
      options: optionsList
          .map((o) => AskUserQuestionOption.fromJson(o as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'question': question,
    if (header != null) 'header': header,
    'multiSelect': multiSelect,
    'options': options.map((o) => o.toJson()).toList(),
  };
}

/// Request sent to the UI to display questions
class AskUserQuestionRequest {
  final String requestId;
  final List<AskUserQuestion> questions;

  const AskUserQuestionRequest({
    required this.requestId,
    required this.questions,
  });
}

/// Response from the UI with user answers
class AskUserQuestionResponse {
  /// Map of question text -> selected answer(s)
  /// For single select: just the label
  /// For multi select: comma-separated labels
  final Map<String, String> answers;

  const AskUserQuestionResponse({required this.answers});
}
