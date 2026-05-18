import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config/gemini_config.dart';
import '../protocol/gemini_event.dart';

/// Subprocess-per-turn transport for the Gemini CLI.
///
/// Unlike Codex CLI's persistent `app-server` subprocess, Gemini CLI has no
/// bidirectional stdin/stdout protocol. Each turn spawns a new process with
/// `gemini -p "..." --output-format stream-json`, streams JSONL events from
/// stdout, and exits when the turn completes.
///
/// Multi-turn sessions work via `--resume <session-id>` — Gemini CLI persists
/// session state on disk and reloads it for subsequent turns.
class GeminiTransport {
  Process? _activeProcess;
  bool _closed = false;

  /// Whether a turn is currently running.
  bool get isRunning => _activeProcess != null;

  /// Run a single turn: spawn `gemini -p "..." --output-format stream-json`,
  /// stream [GeminiEvent]s parsed from stdout JSONL, and complete when the
  /// process exits.
  ///
  /// The returned stream emits parsed events and closes when the subprocess
  /// finishes. Non-JSON lines from stdout are silently skipped.
  Stream<GeminiEvent> runTurn({
    required String prompt,
    required GeminiConfig config,
  }) async* {
    if (_closed) throw StateError('Transport has been closed');
    if (_activeProcess != null) {
      throw StateError('A turn is already in progress');
    }

    final args = config.toCliArgs(prompt);

    final environment = <String, String>{
      ...Platform.environment,
      if (config.apiKey != null) 'GEMINI_API_KEY': config.apiKey!,
    };

    _activeProcess = await Process.start(
      'gemini',
      args,
      workingDirectory: config.workingDirectory,
      environment: environment,
    );

    // Collect stderr for error diagnostics
    final stderrBuffer = StringBuffer();
    _activeProcess!.stderr.transform(utf8.decoder).listen((chunk) {
      stderrBuffer.write(chunk);
    });

    // Parse stdout line-by-line as JSONL
    final lineBuffer = StringBuffer();

    await for (final chunk in _activeProcess!.stdout.transform(utf8.decoder)) {
      lineBuffer.write(chunk);
      final content = lineBuffer.toString();
      final lines = content.split('\n');

      // Keep the last potentially incomplete line in the buffer
      lineBuffer.clear();
      if (!content.endsWith('\n') && lines.isNotEmpty) {
        lineBuffer.write(lines.removeLast());
      } else if (lines.isNotEmpty && lines.last.isEmpty) {
        lines.removeLast();
      }

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        try {
          final json = jsonDecode(trimmed) as Map<String, dynamic>;
          yield GeminiEvent.fromJson(json);
        } on FormatException {
          // Skip non-JSON lines (e.g. startup messages)
          continue;
        }
      }
    }

    // Wait for process to fully exit
    final exitCode = await _activeProcess!.exitCode;
    _activeProcess = null;

    if (exitCode != 0 && stderrBuffer.isNotEmpty) {
      yield GeminiErrorEvent(
        severity: 'error',
        message: 'Gemini CLI exited with code $exitCode: $stderrBuffer',
        timestamp: DateTime.now(),
      );
    }
  }

  /// Kill the active process (for abort).
  void kill() {
    _activeProcess?.kill(ProcessSignal.sigterm);
    _activeProcess = null;
  }

  /// Close the transport permanently.
  void close() {
    if (_closed) return;
    _closed = true;
    kill();
  }
}
