import 'dart:io';

/// Thin wrapper for backwards compatibility during development.
/// This delegates to the main parott executable with --hook flag.
///
/// In production, the compiled executable will be called directly with --hook.
void main(List<String> args) async {
  // Get the path to lib/main.dart relative to this script
  final scriptDir = File(Platform.script.toFilePath()).parent.path;
  final mainDartPath = '$scriptDir/lib/main.dart';

  // Run: dart lib/main.dart --hook
  final process = await Process.start(
    'dart',
    ['run', mainDartPath, '--hook'],
    workingDirectory: scriptDir,
    mode: ProcessStartMode.inheritStdio,
  );

  // Wait for process to complete and exit with same code
  final exitCode = await process.exitCode;
  exit(exitCode);
}
