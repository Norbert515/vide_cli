import 'dart:io';
import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';
import 'package:mcp_dart/mcp_dart.dart';
import '../helpers/mock_vide_config_manager.dart';

void main() {
  group('MemoryMCPServer', () {
    late MockVideConfigManager configManager;
    late MemoryService memoryService;
    late MemoryMCPServer server;
    late McpServer mcpServer;
    late String projectPath;

    setUp(() async {
      configManager = await MockVideConfigManager.create();
      memoryService = MemoryService(configManager: configManager);
      projectPath = '/test/project';
      server = MemoryMCPServer(
        memoryService: memoryService,
        projectPath: projectPath,
      );
      mcpServer = McpServer(server.serverInfo);
      server.registerTools(mcpServer);
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
          containsAll(['memorySave', 'memoryRetrieve', 'memoryDelete', 'memoryList']),
        );
      });

      test('exposes project path', () {
        expect(server.projectPath, projectPath);
      });

      test('exposes memory service', () {
        expect(server.memoryService, memoryService);
      });
    });

    group('memorySave tool', () {
      test('saves value successfully', () async {
        final handler = mcpServer.getToolHandler('memorySave');
        expect(handler, isNotNull);

        final result = await handler!(
          args: {'key': 'test_key', 'value': 'test_value'},
          extra: null,
        );

        expect(result.content.first, isA<TextContent>());
        final text = (result.content.first as TextContent).text;
        expect(text, contains('saved successfully'));
        expect(text, contains('test_key'));

        // Verify it was actually saved
        final entry = await memoryService.retrieve(projectPath, 'test_key');
        expect(entry?.value, 'test_value');
      });

      test('returns error when no args provided', () async {
        final handler = mcpServer.getToolHandler('memorySave');

        final result = await handler!(args: null, extra: null);

        final text = (result.content.first as TextContent).text;
        expect(text, contains('Error'));
        expect(text, contains('No arguments'));
      });
    });

    group('memoryRetrieve tool', () {
      test('retrieves existing value', () async {
        await memoryService.save(projectPath, 'existing_key', 'stored_value');

        final handler = mcpServer.getToolHandler('memoryRetrieve');
        final result = await handler!(
          args: {'key': 'existing_key'},
          extra: null,
        );

        final text = (result.content.first as TextContent).text;
        expect(text, 'stored_value');
      });

      test('returns not found for non-existent key', () async {
        final handler = mcpServer.getToolHandler('memoryRetrieve');
        final result = await handler!(
          args: {'key': 'non_existent'},
          extra: null,
        );

        final text = (result.content.first as TextContent).text;
        expect(text, contains('No memory found'));
        expect(text, contains('non_existent'));
      });

      test('returns error when no args provided', () async {
        final handler = mcpServer.getToolHandler('memoryRetrieve');

        final result = await handler!(args: null, extra: null);

        final text = (result.content.first as TextContent).text;
        expect(text, contains('Error'));
      });
    });

    group('memoryDelete tool', () {
      test('deletes existing value', () async {
        await memoryService.save(projectPath, 'to_delete', 'value');

        final handler = mcpServer.getToolHandler('memoryDelete');
        final result = await handler!(
          args: {'key': 'to_delete'},
          extra: null,
        );

        final text = (result.content.first as TextContent).text;
        expect(text, contains('deleted successfully'));

        // Verify it was actually deleted
        final entry = await memoryService.retrieve(projectPath, 'to_delete');
        expect(entry, isNull);
      });

      test('returns not found for non-existent key', () async {
        final handler = mcpServer.getToolHandler('memoryDelete');
        final result = await handler!(
          args: {'key': 'non_existent'},
          extra: null,
        );

        final text = (result.content.first as TextContent).text;
        expect(text, contains('No memory found'));
      });

      test('returns error when no args provided', () async {
        final handler = mcpServer.getToolHandler('memoryDelete');

        final result = await handler!(args: null, extra: null);

        final text = (result.content.first as TextContent).text;
        expect(text, contains('Error'));
      });
    });

    group('memoryList tool', () {
      test('lists all keys', () async {
        await memoryService.save(projectPath, 'key1', 'value1');
        await memoryService.save(projectPath, 'key2', 'value2');
        await memoryService.save(projectPath, 'key3', 'value3');

        final handler = mcpServer.getToolHandler('memoryList');
        final result = await handler!(args: {}, extra: null);

        final text = (result.content.first as TextContent).text;
        expect(text, contains('3'));
        expect(text, contains('key1'));
        expect(text, contains('key2'));
        expect(text, contains('key3'));
      });

      test('returns message when no memories stored', () async {
        final handler = mcpServer.getToolHandler('memoryList');
        final result = await handler!(args: {}, extra: null);

        final text = (result.content.first as TextContent).text;
        expect(text, contains('No memories stored'));
      });

      test('sorts keys alphabetically', () async {
        await memoryService.save(projectPath, 'zulu', 'value');
        await memoryService.save(projectPath, 'alpha', 'value');
        await memoryService.save(projectPath, 'mike', 'value');

        final handler = mcpServer.getToolHandler('memoryList');
        final result = await handler!(args: {}, extra: null);

        final text = (result.content.first as TextContent).text;
        final alphaPos = text.indexOf('alpha');
        final mikePos = text.indexOf('mike');
        final zuluPos = text.indexOf('zulu');

        expect(alphaPos, lessThan(mikePos));
        expect(mikePos, lessThan(zuluPos));
      });
    });

    group('project scoping', () {
      test('operations are scoped to project path', () async {
        final otherProjectPath = '/other/project';
        final otherServer = MemoryMCPServer(
          memoryService: memoryService,
          projectPath: otherProjectPath,
        );
        final otherMcpServer = McpServer(otherServer.serverInfo);
        otherServer.registerTools(otherMcpServer);

        // Save to first project
        await memoryService.save(projectPath, 'shared_key', 'project1_value');

        // Save to second project
        await memoryService.save(otherProjectPath, 'shared_key', 'project2_value');

        // Retrieve from first project
        final handler1 = mcpServer.getToolHandler('memoryRetrieve');
        final result1 = await handler1!(
          args: {'key': 'shared_key'},
          extra: null,
        );
        expect((result1.content.first as TextContent).text, 'project1_value');

        // Retrieve from second project
        final handler2 = otherMcpServer.getToolHandler('memoryRetrieve');
        final result2 = await handler2!(
          args: {'key': 'shared_key'},
          extra: null,
        );
        expect((result2.content.first as TextContent).text, 'project2_value');
      });
    });
  });
}
