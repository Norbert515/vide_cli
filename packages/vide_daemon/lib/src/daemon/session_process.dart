import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../protocol/daemon_messages.dart';
import 'daemon_starter.dart' show SessionSpawnConfig;

/// Manages a single vide_server subprocess.
class SessionProcess {
  final String sessionId;
  final String mainAgentId;
  final String workingDirectory;
  final int port;
  final DateTime createdAt;
  final String initialMessage;
  final String? model;
  final String? permissionMode;
  final String? team;

  final Process _process;
  final Logger _log;

  /// Current process state.
  SessionProcessState _state = SessionProcessState.starting;
  SessionProcessState get state => _state;

  /// Connected client count (tracked by session process, not daemon).
  int connectedClients = 0;

  /// Callback invoked when the process exits unexpectedly.
  void Function(int exitCode)? onUnexpectedExit;

  /// Callback invoked when process state changes.
  void Function(SessionProcessState state)? onStateChanged;

  SessionProcess._({
    required this.sessionId,
    required this.mainAgentId,
    required this.workingDirectory,
    required this.port,
    required this.createdAt,
    required this.initialMessage,
    required Process process,
    this.model,
    this.permissionMode,
    this.team,
  }) : _process = process,
       _log = Logger('SessionProcess[$sessionId]') {
    _monitorProcess();
  }

  /// Check if the process is still running.
  bool get isAlive => _state == SessionProcessState.ready;

  /// Get the WebSocket URL for this session.
  String get wsUrl => 'ws://127.0.0.1:$port/api/v1/sessions/$sessionId/stream';

  /// Get the HTTP URL for this session.
  String get httpUrl => 'http://127.0.0.1:$port';

  /// Get the process ID.
  int get pid => _process.pid;

