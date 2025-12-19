import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Core service for running Claude Haiku background tasks.
/// All Haiku-powered features share this infrastructure.
class HaikuService {
  /// Enable/disable logging for debugging
  static bool enableLogging = Platform.environment['VIDE_DEBUG_HAIKU'] == '1';

  /// Default configuration
  static const Duration defaultDelay = Duration(milliseconds: 500);
  static const Duration defaultTimeout = Duration(seconds: 10);

  static File? _logFile;

  /// Generic Haiku invocation - foundation for all features
  /// Returns null on any failure (graceful degradation)
  static Future<String?> invoke({
    required String systemPrompt,
    required String userMessage,
    Duration delay = defaultDelay,
    Duration timeout = defaultTimeout,
  }) async {
    _log('invoke called with message: "${_truncate(userMessage, 50)}"');

    try {
      // Small delay to let main Claude process initialize first
      if (delay.inMilliseconds > 0) {
        await Future<void>.delayed(delay);
      }

      final process = await Process.start(
        'claude',
        [
          '-p', userMessage,
          '--model', 'claude-haiku-4-5-20251001',
          '--system-prompt', systemPrompt,
          '--output-format', 'text',
          '--max-turns', '1',
        ],
        environment: <String, String>{'MCP_TOOL_TIMEOUT': '30000000'},
        runInShell: true,
        includeParentEnvironment: true,
      );

      _log('Haiku process started with PID: ${process.pid}');

      await process.stdin.close();

      final stdoutFuture = process.stdout.transform(utf8.decoder).join();
      final stderrFuture = process.stderr.transform(utf8.decoder).join();

      final results = await Future.wait([
        stdoutFuture,
        stderrFuture,
        process.exitCode,
      ]).timeout(timeout);

      final stdout = results[0] as String;
      final stderr = results[1] as String;
      final exitCode = results[2] as int;

      _log('Haiku exit code: $exitCode');

      if (exitCode != 0) {
        _log('Haiku error: $stderr');
        return null;
      }

      final text = stdout.trim();
      _log('Haiku response: ${_truncate(text, 200)}');

      // Filter out error messages that come through stdout
      if (text.isEmpty) return null;
      if (text.startsWith('Error:')) return null;
      if (text.contains('Reached max turns')) return null;
      if (text.contains('rate limit')) return null;
      if (text.contains('API error')) return null;

      return text;
    } on TimeoutException {
      _log('Haiku timed out');
      return null;
    } catch (e) {
      _log('Haiku error: $e');
      return null;
    }
  }

  /// Specialized invocation for list-based outputs (loading words, tips, etc.)
  static Future<List<String>?> invokeForList({
    required String systemPrompt,
    required String userMessage,
    String lineEnding = '...',
    int maxItems = 5,
    Duration delay = defaultDelay,
    Duration timeout = defaultTimeout,
  }) async {
    final result = await invoke(
      systemPrompt: systemPrompt,
      userMessage: userMessage,
      delay: delay,
      timeout: timeout,
    );

    if (result == null) return null;

    final lines = result
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) => line.endsWith(lineEnding) ? line : '$line$lineEnding')
        .take(maxItems)
        .toList();

    return lines.isEmpty ? null : lines;
  }

  static void _log(String message) {
    if (!enableLogging) return;

    final timestamp = DateTime.now().toIso8601String();
    final logLine = '[$timestamp] [HaikuService] $message\n';

    _logFile ??= File('/tmp/vide_haiku.log');
    _logFile!.writeAsStringSync(logLine, mode: FileMode.append);
  }

  static String _truncate(String s, int maxLength) {
    if (s.length <= maxLength) return s;
    return '${s.substring(0, maxLength)}...';
  }
}
