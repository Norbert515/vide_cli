import 'package:test/test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:vide_core/vide_core.dart';
import '../helpers/mock_vide_config_manager.dart';

const _uuid = Uuid();

void main() {
  group('ClaudeClientFactory', () {
    late ProviderContainer container;
    late MockVideConfigManager configManager;

    setUp(() async {
      configManager = await MockVideConfigManager.create();
    });

    tearDown(() async {
      container.dispose();
      await configManager.dispose();
    });

    group('MCP provider chain', () {
      test('genericMcpServerProvider passes projectPath to memoryServerProvider', () {
        // Track the projectPath passed to memoryServerProvider
        String? capturedProjectPath;

        container = ProviderContainer(
          overrides: [
            videConfigManagerProvider.overrideWithValue(configManager),
            // Override memoryServerProvider to capture the projectPath
            memoryServerProvider.overrideWith((ref, params) {
              capturedProjectPath = params.projectPath;
              return MemoryMCPServer(
                memoryService: ref.watch(memoryServiceProvider),
                projectPath: params.projectPath,
              );
            }),
          ],
        );

        const expectedPath = '/test/working/directory';
        final agentId = _uuid.v4();

        // Call genericMcpServerProvider directly with our test params
        final params = AgentIdAndMcpServerType(
          agentId: agentId,
          mcpServerType: McpServerType.memory,
          projectPath: expectedPath,
        );

        container.read(genericMcpServerProvider(params));

        // Verify the memoryServerProvider received the correct projectPath
        expect(capturedProjectPath, expectedPath);
      });

      test('different project paths create different MCP server instances', () {
        final capturedPaths = <String>[];

        container = ProviderContainer(
          overrides: [
            videConfigManagerProvider.overrideWithValue(configManager),
            memoryServerProvider.overrideWith((ref, params) {
              capturedPaths.add(params.projectPath);
              return MemoryMCPServer(
                memoryService: ref.watch(memoryServiceProvider),
                projectPath: params.projectPath,
              );
            }),
          ],
        );

        // Call with different project paths
        container.read(genericMcpServerProvider(AgentIdAndMcpServerType(
          agentId: _uuid.v4(),
          mcpServerType: McpServerType.memory,
          projectPath: '/project/alpha',
        )));

        container.read(genericMcpServerProvider(AgentIdAndMcpServerType(
          agentId: _uuid.v4(),
          mcpServerType: McpServerType.memory,
          projectPath: '/project/beta',
        )));

        expect(capturedPaths, containsAll(['/project/alpha', '/project/beta']));
      });

      test('MemoryMCPServer exposes projectPath from params', () {
        container = ProviderContainer(
          overrides: [
            videConfigManagerProvider.overrideWithValue(configManager),
          ],
        );

        const testPath = '/test/path/with/slashes';
        final testAgentId = _uuid.v4();

        final server = container.read(memoryServerProvider((
          agentId: testAgentId,
          projectPath: testPath,
        )));

        expect(server.projectPath, testPath);
      });

      test('AgentIdAndMcpServerType equality includes projectPath', () {
        final agentId = _uuid.v4();

        final params1 = AgentIdAndMcpServerType(
          agentId: agentId,
          mcpServerType: McpServerType.memory,
          projectPath: '/path/a',
        );

        final params2 = AgentIdAndMcpServerType(
          agentId: agentId,
          mcpServerType: McpServerType.memory,
          projectPath: '/path/a',
        );

        final params3 = AgentIdAndMcpServerType(
          agentId: agentId,
          mcpServerType: McpServerType.memory,
          projectPath: '/path/b',
        );

        // Same projectPath should be equal
        expect(params1, equals(params2));
        expect(params1.hashCode, equals(params2.hashCode));

        // Different projectPath should not be equal
        expect(params1, isNot(equals(params3)));
      });

      test('provider caches servers by full params including projectPath', () {
        var createCount = 0;

        container = ProviderContainer(
          overrides: [
            videConfigManagerProvider.overrideWithValue(configManager),
            memoryServerProvider.overrideWith((ref, params) {
              createCount++;
              return MemoryMCPServer(
                memoryService: ref.watch(memoryServiceProvider),
                projectPath: params.projectPath,
              );
            }),
          ],
        );

        final agentId = _uuid.v4();

        // Same params should use cached instance
        final params = AgentIdAndMcpServerType(
          agentId: agentId,
          mcpServerType: McpServerType.memory,
          projectPath: '/project/one',
        );

        container.read(genericMcpServerProvider(params));
        container.read(genericMcpServerProvider(params));

        expect(createCount, 1); // Should only create once

        // Different projectPath should create new instance
        final differentPathParams = AgentIdAndMcpServerType(
          agentId: agentId,
          mcpServerType: McpServerType.memory,
          projectPath: '/project/two',
        );

        container.read(genericMcpServerProvider(differentPathParams));

        expect(createCount, 2); // Should create a second instance
      });
    });
  });
}
