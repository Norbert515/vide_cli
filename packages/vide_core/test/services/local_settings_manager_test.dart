import 'dart:io';
import 'dart:convert';
import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';

void main() {
  group('LocalSettingsManager', () {
    late Directory tempDir;
    late String projectRoot;
    late LocalSettingsManager manager;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('local_settings_test_');
      projectRoot = tempDir.path;
      manager = LocalSettingsManager(
        projectRoot: projectRoot,
        parrottRoot: projectRoot,
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('settingsFile', () {
      test('returns correct path', () {
        expect(
          manager.settingsFile.path,
          '$projectRoot/.claude/settings.local.json',
        );
      });
    });

    group('readSettings', () {
      test('returns defaults when file does not exist', () async {
        final settings = await manager.readSettings();

        expect(settings.permissions.allow, isEmpty);
        expect(settings.permissions.deny, isEmpty);
      });

      test('reads existing settings', () async {
        // Create settings file
        final claudeDir = Directory('$projectRoot/.claude');
        await claudeDir.create(recursive: true);
        final settingsFile = File('$projectRoot/.claude/settings.local.json');

        final settings = ClaudeSettings(
          permissions: PermissionsConfig(
            allow: ['Read(**)', 'Write(**)'],
            deny: ['Bash(rm:*)'],
            ask: [],
          ),
        );
        await settingsFile.writeAsString(jsonEncode(settings.toJson()));

        final read = await manager.readSettings();

        expect(read.permissions.allow, contains('Read(**)'));
        expect(read.permissions.allow, contains('Write(**)'));
        expect(read.permissions.deny, contains('Bash(rm:*)'));
      });

      test('returns defaults on corrupt JSON', () async {
        final claudeDir = Directory('$projectRoot/.claude');
        await claudeDir.create(recursive: true);
        final settingsFile = File('$projectRoot/.claude/settings.local.json');
        await settingsFile.writeAsString('not valid json{{{');

        final settings = await manager.readSettings();

        expect(settings.permissions.allow, isEmpty);
        expect(settings.permissions.deny, isEmpty);
      });
    });

    group('addToAllowList', () {
      test('adds pattern to allow list', () async {
        await manager.addToAllowList('Bash(npm:*)');

        final settings = await manager.readSettings();
        expect(settings.permissions.allow, contains('Bash(npm:*)'));
      });

      test('creates .claude directory if not exists', () async {
        expect(Directory('$projectRoot/.claude').existsSync(), isFalse);

        await manager.addToAllowList('Read(**)');

        expect(Directory('$projectRoot/.claude').existsSync(), isTrue);
        expect(
          File('$projectRoot/.claude/settings.local.json').existsSync(),
          isTrue,
        );
      });

      test('preserves existing patterns', () async {
        await manager.addToAllowList('Bash(npm:*)');
        await manager.addToAllowList('Bash(dart:*)');

        final settings = await manager.readSettings();
        expect(settings.permissions.allow, contains('Bash(npm:*)'));
        expect(settings.permissions.allow, contains('Bash(dart:*)'));
      });

      test('does not duplicate existing pattern', () async {
        await manager.addToAllowList('Bash(npm:*)');
        await manager.addToAllowList('Bash(npm:*)');

        final settings = await manager.readSettings();
        final count = settings.permissions.allow
            .where((p) => p == 'Bash(npm:*)')
            .length;
        expect(count, 1);
      });

      test('preserves hooks when adding patterns', () async {
        // Create settings with hooks
        final claudeDir = Directory('$projectRoot/.claude');
        await claudeDir.create(recursive: true);
        final settingsFile = File('$projectRoot/.claude/settings.local.json');

        final initialSettings = {
          'permissions': {'allow': [], 'deny': [], 'ask': []},
          'hooks': {
            'PreToolUse': [
              {
                'matcher': 'Bash',
                'hooks': [
                  {'type': 'command', 'command': 'echo test', 'timeout': 5000},
                ],
              },
            ],
          },
        };
        await settingsFile.writeAsString(jsonEncode(initialSettings));

        await manager.addToAllowList('Read(**)');

        final settings = await manager.readSettings();
        expect(settings.hooks, isNotNull);
        expect(settings.hooks!.preToolUse, isNotEmpty);
      });
    });

    group('isCompiled', () {
      test('returns boolean based on executable name', () {
        // This is a bit tricky to test since we can't control the runtime
        // but we can at least verify it returns a boolean
        expect(LocalSettingsManager.isCompiled, isA<bool>());
      });
    });

    group('atomic writes', () {
      test('settings file is valid JSON after write', () async {
        await manager.addToAllowList('Pattern1');
        await manager.addToAllowList('Pattern2');
        await manager.addToAllowList('Pattern3');

        // Read the raw file to verify it's valid JSON
        final content = await manager.settingsFile.readAsString();
        expect(() => jsonDecode(content), returnsNormally);
      });

      test('file is formatted with indentation', () async {
        await manager.addToAllowList('Bash(npm:*)');

        final content = await manager.settingsFile.readAsString();
        expect(content, contains('\n')); // Has newlines
        expect(content, contains('  ')); // Has indentation
      });
    });
  });
}
