import 'dart:io';

import 'package:path/path.dart' as p;

import '../client/daemon_client.dart';
import 'daemon_info.dart';

/// Result of a daemon status check.
class DaemonStatus {
  final bool isRunning;
  final DaemonInfo? info;
  final int? sessionCount;
  final int? uptimeSeconds;

  DaemonStatus({
    required this.isRunning,
    this.info,
    this.sessionCount,
    this.uptimeSeconds,
  });
}

/// Manages daemon process lifecycle: start (detached), stop, and status.
class DaemonLifecycle {
  final String? stateDir;

  DaemonLifecycle({this.stateDir});

  /// Check if a daemon is currently running.
  ///
  /// Reads the info file and verifies the PID is alive.
  /// Cleans up stale info files automatically.
  bool isRunning() {
    final info = DaemonInfo.read(stateDir: stateDir);
    if (info == null) return false;

    if (!_isProcessAlive(info.pid)) {
      // Stale info file — process died without cleanup
      DaemonInfo.delete(stateDir: stateDir);
      return false;
    }

    return true;
  }

  /// Start the daemon as a detached background process.
  ///
  /// Spawns a new `vide daemon start` process in detached mode,
  /// then polls the health endpoint to confirm it started successfully.
  ///
  /// Returns the [DaemonInfo] of the started daemon.
  Future<DaemonInfo> startDetached({
    required int port,
    required String host,
    bool verbose = false,
    bool dangerouslySkipPermissions = false,
  }) async {
    if (isRunning()) {
      final info = DaemonInfo.read(stateDir: stateDir)!;
      throw DaemonAlreadyRunningException(info);
    }

    // Ensure log directory exists
    final logDirPath = DaemonInfo.logDir(stateDir: stateDir);
    await Directory(logDirPath).create(recursive: true);

    final logPath = DaemonInfo.logFilePath(stateDir: stateDir);

    // Build the command args for the daemon process.
    // When running from source (dart run bin/vide.dart), Platform.resolvedExecutable
    // is 'dart' and we need to include 'run <script>' before our subcommand.
    // When compiled, Platform.resolvedExecutable is the vide binary itself.
    final executableName = p.basename(Platform.resolvedExecutable);
    final isCompiled = executableName != 'dart' && executableName != 'dart.exe';

    final daemonArgs = [
      Platform.resolvedExecutable,
      if (!isCompiled) ...['run', p.absolute(Platform.script.toFilePath())],
      'daemon',
      'start',
      '--port',
      port.toString(),
      '--host',
      host,
      if (stateDir != null) ...['--state-dir', stateDir!],
      if (verbose) '--verbose',
      if (dangerouslySkipPermissions) '--dangerously-skip-permissions',
    ];

    // Use shell redirection to capture stdout/stderr to log file.
    // ProcessStartMode.detached doesn't expose stdio, so we use
    // a shell wrapper to redirect output before detaching.
    final shellCommand = '${daemonArgs.map(shellEscape).join(' ')} '
        '>> ${shellEscape(logPath)} 2>&1';

    await Process.start(
      '/bin/sh',
      ['-c', shellCommand],
      mode: ProcessStartMode.detached,
    );

    // Poll health endpoint to confirm startup
    final client = DaemonClient(host: host, port: port);
    try {
      final started = await _waitForHealthy(
        client,
        timeout: const Duration(seconds: 15),
      );
      if (!started) {
        throw DaemonStartFailedException(
          'Daemon process spawned but health check failed. '
          'Check logs at: $logPath',
        );
      }
    } finally {
      client.close();
    }

    // Read the info file that the daemon process wrote
    final info = DaemonInfo.read(stateDir: stateDir);
    if (info == null) {
      throw DaemonStartFailedException(
        'Daemon process started but did not write info file. '
        'Check logs at: $logPath',
      );
    }

    return info;
  }

