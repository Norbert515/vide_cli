import 'dart:io';
import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';

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
        permissions: PermissionsConfig(
          allow: allow,
          deny: deny,
          ask: [],
        ),
      );
      final file = File('$cwd/.claude/settings.local.json');
      await file.writeAsString('${settings.toJson()}');
    }

    group('internal tools auto-approval', () {
      test('auto-approves mcp__vide- tools', () async {
        final result = await checker.checkPermission(
          toolName: 'mcp__vide-agent__spawnAgent',
          toolInput: {},
          cwd: cwd,
        );

        expect(result, isA<PermissionAllow>());
        expect((result as PermissionAllow).reason, contains('internal'));
      });

      test('auto-approves mcp__flutter-runtime__ tools', () async {
        final result = await checker.checkPermission(
          toolName: 'mcp__flutter-runtime__flutterStart',
          toolInput: {},
          cwd: cwd,
        );

        expect(result, isA<PermissionAllow>());
      });

      test('auto-approves TodoWrite', () async {
        final result = await checker.checkPermission(
          toolName: 'TodoWrite',
          toolInput: {},
          cwd: cwd,
        );

        expect(result, isA<PermissionAllow>());
      });

      test('auto-approves BashOutput', () async {
        final result = await checker.checkPermission(
          toolName: 'BashOutput',
          toolInput: {},
          cwd: cwd,
        );

        expect(result, isA<PermissionAllow>());
      });

      test('auto-approves KillShell', () async {
        final result = await checker.checkPermission(
          toolName: 'KillShell',
          toolInput: {},
          cwd: cwd,
        );

        expect(result, isA<PermissionAllow>());
      });
    });

    group('hardcoded deny list', () {
      test('denies mcp__dart__analyze_files', () async {
        final result = await checker.checkPermission(
          toolName: 'mcp__dart__analyze_files',
          toolInput: {},
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
          toolInput: {'command': 'rm -rf /'},
          cwd: cwd,
        );

        expect(result, isA<PermissionDeny>());
        expect((result as PermissionDeny).reason, contains('deny list'));
      });

      test('deny list takes precedence over allow list', () async {
        await writeSettings(
          allow: ['Bash(*)'],
          deny: ['Bash(rm:*)'],
        );

        final result = await checker.checkPermission(
          toolName: 'Bash',
          toolInput: {'command': 'rm -rf /'},
          cwd: cwd,
        );

        expect(result, isA<PermissionDeny>());
      });
    });

    group('safe bash commands', () {
      test('auto-approves ls command', () async {
        final result = await checker.checkPermission(
          toolName: 'Bash',
          toolInput: {'command': 'ls -la'},
          cwd: cwd,
        );

        expect(result, isA<PermissionAllow>());
        expect((result as PermissionAllow).reason, contains('safe'));
      });

      test('auto-approves pwd command', () async {
        final result = await checker.checkPermission(
          toolName: 'Bash',
          toolInput: {'command': 'pwd'},
          cwd: cwd,
        );

        expect(result, isA<PermissionAllow>());
      });

      test('auto-approves git status command', () async {
        final result = await checker.checkPermission(
          toolName: 'Bash',
          toolInput: {'command': 'git status'},
          cwd: cwd,
        );

        expect(result, isA<PermissionAllow>());
      });

      test('auto-approves cat command', () async {
        final result = await checker.checkPermission(
          toolName: 'Bash',
          toolInput: {'command': 'cat file.txt'},
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
          toolInput: {'file_path': '$cwd/lib/main.dart'},
          cwd: cwd,
        );

        expect(result, isA<PermissionAllow>());
        expect((result as PermissionAllow).reason, contains('session cache'));
      });

      test('allows edit operations from session cache', () async {
        checker.addSessionPattern('Edit($cwd/**)');

        final result = await checker.checkPermission(
          toolName: 'Edit',
          toolInput: {'file_path': '$cwd/lib/main.dart'},
          cwd: cwd,
        );

        expect(result, isA<PermissionAllow>());
      });

      test('session cache only applies to write operations', () async {
        checker.addSessionPattern('Bash(npm:*)');

        final result = await checker.checkPermission(
          toolName: 'Bash',
          toolInput: {'command': 'npm install'},
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
          toolInput: {'file_path': '$cwd/lib/main.dart'},
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
          toolInput: {'command': 'npm install'},
          cwd: cwd,
        );

        expect(result, isA<PermissionAllow>());
        expect((result as PermissionAllow).reason, contains('allow list'));
      });

      test('allows WebFetch with domain pattern', () async {
        await writeSettings(allow: ['WebFetch(domain:pub.dev)']);

        final result = await checker.checkPermission(
          toolName: 'WebFetch',
          toolInput: {'url': 'https://pub.dev/packages/flutter'},
          cwd: cwd,
        );

        expect(result, isA<PermissionAllow>());
      });
    });

    group('ask user', () {
      test('asks user for unmatched tools', () async {
        final result = await checker.checkPermission(
          toolName: 'Bash',
          toolInput: {'command': 'npm install'},
          cwd: cwd,
        );

        expect(result, isA<PermissionAskUser>());
      });

      test('includes inferred pattern', () async {
        final result = await checker.checkPermission(
          toolName: 'Write',
          toolInput: {'file_path': '$cwd/lib/main.dart'},
          cwd: cwd,
        );

        expect(result, isA<PermissionAskUser>());
        final askResult = result as PermissionAskUser;
        expect(askResult.inferredPattern, isNotNull);
      });
    });

    group('isAllowedBySessionCache', () {
      test('returns true for matching write pattern', () {
        checker.addSessionPattern('Write(/path/**)');

        final allowed = checker.isAllowedBySessionCache(
          'Write',
          {'file_path': '/path/to/file.dart'},
        );

        expect(allowed, isTrue);
      });

      test('returns false for non-write operations', () {
        checker.addSessionPattern('Bash(*)');

        final allowed = checker.isAllowedBySessionCache(
          'Bash',
          {'command': 'ls'},
        );

        expect(allowed, isFalse);
      });

      test('returns false when no patterns match', () {
        checker.addSessionPattern('Write(/other/**)');

        final allowed = checker.isAllowedBySessionCache(
          'Write',
          {'file_path': '/path/to/file.dart'},
        );

        expect(allowed, isFalse);
      });
    });

    group('dispose', () {
      test('clears session cache', () async {
        checker.addSessionPattern('Write($cwd/**)');
        checker.dispose();

        // After dispose, session cache should be empty
        final allowed = checker.isAllowedBySessionCache(
          'Write',
          {'file_path': '$cwd/lib/main.dart'},
        );

        expect(allowed, isFalse);
      });
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
