import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

import '../protocol/daemon_events.dart';
import '../protocol/daemon_messages.dart';
import 'daemon_starter.dart' show SessionSpawnConfig;
import 'session_process.dart';

/// Result of a health check for a session.
class HealthCheckResult {
  final String sessionId;
  final bool healthy;
  final String? error;

  HealthCheckResult({
    required this.sessionId,
    required this.healthy,
    this.error,
  });
}

/// Tracks all active session processes managed by the daemon.
class SessionRegistry {
  /// Active sessions by session ID.
  final Map<String, SessionProcess> _sessions = {};

  /// Path to state file for persistence.
  final String stateFilePath;

  /// Configuration for spawning session server processes.
  final SessionSpawnConfig spawnConfig;

  /// Event controller for broadcasting daemon events.
  final StreamController<DaemonEvent> _eventController =
      StreamController<DaemonEvent>.broadcast();

  /// Stream of daemon events.
  Stream<DaemonEvent> get events => _eventController.stream;

  /// Health check timer.
  Timer? _healthCheckTimer;

  final Logger _log = Logger('SessionRegistry');

  SessionRegistry({required this.stateFilePath, required this.spawnConfig});

  /// Get all active sessions.
  Iterable<SessionProcess> get sessions => _sessions.values;

  /// Get the number of active sessions.
  int get sessionCount => _sessions.length;

  /// Create a new session process.
  Future<SessionProcess> createSession({
    required String initialMessage,
    required String workingDirectory,
    String? permissionMode,
    String? team,
    List<Map<String, dynamic>>? attachments,
  }) async {
    _log.info('Creating session for workDir: $workingDirectory');

    final session = await SessionProcess.spawn(
      initialMessage: initialMessage,
      workingDirectory: workingDirectory,
      spawnConfig: spawnConfig,
      permissionMode: permissionMode,
      team: team,
      attachments: attachments,
    );

    // Set up event handlers
    session.onUnexpectedExit = (exitCode) {
      _handleSessionCrash(session.sessionId, exitCode);
    };

    session.onStateChanged = (state) {
      _eventController.add(
        SessionHealthEvent(sessionId: session.sessionId, state: state),
      );
    };

    _sessions[session.sessionId] = session;

    // Emit event
    _eventController.add(
      SessionCreatedEvent(
        sessionId: session.sessionId,
        workingDirectory: session.workingDirectory,
        wsUrl: session.wsUrl,
        httpUrl: session.httpUrl,
        port: session.port,
        createdAt: session.createdAt,
      ),
    );

    // Persist state
    await persist();

    _log.info('Session created: ${session.sessionId}');
    return session;
  }

  /// Resume a persisted session by spawning a new vide_server process.
  ///
  /// If the session is already running, returns the existing process.
  Future<SessionProcess> resumeSession({
    required String sessionId,
    required String workingDirectory,
  }) async {
    // Return existing session if already running.
    final existing = _sessions[sessionId];
    if (existing != null && existing.isAlive) {
      _log.info('Session $sessionId is already running');
      return existing;
    }

    _log.info('Resuming session $sessionId for workDir: $workingDirectory');

    final session = await SessionProcess.spawnForResume(
      sessionId: sessionId,
      workingDirectory: workingDirectory,
      spawnConfig: spawnConfig,
    );

    // Set up event handlers
    session.onUnexpectedExit = (exitCode) {
      _handleSessionCrash(session.sessionId, exitCode);
    };

    session.onStateChanged = (state) {
      _eventController.add(
        SessionHealthEvent(sessionId: session.sessionId, state: state),
      );
    };

    _sessions[session.sessionId] = session;

    // Emit event
    _eventController.add(
      SessionCreatedEvent(
        sessionId: session.sessionId,
        workingDirectory: session.workingDirectory,
        wsUrl: session.wsUrl,
        httpUrl: session.httpUrl,
        port: session.port,
        createdAt: session.createdAt,
      ),
    );

    // Persist state
    await persist();

    _log.info('Session resumed: ${session.sessionId}');
    return session;
  }

  /// List all active sessions.
  List<SessionSummary> listSessions() {
    return _sessions.values.map((s) => s.toSummary()).toList();
  }

