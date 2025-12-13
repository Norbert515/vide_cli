import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:sentry/sentry.dart';

/// Sentry DSN for hook handler (runs as separate process)
const String _sentryDsn =
    'https://72bde1285798c1a0ec98c770c65cad3a@o4510511934275584.ingest.de.sentry.io/4510511935717456';

/// Initialize Sentry for hook handler
Future<void> _initSentryForHook() async {
  await Sentry.init((options) {
    options.dsn = _sentryDsn;
    options.environment =
        const String.fromEnvironment('SENTRY_ENV', defaultValue: 'development');
  });
}

/// Runs the Vide CLI hook handler.
///
/// This reads hook input from stdin, checks for a running Vide CLI instance,
/// and makes an HTTP request to get permission decisions.
///
/// Exit codes:
/// - 0: Allow the operation
/// - 2: Deny/block the operation
Future<void> runHook() async {
  try {
    // Initialize Sentry early (non-blocking, errors will still work if this fails)
    unawaited(_initSentryForHook());

    // Read hook input from stdin
    final stdinContent =
        stdin.hasTerminal ? '' : await utf8.decoder.bind(stdin).join();

    if (stdinContent.isEmpty) {
      _outputAllow('No input from stdin, allowing operation');
      exit(0);
    }

    final hookInput = jsonDecode(stdinContent) as Map<String, dynamic>;

    // Extract session ID and tool name
    final sessionId = hookInput['session_id'] as String?;
    final toolName = hookInput['tool_name'] as String?;

    if (sessionId == null) {
      _outputAllow('No session_id in hook input, allowing operation');
      exit(0);
    }

    // Read port file
    final portFile =
        File('${Directory.systemTemp.path}/vide_hook_port_$sessionId');
    if (!await portFile.exists()) {
      // Vide CLI not running - allow the operation (graceful degradation)
      _outputAllow('Vide CLI not running for this session, allowing operation');
      exit(0);
    }

    final portString = await portFile.readAsString();
    final port = int.tryParse(portString.trim());
    if (port == null) {
      _outputAllow('Invalid port in port file, allowing operation');
      exit(0);
    }

    // Check permission mode file
    final modeFile =
        File('${Directory.systemTemp.path}/vide_hook_mode_$sessionId');
    String? permissionMode;
    if (await modeFile.exists()) {
      permissionMode = (await modeFile.readAsString()).trim();
    }

    // Auto-approve Edit/Write operations in acceptEdits mode
    if (permissionMode == 'acceptEdits') {
      if (toolName == 'Edit' || toolName == 'Write') {
        _outputAllow('Auto-approved: $toolName operation in acceptEdits mode');
        exit(0);
      }
    }

    // Auto-approve Read operations inside working directory
    if (toolName == 'Read') {
      final toolInput = hookInput['tool_input'] as Map<String, dynamic>?;
      final filePath = toolInput?['file_path'] as String?;
      final cwd = hookInput['cwd'] as String?;

      if (filePath != null && cwd != null) {
        // Normalize paths by resolving to absolute paths
        final normalizedFilePath =
            filePath.startsWith('/') ? filePath : '$cwd/$filePath';

        // Check if the file is inside the working directory
        if (normalizedFilePath.startsWith(cwd)) {
          _outputAllow('Auto-approved: Read operation inside working directory');
          exit(0);
        }
      }
    }

    // Validate process is alive
    final pidFile =
        File('${Directory.systemTemp.path}/vide_hook_pid_$sessionId');
    if (await pidFile.exists()) {
      final pidString = await pidFile.readAsString();
      final pid = int.tryParse(pidString.trim());
      if (pid != null && !await _isProcessAlive(pid)) {
        // Process is dead, allow operation and clean up stale files
        _outputAllow('Vide CLI process has stopped, allowing operation');
        await portFile.delete().catchError((_) => portFile);
        await pidFile.delete().catchError((_) => pidFile);
        exit(0);
      }
    }

    // Make HTTP request to Vide CLI
    final client = HttpClient();
    try {
      final request =
          await client.postUrl(Uri.parse('http://localhost:$port/permission'));
      request.headers.contentType = ContentType.json;
      request.write(stdinContent);

      final response = await request.close();

      final responseBody = await utf8.decoder.bind(response).join();
      final responseData = jsonDecode(responseBody) as Map<String, dynamic>;
      final decision = responseData['decision'] as String;
      final reason = responseData['reason'] as String? ?? '';

      // Output Claude Code format
      final output = {
        'hookSpecificOutput': {
          'hookEventName': 'PreToolUse',
          'permissionDecision': decision,
          'permissionDecisionReason': reason,
        },
      };

      stdout.writeln(jsonEncode(output));

      // IMPORTANT: Exit with code 2 to actually block the tool when denied
      // Exit code 0 = allow, Exit code 2 = deny/block
      if (decision == 'deny') {
        stderr.writeln('BLOCKED: $reason');
        exit(2);
      }
    } finally {
      client.close();
    }
  } catch (e, stackTrace) {
    // Report error to Sentry, but still allow the operation to proceed
    // This ensures hook failures don't block the user's workflow
    try {
      await Sentry.captureException(e, stackTrace: stackTrace);
    } catch (_) {
      // Ignore Sentry errors - don't let monitoring break the app
    }

    _outputAllow('Error in hook: $e, allowing operation');
  }

  exit(0);
}

void _outputAllow(String reason) {
  final output = {
    'hookSpecificOutput': {
      'hookEventName': 'PreToolUse',
      'permissionDecision': 'allow',
      'permissionDecisionReason': reason,
    },
  };
  stdout.writeln(jsonEncode(output));
}

Future<bool> _isProcessAlive(int pid) async {
  try {
    if (Platform.isWindows) {
      final result = await Process.run('tasklist', ['/FI', 'PID eq $pid']);
      return result.stdout.toString().contains(pid.toString());
    } else {
      final result = await Process.run('kill', ['-0', pid.toString()]);
      return result.exitCode == 0;
    }
  } catch (e) {
    return false;
  }
}
