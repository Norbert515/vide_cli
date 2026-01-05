import 'dart:io';
import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';
import 'package:path/path.dart' as path;

void main() {
  group('VideConfigManager', () {
    late Directory tempDir;
    late VideConfigManager configManager;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('vide_config_test_');
      configManager = VideConfigManager(configRoot: tempDir.path);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('getProjectStorageDir', () {
      test('creates directory if not exists', () {
        final storageDir = configManager.getProjectStorageDir('/some/project');

        expect(Directory(storageDir).existsSync(), isTrue);
      });

      test('returns consistent path for same project', () {
        final path1 = configManager.getProjectStorageDir('/my/project');
        final path2 = configManager.getProjectStorageDir('/my/project');

        expect(path1, path2);
      });

      test('encodes slashes as hyphens', () {
        final storageDir = configManager.getProjectStorageDir(
          '/Users/bob/project',
        );

        expect(storageDir, contains('-Users-bob-project'));
      });

      test('different projects get different directories', () {
        final path1 = configManager.getProjectStorageDir('/project/one');
        final path2 = configManager.getProjectStorageDir('/project/two');

        expect(path1, isNot(path2));
      });
    });

    group('configRoot', () {
      test('returns the configured root', () {
        expect(configManager.configRoot, tempDir.path);
      });
    });

    group('listProjects', () {
      test('returns empty list when no projects', () {
        final projects = configManager.listProjects();

        expect(projects, isEmpty);
      });

      test('returns list of encoded project paths', () {
        configManager.getProjectStorageDir('/project/one');
        configManager.getProjectStorageDir('/project/two');

        final projects = configManager.listProjects();

        expect(projects.length, 2);
        expect(projects, containsAll(['-project-one', '-project-two']));
      });
    });

    group('global settings', () {
      test('returns defaults when file does not exist', () {
        final settings = configManager.readGlobalSettings();

        expect(settings.firstRunComplete, isFalse);
        expect(settings.theme, isNull);
      });

      test('writes and reads settings', () {
        final settings = VideGlobalSettings(
          firstRunComplete: true,
          theme: 'dark',
        );

        configManager.writeGlobalSettings(settings);
        final read = configManager.readGlobalSettings();

        expect(read.firstRunComplete, isTrue);
        expect(read.theme, 'dark');
      });

      test('handles corrupt JSON gracefully', () async {
        final settingsFile = File(path.join(tempDir.path, 'settings.json'));
        await settingsFile.create(recursive: true);
        await settingsFile.writeAsString('not valid json{{{');

        final settings = configManager.readGlobalSettings();

        // Should return defaults instead of throwing
        expect(settings.firstRunComplete, isFalse);
      });
    });

    group('isFirstRun', () {
      test('returns true when firstRunComplete is false', () {
        expect(configManager.isFirstRun(), isTrue);
      });

      test('returns false after markFirstRunComplete', () {
        configManager.markFirstRunComplete();

        expect(configManager.isFirstRun(), isFalse);
      });
    });

    group('markFirstRunComplete', () {
      test('persists first run complete state', () {
        configManager.markFirstRunComplete();

        // Create new instance to verify persistence
        final newManager = VideConfigManager(configRoot: tempDir.path);
        expect(newManager.isFirstRun(), isFalse);
      });
    });

    group('theme', () {
      test('getTheme returns null by default', () {
        expect(configManager.getTheme(), isNull);
      });

      test('setTheme persists theme', () {
        configManager.setTheme('dark');

        expect(configManager.getTheme(), 'dark');
      });

      test('setTheme with null clears theme', () {
        configManager.setTheme('dark');
        configManager.setTheme(null);

        expect(configManager.getTheme(), isNull);
      });

      test('theme persists across instances', () {
        configManager.setTheme('light');

        final newManager = VideConfigManager(configRoot: tempDir.path);
        expect(newManager.getTheme(), 'light');
      });
    });
  });
}
