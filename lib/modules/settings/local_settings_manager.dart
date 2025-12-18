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

  /// Gets the hook command based on whether we're compiled or running from source.
  String getHookCommand() {
    if (isCompiled) {
      // In compiled mode, use the executable directly with --hook flag
      return '${Platform.resolvedExecutable} --hook';
    } else {
      // In development mode, use dart hook.dart (which delegates to main.dart --hook)
      final hookPath = p.join(parrottRoot, 'hook.dart');
      return 'dart $hookPath';
    }
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

  /// The current expected matcher pattern - update this when adding new tool types
  static const String currentMatcherPattern =
      'Write|Edit|Bash|MultiEdit|WebFetch|WebSearch|Read|mcp__.*';

  /// Check if our hook is installed
  Future<bool> isHookInstalled() async {
    final settings = await readSettings();

    if (settings.hooks == null) {
      return false;
    }

    for (final hook in settings.hooks!.preToolUse) {
      if (hook.hooks.any((cmd) => _isOurHook(cmd.command))) {
        return true;
      }
    }

    return false;
  }

  /// Check if the installed hook is up to date (has correct matcher pattern)
  Future<bool> isHookUpToDate() async {
    final settings = await readSettings();

    if (settings.hooks == null) {
      return false;
    }

    for (final hook in settings.hooks!.preToolUse) {
      if (hook.hooks.any((cmd) => _isOurHook(cmd.command))) {
        // Found our hook - check if matcher is current
        return hook.matcher == currentMatcherPattern;
      }
    }

    return false;
  }

  /// Update the hook to the latest configuration (matcher pattern, timeout, etc.)
  Future<void> updateHook() async {
    final settings = await readSettings();
    final videHook = getVideHook();

    if (settings.hooks == null) {
      // No hooks at all - just install fresh
      await installHook();
      return;
    }

    // Find and replace our existing hook
    final updatedHooks = <PreToolUseHook>[];
    bool foundOurHook = false;

    for (final hook in settings.hooks!.preToolUse) {
      if (hook.hooks.any((cmd) => _isOurHook(cmd.command))) {
        // Replace our hook with updated version
        updatedHooks.add(videHook);
        foundOurHook = true;
      } else {
        // Keep other hooks unchanged
        updatedHooks.add(hook);
      }
    }

    if (!foundOurHook) {
      // Our hook wasn't found - add it
      updatedHooks.add(videHook);
    }

    final updatedSettings = ClaudeSettings(
      permissions: settings.permissions,
      hooks: HooksConfig(preToolUse: updatedHooks),
    );

    await _writeSettings(updatedSettings);
  }

  /// Ensure hook is installed and up to date. Returns true if changes were made.
  Future<bool> ensureHookUpToDate() async {
    final installed = await isHookInstalled();

    if (!installed) {
      await installHook();
      return true;
    }

    final upToDate = await isHookUpToDate();
    if (!upToDate) {
      await updateHook();
      return true;
    }

    return false;
  }

  /// Checks if a command belongs to our hook.
  /// This is robust against project renames and different execution modes.
  bool _isOurHook(String command) {
    // Check for known project names
    final hasProjectName =
        command.contains('parott') || command.contains('vide');

    // Check for hook indicators (covers both dev and compiled modes)
    final hasHookIndicator =
        command.contains('hook.dart') || command.contains('--hook');

    // A command is ours if it has either a project name OR a hook indicator
    return hasProjectName || hasHookIndicator;
  }

  /// Get the Vide CLI hook configuration
  PreToolUseHook getVideHook() {
    return PreToolUseHook(
      // Match all tools including MCP tools (mcp__*) so we have full control
      matcher: currentMatcherPattern,
      hooks: [
        HookCommand(
          type: 'command',
          command: getHookCommand(),
          timeout:
              60000, // 60 seconds (in milliseconds) - matches Claude Code default
        ),
      ],
    );
  }

  /// Generate installation diff
  Future<SettingsDiff> generateInstallDiff() async {
    final before = await readSettings();
    final videHook = getVideHook();

    // Preserve existing hooks or start with empty list
    final existingHooks = before.hooks?.preToolUse ?? [];

    final after = ClaudeSettings(
      permissions: before.permissions,
      hooks: HooksConfig(preToolUse: [...existingHooks, videHook]),
    );

    return SettingsDiff(
      before: before,
      after: after,
      explanation:
          '''
Vide CLI will install a PreToolUse hook to handle permissions.

Hook Configuration:
- Matcher: ${videHook.matcher}
- Command: ${videHook.hooks.first.command}
- Timeout: ${videHook.hooks.first.timeout}ms

This hook intercepts file writes, edits, and shell commands
to request permission through the Vide CLI UI.
''',
    );
  }

  /// Install the hook
  Future<void> installHook() async {
    final diff = await generateInstallDiff();
    await _writeSettings(diff.after);
  }

  /// Check if this is the first run of Vide CLI
  Future<bool> isFirstRun() async {
    final settings = await readSettings();
    return settings.videFirstRunComplete != true;
  }

  /// Mark the first run as complete
  Future<void> markFirstRunComplete() async {
    final settings = await readSettings();
    final updatedSettings = settings.copyWith(videFirstRunComplete: true);
    await _writeSettings(updatedSettings);
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

class SettingsDiff {
  final ClaudeSettings before;
  final ClaudeSettings after;
  final String explanation;

  const SettingsDiff({
    required this.before,
    required this.after,
    required this.explanation,
  });

  String toPrettyString() {
    final buffer = StringBuffer();

    // Show new hooks
    final beforeHooks = before.hooks?.preToolUse.length ?? 0;
    final afterHooks = after.hooks?.preToolUse.length ?? 0;
    final newHooks = afterHooks - beforeHooks;

    if (newHooks > 0 && after.hooks != null) {
      buffer.writeln('+ hooks.PreToolUse[$beforeHooks]:');
      final hook = after.hooks!.preToolUse.last;
      buffer.writeln('  + matcher: "${hook.matcher}"');
      buffer.writeln('  + command: "${hook.hooks.first.command}"');
      buffer.writeln('  + timeout: ${hook.hooks.first.timeout}');
      buffer.writeln();
    }

    buffer.writeln(explanation);

    return buffer.toString();
  }
}
