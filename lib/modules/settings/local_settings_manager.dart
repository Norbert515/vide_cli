import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'models/claude_settings.dart';

class LocalSettingsManager {
  final String projectRoot;
  final String parrottRoot;

  LocalSettingsManager({required this.projectRoot, required this.parrottRoot});

  /// Detects if we're running as a compiled executable.
  ///
  /// When compiled, Platform.resolvedExecutable points to the compiled binary
  /// and Platform.script points to the same file (or a file: URI to it).
  /// When running via `dart run`, Platform.resolvedExecutable points to the dart binary.
  static bool get isCompiled {
    final executableName = p.basename(Platform.resolvedExecutable);
    // If the executable is 'dart' or 'dart.exe', we're running from source
    return executableName != 'dart' && executableName != 'dart.exe';
  }

  File get settingsFile {
    final claudeDir = Directory(p.join(projectRoot, '.claude'));
    return File(p.join(claudeDir.path, 'settings.local.json'));
  }

  /// Read current settings (or defaults if not exists)
  Future<ClaudeSettings> readSettings() async {
    if (!await settingsFile.exists()) {
      return ClaudeSettings.defaults();
    }

    try {
      final content = await settingsFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return ClaudeSettings.fromJson(json);
    } catch (e) {
      print('[LocalSettingsManager] Error reading settings: $e');
      return ClaudeSettings.defaults();
    }
  }

  /// Add permission to allow list
  Future<void> addToAllowList(String pattern) async {
    final settings = await readSettings();

    // Check if already in allow list
    if (settings.permissions.allow.contains(pattern)) {
      return;
    }

    final updatedPermissions = settings.permissions.copyWith(
      allow: [...settings.permissions.allow, pattern],
    );

    final updatedSettings = ClaudeSettings(
      permissions: updatedPermissions,
      hooks: settings.hooks,
    );

    await _writeSettings(updatedSettings);
  }

  /// Atomic write using temp file + rename
  Future<void> _writeSettings(ClaudeSettings settings) async {
    // Ensure .claude directory exists
    final claudeDir = settingsFile.parent;
    if (!await claudeDir.exists()) {
      await claudeDir.create(recursive: true);
    }

    // Write to temp file
    final tempFile = File('${settingsFile.path}.tmp');
    final encoder = JsonEncoder.withIndent('  ');
    await tempFile.writeAsString(encoder.convert(settings.toJson()));

    // Atomic rename
    await tempFile.rename(settingsFile.path);
  }
}
