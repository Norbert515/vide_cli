import 'dart:io';
import 'package:vide_cli/main.dart' as app;
import 'package:vide_core/vide_core.dart';
import 'package:path/path.dart' as path;

void main(List<String> args) async {
  // Handle --help flag
  if (args.contains('--help') || args.contains('-h')) {
    _printHelp();
    exit(0);
  }

  // Handle --version flag
  if (args.contains('--version') || args.contains('-v')) {
    print('vide $videVersion');
    exit(0);
  }

  // Handle --connect flag for connecting to remote server
  String? remoteServerUri;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--connect' || args[i] == '-c') {
      if (i + 1 < args.length) {
        remoteServerUri = args[i + 1];
        // Validate URI format
        if (!_isValidServerUri(remoteServerUri)) {
          print('Error: Invalid server URI: $remoteServerUri');
          print('Expected format: host:port (e.g., 192.168.1.100:8547)');
          exit(1);
        }
      } else {
        print('Error: --connect requires a server address (e.g., --connect 192.168.1.100:8547)');
        exit(1);
      }
      break;
    }
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

  await app.main(args, overrides: overrides, remoteServerUri: remoteServerUri);
}

bool _isValidServerUri(String uri) {
  // Allow host:port format
  final parts = uri.split(':');
  if (parts.length != 2) return false;

  final port = int.tryParse(parts[1]);
  if (port == null || port < 1 || port > 65535) return false;

  // Host can be IP or hostname
  final host = parts[0];
  if (host.isEmpty) return false;

  return true;
}

void _printHelp() {
  print('''
vide - An agentic terminal UI for Claude, built for Flutter developers

USAGE:
    vide [OPTIONS]

OPTIONS:
    -h, --help                    Print this help message
    -v, --version                 Print version information
    -c, --connect <host:port>     Connect to a remote vide session

REMOTE ACCESS:
    To enable remote access from within a session, press Ctrl+R.
    Other devices on your local network can then connect using:
        vide --connect <ip>:<port>

ENVIRONMENT VARIABLES:
    DISABLE_AUTOUPDATER=1    Disable automatic updates

DESCRIPTION:
    Vide orchestrates a network of specialized AI agents that collaborate
    asynchronously to help with software development tasks. It features
    Flutter-native testing capabilities and purpose-built MCP servers.

For more information, visit: https://github.com/Norbert515/vide_cli
''');
}
