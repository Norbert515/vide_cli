import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:vide_core/vide_core.dart';
import 'package:vide_server/vide_server.dart' as server;

class SessionServerCommand extends Command<void> {
  @override
  final name = 'session-server';

  @override
  final description = 'Internal: Start as a session server (used by daemon)';

  @override
  final hidden = true;

  SessionServerCommand() {
    argParser
      ..addOption('port', abbr: 'p', help: 'Port for session server')
      ..addOption('host',
          help: 'Host/address to bind to (default: 127.0.0.1)')
      ..addOption('working-dir', help: 'Working directory for session server');
  }

  @override
  Future<void> run() async {
    final portStr = argResults!['port'] as String?;
    if (portStr == null) {
      usageException('--port is required for session-server mode');
    }

    final port = int.tryParse(portStr);
    if (port == null) {
      usageException('Port must be a valid number, got: $portStr');
    }

    final workingDir = argResults!['working-dir'] as String?;
    if (workingDir == null) {
      usageException('--working-dir is required for session-server mode');
    }

    Directory.current = workingDir;

    final dangerouslySkipPermissions =
        Platform.environment['VIDE_DANGEROUSLY_SKIP_PERMISSIONS'] == '1';

    // Initialize structured logging
    VideLogger.init('${VideConfigManager().configRoot}/logs');

    final host = argResults!['host'] as String?;

    await server.startServer(
      server.VideServerConfig(
        port: port,
        host: host,
        workingDirectory: workingDir,
        dangerouslySkipPermissions: dangerouslySkipPermissions,
      ),
    );

    // Keep the process alive
    await Completer<void>().future;
  }
}
