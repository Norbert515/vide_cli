import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:vide_cli/main.dart' as app;
import 'package:vide_core/vide_core.dart';

class ConnectCommand extends Command<void> {
  @override
  final name = 'connect';

  @override
  final description = 'Connect to a running vide daemon';

  @override
  final invocation = 'vide connect <host:port>';

  ConnectCommand() {
    argParser
      ..addOption(
        'session',
        abbr: 's',
        help: 'Connect to a specific session ID',
      )
      ..addOption('auth-token', help: 'Authentication token for remote daemon');
  }

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.length != 1) {
      usageException(
        'Expected exactly one argument: <host:port> or <port>',
      );
    }

    final connectArg = rest.first;
    final sessionId = argResults!['session'] as String?;
    final authToken = argResults!['auth-token'] as String?;

    final forceLocal = globalResults!['local'] as bool;
    if (forceLocal) {
      usageException('--local cannot be used with the connect command');
    }

    final remoteConfig = _parseConnectArg(connectArg, sessionId, authToken);

    final dangerouslySkipPermissions =
        globalResults!['dangerously-skip-permissions'] as bool;

    final configManager = VideConfigManager();
    final overrides = [
      videConfigManagerProvider.overrideWithValue(configManager),
      workingDirProvider.overrideWithValue(Directory.current.path),
    ];

    await app.main(
      [],
      overrides: overrides,
      remoteConfig: remoteConfig,
      dangerouslySkipPermissions: dangerouslySkipPermissions,
    );
  }

  app.RemoteConfig _parseConnectArg(
    String connectArg,
    String? sessionId,
    String? authToken,
  ) {
    String host = '127.0.0.1';
    int port;

    if (connectArg.contains(':')) {
      final parts = connectArg.split(':');
      host = parts[0].isEmpty ? '127.0.0.1' : parts[0];
      port = int.tryParse(parts[1]) ?? 8080;
    } else {
      port = int.tryParse(connectArg) ?? 8080;
    }

    return app.RemoteConfig(
      host: host,
      port: port,
      sessionId: sessionId,
      authToken: authToken,
    );
  }
}
