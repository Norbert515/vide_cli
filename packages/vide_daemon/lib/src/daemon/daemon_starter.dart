import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import 'daemon_server.dart';
import 'session_registry.dart';

/// Configuration for starting a daemon server.
class DaemonConfig {
  /// Port to listen on.
  final int port;

  /// Directory for daemon state (sessions, etc.).
  /// Defaults to ~/.vide/daemon if not specified.
  final String? stateDir;

  /// Path to vide_server entry point (for source mode).
  /// Auto-detected if not specified.
  final String? videServerPath;

  /// Auth token for the daemon.
  /// If null and [generateToken] is false, no auth is required.
  final String? authToken;

  /// Generate a random auth token.
  final bool generateToken;

  /// Enable verbose logging.
  final bool verbose;

  /// IP address to bind to.
  /// Defaults to '127.0.0.1' (localhost only).
  /// Use '0.0.0.0' for all interfaces, or a specific IP (e.g., Tailscale).
  /// WARNING: When binding to non-localhost, use authentication.
  final String bindAddress;

  /// Callback invoked when server is ready.
  /// Receives the server URL and optional auth token.
  final void Function(String url, String? token)? onReady;

  DaemonConfig({
    required this.port,
    this.stateDir,
    this.videServerPath,
    this.authToken,
    this.generateToken = false,
    this.verbose = false,
    this.bindAddress = '127.0.0.1',
    this.onReady,
  });
}

/// Describes how to spawn session server processes.
///
/// This captures the executable and base arguments needed to start
/// a session server. The spawn command works both when running from
/// source (`dart run bin/vide.dart`) and when compiled (`./vide`).
class SessionSpawnConfig {
  /// The executable to run (e.g., 'dart' or '/path/to/vide').
  final String executable;

  /// Base arguments before the session-server subcommand (e.g., ['run', 'bin/vide.dart']).
  /// Empty for compiled binaries.
  final List<String> baseArgs;

  const SessionSpawnConfig({required this.executable, required this.baseArgs});

  /// Whether this is a compiled binary (no baseArgs means compiled).
  bool get isCompiled => baseArgs.isEmpty;

  /// Get the full command to spawn a session server on a given port.
  ({String executable, List<String> args}) getSpawnCommand({
    required int port,
    required String workingDirectory,
  }) {
    return (
      executable: executable,
      args: [
        ...baseArgs,
        'session-server',
        '--port',
        port.toString(),
        '--working-dir',
        workingDirectory,
      ],
    );
  }

  @override
  String toString() {
    if (isCompiled) {
      return 'SessionSpawnConfig(compiled: $executable)';
    }
    return 'SessionSpawnConfig(source: $executable ${baseArgs.join(' ')})';
  }
}

/// Shared daemon startup logic.
///
/// Used by both `vide serve` and `bin/vide_daemon.dart`.
class DaemonStarter {
  final DaemonConfig config;
  final Logger _log = Logger('VideDaemon');

  DaemonServer? _server;
  SessionRegistry? _registry;

  DaemonStarter(this.config);

  /// Start the daemon server.
  ///
  /// This method sets up logging, creates the session registry,
  /// starts the HTTP server, and returns. The caller is responsible
  /// for keeping the process alive (e.g., with signal handlers).
  ///
  /// Returns the running [DaemonServer] and [SessionRegistry].
  Future<({DaemonServer server, SessionRegistry registry})> start() async {
    // Set up logging
    Logger.root.level = config.verbose ? Level.ALL : Level.INFO;
    Logger.root.onRecord.listen((record) {
      final time = record.time.toIso8601String().substring(11, 23);
      print(
        '[$time] ${record.level.name.padRight(7)} ${record.loggerName}: ${record.message}',
      );
      if (record.error != null) print('  Error: ${record.error}');
      if (record.stackTrace != null && config.verbose) {
        print('  Stack: ${record.stackTrace}');
      }
    });

    // Determine state directory
    final stateDir = config.stateDir ?? _defaultStateDir();
    final stateFilePath = path.join(stateDir, 'state.json');

    // Ensure state directory exists
    await Directory(stateDir).create(recursive: true);

    // Determine how to spawn session servers
    final spawnConfig = _determineSpawnConfig(config.videServerPath);
    _log.info('Session spawn config: $spawnConfig');

    // Handle auth token
    String? authToken = config.authToken;
    if (authToken == null && config.generateToken) {
      authToken = _generateToken();
    }

    // Create registry
    final registry = SessionRegistry(
      stateFilePath: stateFilePath,
      spawnConfig: spawnConfig,
    );

    // Restore any existing sessions
    await registry.restore();

    // Create and start server
    final server = DaemonServer(
      registry: registry,
      port: config.port,
      authToken: authToken,
      bindAddress: config.bindAddress,
    );

    await server.start();

    // Start health checks
    registry.startHealthChecks();

    // Print startup banner
    _printBanner(
      port: config.port,
      stateDir: stateDir,
      authToken: authToken,
      sessionCount: registry.sessionCount,
      bindAddress: config.bindAddress,
    );

    // Invoke ready callback if provided
    config.onReady?.call(
      'http://${config.bindAddress}:${config.port}',
      authToken,
    );

    _server = server;
    _registry = registry;

    return (server: server, registry: registry);
  }

