import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';
import '../helpers/mock_vide_config_manager.dart';

/// Integration tests for Memory subsystem components working together.
///
/// Tests the interaction between:
/// - MemoryService (persistence layer)
/// - MemoryMCPServer (MCP interface)
/// - VideConfigManager (storage backend)
void main() {
  group('Memory Integration', () {
    late MockVideConfigManager configManager;
    late MemoryService memoryService;

    setUp(() async {
      configManager = await MockVideConfigManager.create();
      memoryService = MemoryService(configManager: configManager);
    });

    tearDown(() async {
      await configManager.dispose();
    });

    group('Multi-project isolation', () {
      test('different projects have isolated memory spaces', () async {
        const project1 = '/project/alpha';
        const project2 = '/project/beta';

        // Save same key in different projects
        await memoryService.save(project1, 'api_key', 'alpha-key-123');
        await memoryService.save(project2, 'api_key', 'beta-key-456');

        // Retrieve and verify isolation
        final entry1 = await memoryService.retrieve(project1, 'api_key');
        final entry2 = await memoryService.retrieve(project2, 'api_key');

        expect(entry1?.value, 'alpha-key-123');
        expect(entry2?.value, 'beta-key-456');
      });

      test('listing entries respects project scope', () async {
        const project1 = '/project/alpha';
        const project2 = '/project/beta';

        await memoryService.save(project1, 'key1', 'value1');
        await memoryService.save(project1, 'key2', 'value2');
        await memoryService.save(project2, 'key3', 'value3');

        final list1 = await memoryService.list(project1);
        final list2 = await memoryService.list(project2);

        expect(list1.length, 2);
        expect(list2.length, 1);
        expect(list1.map((e) => e.key), containsAll(['key1', 'key2']));
        expect(list2.map((e) => e.key), contains('key3'));
      });

      test('deleting from one project does not affect another', () async {
        const project1 = '/project/alpha';
        const project2 = '/project/beta';

        await memoryService.save(project1, 'shared_key', 'value1');
        await memoryService.save(project2, 'shared_key', 'value2');

        await memoryService.delete(project1, 'shared_key');

        final entry1 = await memoryService.retrieve(project1, 'shared_key');
        final entry2 = await memoryService.retrieve(project2, 'shared_key');

        expect(entry1, isNull);
        expect(entry2?.value, 'value2');
      });
    });

    group('MCP Server integration', () {
      test(
        'MCP servers for different projects share memory service but have scoped data',
        () async {
          const project1 = '/project/alpha';
          const project2 = '/project/beta';

          final server1 = MemoryMCPServer(
            memoryService: memoryService,
            projectPath: project1,
          );
          final server2 = MemoryMCPServer(
            memoryService: memoryService,
            projectPath: project2,
          );

          // Both servers share the same underlying service
          expect(server1.memoryService, same(server2.memoryService));

          // But operate on different project paths
          expect(server1.projectPath, project1);
          expect(server2.projectPath, project2);

          // Save via server references (simulating MCP tool calls)
          await server1.memoryService.save(
            server1.projectPath,
            'config',
            'config1',
          );
          await server2.memoryService.save(
            server2.projectPath,
            'config',
            'config2',
          );

          // Verify isolation
          final entry1 = await memoryService.retrieve(project1, 'config');
          final entry2 = await memoryService.retrieve(project2, 'config');

          expect(entry1?.value, 'config1');
          expect(entry2?.value, 'config2');
        },
      );
    });

    group('Persistence across service instances', () {
      test(
        'data persists when new MemoryService is created with same config',
        () async {
          const projectPath = '/test/project';

          // Save data with first service instance
          await memoryService.save(
            projectPath,
            'persistent_key',
            'persistent_value',
          );

          // Create new service instance with same config manager
          final newMemoryService = MemoryService(configManager: configManager);

          // Data should be retrievable
          final entry = await newMemoryService.retrieve(
            projectPath,
            'persistent_key',
          );
          expect(entry?.value, 'persistent_value');
        },
      );

      test('updates preserve existing entries', () async {
        const projectPath = '/test/project';

        // Save multiple entries
        await memoryService.save(projectPath, 'key1', 'value1');
        await memoryService.save(projectPath, 'key2', 'value2');
        await memoryService.save(projectPath, 'key3', 'value3');

        // Update one entry
        await memoryService.save(projectPath, 'key2', 'updated_value2');

        // All entries should exist
        final list = await memoryService.list(projectPath);
        expect(list.length, 3);

        // Verify the update
        final entry2 = await memoryService.retrieve(projectPath, 'key2');
        expect(entry2?.value, 'updated_value2');

        // Verify others unchanged
        final entry1 = await memoryService.retrieve(projectPath, 'key1');
        final entry3 = await memoryService.retrieve(projectPath, 'key3');
        expect(entry1?.value, 'value1');
        expect(entry3?.value, 'value3');
      });
    });

    group('Multiple operations', () {
      test('sequential saves to different keys succeed', () async {
        const projectPath = '/test/project';

        // Perform saves sequentially
        // Note: Concurrent saves to same file can cause race conditions,
        // so MemoryService operations should be sequential per project
        await memoryService.save(projectPath, 'seq_1', 'value1');
        await memoryService.save(projectPath, 'seq_2', 'value2');
        await memoryService.save(projectPath, 'seq_3', 'value3');
        await memoryService.save(projectPath, 'seq_4', 'value4');

        // All should be saved
        final list = await memoryService.list(projectPath);
        expect(list.length, 4);
      });

      test('concurrent reads return correct values', () async {
        const projectPath = '/test/project';

        // Setup data
        await memoryService.save(projectPath, 'read_key_1', 'read_value_1');
        await memoryService.save(projectPath, 'read_key_2', 'read_value_2');

        // Concurrent reads
        final results = await Future.wait([
          memoryService.retrieve(projectPath, 'read_key_1'),
          memoryService.retrieve(projectPath, 'read_key_2'),
          memoryService.retrieve(projectPath, 'read_key_1'),
          memoryService.retrieve(projectPath, 'read_key_2'),
        ]);

        expect(results[0]?.value, 'read_value_1');
        expect(results[1]?.value, 'read_value_2');
        expect(results[2]?.value, 'read_value_1');
        expect(results[3]?.value, 'read_value_2');
      });
    });
  });
}
