import 'dart:convert';
import 'dart:io';

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

  DaemonInfo({
    required this.pid,
    required this.port,
    required this.host,
    required this.startedAt,
    this.logFile,
  });

  String get url => 'http://$host:$port';

  factory DaemonInfo.fromJson(Map<String, dynamic> json) {
    return DaemonInfo(
      pid: json['pid'] as int,
      port: json['port'] as int,
      host: json['host'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      logFile: json['log_file'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'pid': pid,
    'port': port,
    'host': host,
    'started_at': startedAt.toUtc().toIso8601String(),
    'log_file': logFile,
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

  /// Read daemon info from disk. Returns null if not found.
  static DaemonInfo? read({String? stateDir}) {
    final file = File(filePath(stateDir: stateDir));
    if (!file.existsSync()) return null;

    final contents = file.readAsStringSync();
    final json = jsonDecode(contents) as Map<String, dynamic>;
    return DaemonInfo.fromJson(json);
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
}
