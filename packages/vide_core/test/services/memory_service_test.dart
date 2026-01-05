import 'dart:io';
import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';
import '../helpers/mock_vide_config_manager.dart';

void main() {
  group('MemoryService', () {
    late MockVideConfigManager configManager;
    late MemoryService memoryService;
    late String testProjectPath;

    setUp(() async {
      configManager = await MockVideConfigManager.create();
      memoryService = MemoryService(configManager: configManager);
      testProjectPath = '/test/project';
    });

    tearDown(() async {
      await configManager.dispose();
    });

    group('save and retrieve', () {
      test('saves and retrieves a value', () async {
        await memoryService.save(
          testProjectPath,
          'build_command',
          'flutter run',
        );

        final entry = await memoryService.retrieve(
          testProjectPath,
          'build_command',
        );

        expect(entry, isNotNull);
        expect(entry!.key, 'build_command');
        expect(entry.value, 'flutter run');
        expect(entry.createdAt, isNotNull);
        expect(entry.updatedAt, isNull);
      });

      test('returns null for non-existent key', () async {
        final entry = await memoryService.retrieve(
          testProjectPath,
          'non_existent',
        );

        expect(entry, isNull);
      });

      test('updates existing value', () async {
        await memoryService.save(testProjectPath, 'platform', 'web');
        final original = await memoryService.retrieve(
          testProjectPath,
          'platform',
        );

        // Small delay to ensure different timestamps
        await Future.delayed(Duration(milliseconds: 10));

        await memoryService.save(testProjectPath, 'platform', 'ios');
        final updated = await memoryService.retrieve(
          testProjectPath,
          'platform',
        );

        expect(updated, isNotNull);
        expect(updated!.value, 'ios');
        expect(updated.createdAt, original!.createdAt); // Same createdAt
        expect(updated.updatedAt, isNotNull); // Has updatedAt
      });

      test('handles special characters in value', () async {
        final specialValue = 'Line1\nLine2\t"quoted"\n{json: true}';

        await memoryService.save(testProjectPath, 'notes', specialValue);
        final entry = await memoryService.retrieve(testProjectPath, 'notes');

        expect(entry!.value, specialValue);
      });
    });

    group('delete', () {
      test('deletes existing entry', () async {
        await memoryService.save(testProjectPath, 'to_delete', 'value');

        final deleted = await memoryService.delete(
          testProjectPath,
          'to_delete',
        );

        expect(deleted, isTrue);

        final entry = await memoryService.retrieve(
          testProjectPath,
          'to_delete',
        );
        expect(entry, isNull);
      });

      test('returns false for non-existent key', () async {
        final deleted = await memoryService.delete(
          testProjectPath,
          'non_existent',
        );

        expect(deleted, isFalse);
      });
    });

    group('list and listKeys', () {
      test('lists all entries for project', () async {
        await memoryService.save(testProjectPath, 'key1', 'value1');
        await memoryService.save(testProjectPath, 'key2', 'value2');
        await memoryService.save(testProjectPath, 'key3', 'value3');

        final entries = await memoryService.list(testProjectPath);

        expect(entries.length, 3);
        expect(
          entries.map((e) => e.key),
          containsAll(['key1', 'key2', 'key3']),
        );
      });

      test('lists all keys for project', () async {
        await memoryService.save(testProjectPath, 'key1', 'value1');
        await memoryService.save(testProjectPath, 'key2', 'value2');

        final keys = await memoryService.listKeys(testProjectPath);

        expect(keys, containsAll(['key1', 'key2']));
      });

      test('returns empty list when no entries', () async {
        final entries = await memoryService.list(testProjectPath);
        final keys = await memoryService.listKeys(testProjectPath);

        expect(entries, isEmpty);
        expect(keys, isEmpty);
      });
    });

    group('project isolation', () {
      test('entries are scoped by project path', () async {
        const project1 = '/project/one';
        const project2 = '/project/two';

        await memoryService.save(project1, 'key', 'value1');
        await memoryService.save(project2, 'key', 'value2');

        final entry1 = await memoryService.retrieve(project1, 'key');
        final entry2 = await memoryService.retrieve(project2, 'key');

        expect(entry1!.value, 'value1');
        expect(entry2!.value, 'value2');
      });

      test('deleting from one project does not affect another', () async {
        const project1 = '/project/one';
        const project2 = '/project/two';

        await memoryService.save(project1, 'shared_key', 'value1');
        await memoryService.save(project2, 'shared_key', 'value2');

        await memoryService.delete(project1, 'shared_key');

        final entry1 = await memoryService.retrieve(project1, 'shared_key');
        final entry2 = await memoryService.retrieve(project2, 'shared_key');

        expect(entry1, isNull);
        expect(entry2!.value, 'value2');
      });
    });

    group('persistence', () {
      test('entries persist across service instances', () async {
        await memoryService.save(testProjectPath, 'persistent', 'data');

        // Create new service instance
        final newService = MemoryService(configManager: configManager);
        final entry = await newService.retrieve(testProjectPath, 'persistent');

        expect(entry!.value, 'data');
      });
    });

    group('getAllProjectPaths', () {
      test('returns all projects with memory files', () async {
        await memoryService.save('/project/one', 'key', 'value');
        await memoryService.save('/project/two', 'key', 'value');

        final paths = await memoryService.getAllProjectPaths();

        expect(paths.length, 2);
        expect(paths, containsAll(['/project/one', '/project/two']));
      });

      test('returns empty list when no projects', () async {
        final paths = await memoryService.getAllProjectPaths();

        expect(paths, isEmpty);
      });
    });

    group('getAllEntries', () {
      test('returns entries grouped by project', () async {
        await memoryService.save('/project/one', 'key1', 'value1');
        await memoryService.save('/project/one', 'key2', 'value2');
        await memoryService.save('/project/two', 'key3', 'value3');

        final allEntries = await memoryService.getAllEntries();

        expect(allEntries.length, 2);
        expect(allEntries['/project/one']?.length, 2);
        expect(allEntries['/project/two']?.length, 1);
      });

      test('excludes projects with no entries', () async {
        await memoryService.save('/project/one', 'key', 'value');
        await memoryService.delete('/project/one', 'key');

        // Project one now has file but no entries
        final allEntries = await memoryService.getAllEntries();

        expect(allEntries['/project/one'], isNull);
      });
    });

    group('error handling', () {
      test('handles corrupt JSON gracefully', () async {
        // Save a valid entry first to create the file
        await memoryService.save(testProjectPath, 'key', 'value');

        // Corrupt the file
        final storagePath = configManager.getProjectStorageDir(testProjectPath);
        final memoryFile = File('$storagePath/memory.json');
        await memoryFile.writeAsString('not valid json{{{');

        // Should return empty rather than throwing
        final entries = await memoryService.list(testProjectPath);
        expect(entries, isEmpty);

        final entry = await memoryService.retrieve(testProjectPath, 'key');
        expect(entry, isNull);
      });
    });
  });
}
