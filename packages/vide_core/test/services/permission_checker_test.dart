import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';
import 'package:vide_core/src/models/claude_settings.dart';

void main() {
  group('PermissionChecker', () {
    late PermissionChecker checker;
    late Directory tempDir;
    late String cwd;

    setUp(() async {
      checker = PermissionChecker();
      tempDir = await Directory.systemTemp.createTemp('permission_test_');
      cwd = tempDir.path;

      // Create .claude directory for settings
      await Directory('$cwd/.claude').create(recursive: true);
    });

    tearDown(() async {
      checker.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    /// Helper to write settings file
    Future<void> writeSettings({
      List<String> allow = const [],
      List<String> deny = const [],
    }) async {
      final settings = ClaudeSettings(
        permissions: PermissionsConfig(allow: allow, deny: deny, ask: []),
      );
      final file = File('$cwd/.claude/settings.local.json');
      await file.writeAsString(jsonEncode(settings.toJson()));
    }

    group('internal tools auto-approval', () {
      test('auto-approves mcp__vide- tools', () async {
        final result = await checker.checkPermission(
          toolName: 'mcp__vide-agent__spawnAgent',
          input: const UnknownToolInput(
            toolName: 'mcp__vide-agent__spawnAgent',
            raw: {},
          ),
          cwd: cwd,
        );

        expect(result, isA<PermissionAllow>());
        expect((result as PermissionAllow).reason, contains('internal'));
      });

      test('auto-approves mcp__flutter-runtime__ tools', () async {
        final result = await checker.checkPermission(
          toolName: 'mcp__flutter-runtime__flutterStart',
          input: const UnknownToolInput(
            toolName: 'mcp__flutter-runtime__flutterStart',
            raw: {},
          ),
          cwd: cwd,
        );

        expect(result, isA<PermissionAllow>());
      });

      test('auto-approves TodoWrite', () async {
        final result = await checker.checkPermission(
          toolName: 'TodoWrite',
          input: const UnknownToolInput(toolName: 'TodoWrite', raw: {}),
          cwd: cwd,
        );

        expect(result, isA<PermissionAllow>());
      });

      test('auto-approves BashOutput', () async {
        final result = await checker.checkPermission(
          toolName: 'BashOutput',
          input: const UnknownToolInput(toolName: 'BashOutput', raw: {}),
          cwd: cwd,
        );

        expect(result, isA<PermissionAllow>());
      });

      test('auto-approves KillShell', () async {
        final result = await checker.checkPermission(
          toolName: 'KillShell',
          input: const UnknownToolInput(toolName: 'KillShell', raw: {}),
          cwd: cwd,
        );

        expect(result, isA<PermissionAllow>());
      });
    });

    group('hardcoded deny list', () {
      test('denies mcp__dart__analyze_files', () async {
        final result = await checker.checkPermission(
          toolName: 'mcp__dart__analyze_files',
          input: const UnknownToolInput(
            toolName: 'mcp__dart__analyze_files',
            raw: {},
          ),
          cwd: cwd,
        );

        expect(result, isA<PermissionDeny>());
        expect((result as PermissionDeny).reason, contains('floods context'));
      });
    });

    group('deny list from settings', () {
      test('denies tools matching deny pattern', () async {
        await writeSettings(deny: ['Bash(rm:*)']);

        final result = await checker.checkPermission(
          toolName: 'Bash',
          input: const BashToolInput(command: 'rm -rf /'),
          cwd: cwd,
        );

        expect(result, isA<PermissionDeny>());
        expect((result as PermissionDeny).reason, contains('deny list'));
      });

      test('deny list takes precedence over allow list', () async {
        await writeSettings(allow: ['Bash(*)'], deny: ['Bash(rm:*)']);

        final result = await checker.checkPermission(
          toolName: 'Bash',
          input: const BashToolInput(command: 'rm -rf /'),
          cwd: cwd,
        );

        expect(result, isA<PermissionDeny>());
      });
    });

    group('safe bash commands', () {
      test('auto-approves ls command', () async {
        final result = await checker.checkPermission(
          toolName: 'Bash',
          input: const BashToolInput(command: 'ls -la'),
          cwd: cwd,
        );

        expect(result, isA<PermissionAllow>());
        expect((result as PermissionAllow).reason, contains('safe'));
      });

      test('auto-approves pwd command', () async {
        final result = await checker.checkPermission(
          toolName: 'Bash',
          input: const BashToolInput(command: 'pwd'),
          cwd: cwd,
        );

        expect(result, isA<PermissionAllow>());
      });

      test('auto-approves git status command', () async {
        final result = await checker.checkPermission(
          toolName: 'Bash',
          input: const BashToolInput(command: 'git status'),
          cwd: cwd,
        );

        expect(result, isA<PermissionAllow>());
      });

      test('auto-approves cat command', () async {
        final result = await checker.checkPermission(
          toolName: 'Bash',
          input: const BashToolInput(command: 'cat file.txt'),
          cwd: cwd,
        );

        expect(result, isA<PermissionAllow>());
      });
    });

    group('session cache', () {
      test('allows write operations from session cache', () async {
        checker.addSessionPattern('Write($cwd/**)');

        final result = await checker.checkPermission(
          toolName: 'Write',
          input: WriteToolInput(filePath: '$cwd/lib/main.dart', content: ''),
          cwd: cwd,
        );

        expect(result, isA<PermissionAllow>());
        expect((result as PermissionAllow).reason, contains('session cache'));
      });

      test('allows edit operations from session cache', () async {
        checker.addSessionPattern('Edit($cwd/**)');

        final result = await checker.checkPermission(
          toolName: 'Edit',
          input: EditToolInput(
            filePath: '$cwd/lib/main.dart',
            oldString: '',
            newString: '',
          ),
          cwd: cwd,
        );

        expect(result, isA<PermissionAllow>());
      });

      test('session cache only applies to write operations', () async {
        checker.addSessionPattern('Bash(npm:*)');

        final result = await checker.checkPermission(
          toolName: 'Bash',
          input: const BashToolInput(command: 'npm install'),
          cwd: cwd,
        );

        // Session cache should NOT apply to Bash
        expect(result, isA<PermissionAskUser>());
      });

      test('clearSessionCache removes patterns', () async {
        checker.addSessionPattern('Write($cwd/**)');
        checker.clearSessionCache();

        final result = await checker.checkPermission(
          toolName: 'Write',
          input: WriteToolInput(filePath: '$cwd/lib/main.dart', content: ''),
          cwd: cwd,
        );

        expect(result, isA<PermissionAskUser>());
      });
    });

    group('allow list from settings', () {
      test('allows tools matching allow pattern', () async {
        await writeSettings(allow: ['Bash(npm:*)']);

        final result = await checker.checkPermission(
          toolName: 'Bash',
          input: const BashToolInput(command: 'npm install'),
          cwd: cwd,
        );

        expect(result, isA<PermissionAllow>());
        expect((result as PermissionAllow).reason, contains('allow list'));
      });

      test('allows WebFetch with domain pattern', () async {
        await writeSettings(allow: ['WebFetch(domain:pub.dev)']);

        final result = await checker.checkPermission(
          toolName: 'WebFetch',
          input: const WebFetchToolInput(
            url: 'https://pub.dev/packages/flutter',
          ),
          cwd: cwd,
        );

        expect(result, isA<PermissionAllow>());
      });
    });

    group('ask user', () {
      test('asks user for unmatched tools', () async {
        final result = await checker.checkPermission(
          toolName: 'Bash',
          input: const BashToolInput(command: 'npm install'),
          cwd: cwd,
        );

        expect(result, isA<PermissionAskUser>());
      });

      test('includes inferred pattern', () async {
        final result = await checker.checkPermission(
          toolName: 'Write',
          input: WriteToolInput(filePath: '$cwd/lib/main.dart', content: ''),
          cwd: cwd,
        );

        expect(result, isA<PermissionAskUser>());
        final askResult = result as PermissionAskUser;
        expect(askResult.inferredPattern, isNotNull);
      });
    });

    group('allow list runs before asking user', () {
      test(
        'returns PermissionAllow when allow list matches, even with deny askUserBehavior',
        () async {
          // Use a config that would deny if it reached the ask-user step
          final denyChecker = PermissionChecker(
            config: const PermissionCheckerConfig(
              askUserBehavior: AskUserBehavior.deny,
            ),
          );
          addTearDown(denyChecker.dispose);

          await writeSettings(allow: ['Bash(npm:*)']);

          final result = await denyChecker.checkPermission(
            toolName: 'Bash',
            input: const BashToolInput(command: 'npm install'),
            cwd: cwd,
          );

          expect(result, isA<PermissionAllow>());
          expect((result as PermissionAllow).reason, contains('allow list'));
        },
      );

      test(
        'returns PermissionDeny for unmatched tools when askUserBehavior is deny',
        () async {
          final denyChecker = PermissionChecker(
            config: const PermissionCheckerConfig(
              askUserBehavior: AskUserBehavior.deny,
            ),
          );
          addTearDown(denyChecker.dispose);

          final result = await denyChecker.checkPermission(
            toolName: 'Bash',
            input: const BashToolInput(command: 'npm install'),
            cwd: cwd,
          );

          expect(result, isA<PermissionDeny>());
        },
      );
    });

    group('isAllowedBySessionCache', () {
      test('returns true for matching write pattern', () {
        checker.addSessionPattern('Write(/path/**)');

        final allowed = checker.isAllowedBySessionCache(
          'Write',
          const WriteToolInput(filePath: '/path/to/file.dart', content: ''),
        );

        expect(allowed, isTrue);
      });

      test('returns false for non-write operations', () {
        checker.addSessionPattern('Bash(*)');

        final allowed = checker.isAllowedBySessionCache(
          'Bash',
          const BashToolInput(command: 'ls'),
        );

        expect(allowed, isFalse);
      });

      test('returns false when no patterns match', () {
        checker.addSessionPattern('Write(/other/**)');

        final allowed = checker.isAllowedBySessionCache(
          'Write',
          const WriteToolInput(filePath: '/path/to/file.dart', content: ''),
        );

        expect(allowed, isFalse);
      });
    });

    group('invalidateSettingsCache', () {
      test('re-reads settings from disk after invalidation', () async {
        // First check with no allow list — should ask user
        var result = await checker.checkPermission(
          toolName: 'Bash',
          input: const BashToolInput(command: 'npm install'),
          cwd: cwd,
        );
        expect(result, isA<PermissionAskUser>());

        // Write allow list to disk (simulating "remember")
        await writeSettings(allow: ['Bash(npm:*)']);

        // Without invalidation, cached settings are stale — still asks user
        result = await checker.checkPermission(
          toolName: 'Bash',
          input: const BashToolInput(command: 'npm install'),
          cwd: cwd,
        );
        expect(result, isA<PermissionAskUser>());

        // After invalidation, re-reads from disk — now allowed
        checker.invalidateSettingsCache();
        result = await checker.checkPermission(
          toolName: 'Bash',
          input: const BashToolInput(command: 'npm install'),
          cwd: cwd,
        );
        expect(result, isA<PermissionAllow>());
      });
    });

    group('indefinite permission waiting', () {
      test('permission requests return PermissionAskUser with no timeout — '
          'callers await indefinitely until explicitly resolved', () async {
        // This test documents INTENTIONAL behavior: when no allow/deny
        // list matches, PermissionChecker returns PermissionAskUser.
        // The caller (LocalVideSession) creates a Completer and awaits
        // it with NO timeout. The user can take as long as needed to
        // respond. Only explicit resolution or session disposal completes
        // the future.
        final result = await checker.checkPermission(
          toolName: 'Bash',
          input: const BashToolInput(command: 'npm install'),
          cwd: cwd,
        );

        // The result is PermissionAskUser, NOT PermissionDeny with a
        // timeout message. This confirms no timeout is applied at the
        // checker level.
        expect(result, isA<PermissionAskUser>());

        // Verify the result doesn't carry a timeout or expiry — it's
        // a pure "ask the user" signal with an optional inferred pattern.
        final askResult = result as PermissionAskUser;
        expect(askResult.inferredPattern, isNotNull);
      });
    });

    group('dispose', () {
      test('clears session cache', () async {
        checker.addSessionPattern('Write($cwd/**)');
        checker.dispose();

        // After dispose, session cache should be empty
        final allowed = checker.isAllowedBySessionCache(
          'Write',
          WriteToolInput(filePath: '$cwd/lib/main.dart', content: ''),
        );

        expect(allowed, isFalse);
      });
    });
  });

  group('PermissionCheckerConfig', () {
    test('tui config has default values', () {
      const config = PermissionCheckerConfig.tui;
      expect(config.enableSessionCache, isTrue);
      expect(config.loadSettings, isTrue);
      expect(config.respectGitignore, isTrue);
      expect(config.askUserBehavior, AskUserBehavior.ask);
    });

    test('testing config auto-allows and skips settings/gitignore', () {
      const config = PermissionCheckerConfig.testing;
      expect(config.askUserBehavior, AskUserBehavior.allow);
      expect(config.loadSettings, isFalse);
      expect(config.respectGitignore, isFalse);
    });
  });

  group('PermissionCheckResult', () {
    test('PermissionAllow carries reason', () {
      const result = PermissionAllow('Test reason');
      expect(result.reason, 'Test reason');
    });

    test('PermissionDeny carries reason', () {
      const result = PermissionDeny('Blocked');
      expect(result.reason, 'Blocked');
    });

    test('PermissionAskUser carries optional inferred pattern', () {
      const withPattern = PermissionAskUser(inferredPattern: 'Bash(npm:*)');
      const withoutPattern = PermissionAskUser();

      expect(withPattern.inferredPattern, 'Bash(npm:*)');
      expect(withoutPattern.inferredPattern, isNull);
    });
  });
}
