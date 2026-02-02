import 'dart:io';

import 'package:args/args.dart';
import 'package:vide_core/vide_core.dart';

import '../lib/src/repl.dart';

void main(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      'dir',
      abbr: 'd',
      help: 'Working directory (default: current directory)',
    )
    ..addOption('model', abbr: 'm', help: 'Model to use: sonnet, opus, haiku')
    ..addOption(
      'config-dir',
      help: 'Configuration directory (default: ~/.vide)',
    )
    ..addOption(
      'team',
      abbr: 't',
      help:
          'Team to use: vide, enterprise, startup, balanced, research, ideator',
      defaultsTo: 'vide',
    )
    ..addFlag('help', abbr: 'h', help: 'Show this help', negatable: false)
    ..addFlag('version', abbr: 'v', help: 'Show version', negatable: false);

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
    exit(0);
  }

  if (results['version'] as bool) {
    stdout.writeln('vide_cli 0.1.0');
    exit(0);
  }

  final workingDir = results['dir'] as String? ?? Directory.current.path;
  final model = results['model'] as String?;
  final configDir = results['config-dir'] as String?;
  final team = results['team'] as String;
  final initialMessage = results.rest.join(' ');

  // Validate working directory
  if (!Directory(workingDir).existsSync()) {
    stderr.writeln('Error: Working directory does not exist: $workingDir');
    exit(1);
  }

  // Create VideCore with permission handler
  final permissionHandler = PermissionHandler();
  final core = VideCore(
    VideCoreConfig(
      configDir: configDir,
      permissionHandler: permissionHandler,
    ),
  );

  // Interactive REPL mode
  await runRepl(
    core: core,
    workingDirectory: workingDir,
    model: model,
    team: team,
    initialMessage: initialMessage.isEmpty ? null : initialMessage,
  );
}
