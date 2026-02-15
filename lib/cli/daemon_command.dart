import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:vide_daemon/vide_daemon.dart';

/// Parent command for daemon lifecycle management.
///
/// Subcommands: start, stop, status, install, uninstall.
class DaemonCommand extends Command<void> {
  @override
  final name = 'daemon';

  @override
  final description = 'Manage the vide daemon';

  DaemonCommand() {
    addSubcommand(DaemonStartCommand());
    addSubcommand(DaemonStopCommand());
    addSubcommand(DaemonStatusCommand());
    addSubcommand(DaemonInstallCommand());
    addSubcommand(DaemonUninstallCommand());
  }
}

/// Start the daemon (foreground by default, --detach for background).
class DaemonStartCommand extends Command<void> {
  @override
  final name = 'start';

  @override
  final description = 'Start the daemon server';

  DaemonStartCommand() {
    argParser
      ..addOption(
        'port',
        abbr: 'p',
        defaultsTo: '8080',
        help: 'Port for daemon server',
      )
      ..addOption(
        'host',
        defaultsTo: '127.0.0.1',
        help: 'IP address to bind to (e.g., 100.x.x.x for Tailscale)',
      )
      ..addOption('state-dir', help: 'Directory for daemon state')
      ..addFlag('verbose', negatable: false, help: 'Enable verbose logging')
      ..addFlag(
        'detach',
        negatable: false,
        help: 'Run daemon in the background',
      )
      ..addFlag(
        'bind-all',
        negatable: false,
        help:
            'Bind to all network interfaces (0.0.0.0). '
            'WARNING: Requires confirmation prompt for security.',
      )
      ..addFlag(
        'dangerously-skip-permissions',
        negatable: false,
        help:
            'Skip all permission checks for spawned sessions. '
            'DANGEROUS: Only for sandboxed environments (Docker, VMs).',
      );
  }

  @override
  Future<void> run() async {
    final portStr = argResults!['port'] as String;
    final port = int.tryParse(portStr);
    if (port == null) {
      usageException('Port must be a valid number, got: $portStr');
    }
    if (port < 1 || port > 65535) {
      usageException('Port must be between 1 and 65535, got: $port');
    }

    final bindAll = argResults!['bind-all'] as bool;
    final host = bindAll ? '0.0.0.0' : argResults!['host'] as String;
    final stateDir = argResults!['state-dir'] as String?;
    final verbose = argResults!['verbose'] as bool;
    final detach = argResults!['detach'] as bool;
    final dangerouslySkipPermissions =
        argResults!['dangerously-skip-permissions'] as bool;

    // Prompt for confirmation BEFORE detaching, while stdin is still available
    if (dangerouslySkipPermissions) {
      _confirmDangerouslySkipPermissions();
    }

    if (detach) {
      await _startDetached(
        port: port,
        host: host,
        stateDir: stateDir,
        verbose: verbose,
        dangerouslySkipPermissions: dangerouslySkipPermissions,
      );
    } else {
      await _startForeground(
        port: port,
        host: host,
        stateDir: stateDir,
        verbose: verbose,
        dangerouslySkipPermissions: dangerouslySkipPermissions,
      );
    }
  }

  void _confirmDangerouslySkipPermissions() {
    print('');
    print('╔══════════════════════════════════════════════════════════════╗');
    print('║                    ⚠️  SECURITY WARNING ⚠️                    ║');
    print('╠══════════════════════════════════════════════════════════════╣');
    print('║                                                              ║');
    print('║  You are about to SKIP ALL PERMISSION CHECKS.               ║');
    print('║                                                              ║');
    print('║  All sessions spawned by this daemon will auto-approve       ║');
    print('║  every tool call, including:                                  ║');
    print('║    • File writes and deletions                               ║');
    print('║    • Arbitrary shell command execution                       ║');
    print('║    • Git operations (push, force-push, etc.)                 ║');
    print('║    • Network requests                                        ║');
    print('║                                                              ║');
    print('║  ⚠️  ONLY USE THIS IN A SANDBOXED ENVIRONMENT ⚠️              ║');
    print('║                                                              ║');
    print('║  Safe environments:                                          ║');
    print('║    • Docker containers                                       ║');
    print('║    • Virtual machines                                        ║');
    print('║    • Disposable CI/CD runners                                ║');
    print('║                                                              ║');
    print('║  NEVER use this on your host machine or with access          ║');
    print('║  to sensitive data, credentials, or production systems.      ║');
    print('║                                                              ║');
    print('╚══════════════════════════════════════════════════════════════╝');
    print('');
    stdout.write('Type "yes" to confirm skipping all permission checks: ');

    final response = stdin.readLineSync()?.trim().toLowerCase();
    if (response != 'yes') {
      print('');
      print('Daemon startup cancelled.');
      print('');
      exit(1);
    }

    print('');
    print('⚠️  Proceeding with ALL permission checks DISABLED');
    print('');
  }

