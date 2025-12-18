/// Prompt builder for summarizing sub-agent activities
class ProgressSummaryPrompt {
  static String build(List<String> recentActivities) {
    final activitiesText = recentActivities.take(8).join('\n');

    return '''
Summarize what AI sub-agents are currently doing based on their recent tool calls.

RECENT ACTIVITIES (format: [AgentName] tool: params):
$activitiesText

RULES:
- ONE short sentence, 12 words max
- Present tense, action-focused
- If multiple agents, briefly mention what each is doing
- No emojis
- Output ONLY the summary text
''';
  }
}
