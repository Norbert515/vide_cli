import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';
import 'package:vide_core/src/services/agent_network_manager.dart';

import '../helpers/test_fixtures.dart';

/// Tests for AgentNetworkManager resume-related state management.
///
/// Note: Tests that call `manager.resume()` with agents are skipped because
/// they require the Claude CLI binary (not available in CI/test environments).
/// The core state logic is covered via AgentNetworkState unit tests below.
void main() {
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

  group('AgentNetwork resume state', () {
    test('network state preserves all agent metadata', () {
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

      final network = AgentNetwork(
        id: 'test-network-123',
        goal: 'Test resume functionality',
        agents: agents,
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
        team: 'vide',
      );

      final state = AgentNetworkState(currentNetwork: network);

      expect(state.currentNetwork, isNotNull);
      expect(state.currentNetwork!.id, equals('test-network-123'));
      expect(state.currentNetwork!.goal, equals('Test resume functionality'));
      expect(state.agents.length, equals(3));

      final agentIds = state.agents.map((a) => a.id).toList();
      expect(
        agentIds,
        containsAll(['main-agent', 'impl-agent', 'researcher-agent']),
      );

      final mainAgent = state.agents.firstWhere((a) => a.id == 'main-agent');
      expect(mainAgent.name, equals('Lead'));
      expect(mainAgent.type, equals('main'));

      final implAgent = state.agents.firstWhere((a) => a.id == 'impl-agent');
      expect(implAgent.name, equals('Implementer'));
      expect(implAgent.type, equals('implementer'));
      expect(implAgent.spawnedBy, equals('main-agent'));
    });

    test('network state with convenience getters', () {
      final agents = [
        TestFixtures.agentMetadata(
          id: 'agent-1',
          name: 'Agent 1',
          type: 'main',
        ),
        TestFixtures.agentMetadata(
          id: 'agent-2',
          name: 'Agent 2',
          type: 'implementer',
        ),
      ];

      final network = TestFixtures.agentNetwork(
        id: 'network-1',
        goal: 'Test agents getter',
        agents: agents,
      ).copyWith(team: 'vide');

      final state = AgentNetworkState(currentNetwork: network);

      expect(state.agents, isNotEmpty);
      expect(state.agents.length, equals(2));
      expect(state.agentIds, containsAll(['agent-1', 'agent-2']));
    });

    test('network copyWith updates lastActiveAt', () {
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

      final beforeUpdate = DateTime.now();
      final updated = network.copyWith(lastActiveAt: DateTime.now());

      expect(
        updated.lastActiveAt!.isAfter(beforeUpdate) ||
            updated.lastActiveAt!.isAtSameMomentAs(beforeUpdate),
        isTrue,
      );
      expect(updated.createdAt, equals(network.createdAt));
    });

    test('empty agents list works', () {
      final network = AgentNetwork(
        id: 'empty-network',
        goal: 'Empty network test',
        agents: [],
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
        team: 'vide',
      );

      final state = AgentNetworkState(currentNetwork: network);
      expect(state.currentNetwork, isNotNull);
      expect(state.currentNetwork!.id, equals('empty-network'));
      expect(state.agents, isEmpty);
      expect(state.agentIds, isEmpty);
    });

    test('network preserves worktreePath', () {
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

      final state = AgentNetworkState(currentNetwork: network);
      expect(state.currentNetwork!.worktreePath, equals('/path/to/worktree'));
    });
  });
}
