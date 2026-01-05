import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';
import '../helpers/mock_vide_config_manager.dart';

void main() {
  group('MemoryMCPServer', () {
    late MockVideConfigManager configManager;
    late MemoryService memoryService;
    late MemoryMCPServer server;
    late String projectPath;

    setUp(() async {
      configManager = await MockVideConfigManager.create();
      memoryService = MemoryService(configManager: configManager);
      projectPath = '/test/project';
      server = MemoryMCPServer(
        memoryService: memoryService,
        projectPath: projectPath,
      );
    });

    tearDown(() async {
      await configManager.dispose();
    });

    group('properties', () {
      test('has correct server name', () {
        expect(MemoryMCPServer.serverName, 'vide-memory');
        expect(server.name, 'vide-memory');
      });

      test('has correct version', () {
        expect(server.version, '1.0.0');
      });

      test('exposes tool names', () {
        expect(
          server.toolNames,
          containsAll([
            'memorySave',
            'memoryRetrieve',
            'memoryDelete',
            'memoryList',
          ]),
        );
      });

      test('exposes project path', () {
        expect(server.projectPath, projectPath);
      });

      test('exposes memory service', () {
        expect(server.memoryService, memoryService);
      });
    });

    // Note: Tool callback testing requires MCP protocol simulation.
    // The MemoryMCPServer is a thin wrapper around MemoryService,
    // which is thoroughly tested in memory_service_test.dart.
    // Here we verify the server is correctly configured.

    group('underlying service operations', () {
      test('memory service save works through server reference', () async {
        await server.memoryService.save(projectPath, 'key', 'value');

        final entry = await server.memoryService.retrieve(projectPath, 'key');
        expect(entry?.value, 'value');
      });

      test('server uses correct project path for scoping', () async {
        const otherProject = '/other/project';
        final otherServer = MemoryMCPServer(
          memoryService: memoryService,
          projectPath: otherProject,
        );

        // Save via first server's project path
        await memoryService.save(server.projectPath, 'key', 'value1');

        // Save via second server's project path
        await memoryService.save(otherServer.projectPath, 'key', 'value2');

        // Verify isolation
        final entry1 = await memoryService.retrieve(server.projectPath, 'key');
        final entry2 = await memoryService.retrieve(
          otherServer.projectPath,
          'key',
        );

        expect(entry1?.value, 'value1');
        expect(entry2?.value, 'value2');
      });
    });

    group('tool names coverage', () {
      test('includes memorySave tool', () {
        expect(server.toolNames, contains('memorySave'));
      });

      test('includes memoryRetrieve tool', () {
        expect(server.toolNames, contains('memoryRetrieve'));
      });

      test('includes memoryDelete tool', () {
        expect(server.toolNames, contains('memoryDelete'));
      });

      test('includes memoryList tool', () {
        expect(server.toolNames, contains('memoryList'));
      });

      test('has exactly 4 tools', () {
        expect(server.toolNames.length, 4);
      });
    });
  });
}
