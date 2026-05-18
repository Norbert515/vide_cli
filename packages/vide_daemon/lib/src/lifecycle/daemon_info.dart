import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as path;

/// Information about a running daemon process.
///
/// Written to `~/.vide/daemon/daemon.json` on startup,
/// deleted on clean shutdown. Used by stop/status commands
/// to locate and communicate with the daemon.
class DaemonInfo {
  final int pid;
  final int port;
  final String host;
  final DateTime startedAt;
  final String? logFile;
  final String authToken;

  DaemonInfo({
    required this.pid,
    required this.port,
    required this.host,
    required this.startedAt,
    this.logFile,
    required this.authToken,
  });

  String get url => 'http://$host:$port';

  factory DaemonInfo.fromJson(Map<String, dynamic> json) {
    return DaemonInfo(
      pid: json['pid'] as int,
      port: json['port'] as int,
      host: json['host'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      logFile: json['log_file'] as String?,
      authToken: json['auth_token'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'pid': pid,
    'port': port,
    'host': host,
    'started_at': startedAt.toUtc().toIso8601String(),
    'log_file': logFile,
    'auth_token': authToken,
  };

  /// Default directory for daemon state: `~/.vide/daemon`.
  static String defaultStateDir() {
    final homeDir =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.current.path;
    return path.join(homeDir, '.vide', 'daemon');
  }

  /// Path to the daemon info file.
  static String filePath({String? stateDir}) {
    return path.join(stateDir ?? defaultStateDir(), 'daemon.json');
  }

  /// Path to the daemon log directory.
  static String logDir({String? stateDir}) {
    return path.join(stateDir ?? defaultStateDir(), 'logs');
  }

  /// Path to the daemon log file.
  static String logFilePath({String? stateDir}) {
    return path.join(logDir(stateDir: stateDir), 'daemon.log');
  }

  /// Read daemon info from disk. Returns null if not found or corrupt.
  static DaemonInfo? read({String? stateDir}) {
    final file = File(filePath(stateDir: stateDir));
    if (!file.existsSync()) return null;

    try {
      final contents = file.readAsStringSync();
      final json = jsonDecode(contents) as Map<String, dynamic>;
      return DaemonInfo.fromJson(json);
    } on FormatException {
      // Corrupt JSON (e.g., process crashed mid-write) — treat as absent
      file.deleteSync();
      return null;
    } on TypeError {
      // Unexpected JSON structure — treat as absent
      file.deleteSync();
      return null;
    }
  }

  /// Write daemon info to disk.
  static void write(DaemonInfo info, {String? stateDir}) {
    final file = File(filePath(stateDir: stateDir));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(info.toJson()),
    );
  }

  /// Delete daemon info from disk.
  static void delete({String? stateDir}) {
    final file = File(filePath(stateDir: stateDir));
    if (file.existsSync()) {
      file.deleteSync();
    }
  }

  /// Path to the persistent auth token file.
  ///
  /// This file survives daemon restarts (unlike daemon.json which is deleted
  /// on shutdown). The token is reused across restarts so that clients
  /// (mobile app, remote TUI) don't need to reconfigure after a restart.
  static String authTokenFilePath({String? stateDir}) {
    return path.join(stateDir ?? defaultStateDir(), 'auth-token');
  }

  /// Load or generate the auth token.
  ///
  /// Reads from the persistent `auth-token` file if it exists.
  /// Otherwise generates a new 32-byte hex token and persists it.
  static String loadOrGenerateAuthToken({String? stateDir}) {
    final file = File(authTokenFilePath(stateDir: stateDir));

    if (file.existsSync()) {
      final token = file.readAsStringSync().trim();
      if (token.isNotEmpty) return token;
    }

    final token = _generateToken();
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(token);
    return token;
  }

  /// Generate a cryptographically random 32-byte hex token.
  static String _generateToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
