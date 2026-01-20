import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:vide_core/vide_core.dart';

import '../lib/src/repl.dart';
import '../lib/src/event_renderer.dart';

void main(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      'dir',
      abbr: 'd',
      help: 'Working directory (default: current directory)',
    )
    ..addOption(
      'model',
      abbr: 'm',
      help: 'Model to use: sonnet, opus, haiku',
    )
    ..addOption(
      'config-dir',
      help: 'Configuration directory (default: ~/.vide)',
    )
    ..addFlag(
      'serve',
      help: 'Start embedded HTTP/WebSocket server',
      negatable: false,
    )
    ..addOption(
      'port',
      abbr: 'p',
      help: 'Server port (default: 8080)',
      defaultsTo: '8080',
    )
    ..addOption(
      'team',
      abbr: 't',
      help: 'Team to use: vide, enterprise, startup, balanced, research, ideator',
      defaultsTo: 'vide',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      help: 'Show this help',
      negatable: false,
    )
    ..addFlag(
      'version',
      abbr: 'v',
      help: 'Show version',
      negatable: false,
    );

  ArgResults results;
  try {
    results = parser.parse(args);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    stderr.writeln();
    stderr.writeln('Usage: vide_cli [options] [initial message]');
    stderr.writeln(parser.usage);
    exit(1);
  }

  if (results['help'] as bool) {
    stdout.writeln('vide_cli - Simple CLI for testing vide_core API');
    stdout.writeln();
    stdout.writeln('Usage: vide_cli [options] [initial message]');
    stdout.writeln();
    stdout.writeln('Options:');
    stdout.writeln(parser.usage);
    stdout.writeln();
    stdout.writeln('Examples:');
    stdout.writeln('  vide_cli "What files are in this directory?"');
    stdout.writeln('  vide_cli -m opus "Help me fix the bug"');
    stdout.writeln('  vide_cli -d /path/to/project');
    stdout.writeln('  vide_cli  # Start interactive REPL');
    stdout.writeln('  vide_cli --serve -p 8080 "Start working"');
    exit(0);
  }

  if (results['version'] as bool) {
    stdout.writeln('vide_cli 0.1.0');
    exit(0);
  }

  final workingDir = results['dir'] as String? ?? Directory.current.path;
  final model = results['model'] as String?;
  final configDir = results['config-dir'] as String?;
  final serve = results['serve'] as bool;
  final port = int.tryParse(results['port'] as String) ?? 8080;
  final team = results['team'] as String;
  final initialMessage = results.rest.join(' ');

  // Validate working directory
  if (!Directory(workingDir).existsSync()) {
    stderr.writeln('Error: Working directory does not exist: $workingDir');
    exit(1);
  }

  // Create VideCore
  final core = VideCore(VideCoreConfig(
    configDir: configDir,
  ));

  if (serve) {
    await runServeMode(
      core: core,
      workingDirectory: workingDir,
      model: model,
      port: port,
      team: team,
      initialMessage: initialMessage.isEmpty ? null : initialMessage,
    );
  } else {
    // Interactive REPL mode
    await runRepl(
      core: core,
      workingDirectory: workingDir,
      model: model,
      team: team,
      initialMessage: initialMessage.isEmpty ? null : initialMessage,
    );
  }
}

/// Run in server mode - start HTTP/WebSocket server for remote access.
Future<void> runServeMode({
  required VideCore core,
  required String workingDirectory,
  String? model,
  required int port,
  required String team,
  String? initialMessage,
}) async {
  final renderer = EventRenderer(useColors: stdout.hasTerminal);

  // Require initial message for serve mode
  if (initialMessage == null || initialMessage.isEmpty) {
    stderr.writeln('Error: --serve mode requires an initial message');
    stderr.writeln('Example: vide_cli --serve -p 8080 "Help me with this project"');
    core.dispose();
    exit(1);
  }

  stdout.writeln('Starting session...');

  // Start session
  final session = await core.startSession(VideSessionConfig(
    workingDirectory: workingDirectory,
    initialMessage: initialMessage,
    model: model,
    team: team,
  ));

  // Subscribe to events and render to console
  final eventSub = session.events.listen((event) {
    renderer.render(event);

    // Auto-allow permissions in serve mode (can be changed later)
    if (event is PermissionRequestEvent) {
      stdout.writeln('[Auto-allowing in serve mode]');
      session.respondToPermission(event.requestId, allow: true);
    }
  });

  // Start embedded server
  final server = await VideEmbeddedServer.start(
    session: session,
    port: port,
  );

  stdout.writeln();
  stdout.writeln('╔════════════════════════════════════════════════════════════╗');
  stdout.writeln('║  vide_cli Server Mode                                      ║');
  stdout.writeln('╠════════════════════════════════════════════════════════════╣');
  stdout.writeln('║  HTTP Server: http://localhost:$port                        ');
  stdout.writeln('║  WebSocket:   ws://localhost:$port/ws                       ');
  stdout.writeln('╠════════════════════════════════════════════════════════════╣');
  stdout.writeln('║  Endpoints:                                                ║');
  stdout.writeln('║    GET  /health    - Server health check                   ║');
  stdout.writeln('║    GET  /session   - Session info                          ║');
  stdout.writeln('║    GET  /agents    - List agents                           ║');
  stdout.writeln('║    POST /message   - Send message                          ║');
  stdout.writeln('║    POST /permission - Respond to permission                ║');
  stdout.writeln('║    POST /abort     - Abort session                         ║');
  stdout.writeln('║    WS   /ws        - WebSocket for real-time events        ║');
  stdout.writeln('╠════════════════════════════════════════════════════════════╣');
  stdout.writeln('║  Press Ctrl+C to stop the server                           ║');
  stdout.writeln('╚════════════════════════════════════════════════════════════╝');
  stdout.writeln();

  // Handle Ctrl+C
  final completer = Completer<void>();

  ProcessSignal.sigint.watch().listen((_) async {
    stdout.writeln('\nShutting down...');
    await eventSub.cancel();
    await server.stop();
    await session.dispose();
    core.dispose();
    completer.complete();
  });

  // Wait for shutdown signal
  await completer.future;
  stdout.writeln('Goodbye!');
}
