import 'dart:io';
import 'package:vide_cli/main.dart' as app;
import 'package:vide_core/vide_core.dart';
import 'package:path/path.dart' as path;

void main(List<String> args) async {
  // Determine config root for TUI: ~/.vide
  final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
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

  await app.main(args, overrides: overrides);
}
