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

  // Determine config root for TUI: ~/.vide
  final homeDir =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (homeDir == null) {
    print('Error: Could not determine home directory');
    exit(1);
  }
  final configRoot = path.join(homeDir, '.vide');

  // Sync team framework assets from package to ~/.vide/defaults/
  // In development (running from source), always force sync to avoid stale assets
  final isDevelopment = _isRunningFromSource();
  await TeamFrameworkAssetInitializer.initialize(
    videHome: configRoot,
    forceSync: isDevelopment,
  );

  // Create provider overrides for TUI
  final overrides = [
    // Override VideConfigManager with TUI-specific config root
    videConfigManagerProvider.overrideWithValue(
      VideConfigManager(configRoot: configRoot),
    ),
    // Override working directory provider with current directory
    workingDirProvider.overrideWithValue(Directory.current.path),
  ];

  await app.main(args, overrides: overrides);
}

/// Check if we're running from source (development mode).
/// Returns true if the package assets directory exists in the current path.
bool _isRunningFromSource() {
  final assetsDir = Directory('packages/vide_core/assets/team_framework');
  return assetsDir.existsSync();
}

void _printHelp() {
  print('''
vide - An agentic terminal UI for Claude, built for Flutter developers

USAGE:
    vide [OPTIONS]

OPTIONS:
    -h, --help       Print this help message
    -v, --version    Print version information

ENVIRONMENT VARIABLES:
    DISABLE_AUTOUPDATER=1    Disable automatic updates

DESCRIPTION:
    Vide orchestrates a network of specialized AI agents that collaborate
    asynchronously to help with software development tasks. It features
    Flutter-native testing capabilities and purpose-built MCP servers.

For more information, visit: https://github.com/Norbert515/vide_cli
''');
}
