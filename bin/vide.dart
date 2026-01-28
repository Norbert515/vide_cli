import 'dart:io';
import 'package:args/args.dart';
import 'package:vide_cli/main.dart' as app;
import 'package:vide_core/vide_core.dart';
import 'package:path/path.dart' as path;

void main(List<String> args) async {
  final parser = ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Print this help message',
    )
    ..addFlag(
      'version',
      abbr: 'v',
      negatable: false,
      help: 'Print version information',
    )
    ..addOption(
      'connect',
      abbr: 'c',
      help:
          'Connect to a daemon (format: host:port or just port for localhost)',
    )
    ..addOption(
      'session',
      abbr: 's',
      help: 'Connect to a specific session ID (requires --connect)',
    )
    ..addOption('auth-token', help: 'Authentication token for remote daemon')
    ..addFlag(
      'local',
      negatable: false,
      help: 'Force local session mode (ignore daemon setting)',
    )
    ..addFlag('daemon', negatable: false, help: 'Force daemon session mode');

  ArgResults argResults;
  try {
    argResults = parser.parse(args);
  } catch (e) {
    print('Error: $e');
    print('');
    _printHelp(parser);
    exit(1);
  }

  if (argResults['help'] as bool) {
    _printHelp(parser);
    exit(0);
  }

  if (argResults['version'] as bool) {
    print('vide $videVersion');
    exit(0);
  }

  // Determine config root for TUI: ~/.vide
  final homeDir =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (homeDir == null) {
    print('Error: Could not determine home directory');
    exit(1);
  }
  final configRoot = path.join(homeDir, '.vide');

  // Create provider overrides for TUI
  final overrides = [
    // Override VideConfigManager with TUI-specific config root
    videConfigManagerProvider.overrideWithValue(
      VideConfigManager(configRoot: configRoot),
    ),
    // Override working directory provider with current directory
    workingDirProvider.overrideWithValue(Directory.current.path),
  ];

  // Parse connection options
  final connectArg = argResults['connect'] as String?;
  final sessionId = argResults['session'] as String?;
  final authToken = argResults['auth-token'] as String?;
  final forceLocal = argResults['local'] as bool;
  final forceDaemon = argResults['daemon'] as bool;

  // Build remote config if --connect is specified
  app.RemoteConfig? remoteConfig;
  if (connectArg != null) {
    remoteConfig = _parseConnectArg(connectArg, sessionId, authToken);
  }

  await app.main(
    argResults.rest,
    overrides: overrides,
    remoteConfig: remoteConfig,
    forceLocal: forceLocal,
    forceDaemon: forceDaemon,
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
    // Just a port number
    port = int.tryParse(connectArg) ?? 8080;
  }

  return app.RemoteConfig(
    host: host,
    port: port,
    sessionId: sessionId,
    authToken: authToken,
  );
}

void _printHelp(ArgParser parser) {
  print('''
vide - An agentic terminal UI for Claude, built for Flutter developers

USAGE:
    vide [OPTIONS]

OPTIONS:
${parser.usage}

ENVIRONMENT VARIABLES:
    DISABLE_AUTOUPDATER=1    Disable automatic updates

REMOTE MODE:
    Use --connect to connect to a running vide_daemon:

    vide --connect 8080                    Connect to localhost:8080
    vide --connect 192.168.1.10:8080       Connect to remote daemon
    vide --connect 8080 --session abc123   Connect to specific session

DESCRIPTION:
    Vide orchestrates a network of specialized AI agents that collaborate
    asynchronously to help with software development tasks. It features
    Flutter-native testing capabilities and purpose-built MCP servers.

For more information, visit: https://github.com/Norbert515/vide_cli
''');
}
