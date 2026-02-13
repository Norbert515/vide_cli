import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:vide_daemon/vide_daemon.dart';

class ServeCommand extends Command<void> {
  @override
  final name = 'serve';

  @override
  final description = 'Start the daemon server';

  ServeCommand() {
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
      ..addOption('token', help: 'Auth token for daemon')
      ..addFlag(
        'generate-token',
        negatable: false,
        help: 'Generate auth token for daemon',
      )
      ..addFlag('verbose', negatable: false, help: 'Enable verbose logging')
      ..addFlag(
        'bind-all',
        negatable: false,
        help:
            'Bind to all network interfaces (0.0.0.0) instead of localhost only. '
            'Shortcut for --host=0.0.0.0. '
            'WARNING: Use with --token or --generate-token for security.',
      );
  }

  @override
  Future<void> run() async {
    final portStr = argResults!['port'] as String;
    final port = int.tryParse(portStr);
    if (port == null) {
      usageException('Port must be a valid number, got: $portStr');
    }

    final bindAll = argResults!['bind-all'] as bool;
    final host = bindAll ? '0.0.0.0' : argResults!['host'] as String;
    final config = DaemonConfig(
      port: port,
      stateDir: argResults!['state-dir'] as String?,
      authToken: argResults!['token'] as String?,
      generateToken: argResults!['generate-token'] as bool,
      verbose: argResults!['verbose'] as bool,
      bindAddress: host,
    );

    final starter = DaemonStarter(config);
    await starter.start();
    starter.setupSignalHandlers();

    // Keep the process alive
    await Completer<void>().future;
  }
}
