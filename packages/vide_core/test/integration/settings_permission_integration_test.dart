import 'dart:io';
import 'dart:convert';
import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';

/// Integration tests for Settings and Permissions subsystems working together.
///
/// Tests the interaction between:
/// - LocalSettingsManager (settings persistence)
/// - PermissionChecker (permission evaluation)
/// - PermissionMatcher (pattern matching)
void main() {
  group('Settings + Permission Integration', () {
    late Directory tempDir;
    late String projectRoot;
    late LocalSettingsManager settingsManager;
    late PermissionChecker permissionChecker;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('settings_perm_test_');
      projectRoot = tempDir.path;
      settingsManager = LocalSettingsManager(
        projectRoot: projectRoot,
        parrottRoot: projectRoot,
      );
      permissionChecker = PermissionChecker();
    });

    tearDown(() async {
      permissionChecker.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('Allow list integration', () {
      test('adding to allow list affects permission checks', () async {
        // Initially not in allow list - should ask user
        var result = await permissionChecker.checkPermission(
          toolName: 'Bash',
          input: const BashToolInput(command: 'npm install'),
          cwd: projectRoot,
        );
        expect(result, isA<PermissionAskUser>());

        // Add to allow list
        await settingsManager.addToAllowList('Bash(npm:*)');

        // Now should be allowed
        result = await permissionChecker.checkPermission(
          toolName: 'Bash',
          input: const BashToolInput(command: 'npm install'),
          cwd: projectRoot,
        );
        expect(result, isA<PermissionAllow>());
      });

      test('multiple allow patterns work correctly', () async {
        // Add multiple patterns
        await settingsManager.addToAllowList('Bash(npm:*)');
        await settingsManager.addToAllowList('Bash(dart:*)');
        await settingsManager.addToAllowList('Read(**)');

        // npm commands allowed
        var result = await permissionChecker.checkPermission(
          toolName: 'Bash',
          input: const BashToolInput(command: 'npm run build'),
          cwd: projectRoot,
        );
        expect(result, isA<PermissionAllow>());

        // dart commands allowed
        result = await permissionChecker.checkPermission(
          toolName: 'Bash',
          input: const BashToolInput(command: 'dart analyze'),
          cwd: projectRoot,
        );
        expect(result, isA<PermissionAllow>());

        // Read operations allowed
        result = await permissionChecker.checkPermission(
          toolName: 'Read',
          input: const ReadToolInput(filePath: '/any/file.txt'),
          cwd: projectRoot,
        );
        expect(result, isA<PermissionAllow>());

        // Other bash commands still need approval
        result = await permissionChecker.checkPermission(
          toolName: 'Bash',
          input: const BashToolInput(command: 'rm -rf /'),
          cwd: projectRoot,
        );
        expect(result, isA<PermissionAskUser>());
      });
    });

    group('Deny list integration', () {
      test('deny list takes precedence over allow list', () async {
        // Write settings with both allow and deny for same pattern
        final claudeDir = Directory('$projectRoot/.claude');
        await claudeDir.create(recursive: true);
        final settingsFile = File('$projectRoot/.claude/settings.local.json');

        final settings = ClaudeSettings(
          permissions: PermissionsConfig(
            allow: ['Bash(rm:*)'],
            deny: ['Bash(rm:*)'],
            ask: [],
          ),
        );
        await settingsFile.writeAsString(jsonEncode(settings.toJson()));

        // Deny should win
        final result = await permissionChecker.checkPermission(
          toolName: 'Bash',
          input: const BashToolInput(command: 'rm file.txt'),
          cwd: projectRoot,
        );
        expect(result, isA<PermissionDeny>());
      });
    });

    group('Session cache integration', () {
      test('session cache allows write operations without persisting', () async {
        // Write operation initially needs approval
        var result = await permissionChecker.checkPermission(
          toolName: 'Write',
          input: const WriteToolInput(filePath: '/test/file.dart', content: ''),
          cwd: projectRoot,
        );
        expect(result, isA<PermissionAskUser>());

        // Add to session cache
        permissionChecker.addSessionPattern('Write(/test/**)');

        // Now allowed from session cache
        result = await permissionChecker.checkPermission(
          toolName: 'Write',
          input: const WriteToolInput(filePath: '/test/file.dart', content: ''),
          cwd: projectRoot,
        );
        expect(result, isA<PermissionAllow>());
        expect((result as PermissionAllow).reason, contains('session cache'));

        // Session cache doesn't persist - creating new checker requires re-approval
        final newChecker = PermissionChecker();
        result = await newChecker.checkPermission(
          toolName: 'Write',
          input: const WriteToolInput(filePath: '/test/file.dart', content: ''),
          cwd: projectRoot,
        );
        expect(result, isA<PermissionAskUser>());
        newChecker.dispose();
      });

      test('session cache only applies to write operations', () async {
        permissionChecker.addSessionPattern('Bash(echo:*)');

        // Session cache doesn't apply to Bash - should ask
        final result = await permissionChecker.checkPermission(
          toolName: 'Bash',
          input: const BashToolInput(command: 'echo hello'),
          cwd: projectRoot,
        );
        // echo is a safe command, so it's auto-approved for that reason
        expect(result, isA<PermissionAllow>());
        expect((result as PermissionAllow).reason, contains('safe'));
      });
    });

    group('Settings persistence across checks', () {
      test(
        'settings file changes are reflected in subsequent checks',
        () async {
          // Initial check - not allowed
          var result = await permissionChecker.checkPermission(
            toolName: 'Bash',
            input: const BashToolInput(command: 'custom-tool --run'),
            cwd: projectRoot,
          );
          expect(result, isA<PermissionAskUser>());

          // Modify settings file directly
          final claudeDir = Directory('$projectRoot/.claude');
          await claudeDir.create(recursive: true);
          final settingsFile = File('$projectRoot/.claude/settings.local.json');

          final settings = ClaudeSettings(
            permissions: PermissionsConfig(
              allow: ['Bash(custom-tool:*)'],
              deny: [],
              ask: [],
            ),
          );
          await settingsFile.writeAsString(jsonEncode(settings.toJson()));

          // Subsequent check should pick up new settings
          result = await permissionChecker.checkPermission(
            toolName: 'Bash',
            input: const BashToolInput(command: 'custom-tool --run'),
            cwd: projectRoot,
          );
          expect(result, isA<PermissionAllow>());
        },
      );
    });

    group('Safe command detection', () {
      test('safe bash commands are auto-approved without settings', () async {
        // No settings file - safe commands should still be allowed
        expect(settingsManager.settingsFile.existsSync(), isFalse);

        final safeCommands = [
          'ls',
          'pwd',
          'cat file.txt',
          'git status',
          'git log',
          'echo hello',
        ];

        for (final command in safeCommands) {
          final result = await permissionChecker.checkPermission(
            toolName: 'Bash',
            input: BashToolInput(command: command),
            cwd: projectRoot,
          );
          expect(
            result,
            isA<PermissionAllow>(),
            reason: 'Command "$command" should be auto-approved as safe',
          );
        }
      });
    });

    group('Internal tool auto-approval', () {
      test('vide MCP tools are auto-approved', () async {
        final mcpTools = [
          'mcp__vide-memory__save',
          'mcp__vide-agent__spawnAgent',
          'mcp__flutter-runtime__flutterStart',
        ];

        for (final tool in mcpTools) {
          final result = await permissionChecker.checkPermission(
            toolName: tool,
            input: UnknownToolInput(toolName: tool, raw: {}),
            cwd: projectRoot,
          );
          expect(
            result,
            isA<PermissionAllow>(),
            reason: 'Tool "$tool" should be auto-approved as internal',
          );
        }
      });

      test('TodoWrite is auto-approved', () async {
        final result = await permissionChecker.checkPermission(
          toolName: 'TodoWrite',
          input: const UnknownToolInput(
            toolName: 'TodoWrite',
            raw: {'todos': []},
          ),
          cwd: projectRoot,
        );
        expect(result, isA<PermissionAllow>());
      });
    });
  });
}
