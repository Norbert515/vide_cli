import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import '../lifecycle/daemon_info.dart';
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

  /// Enable verbose logging.
  final bool verbose;

  /// IP address to bind to.
  /// Defaults to '127.0.0.1' (localhost only).
  /// Use '0.0.0.0' for all interfaces, or a specific IP (e.g., Tailscale).
  final String bindAddress;

  /// Whether to skip all permission checks for spawned sessions.
  ///
  /// DANGEROUS: Only for sandboxed environments (Docker, VMs) where
  /// filesystem isolation protects the host system.
  final bool dangerouslySkipPermissions;

  /// Whether to skip interactive confirmation prompts (e.g., 0.0.0.0 binding).
  /// Required for non-interactive environments (Docker, CI).
  final bool skipConfirmation;

  /// Callback invoked when server is ready.
  /// Receives the server URL.
  final void Function(String url)? onReady;

  DaemonConfig({
    required this.port,
    this.stateDir,
    this.videServerPath,
    this.verbose = false,
    this.bindAddress = '127.0.0.1',
    this.dangerouslySkipPermissions = false,
    this.skipConfirmation = false,
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
/// Used by `vide daemon start` and `bin/vide_daemon.dart`.
class DaemonStarter {
  final DaemonConfig config;
  final Logger _log = Logger('VideDaemon');

  DaemonServer? _server;
  SessionRegistry? _registry;
  bool _shuttingDown = false;

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

    // Check bind address and warn if dangerous
    await _checkBindAddress(config.bindAddress, config.skipConfirmation);

    if (config.dangerouslySkipPermissions) {
      _log.warning(
        'dangerously-skip-permissions is enabled — '
        'all sessions will auto-approve every tool call',
      );
    }

    // Determine state directory
    final stateDir = config.stateDir ?? _defaultStateDir();
    final stateFilePath = path.join(stateDir, 'state.json');

    // Ensure state directory exists
    await Directory(stateDir).create(recursive: true);

    // Determine how to spawn session servers
    final spawnConfig = _determineSpawnConfig(config.videServerPath);
    _log.info('Session spawn config: $spawnConfig');

    // Create registry
    final registry = SessionRegistry(
      stateFilePath: stateFilePath,
      spawnConfig: spawnConfig,
      dangerouslySkipPermissions: config.dangerouslySkipPermissions,
    );

    // Restore any existing sessions
    await registry.restore();

    // Load or generate a persistent auth token.
    // The token file survives daemon restarts so remote clients
    // (mobile app, SSH tunnels) don't need to reconfigure.
    final authToken = DaemonInfo.loadOrGenerateAuthToken(stateDir: stateDir);
    _log.info('Auth token loaded (persistent across restarts)');

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
      sessionCount: registry.sessionCount,
      bindAddress: config.bindAddress,
      authToken: authToken,
    );

    // Invoke ready callback if provided
    config.onReady?.call('http://${config.bindAddress}:${config.port}');

    _server = server;
    _registry = registry;

    // Write daemon info file for lifecycle management (stop/status)
    DaemonInfo.write(
      DaemonInfo(
        pid: pid,
        port: config.port,
        host: config.bindAddress,
        startedAt: DateTime.now().toUtc(),
        logFile: DaemonInfo.logFilePath(stateDir: stateDir),
        authToken: authToken,
      ),
      stateDir: stateDir,
    );

    return (server: server, registry: registry);
  }

  /// Stop the daemon server and clean up resources.
  Future<void> stop() async {
    if (_shuttingDown) return;
    _shuttingDown = true;

    _log.info('Shutting down...');
    await _server?.stop();
    await _registry?.dispose();

    // Remove daemon info file
    final stateDir = config.stateDir ?? _defaultStateDir();
    DaemonInfo.delete(stateDir: stateDir);

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

  /// Print the startup banner.
  void _printBanner({
    required int port,
    required String stateDir,
    required int sessionCount,
    required String bindAddress,
    required String authToken,
  }) {
    final url = 'http://$bindAddress:$port';
    print('');
    print('╔══════════════════════════════════════════════════════════════╗');
    print('║                        Vide Daemon                           ║');
    print('╠══════════════════════════════════════════════════════════════╣');
    print('║  URL: ${url.padRight(54)}║');
    print('║  State: ${stateDir.padRight(52)}║');
    print('║  Sessions: ${sessionCount.toString().padRight(49)}║');
    print('╠══════════════════════════════════════════════════════════════╣');
    print('║  Auth: Bearer token required (except /health)               ║');
    print('║  Token: ${authToken.substring(0, 16)}...${' '.padRight(37)}║');
    print('╠══════════════════════════════════════════════════════════════╣');
    print('║  Endpoints:                                                  ║');
    print('║    POST   /sessions        - Create new session              ║');
    print('║    GET    /sessions        - List all sessions               ║');
    print('║    GET    /sessions/:id    - Get session details             ║');
    print('║    DELETE /sessions/:id    - Stop a session                  ║');
    print('║    WS     /sessions/:id/stream - Session event stream        ║');
    print('║    WS     /daemon          - Real-time daemon events         ║');
    print('╠══════════════════════════════════════════════════════════════╣');
    _printSecurityNotice(bindAddress);
    if (config.dangerouslySkipPermissions) {
      print('╠══════════════════════════════════════════════════════════════╣');
      print('║                                                              ║');
      print(
        '║  ⚠️  PERMISSIONS DISABLED: All tool calls auto-approved       ║',
      );
      print('║  Only use in sandboxed environments (Docker, VMs)!          ║');
      print('║                                                              ║');
    }
    print('╚══════════════════════════════════════════════════════════════╝');
    print('');
    print('Server ready. Press Ctrl+C to stop.');
  }

  /// Print security notice based on bind address.
  void _printSecurityNotice(String bindAddress) {
    if (bindAddress == '127.0.0.1' || bindAddress == 'localhost') {
      print('║                                                              ║');
      print('║  🔒 Security: Localhost only                                 ║');
      print('║  Only this PC can access the daemon (no network access).    ║');
      print('║                                                              ║');
      print('║  💡 For Tailscale: Use --host <tailscale-ip>                ║');
      print('║     Example: vide_daemon --host 100.64.1.5                  ║');
    } else if (bindAddress == '0.0.0.0') {
      print('║                                                              ║');
      print('║  ⚠️  WARNING: EXPOSED TO ALL NETWORK INTERFACES              ║');
      print('║  Anyone on your local network can access this daemon!       ║');
      print('║                                                              ║');
      print('║  🔐 Recommendation: Use Tailscale instead                    ║');
      print('║     1. Install Tailscale: https://tailscale.com             ║');
      print('║     2. Find your IP: tailscale ip -4                        ║');
      print('║     3. Restart with: vide_daemon --host <tailscale-ip>      ║');
    } else if (_isTailscaleIP(bindAddress)) {
      print('║                                                              ║');
      print('║  ✅ Security: Tailscale network                              ║');
      print('║  Encrypted connection via WireGuard.                        ║');
      print('║  Only devices in your tailnet can connect.                  ║');
    } else {
      print('║                                                              ║');
      print('║  🔒 Security: Bound to ${'$bindAddress'.padRight(33)}║');
      print('║  Accessible on this network interface only.                 ║');
    }
  }

  /// Check bind address and show warnings/prompts.
  Future<void> _checkBindAddress(
    String bindAddress,
    bool skipConfirmation,
  ) async {
    if (bindAddress == '0.0.0.0') {
      if (skipConfirmation) {
        _log.warning(
          'Binding to 0.0.0.0 (all interfaces) — confirmed via --yes',
        );
        return;
      }
      print('');
      print('╔══════════════════════════════════════════════════════════════╗');
      print(
        '║                    ⚠️  SECURITY WARNING ⚠️                    ║',
      );
      print('╠══════════════════════════════════════════════════════════════╣');
      print('║                                                              ║');
      print('║  You are about to bind to 0.0.0.0 (ALL network interfaces)  ║');
      print('║                                                              ║');
      print('║  This means ANYONE on your local network can:               ║');
      print('║    • Access your daemon                                      ║');
      print('║    • Create sessions                                         ║');
      print('║    • Execute commands on your machine                        ║');
      print('║                                                              ║');
      print('║  ❌ Traffic is NOT encrypted (bearer token sent in cleartext) ║');
      print('║                                                              ║');
      print('║  🔐 RECOMMENDED: Use Tailscale instead                       ║');
      print('║     • Encrypted WireGuard connection                         ║');
      print('║     • Only your devices can connect                          ║');
      print('║     • Easy setup: https://tailscale.com                      ║');
      print('║                                                              ║');
      print('║  To use Tailscale:                                           ║');
      print('║    1. Install Tailscale                                      ║');
      print('║    2. Run: tailscale ip -4                                   ║');
      print('║    3. Use: vide_daemon --host <tailscale-ip>                 ║');
      print('║                                                              ║');
      print('╚══════════════════════════════════════════════════════════════╝');
      print('');
      stdout.write('Type "yes" to confirm binding to 0.0.0.0: ');

      final response = stdin.readLineSync()?.trim().toLowerCase();
      if (response != 'yes') {
        print('');
        print('Daemon startup cancelled.');
        print('');
        print('Tip: For safe remote access, use:');
        print('  vide_daemon --host <your-tailscale-ip>');
        print('');
        exit(1);
      }

      print('');
      print('⚠️  Proceeding with 0.0.0.0 binding (DANGEROUS)');
      print('');
    }
  }

  /// Check if an IP address is a Tailscale IP (100.64.0.0/10 range).
  static bool _isTailscaleIP(String ip) {
    try {
      final parts = ip.split('.');
      if (parts.length != 4) return false;

      final firstOctet = int.parse(parts[0]);
      final secondOctet = int.parse(parts[1]);

      // Tailscale uses 100.64.0.0/10 (100.64.0.0 - 100.127.255.255)
      if (firstOctet == 100 && secondOctet >= 64 && secondOctet <= 127) {
        return true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }
}
