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

  /// Path to vide_server entry point.
  /// Auto-detected if not specified.
  final String? videServerPath;

  /// Auth token for the daemon.
  /// If null and [generateToken] is false, no auth is required.
  final String? authToken;

  /// Generate a random auth token.
  final bool generateToken;

  /// Enable verbose logging.
  final bool verbose;

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
    this.onReady,
  });
}

/// Shared daemon startup logic.
///
/// Used by both `bin/vide.dart --serve` and `bin/vide_daemon.dart`.
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

    // Determine vide_server path
    final videServerPath = config.videServerPath ?? _findVideServerPath();
    _log.info('vide_server path: $videServerPath');

    // Handle auth token
    String? authToken = config.authToken;
    if (authToken == null && config.generateToken) {
      authToken = _generateToken();
    }

    // Create registry
    final registry = SessionRegistry(
      stateFilePath: stateFilePath,
      videServerPath: videServerPath,
    );

    // Restore any existing sessions
    await registry.restore();

    // Create and start server
    final server = DaemonServer(
      registry: registry,
      port: config.port,
      authToken: authToken,
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
    );

    // Invoke ready callback if provided
    config.onReady?.call('http://127.0.0.1:${config.port}', authToken);

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

  /// Find the vide_server entry point.
  ///
  /// Searches common locations relative to the current script.
  static String _findVideServerPath() {
    final log = Logger('VideDaemon');
    final scriptDir = path.dirname(Platform.script.toFilePath());

    final possiblePaths = [
      // Running from bin/ (e.g., dart run bin/vide.dart)
      path.join(
        scriptDir,
        '..',
        'packages',
        'vide_server',
        'bin',
        'vide_server.dart',
      ),
      // Running from packages/vide_daemon/bin/
      path.join(
        scriptDir,
        '..',
        '..',
        'vide_server',
        'bin',
        'vide_server.dart',
      ),
      // Running from packages/vide_daemon/
      path.join(scriptDir, '..', 'vide_server', 'bin', 'vide_server.dart'),
      // Running from repo root
      path.join(
        scriptDir,
        'packages',
        'vide_server',
        'bin',
        'vide_server.dart',
      ),
      // Running as compiled binary alongside packages
      path.join(scriptDir, 'packages', 'vide_server', 'bin', 'vide_server.dart'),
    ];

    for (final p in possiblePaths) {
      final normalized = path.normalize(p);
      if (File(normalized).existsSync()) {
        return normalized;
      }
    }

    // Fallback: use relative path and hope for the best
    log.warning(
      'Could not find vide_server, using fallback path: bin/vide_server.dart',
    );
    return 'bin/vide_server.dart';
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
  }) {
    final url = 'http://127.0.0.1:$port';
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
    print('║    WS     /daemon          - Real-time daemon events         ║');
    print('╚══════════════════════════════════════════════════════════════╝');
    print('');
    print('Server ready. Press Ctrl+C to stop.');
  }
}
