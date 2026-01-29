#!/usr/bin/env dart

import 'dart:io';
import 'dart:math';

import 'package:args/args.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import 'package:vide_daemon/vide_daemon.dart';

void main(List<String> arguments) async {
  // Parse command-line arguments
  final parser = ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show this help message',
    )
    ..addOption(
      'port',
      abbr: 'p',
      defaultsTo: '8080',
      help: 'Port number to listen on',
    )
    ..addOption(
      'vide-server-path',
      help: 'Path to vide_server package (defaults to sibling package)',
    )
    ..addOption(
      'state-dir',
      help: 'Directory for daemon state (defaults to ~/.vide/daemon)',
    )
    ..addFlag(
      'generate-token',
      help: 'Generate and require an auth token',
      negatable: false,
    )
    ..addOption(
      'token',
      help: 'Auth token to require (implies --generate-token behavior)',
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Enable verbose logging',
    );

  void printUsage() {
    print('Vide Daemon - Persistent session manager');
    print('');
    print('Usage: vide_daemon [options]');
    print('');
    print('Options:');
    print(parser.usage);
    print('');
    print('Examples:');
    print('  vide_daemon');
    print('  vide_daemon --port 9000');
    print('  vide_daemon --generate-token');
  }

  ArgResults argResults;
  try {
    argResults = parser.parse(arguments);
  } catch (e) {
    print('Error: $e');
    print('');
    printUsage();
    exit(1);
  }

  if (argResults['help'] as bool) {
    printUsage();
    exit(0);
  }

  // Parse port
  final portStr = argResults['port'] as String;
  final port = int.tryParse(portStr);
  if (port == null) {
    print('Error: Port must be a valid number, got: $portStr');
    exit(1);
  }

  // Set up logging
  final verbose = argResults['verbose'] as bool;
  Logger.root.level = verbose ? Level.ALL : Level.INFO;
  Logger.root.onRecord.listen((record) {
    final time = record.time.toIso8601String().substring(11, 23);
    print(
      '[$time] ${record.level.name.padRight(7)} ${record.loggerName}: ${record.message}',
    );
    if (record.error != null) print('  Error: ${record.error}');
    if (record.stackTrace != null && verbose)
      print('  Stack: ${record.stackTrace}');
  });

  final log = Logger('VideDaemon');

  // Determine state directory
  final homeDir =
      Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      Directory.current.path;

  final stateDir =
      argResults['state-dir'] as String? ??
      path.join(homeDir, '.vide', 'daemon');
  final stateFilePath = path.join(stateDir, 'state.json');

  // Ensure state directory exists
  await Directory(stateDir).create(recursive: true);

  // Determine vide_server path
  String videServerPath = argResults['vide-server-path'] as String? ?? '';
  if (videServerPath.isEmpty) {
    // Try to find vide_server relative to this package
    final scriptDir = path.dirname(Platform.script.toFilePath());
    final possiblePaths = [
      // Running from bin/
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
    ];

    for (final p in possiblePaths) {
      final normalized = path.normalize(p);
      if (File(normalized).existsSync()) {
        videServerPath = normalized;
        break;
      }
    }

    if (videServerPath.isEmpty) {
      // Fallback: assume it's in PATH or use dart run
      videServerPath = 'bin/vide_server.dart';
      log.warning(
        'Could not find vide_server, using relative path: $videServerPath',
      );
    }
  }

  log.info('vide_server path: $videServerPath');

  // Handle auth token
  String? authToken;
  if (argResults['token'] != null) {
    authToken = argResults['token'] as String;
  } else if (argResults['generate-token'] as bool) {
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
    port: port,
    authToken: authToken,
  );

  await server.start();

  // Start health checks
  registry.startHealthChecks();

  // Print startup info
  print('');
  print('╔════════════════════════════════════════════════════════════════╗');
  print('║                     Vide Daemon                                ║');
  print('╠════════════════════════════════════════════════════════════════╣');
  print(
    '║  URL: http://127.0.0.1:$port${' ' * (54 - port.toString().length)}║',
  );
  print('║  State: ${stateDir.padRight(53)}║');
  if (authToken != null) {
    print('║  Token: ${authToken.padRight(53)}║');
  } else {
    print('║  Auth: none (localhost only)                                   ║');
  }
  print('║  Sessions: ${registry.sessionCount.toString().padRight(50)}║');
  print('╠════════════════════════════════════════════════════════════════╣');
  print('║  Endpoints:                                                     ║');
  print('║    POST   /sessions        - Create new session                 ║');
  print('║    GET    /sessions        - List all sessions                  ║');
  print('║    GET    /sessions/:id    - Get session details                ║');
  print('║    DELETE /sessions/:id    - Stop a session                     ║');
  print('║    WS     /daemon          - Real-time daemon events            ║');
  print('╚════════════════════════════════════════════════════════════════╝');
  print('');
  print('Server ready. Press Ctrl+C to stop.');

  // Handle shutdown
  ProcessSignal.sigint.watch().listen((_) async {
    print('');
    log.info('Shutting down...');
    await server.stop();
    await registry.dispose();
    log.info('Goodbye!');
    exit(0);
  });

  ProcessSignal.sigterm.watch().listen((_) async {
    log.info('Received SIGTERM, shutting down...');
    await server.stop();
    await registry.dispose();
    exit(0);
  });
}

String _generateToken() {
  final random = Random.secure();
  const chars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  return List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
}