  /// Get session by ID.
  SessionProcess? getSession(String sessionId) {
    return _sessions[sessionId];
  }

  /// Stop and remove a session.
  Future<void> stopSession(String sessionId) async {
    final session = _sessions[sessionId];
    if (session == null) {
      _log.warning('Session not found: $sessionId');
      return;
    }

    _log.info('Stopping session: $sessionId');
    await session.stop();
    _sessions.remove(sessionId);

    // Emit event
    _eventController.add(
      SessionStoppedEvent(sessionId: sessionId, reason: 'user-request'),
    );

    // Persist state
    await persist();
  }

  /// Force kill a session.
  Future<void> killSession(String sessionId) async {
    final session = _sessions[sessionId];
    if (session == null) {
      _log.warning('Session not found: $sessionId');
      return;
    }

    _log.info('Force killing session: $sessionId');
    await session.kill();
    _sessions.remove(sessionId);

    // Emit event
    _eventController.add(
      SessionStoppedEvent(sessionId: sessionId, reason: 'user-request'),
    );

    // Persist state
    await persist();
  }

  void _handleSessionCrash(String sessionId, int exitCode) {
    _log.warning('Session $sessionId crashed with exit code $exitCode');
    _sessions.remove(sessionId);

    // Emit event
    _eventController.add(
      SessionStoppedEvent(
        sessionId: sessionId,
        reason: 'crash',
        exitCode: exitCode,
      ),
    );

    // Persist state
    persist();
  }

  /// Restore sessions after daemon restart.
  ///
  /// Loads persisted state and checks which processes are still alive.
  Future<void> restore() async {
    _log.info('Restoring sessions from $stateFilePath');

    final file = File(stateFilePath);
    if (!file.existsSync()) {
      _log.info('No persisted state found');
      return;
    }

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final state = DaemonState.fromJson(json);

      _log.info('Found ${state.sessions.length} persisted sessions');

      for (final persistedSession in state.sessions) {
        final session = await SessionProcess.adopt(
          persistedState: persistedSession,
        );

        if (session != null) {
          _sessions[session.sessionId] = session;
          _log.info('Restored session: ${session.sessionId}');
        } else {
          _log.warning(
            'Could not restore session: ${persistedSession.sessionId}',
          );
        }
      }

      // Persist updated state (removes dead sessions)
      await persist();
    } catch (e, st) {
      _log.severe('Failed to restore sessions: $e', e, st);
    }
  }

  /// Persist current state.
  Future<void> persist() async {
    _log.fine('Persisting daemon state');

    final state = DaemonState(
      sessions: _sessions.values.map((s) => s.toPersistedState()).toList(),
      lastUpdated: DateTime.now(),
    );

    final file = File(stateFilePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(state.toJson()),
    );
  }

  /// Check health of all sessions.
  Future<List<HealthCheckResult>> checkHealth() async {
    final results = <HealthCheckResult>[];

    for (final session in _sessions.values) {
      try {
        final healthy = await session.healthCheck();
        results.add(
          HealthCheckResult(sessionId: session.sessionId, healthy: healthy),
        );

        if (!healthy) {
          _eventController.add(
            SessionHealthEvent(
              sessionId: session.sessionId,
              state: session.state,
              error: 'Health check failed',
            ),
          );
        }
      } catch (e) {
        results.add(
          HealthCheckResult(
            sessionId: session.sessionId,
            healthy: false,
            error: e.toString(),
          ),
        );
      }
    }

    return results;
  }

  /// Start periodic health checks.
  void startHealthChecks({Duration interval = const Duration(seconds: 30)}) {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(interval, (_) => checkHealth());
    _log.info('Health checks started with interval: $interval');
  }

  /// Stop periodic health checks.
  void stopHealthChecks() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
    _log.info('Health checks stopped');
  }

  /// Stop all sessions and clean up.
  Future<void> dispose() async {
    _log.info('Disposing session registry');
    stopHealthChecks();

    // Stop all sessions
    final futures = _sessions.values.map((s) => s.stop()).toList();
    await Future.wait(futures);

    _sessions.clear();
    await _eventController.close();
  }
}