  /// Stop the running daemon.
  ///
  /// Sends SIGTERM (or SIGKILL if [force] is true) and waits for
  /// the process to exit.
  Future<void> stop({bool force = false}) async {
    final info = DaemonInfo.read(stateDir: stateDir);
    if (info == null) {
      throw DaemonNotRunningException();
    }

    if (!_isProcessAlive(info.pid)) {
      // Process already dead — clean up stale info file
      DaemonInfo.delete(stateDir: stateDir);
      throw DaemonNotRunningException();
    }

    // Send signal
    final signal = force ? ProcessSignal.sigkill : ProcessSignal.sigterm;
    Process.killPid(info.pid, signal);

    // Wait for process to die
    final died = await _waitForProcessDeath(
      info.pid,
      timeout: Duration(seconds: force ? 2 : 5),
    );

    if (!died) {
      if (!force) {
        // Escalate to SIGKILL
        Process.killPid(info.pid, ProcessSignal.sigkill);
        await _waitForProcessDeath(
          info.pid,
          timeout: const Duration(seconds: 2),
        );
      }
    }

    // Clean up info file if process is gone
    if (!_isProcessAlive(info.pid)) {
      DaemonInfo.delete(stateDir: stateDir);
    }
  }

  /// Get the current daemon status with health information.
  Future<DaemonStatus> status() async {
    final info = DaemonInfo.read(stateDir: stateDir);
    if (info == null) {
      return DaemonStatus(isRunning: false);
    }

    if (!_isProcessAlive(info.pid)) {
      DaemonInfo.delete(stateDir: stateDir);
      return DaemonStatus(isRunning: false);
    }

    // Query health endpoint for live data
    final client = DaemonClient(host: info.host, port: info.port);
    try {
      final health = await client.getHealth();
      return DaemonStatus(
        isRunning: true,
        info: info,
        sessionCount: health['session-count'] as int?,
        uptimeSeconds: health['uptime-seconds'] as int?,
      );
    } on DaemonClientException {
      // Process alive but not responding — still report as running
      return DaemonStatus(isRunning: true, info: info);
    } catch (_) {
      return DaemonStatus(isRunning: true, info: info);
    } finally {
      client.close();
    }
  }

  /// Check if a process is alive.
  ///
  /// Uses `kill -0` via a shell command, which checks process existence
  /// without sending any actual signal (unlike SIGCONT which would
  /// resume a stopped process as a side effect).
  static bool _isProcessAlive(int pid) {
    try {
      final result = Process.runSync('kill', ['-0', pid.toString()]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Poll the health endpoint until it responds or timeout.
  Future<bool> _waitForHealthy(
    DaemonClient client, {
    required Duration timeout,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await client.isHealthy()) return true;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return false;
  }

  /// Wait for a process to die.
  Future<bool> _waitForProcessDeath(
    int pid, {
    required Duration timeout,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (!_isProcessAlive(pid)) return true;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    return !_isProcessAlive(pid);
  }

  /// Escape a string for safe use in a shell command.
  ///
  /// Uses single-quoting to prevent shell interpretation of special
  /// characters ($, `, !, etc.). Single quotes within the string are
  /// escaped using the '\'' pattern.
  ///
  /// Visible for testing.
  static String shellEscape(String s) {
    if (s.isEmpty) return "''";
    // If the string is simple (alphanumeric, dashes, dots, slashes), no quoting needed
    if (RegExp(r'^[a-zA-Z0-9._/:-]+$').hasMatch(s)) return s;
    // Otherwise, wrap in single quotes and escape any single quotes within
    return "'${s.replaceAll("'", r"'\''")}'";
  }
}

/// Thrown when trying to start a daemon that is already running.
class DaemonAlreadyRunningException implements Exception {
  final DaemonInfo info;
  DaemonAlreadyRunningException(this.info);

  @override
  String toString() =>
      'Daemon is already running (PID ${info.pid}) at ${info.url}';
}

/// Thrown when trying to stop a daemon that is not running.
class DaemonNotRunningException implements Exception {
  @override
  String toString() => 'Daemon is not running';
}

/// Thrown when a detached daemon fails to start.
class DaemonStartFailedException implements Exception {
  final String message;
  DaemonStartFailedException(this.message);

  @override
  String toString() => 'Failed to start daemon: $message';
}
