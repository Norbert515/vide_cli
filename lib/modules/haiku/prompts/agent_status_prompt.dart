/// Prompt builder for deriving agent status from tool activity
class AgentStatusPrompt {
  static String build({
    required String toolName,
    required Map<String, dynamic> toolParams,
  }) {
    final paramsSummary = _summarizeParams(toolParams);

    return '''
Derive a very short status phrase for an AI agent based on its current tool use.

TOOL: $toolName
PARAMS: $paramsSummary

RULES:
- 2-4 words MAXIMUM
- Present participle form (e.g., "Reading auth.dart", "Searching for errors")
- Focus on WHAT is happening, not technical details
- If file path: use just filename
- If search: include query briefly
- If bash: summarize command intent
- No emojis, no punctuation at end
- Output ONLY the status phrase
''';
  }

  static String _summarizeParams(Map<String, dynamic> params) {
    final parts = <String>[];

    if (params.containsKey('file_path')) {
      final path = params['file_path'] as String;
      parts.add('file: ${path.split('/').last}');
    }
    if (params.containsKey('pattern')) {
      parts.add('pattern: "${params['pattern']}"');
    }
    if (params.containsKey('command')) {
      final cmd = params['command'] as String;
      final truncated = cmd.length > 50 ? '${cmd.substring(0, 47)}...' : cmd;
      parts.add('command: "$truncated"');
    }
    if (params.containsKey('query')) {
      parts.add('query: "${params['query']}"');
    }
    if (params.containsKey('url')) {
      parts.add('url: "${params['url']}"');
    }
    if (params.containsKey('content')) {
      parts.add('content: [writing]');
    }

    return parts.isEmpty ? '[no params]' : parts.join(', ');
  }
}