  /// Spawn a new vide_server process and create a session within it.
  ///
  /// Returns the SessionProcess once the session is created and ready.
  static Future<SessionProcess> spawn({
    required String initialMessage,
    required String workingDirectory,
    required SessionSpawnConfig spawnConfig,
    String? model,
    String? permissionMode,
    String? team,
    List<Map<String, dynamic>>? attachments,
    Duration startupTimeout = const Duration(seconds: 30),
  }) async {
    final log = Logger('SessionProcess.spawn');

    // Find an available port
    final serverSocket = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final port = serverSocket.port;
    await serverSocket.close();

    log.info(
      'Starting session server on port $port for workDir: $workingDirectory',
    );

    // Get spawn command from config
    final spawnCommand = spawnConfig.getSpawnCommand(
      port: port,
      workingDirectory: workingDirectory,
    );

    log.fine(
      'Spawn command: ${spawnCommand.executable} ${spawnCommand.args.join(' ')}',
    );

    // Start session server process
    final process = await Process.start(
      spawnCommand.executable,
      spawnCommand.args,
      workingDirectory: workingDirectory,
      environment: {
        ...Platform.environment,
        // Ensure the process knows its working directory
        'VIDE_WORKING_DIR': workingDirectory,
      },
    );

    // Log process output
    process.stdout.transform(utf8.decoder).listen((data) {
      log.fine('[stdout:$port] $data');
    });
    process.stderr.transform(utf8.decoder).listen((data) {
      log.warning('[stderr:$port] $data');
    });

    // Wait for server to be ready
    final client = http.Client();
    final healthUrl = Uri.parse('http://127.0.0.1:$port/health');
    final startTime = DateTime.now();

    while (DateTime.now().difference(startTime) < startupTimeout) {
      try {
        final response = await client
            .get(healthUrl)
            .timeout(const Duration(seconds: 2));
        if (response.statusCode == 200) {
          log.info('Server ready on port $port');
          break;
        }
      } catch (_) {
        // Server not ready yet
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Check if server is ready
    try {
      final response = await client
          .get(healthUrl)
          .timeout(const Duration(seconds: 2));
      if (response.statusCode != 200) {
        process.kill();
        throw StateError(
          'vide_server failed to start: health check returned ${response.statusCode}',
        );
      }
    } catch (e) {
      process.kill();
      throw StateError('vide_server failed to start: $e');
    }

    // Create session via REST API
    final createUrl = Uri.parse('http://127.0.0.1:$port/api/v1/sessions');
    final createBody = jsonEncode({
      'initial-message': initialMessage,
      'working-directory': workingDirectory,
      if (model != null) 'model': model,
      if (permissionMode != null) 'permission-mode': permissionMode,
      if (team != null) 'team': team,
      if (attachments != null && attachments.isNotEmpty)
        'attachments': attachments,
    });

    log.info('Creating session via POST $createUrl');
    final createResponse = await client.post(
      createUrl,
      headers: {'Content-Type': 'application/json'},
      body: createBody,
    );

    client.close();

    if (createResponse.statusCode != 200 && createResponse.statusCode != 201) {
      process.kill();
      throw StateError(
        'Failed to create session: ${createResponse.statusCode} ${createResponse.body}',
      );
    }

    final responseJson =
        jsonDecode(createResponse.body) as Map<String, dynamic>;
    final sessionId = responseJson['session-id'] as String;
    final mainAgentId = responseJson['main-agent-id'] as String;

    log.info('Session created: $sessionId with main agent: $mainAgentId');

    final sessionProcess = SessionProcess._(
      sessionId: sessionId,
      mainAgentId: mainAgentId,
      workingDirectory: workingDirectory,
      port: port,
      createdAt: DateTime.now(),
      initialMessage: initialMessage,
      process: process,
      model: model,
      permissionMode: permissionMode,
      team: team,
    );

    sessionProcess._setState(SessionProcessState.ready);

    return sessionProcess;
  }

  /// Spawn a new vide_server process and resume an existing session from
  /// persistence within it.
  ///
  /// Similar to [spawn], but instead of creating a new session it calls
  /// the vide_server resume endpoint to reload a persisted session.
  static Future<SessionProcess> spawnForResume({
    required String sessionId,
    required String workingDirectory,
    required SessionSpawnConfig spawnConfig,
    Duration startupTimeout = const Duration(seconds: 30),
  }) async {
    final log = Logger('SessionProcess.spawnForResume');

    // Find an available port
    final serverSocket = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final port = serverSocket.port;
    await serverSocket.close();

    log.info(
      'Starting session server on port $port to resume $sessionId '
      'for workDir: $workingDirectory',
    );

    // Get spawn command from config
    final spawnCommand = spawnConfig.getSpawnCommand(
      port: port,
      workingDirectory: workingDirectory,
    );

    log.fine(
      'Spawn command: ${spawnCommand.executable} ${spawnCommand.args.join(' ')}',
    );

    // Start session server process
    final process = await Process.start(
      spawnCommand.executable,
      spawnCommand.args,
      workingDirectory: workingDirectory,
      environment: {
        ...Platform.environment,
        'VIDE_WORKING_DIR': workingDirectory,
      },
    );

    // Log process output
    process.stdout.transform(utf8.decoder).listen((data) {
      log.fine('[stdout:$port] $data');
    });
    process.stderr.transform(utf8.decoder).listen((data) {
      log.warning('[stderr:$port] $data');
    });

    // Wait for server to be ready
    final client = http.Client();
    final healthUrl = Uri.parse('http://127.0.0.1:$port/health');
    final startTime = DateTime.now();

    while (DateTime.now().difference(startTime) < startupTimeout) {
      try {
        final response = await client
            .get(healthUrl)
            .timeout(const Duration(seconds: 2));
        if (response.statusCode == 200) {
          log.info('Server ready on port $port');
          break;
        }
      } catch (_) {
        // Server not ready yet
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Check if server is ready
    try {
      final response = await client
          .get(healthUrl)
          .timeout(const Duration(seconds: 2));
      if (response.statusCode != 200) {
        process.kill();
        throw StateError(
          'vide_server failed to start: health check returned ${response.statusCode}',
        );
      }
    } catch (e) {
      process.kill();
      throw StateError('vide_server failed to start: $e');
    }

    // Resume session via REST API
    final resumeUrl = Uri.parse(
      'http://127.0.0.1:$port/api/v1/sessions/$sessionId/resume',
    );
    final resumeBody = jsonEncode({'working-directory': workingDirectory});

    log.info('Resuming session via POST $resumeUrl');
    final resumeResponse = await client.post(
      resumeUrl,
      headers: {'Content-Type': 'application/json'},
      body: resumeBody,
    );

    client.close();

    if (resumeResponse.statusCode != 200 && resumeResponse.statusCode != 201) {
      process.kill();
      throw StateError(
        'Failed to resume session: ${resumeResponse.statusCode} ${resumeResponse.body}',
      );
    }

    final responseJson =
        jsonDecode(resumeResponse.body) as Map<String, dynamic>;
    final mainAgentId = responseJson['main-agent-id'] as String? ?? '';

    log.info('Session resumed: $sessionId with main agent: $mainAgentId');

    final sessionProcess = SessionProcess._(
      sessionId: sessionId,
      mainAgentId: mainAgentId,
      workingDirectory: workingDirectory,
      port: port,
      createdAt: DateTime.now(),
      initialMessage: '',
      process: process,
    );

    sessionProcess._setState(SessionProcessState.ready);

    return sessionProcess;
  }

  /// Adopt an existing vide_server process (for daemon restart recovery).
  ///
  /// Verifies the process is still alive and the session exists.
  static Future<SessionProcess?> adopt({
    required PersistedSessionState persistedState,
  }) async {
    final log = Logger('SessionProcess.adopt');
    final pid = persistedState.pid;
    final port = persistedState.port;

    // Check if process is still running
    try {
      final result = Process.runSync('kill', ['-0', pid.toString()]);
      if (result.exitCode != 0) {
        log.warning('Process $pid is not running');
        return null;
      }
    } catch (e) {
      log.warning('Failed to check process $pid: $e');
      return null;
    }

    // Check if server is responding
    final client = http.Client();
    try {
      final healthUrl = Uri.parse('http://127.0.0.1:$port/health');
      final response = await client
          .get(healthUrl)
          .timeout(const Duration(seconds: 2));
      if (response.statusCode != 200) {
        log.warning('Server on port $port is not healthy');
        return null;
      }
    } catch (e) {
      log.warning('Failed to reach server on port $port: $e');
      return null;
    } finally {
      client.close();
    }

    log.info('Adopted existing process $pid on port $port');

    // We don't have the actual Process object, so we can't monitor it directly.
    // This is a limitation of adopting existing processes - we'd need to spawn
    // a monitoring mechanism.
    //
    // For now, we return null to indicate we can't fully adopt.
    // A future improvement could use process supervision or polling.
    log.warning(
      'Process adoption not fully supported - process will not be monitored',
    );
    return null;
  }

  void _setState(SessionProcessState newState) {
    if (_state != newState) {
      _state = newState;
      onStateChanged?.call(newState);
    }
  }

  void _monitorProcess() {
    _process.exitCode.then((code) {
      _log.info('Process exited with code $code');
      if (_state != SessionProcessState.stopping) {
        _setState(SessionProcessState.error);
        onUnexpectedExit?.call(code);
      }
    });
  }

  /// Perform a health check on the session process.
  Future<bool> healthCheck() async {
    if (_state == SessionProcessState.stopping) {
      return false;
    }

    final client = http.Client();
    try {
      final response = await client
          .get(Uri.parse('$httpUrl/health'))
          .timeout(const Duration(seconds: 5));
      final healthy = response.statusCode == 200;
      if (!healthy && _state == SessionProcessState.ready) {
        _setState(SessionProcessState.error);
      }
      return healthy;
    } catch (e) {
      _log.warning('Health check failed: $e');
      if (_state == SessionProcessState.ready) {
        _setState(SessionProcessState.error);
      }
      return false;
    } finally {
      client.close();
    }
  }

  /// Gracefully stop the process.
  Future<void> stop() async {
    _log.info('Stopping session process');
    _setState(SessionProcessState.stopping);

    // Send SIGTERM for graceful shutdown
    _process.kill(ProcessSignal.sigterm);

    // Wait for process to exit (with timeout)
    try {
      await _process.exitCode.timeout(const Duration(seconds: 10));
    } catch (_) {
      // Force kill if it doesn't respond to SIGTERM
      _log.warning('Process did not respond to SIGTERM, sending SIGKILL');
      _process.kill(ProcessSignal.sigkill);
    }
  }

  /// Force kill the process immediately.
  Future<void> kill() async {
    _log.info('Force killing session process');
    _setState(SessionProcessState.stopping);

    _process.kill(ProcessSignal.sigkill);
    await _process.exitCode;
  }

  /// Create a summary for listing.
  SessionSummary toSummary() {
    return SessionSummary(
      sessionId: sessionId,
      workingDirectory: workingDirectory,
      createdAt: createdAt,
      state: state,
      connectedClients: connectedClients,
      port: port,
    );
  }

  /// Create detailed response.
  SessionDetailsResponse toDetails() {
    return SessionDetailsResponse(
      sessionId: sessionId,
      workingDirectory: workingDirectory,
      wsUrl: wsUrl,
      httpUrl: httpUrl,
      port: port,
      createdAt: createdAt,
      state: state,
      connectedClients: connectedClients,
      pid: pid,
    );
  }

  /// Create persisted state for daemon restart recovery.
  PersistedSessionState toPersistedState() {
    return PersistedSessionState(
      sessionId: sessionId,
      port: port,
      workingDirectory: workingDirectory,
      createdAt: createdAt,
      pid: pid,
      initialMessage: initialMessage,
      model: model,
      permissionMode: permissionMode,
      team: team,
    );
  }
}
