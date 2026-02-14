#!/usr/bin/env dart

import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';

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
    ..addOption(
      'host',
      defaultsTo: '127.0.0.1',
      help: 'IP address to bind to (e.g., 100.x.x.x for Tailscale)',
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

  // Create daemon configuration
  final config = DaemonConfig(
    port: port,
    stateDir: argResults['state-dir'] as String?,
    videServerPath: argResults['vide-server-path'] as String?,
    verbose: argResults['verbose'] as bool,
    bindAddress: argResults['host'] as String,
  );

  // Start the daemon
  final starter = DaemonStarter(config);
  await starter.start();
  starter.setupSignalHandlers();

  // Keep the process alive
  await Completer<void>().future;
}
