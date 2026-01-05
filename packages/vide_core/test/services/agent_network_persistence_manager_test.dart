import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';
import '../helpers/mock_vide_config_manager.dart';
import '../helpers/test_fixtures.dart';

void main() {
  group('AgentNetworkPersistenceManager', () {
    late MockVideConfigManager configManager;
    late AgentNetworkPersistenceManager persistenceManager;

    setUp(() async {
      configManager = await MockVideConfigManager.create();
      persistenceManager = AgentNetworkPersistenceManager(
        configManager: configManager,
        projectPath: '/test/project',
      );
    });

    tearDown(() async {
      await configManager.dispose();
    });

    group('loadNetworks', () {
      test('returns empty list when file does not exist', () async {
        final networks = await persistenceManager.loadNetworks();

        expect(networks, isEmpty);
      });

      test('loads networks from JSON file', () async {
        // Create initial networks
        final network1 = TestFixtures.agentNetwork(
          id: 'network-1',
          goal: 'Goal 1',
        );
        final network2 = TestFixtures.agentNetwork(
          id: 'network-2',
          goal: 'Goal 2',
        );

        await persistenceManager.saveNetworks([network1, network2]);

        final loaded = await persistenceManager.loadNetworks();

        expect(loaded.length, 2);
        expect(loaded[0].id, 'network-1');
        expect(loaded[0].goal, 'Goal 1');
        expect(loaded[1].id, 'network-2');
        expect(loaded[1].goal, 'Goal 2');
      });

      test('handles corrupt JSON gracefully', () async {
        // Save a valid network first to get the file path
        final network = TestFixtures.agentNetwork();
        await persistenceManager.saveNetwork(network);

        // Now corrupt the file
        final storageDir = configManager.getProjectStorageDir('/test/project');
        final file = File('$storageDir/agent_networks.json');
        await file.writeAsString('not valid json{{{');

        final loaded = await persistenceManager.loadNetworks();

        expect(loaded, isEmpty);
      });
    });

    group('saveNetworks', () {
      test('saves networks to JSON file', () async {
        final networks = [
          TestFixtures.agentNetwork(id: 'network-1'),
          TestFixtures.agentNetwork(id: 'network-2'),
        ];

        await persistenceManager.saveNetworks(networks);

        // Read the file directly
        final storageDir = configManager.getProjectStorageDir('/test/project');
        final file = File('$storageDir/agent_networks.json');
        final contents = await file.readAsString();
        final json = jsonDecode(contents) as Map<String, dynamic>;

        expect(json['networks'], isA<List>());
        expect((json['networks'] as List).length, 2);
      });

      test('creates storage directory if not exists', () async {
        final networks = [TestFixtures.agentNetwork()];

        await persistenceManager.saveNetworks(networks);

        final storageDir = configManager.getProjectStorageDir('/test/project');
        expect(Directory(storageDir).existsSync(), isTrue);
      });

      test('overwrites existing file', () async {
        final original = [TestFixtures.agentNetwork(id: 'original')];
        await persistenceManager.saveNetworks(original);

        final updated = [TestFixtures.agentNetwork(id: 'updated')];
        await persistenceManager.saveNetworks(updated);

        final loaded = await persistenceManager.loadNetworks();
        expect(loaded.length, 1);
        expect(loaded[0].id, 'updated');
      });
    });

    group('saveNetwork', () {
      test('adds new network', () async {
        final network = TestFixtures.agentNetwork(id: 'new-network');

        await persistenceManager.saveNetwork(network);

        final loaded = await persistenceManager.loadNetworks();
        expect(loaded.length, 1);
        expect(loaded[0].id, 'new-network');
      });

      test('updates existing network', () async {
        final network = TestFixtures.agentNetwork(
          id: 'my-network',
          goal: 'Original Goal',
        );
        await persistenceManager.saveNetwork(network);

        final updated = network.copyWith(goal: 'Updated Goal');
        await persistenceManager.saveNetwork(updated);

        final loaded = await persistenceManager.loadNetworks();
        expect(loaded.length, 1);
        expect(loaded[0].goal, 'Updated Goal');
      });

      test('preserves other networks when updating', () async {
        final network1 = TestFixtures.agentNetwork(
          id: 'network-1',
          goal: 'Goal 1',
        );
        final network2 = TestFixtures.agentNetwork(
          id: 'network-2',
          goal: 'Goal 2',
        );

        await persistenceManager.saveNetwork(network1);
        await persistenceManager.saveNetwork(network2);

        // Update network1
        final updated1 = network1.copyWith(goal: 'Updated Goal 1');
        await persistenceManager.saveNetwork(updated1);

        final loaded = await persistenceManager.loadNetworks();
        expect(loaded.length, 2);

        final loadedNetwork1 = loaded.firstWhere((n) => n.id == 'network-1');
        final loadedNetwork2 = loaded.firstWhere((n) => n.id == 'network-2');

        expect(loadedNetwork1.goal, 'Updated Goal 1');
        expect(loadedNetwork2.goal, 'Goal 2');
      });
    });

    group('deleteNetwork', () {
      test('deletes existing network', () async {
        final network = TestFixtures.agentNetwork(id: 'to-delete');
        await persistenceManager.saveNetwork(network);

        await persistenceManager.deleteNetwork('to-delete');

        final loaded = await persistenceManager.loadNetworks();
        expect(loaded, isEmpty);
      });

      test('preserves other networks when deleting', () async {
        final network1 = TestFixtures.agentNetwork(id: 'network-1');
        final network2 = TestFixtures.agentNetwork(id: 'network-2');

        await persistenceManager.saveNetwork(network1);
        await persistenceManager.saveNetwork(network2);

        await persistenceManager.deleteNetwork('network-1');

        final loaded = await persistenceManager.loadNetworks();
        expect(loaded.length, 1);
        expect(loaded[0].id, 'network-2');
      });

      test('is safe for non-existent network', () async {
        final network = TestFixtures.agentNetwork(id: 'existing');
        await persistenceManager.saveNetwork(network);

        // Should not throw
        await persistenceManager.deleteNetwork('non-existent');

        final loaded = await persistenceManager.loadNetworks();
        expect(loaded.length, 1);
      });
    });

    group('persistence across instances', () {
      test('data persists across manager instances', () async {
        final network = TestFixtures.agentNetwork(id: 'persistent');
        await persistenceManager.saveNetwork(network);

        // Create new manager instance
        final newManager = AgentNetworkPersistenceManager(
          configManager: configManager,
          projectPath: '/test/project',
        );

        final loaded = await newManager.loadNetworks();
        expect(loaded.length, 1);
        expect(loaded[0].id, 'persistent');
      });
    });

    group('agent metadata preservation', () {
      test('preserves full agent metadata through serialization', () async {
        final agents = [
          AgentMetadata(
            id: 'main-agent',
            name: 'Main',
            type: 'main',
            createdAt: DateTime(2024, 1, 15, 10, 30),
            status: AgentStatus.working,
          ),
          AgentMetadata(
            id: 'impl-agent',
            name: 'Implementation',
            type: 'implementation',
            spawnedBy: 'main-agent',
            createdAt: DateTime(2024, 1, 15, 10, 35),
            status: AgentStatus.waitingForAgent,
            taskName: 'Fix bug',
          ),
        ];

        final network = AgentNetwork(
          id: 'network-1',
          goal: 'Test Goal',
          agents: agents,
          createdAt: DateTime(2024, 1, 15, 10, 30),
          lastActiveAt: DateTime(2024, 1, 15, 11, 0),
          worktreePath: '/path/to/worktree',
        );

        await persistenceManager.saveNetwork(network);
        final loaded = (await persistenceManager.loadNetworks()).first;

        expect(loaded.agents.length, 2);

        final mainAgent = loaded.agents.firstWhere((a) => a.id == 'main-agent');
        expect(mainAgent.name, 'Main');
        expect(mainAgent.type, 'main');
        expect(mainAgent.status, AgentStatus.working);

        final implAgent = loaded.agents.firstWhere((a) => a.id == 'impl-agent');
        expect(implAgent.name, 'Implementation');
        expect(implAgent.type, 'implementation');
        expect(implAgent.spawnedBy, 'main-agent');
        expect(implAgent.status, AgentStatus.waitingForAgent);
        expect(implAgent.taskName, 'Fix bug');

        expect(loaded.worktreePath, '/path/to/worktree');
      });
    });
  });
}