  /// Stop the daemon server and clean up resources.
  Future<void> stop() async {
    _log.info('Shutting down...');
    await _server?.stop();
    await _registry?.dispose();
    _log.info('Goodbye!');
  }

  /// Set up signal handlers for graceful shutdown.
  ///
  /// Call this after [start] to handle SIGINT and SIGTERM.
  void setupSignalHandlers() {
    ProcessSignal.sigint.watch().listen((_) async {
      print('');
      await stop();
      exit(0);
    });

    ProcessSignal.sigterm.watch().listen((_) async {
      await stop();
      exit(0);
    });
  }

  /// Get the default state directory (~/.vide/daemon).
  static String _defaultStateDir() {
    final homeDir =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.current.path;
    return path.join(homeDir, '.vide', 'daemon');
  }

  /// Determine how to spawn session server processes.
  ///
  /// When running from source (via `dart run`), we need to use:
  ///   dart run <script-path> session-server ...
  ///
  /// When running as a compiled binary, we use:
  ///   <binary-path> session-server ...
  static SessionSpawnConfig _determineSpawnConfig(String? overridePath) {
    final log = Logger('VideDaemon');

    // Check if we're running as a compiled binary
    final executableName = path.basename(Platform.resolvedExecutable);
    final isCompiled = executableName != 'dart' && executableName != 'dart.exe';

    if (isCompiled) {
      // Compiled binary - spawn using the same binary with session-server subcommand
      log.fine('Running as compiled binary');
      return SessionSpawnConfig(
        executable: Platform.resolvedExecutable,
        baseArgs: const [],
      );
    }

    // Running from source - need to find the script path
    // Platform.script gives us the URI to the current script
    final scriptPath = Platform.script.toFilePath();
    final absoluteScriptPath = path.absolute(scriptPath);

    log.fine('Running from source, script: $absoluteScriptPath');

    return SessionSpawnConfig(
      executable: Platform.resolvedExecutable, // 'dart'
      baseArgs: ['run', absoluteScriptPath],
    );
  }

  /// Generate a random 32-character auth token.
  static String _generateToken() {
    final random = Random.secure();
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Print the startup banner.
  void _printBanner({
    required int port,
    required String stateDir,
    required String? authToken,
    required int sessionCount,
    required String bindAddress,
  }) {
    final url = 'http://$bindAddress:$port';
    print('');
    print('╔══════════════════════════════════════════════════════════════╗');
    print('║                        Vide Daemon                           ║');
    print('╠══════════════════════════════════════════════════════════════╣');
    print('║  URL: ${url.padRight(54)}║');
    print('║  State: ${stateDir.padRight(52)}║');
    if (authToken != null) {
      print('║  Token: ${authToken.padRight(52)}║');
    } else {
      print('║  Auth: none (localhost only)                                ║');
    }
    print('║  Sessions: ${sessionCount.toString().padRight(49)}║');
    print('╠══════════════════════════════════════════════════════════════╣');
    print('║  Endpoints:                                                  ║');
    print('║    POST   /sessions        - Create new session              ║');
    print('║    GET    /sessions        - List all sessions               ║');
    print('║    GET    /sessions/:id    - Get session details             ║');
    print('║    DELETE /sessions/:id    - Stop a session                  ║');
    print('║    WS     /sessions/:id/stream - Session event stream        ║');
    print('║    WS     /daemon          - Real-time daemon events         ║');
    print('╚══════════════════════════════════════════════════════════════╝');
    print('');
    print('Server ready. Press Ctrl+C to stop.');
  }
}
