import 'dart:io';

import 'package:path/path.dart' as path;

/// Log level for structured logging.
enum LogLevel {
  debug,
  info,
  warn,
  error;

  String get label => switch (this) {
    LogLevel.debug => 'DEBUG',
    LogLevel.info => 'INFO ',
    LogLevel.warn => 'WARN ',
    LogLevel.error => 'ERROR',
  };
}

/// Global singleton logger for Vide.
///
/// Writes structured, timestamped logs to:
/// - A global `vide.log` file (all sessions)
/// - Per-session `sessions/{sessionId}.log` files
///
/// Uses [IOSink] for buffered, non-blocking writes that won't slow down
/// the event loop or interfere with TUI rendering.
///
/// Usage:
/// ```dart
/// // Initialize once at startup
/// VideLogger.init('/path/to/logs');
///
/// // Use anywhere
/// VideLogger.instance.info('MyComponent', 'Something happened');
/// VideLogger.instance.error('MyComponent', 'Failed: $e', sessionId: networkId);
/// ```
class VideLogger {
  VideLogger._(this._logDir) {
    _init();
  }

  /// Internal constructor for subclasses that skip initialization.
  VideLogger._noop() : _logDir = '';

  void _init() {
    // Ensure directories exist
    Directory(_logDir).createSync(recursive: true);
    Directory(path.join(_logDir, 'sessions')).createSync(recursive: true);

    // Open global log sink
    final globalFile = File(path.join(_logDir, 'vide.log'));
    _globalSink = globalFile.openWrite(mode: FileMode.append);

    // Clean up old session logs
    _cleanupOldLogs();
  }

  static VideLogger? _instance;

  /// Initialize the global logger. Call once at startup.
  ///
  /// [logDir] is typically `${configRoot}/logs` (e.g., `~/.vide/logs`).
  static void init(String logDir) {
    _instance?.dispose();
    _instance = VideLogger._(logDir);
  }

  /// Access the global logger instance.
  ///
  /// Returns a no-op logger if [init] hasn't been called yet,
  /// so callers never need null checks.
  static VideLogger get instance => _instance ?? _noopInstance;

  static final VideLogger _noopInstance = _NoOpVideLogger();

  final String _logDir;
  late final IOSink _globalSink;
  final Map<String, IOSink> _sessionSinks = {};

  /// Start logging for a session. Opens the session-specific log file.
  void startSession(String sessionId) {
    if (_sessionSinks.containsKey(sessionId)) return;
    final sessionFile = File(
      path.join(_logDir, 'sessions', '$sessionId.log'),
    );
    _sessionSinks[sessionId] = sessionFile.openWrite(mode: FileMode.append);
    info('VideLogger', 'Session started', sessionId: sessionId);
  }

  /// End logging for a session. Flushes and closes the session sink.
  void endSession(String sessionId) {
    final sink = _sessionSinks.remove(sessionId);
    if (sink != null) {
      info('VideLogger', 'Session ended', sessionId: sessionId);
      sink.flush().then((_) => sink.close()).ignore();
    }
  }

  /// Log a debug message.
  void debug(String component, String message, {String? sessionId}) {
    _log(LogLevel.debug, component, message, sessionId: sessionId);
  }

  /// Log an info message.
  void info(String component, String message, {String? sessionId}) {
    _log(LogLevel.info, component, message, sessionId: sessionId);
  }

  /// Log a warning message.
  void warn(String component, String message, {String? sessionId}) {
    _log(LogLevel.warn, component, message, sessionId: sessionId);
  }

  /// Log an error message.
  void error(String component, String message, {String? sessionId}) {
    _log(LogLevel.error, component, message, sessionId: sessionId);
  }

  void _log(
    LogLevel level,
    String component,
    String message, {
    String? sessionId,
  }) {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final sessionTag =
        sessionId != null ? ' [session:${_shortId(sessionId)}]' : '';
    final line = '$timestamp [${level.label}]$sessionTag [$component] $message';

    _globalSink.writeln(line);

    // Also write to session-specific log if active
    if (sessionId != null) {
      _sessionSinks[sessionId]?.writeln(line);
    }
  }

  /// Shorten UUIDs for readability (first 8 chars).
  String _shortId(String id) {
    return id.length > 8 ? id.substring(0, 8) : id;
  }

  /// Delete session log files older than 7 days.
  void _cleanupOldLogs() {
    try {
      final sessionsDir = Directory(path.join(_logDir, 'sessions'));
      if (!sessionsDir.existsSync()) return;

      final cutoff = DateTime.now().subtract(const Duration(days: 7));
      for (final entity in sessionsDir.listSync()) {
        if (entity is File && entity.path.endsWith('.log')) {
          final modified = entity.lastModifiedSync();
          if (modified.isBefore(cutoff)) {
            entity.deleteSync();
          }
        }
      }
    } catch (_) {
      // Don't let cleanup failures prevent logger initialization
    }
  }

  /// Flush and close all sinks.
  void dispose() {
    for (final sink in _sessionSinks.values) {
      sink.flush().then((_) => sink.close()).ignore();
    }
    _sessionSinks.clear();
    _globalSink.flush().then((_) => _globalSink.close()).ignore();
    if (_instance == this) {
      _instance = null;
    }
  }
}

/// No-op logger used before [VideLogger.init] is called.
/// Silently discards all log messages.
class _NoOpVideLogger extends VideLogger {
  _NoOpVideLogger() : super._noop();

  // Override the constructor side effects — no directories, no sinks
  @override
  void startSession(String sessionId) {}

  @override
  void endSession(String sessionId) {}

  @override
  void debug(String component, String message, {String? sessionId}) {}

  @override
  void info(String component, String message, {String? sessionId}) {}

  @override
  void warn(String component, String message, {String? sessionId}) {}

  @override
  void error(String component, String message, {String? sessionId}) {}

  @override
  void dispose() {}
}
