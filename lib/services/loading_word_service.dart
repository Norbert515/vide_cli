import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Service that generates fun, whimsical loading words based on user input.
/// Uses Claude Haiku to generate creative, context-aware words.
class LoadingWordService {
  /// Enable/disable logging for debugging.
  static bool enableLogging = Platform.environment['VIDE_DEBUG_LOADING_WORDS'] == '1';

  /// System prompt for Haiku-based word generation
  static const _haikuSystemPrompt = '''
You are a loading message generator. Output 5 fun, satirical loading messages.

RULES:
- Output EXACTLY 5 messages, one per line
- Each message MUST end with "..."
- Each message should be 2-4 words total
- Each message must include at least ONE whimsical made-up word
- Prefer fake verbs ending in -ating or -ling
- You MAY add a short real-word phrase for contrast
- Tone: dry, self-aware, gently sarcastic
- Humor should feel intentional, not random
- No emojis, no memes, no AI references
- NO explanations - output only the 5 messages
''';

  /// Generates loading words using Claude Haiku CLI for creative, context-aware results.
  /// Returns null on failure (timeout, CLI error, etc.)
  static Future<List<String>?> generateWordsWithHaiku(String userMessage) async {
    _log('generateWordsWithHaiku called with: "${_truncate(userMessage, 50)}"');

    try {
      // Small delay to let the main Claude process initialize first
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // Wrap user message to make it clear this is for loading word generation
      final wrappedMessage = 'Generate loading words for this task: "$userMessage"';

      // Use Process.start like the main ClaudeClient does for parallel execution
      final process = await Process.start(
        'claude',
        [
          '-p', wrappedMessage,
          '--model', 'claude-haiku-4-5-20251001',
          '--system-prompt', _haikuSystemPrompt,
          '--output-format', 'text',
          '--max-turns', '1',
        ],
        environment: <String, String>{'MCP_TOOL_TIMEOUT': '30000000'},
        runInShell: true,
        includeParentEnvironment: true,
      );

      _log('Haiku process started with PID: ${process.pid}');

      // Close stdin immediately
      await process.stdin.close();

      // Collect stdout with timeout
      final stdoutFuture = process.stdout.transform(utf8.decoder).join();
      final stderrFuture = process.stderr.transform(utf8.decoder).join();

      final results = await Future.wait([
        stdoutFuture,
        stderrFuture,
        process.exitCode,
      ]).timeout(const Duration(seconds: 10));

      final stdout = results[0] as String;
      final stderr = results[1] as String;
      final exitCode = results[2] as int;

      _log('Claude CLI exit code: $exitCode');

      if (exitCode != 0) {
        _log('Claude CLI error: $stderr');
        return null;
      }

      final text = stdout.trim();
      _log('Claude CLI response: $text');

      if (text.isEmpty) {
        _log('Claude CLI returned empty response');
        return null;
      }

      // Parse response: split by newlines, filter empty, limit to 5
      final words = text
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty && line.endsWith('...'))
          .take(5)
          .toList();

      if (words.isEmpty) {
        _log('Claude CLI returned no valid words');
        return null;
      }

      _log('Generated words from Haiku CLI: ${words.join(", ")}');
      return words;
    } on TimeoutException {
      _log('Claude CLI timed out');
      return null;
    } catch (e) {
      _log('Claude CLI error: $e');
      return null;
    }
  }

  static File? _logFile;

  static void _log(String message) {
    if (!enableLogging) return;

    final timestamp = DateTime.now().toIso8601String();
    final logLine = '[$timestamp] $message\n';

    // Write to log file in /tmp
    _logFile ??= File('/tmp/vide_loading_words.log');
    _logFile!.writeAsStringSync(logLine, mode: FileMode.append);
  }

  static String _truncate(String s, int maxLength) {
    if (s.length <= maxLength) return s;
    return '${s.substring(0, maxLength)}...';
  }
}
