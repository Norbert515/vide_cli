import 'dart:io';

import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';

import '../helpers/mock_vide_config_manager.dart';
import '../helpers/test_fixtures.dart';

/// Tests for AgentNetworkManager.resume() functionality.
///
/// These tests verify that resuming a session correctly populates
/// the agent network state with the resumed network's agents.
void main() {
  group('AgentNetworkManager.resume', () {
    late ProviderContainer container;
    late MockVideConfigManager configManager;
    late Directory testWorkingDir;

    setUp(() async {
      configManager = await MockVideConfigManager.create();
      testWorkingDir = await Directory.systemTemp.createTemp('vide_test_wd_');

      container = ProviderContainer(
        overrides: [
          workingDirProvider.overrideWithValue(testWorkingDir.path),
          videConfigManagerProvider.overrideWithValue(configManager),
          permissionHandlerProvider.overrideWithValue(PermissionHandler()),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await configManager.dispose();
      if (testWorkingDir.existsSync()) {
        await testWorkingDir.delete(recursive: true);
      }
    });

    test('state.currentNetwork is set immediately with resumed network', () async {
      // Create a network with multiple agents to resume
      final agents = [
        AgentMetadata(
          id: 'main-agent',
          name: 'Lead',
          type: 'main',
          createdAt: DateTime.now(),
        ),
        AgentMetadata(
          id: 'impl-agent',
          name: 'Implementer',
          type: 'implementer',
          spawnedBy: 'main-agent',
          createdAt: DateTime.now(),
        ),
        AgentMetadata(
          id: 'researcher-agent',
          name: 'Researcher',
          type: 'researcher',
          spawnedBy: 'main-agent',
          createdAt: DateTime.now(),
        ),
      ];

      final networkToResume = AgentNetwork(
        id: 'test-network-123',
        goal: 'Test resume functionality',
        agents: agents,
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
        team: 'vide',
      );

      // Get the manager
      final manager = container.read(agentNetworkManagerProvider.notifier);

      // Before resume, currentNetwork should be null
      var state = container.read(agentNetworkManagerProvider);
      expect(state.currentNetwork, isNull);
      expect(state.agents, isEmpty);

      // Resume the network - this may fail due to team framework loading,
      // but we're testing the immediate state update behavior
      try {
        await manager.resume(networkToResume);
      } catch (e) {
        // Expected: TeamFrameworkLoader may fail in test environment
        // But the state should have been set BEFORE the error
      }

      // After resume attempt, currentNetwork should be set with our agents
      state = container.read(agentNetworkManagerProvider);
      expect(state.currentNetwork, isNotNull);
      expect(state.currentNetwork!.id, equals('test-network-123'));
      expect(state.currentNetwork!.goal, equals('Test resume functionality'));
      expect(state.agents.length, equals(3));

      // Verify all agent IDs are present
      final agentIds = state.agents.map((a) => a.id).toList();
      expect(agentIds, containsAll(['main-agent', 'impl-agent', 'researcher-agent']));

      // Verify agent metadata is preserved
      final mainAgent = state.agents.firstWhere((a) => a.id == 'main-agent');
      expect(mainAgent.name, equals('Lead'));
      expect(mainAgent.type, equals('main'));

      final implAgent = state.agents.firstWhere((a) => a.id == 'impl-agent');
      expect(implAgent.name, equals('Implementer'));
      expect(implAgent.type, equals('implementer'));
      expect(implAgent.spawnedBy, equals('main-agent'));
    });

    test('state.agents convenience getter returns network agents', () async {
      final agents = [
        TestFixtures.agentMetadata(id: 'agent-1', name: 'Agent 1', type: 'main'),
        TestFixtures.agentMetadata(id: 'agent-2', name: 'Agent 2', type: 'implementer'),
      ];

      final network = TestFixtures.agentNetwork(
        id: 'network-1',
        goal: 'Test agents getter',
        agents: agents,
      ).copyWith(team: 'vide');

      final manager = container.read(agentNetworkManagerProvider.notifier);

      try {
        await manager.resume(network);
      } catch (e) {
        // Expected in test environment
      }

      final state = container.read(agentNetworkManagerProvider);

      // state.agents should be the convenience getter that returns network.agents
      expect(state.agents, isNotEmpty);
      expect(state.agents.length, equals(2));
      expect(state.agentIds, containsAll(['agent-1', 'agent-2']));
    });

    test('resume updates lastActiveAt timestamp', () async {
      final originalLastActive = DateTime(2024, 1, 1, 10, 0);
      final network = AgentNetwork(
        id: 'network-timestamp-test',
        goal: 'Test timestamp update',
        agents: [
          AgentMetadata(
            id: 'agent-1',
            name: 'Agent',
            type: 'main',
            createdAt: DateTime.now(),
          ),
        ],
        createdAt: DateTime(2024, 1, 1, 9, 0),
        lastActiveAt: originalLastActive,
        team: 'vide',
      );

      final manager = container.read(agentNetworkManagerProvider.notifier);
      final beforeResume = DateTime.now();

      try {
        await manager.resume(network);
      } catch (e) {
        // Expected
      }

      final state = container.read(agentNetworkManagerProvider);
      final resumedNetwork = state.currentNetwork!;

      // lastActiveAt should be updated to roughly now (within 1 second)
      expect(
        resumedNetwork.lastActiveAt!.isAfter(beforeResume) ||
            resumedNetwork.lastActiveAt!.isAtSameMomentAs(beforeResume),
        isTrue,
      );
      expect(
        resumedNetwork.lastActiveAt!.isBefore(DateTime.now().add(Duration(seconds: 1))),
        isTrue,
      );

      // createdAt should remain unchanged
      expect(resumedNetwork.createdAt, equals(network.createdAt));
    });

    test('resume with empty agents list still sets currentNetwork', () async {
      // Edge case: network with no agents (shouldn't happen in practice)
      final network = AgentNetwork(
        id: 'empty-network',
        goal: 'Empty network test',
        agents: [],
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
        team: 'vide',
      );

      final manager = container.read(agentNetworkManagerProvider.notifier);

      try {
        await manager.resume(network);
      } catch (e) {
        // Expected
      }

      final state = container.read(agentNetworkManagerProvider);
      expect(state.currentNetwork, isNotNull);
      expect(state.currentNetwork!.id, equals('empty-network'));
      expect(state.agents, isEmpty);
      expect(state.agentIds, isEmpty);
    });

    test('resume preserves worktreePath', () async {
      final network = AgentNetwork(
        id: 'worktree-network',
        goal: 'Worktree test',
        agents: [
          AgentMetadata(
            id: 'agent-1',
            name: 'Agent',
            type: 'main',
            createdAt: DateTime.now(),
          ),
        ],
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
        worktreePath: '/path/to/worktree',
        team: 'vide',
      );

      final manager = container.read(agentNetworkManagerProvider.notifier);

      try {
        await manager.resume(network);
      } catch (e) {
        // Expected
      }

      final state = container.read(agentNetworkManagerProvider);
      expect(state.currentNetwork!.worktreePath, equals('/path/to/worktree'));
    });
  });

  group('AgentNetworkState', () {
    test('agents getter returns empty list when currentNetwork is null', () {
      final state = AgentNetworkState(currentNetwork: null);
      expect(state.agents, isEmpty);
      expect(state.agentIds, isEmpty);
    });

    test('agents getter returns network agents when currentNetwork is set', () {
      final agents = [
        AgentMetadata(
          id: 'agent-1',
          name: 'Agent 1',
          type: 'main',
          createdAt: DateTime.now(),
        ),
        AgentMetadata(
          id: 'agent-2',
          name: 'Agent 2',
          type: 'implementer',
          createdAt: DateTime.now(),
        ),
      ];

      final network = AgentNetwork(
        id: 'test-network',
        goal: 'Test',
        agents: agents,
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      );

      final state = AgentNetworkState(currentNetwork: network);
      expect(state.agents.length, equals(2));
      expect(state.agentIds, containsAll(['agent-1', 'agent-2']));
    });

    test('copyWith creates new state with updated network', () {
      final originalNetwork = AgentNetwork(
        id: 'original',
        goal: 'Original',
        agents: [],
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      );

      final newNetwork = AgentNetwork(
        id: 'new',
        goal: 'New',
        agents: [
          AgentMetadata(
            id: 'new-agent',
            name: 'New Agent',
            type: 'main',
            createdAt: DateTime.now(),
          ),
        ],
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      );

      final originalState = AgentNetworkState(currentNetwork: originalNetwork);
      final newState = originalState.copyWith(currentNetwork: newNetwork);

      expect(newState.currentNetwork!.id, equals('new'));
      expect(newState.agents.length, equals(1));
      expect(originalState.currentNetwork!.id, equals('original'));
    });
  });
}