  Future<void> _startDetached({
    required int port,
    required String host,
    String? stateDir,
    required bool verbose,
    required bool dangerouslySkipPermissions,
  }) async {
    final lifecycle = DaemonLifecycle(stateDir: stateDir);

    try {
      final info = await lifecycle.startDetached(
        port: port,
        host: host,
        verbose: verbose,
        dangerouslySkipPermissions: dangerouslySkipPermissions,
      );
      print('Daemon started in background');
      print('  PID:  ${info.pid}');
      print('  URL:  ${info.url}');
      if (info.logFile != null) {
        print('  Logs: ${info.logFile}');
      }
    } on DaemonAlreadyRunningException catch (e) {
      print(e.toString());
      exit(1);
    } on DaemonStartFailedException catch (e) {
      print(e.toString());
      exit(1);
    }
  }

  Future<void> _startForeground({
    required int port,
    required String host,
    String? stateDir,
    required bool verbose,
    required bool dangerouslySkipPermissions,
  }) async {
    final config = DaemonConfig(
      port: port,
      stateDir: stateDir,
      verbose: verbose,
      bindAddress: host,
      dangerouslySkipPermissions: dangerouslySkipPermissions,
    );

    final starter = DaemonStarter(config);
    await starter.start();
    starter.setupSignalHandlers();

    // Keep the process alive
    await Completer<void>().future;
  }
}

/// Stop the running daemon.
class DaemonStopCommand extends Command<void> {
  @override
  final name = 'stop';

  @override
  final description = 'Stop the running daemon';

  DaemonStopCommand() {
    argParser
      ..addFlag(
        'force',
        negatable: false,
        help: 'Force kill the daemon (SIGKILL instead of SIGTERM)',
      )
      ..addOption('state-dir', help: 'Directory for daemon state');
  }

  @override
  Future<void> run() async {
    final force = argResults!['force'] as bool;
    final stateDir = argResults!['state-dir'] as String?;
    final lifecycle = DaemonLifecycle(stateDir: stateDir);

    try {
      await lifecycle.stop(force: force);
      print('Daemon stopped.');
    } on DaemonNotRunningException {
      print('Daemon is not running.');
      exit(1);
    }
  }
}

/// Show daemon status.
class DaemonStatusCommand extends Command<void> {
  @override
  final name = 'status';

  @override
  final description = 'Show daemon status';

  DaemonStatusCommand() {
    argParser.addOption('state-dir', help: 'Directory for daemon state');
  }

  @override
  Future<void> run() async {
    final stateDir = argResults!['state-dir'] as String?;
    final lifecycle = DaemonLifecycle(stateDir: stateDir);
    final status = await lifecycle.status();

    if (!status.isRunning) {
      print('Vide Daemon: Not running');
      return;
    }

    final info = status.info!;
    print('Vide Daemon: Running');
    print('  PID:      ${info.pid}');
    print('  URL:      ${info.url}');

    if (status.uptimeSeconds != null) {
      print('  Uptime:   ${_formatUptime(status.uptimeSeconds!)}');
    }

    if (status.sessionCount != null) {
      final label = status.sessionCount == 1 ? 'session' : 'sessions';
      print('  Sessions: ${status.sessionCount} $label');
    }

    if (info.logFile != null) {
      print('  Logs:     ${info.logFile}');
    }
  }

  String _formatUptime(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m ${seconds % 60}s';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return '${hours}h ${minutes}m';
  }
}

/// Install daemon as a system service (starts on boot/login).
class DaemonInstallCommand extends Command<void> {
  @override
  final name = 'install';

  @override
  final description = 'Install daemon as a system service (starts on login)';

  DaemonInstallCommand() {
    argParser
      ..addOption(
        'port',
        abbr: 'p',
        defaultsTo: '8080',
        help: 'Port for daemon server',
      )
      ..addOption(
        'host',
        defaultsTo: '127.0.0.1',
        help: 'IP address to bind to',
      );
  }

  @override
  Future<void> run() async {
    final portStr = argResults!['port'] as String;
    final port = int.tryParse(portStr);
    if (port == null) {
      usageException('Port must be a valid number, got: $portStr');
    }
    if (port < 1 || port > 65535) {
      usageException('Port must be between 1 and 65535, got: $port');
    }

    final host = argResults!['host'] as String;

    try {
      final installer = ServiceInstaller();
      await installer.install(port: port, host: host);
    } on UnsupportedError catch (e) {
      print(e.message);
      exit(1);
    }
  }
}

/// Uninstall daemon system service.
class DaemonUninstallCommand extends Command<void> {
  @override
  final name = 'uninstall';

  @override
  final description = 'Uninstall daemon system service';

  @override
  Future<void> run() async {
    try {
      final installer = ServiceInstaller();
      await installer.uninstall();
    } on UnsupportedError catch (e) {
      print(e.message);
      exit(1);
    }
  }
}
