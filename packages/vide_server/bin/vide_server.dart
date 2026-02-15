#!/usr/bin/env dart

import 'dart:async';
import 'dart:io';
import 'package:args/args.dart';
import 'package:vide_server/server_main.dart';

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
      help: 'Port number to listen on (default: auto-select)',
    )
    ..addOption(
      'filesystem-root',
      help: 'Root directory for filesystem/git API (overrides config file)',
    );

  void printUsage() {
    print('Vide API Server');
    print('');
    print('Usage: dart run bin/vide_server.dart [options]');
    print('');
    print('Options:');
    print(parser.usage);
    print('');
    print('Examples:');
    print('  dart run bin/vide_server.dart');
    print('  dart run bin/vide_server.dart --port 8080');
    print('  dart run bin/vide_server.dart -p 8888');
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

  // Parse port if provided
  int? port;
  final portStr = argResults['port'] as String?;
  if (portStr != null) {
    port = int.tryParse(portStr);
    if (port == null) {
      print('Error: Port must be a valid number, got: $portStr');
      print('');
      printUsage();
      exit(1);
    }
  }

  final filesystemRoot = argResults['filesystem-root'] as String?;

  // Start the server using shared logic
  await startServer(VideServerConfig(
    port: port,
    filesystemRoot: filesystemRoot,
  ));

  // Keep the process alive
  await Completer<void>().future;
}
