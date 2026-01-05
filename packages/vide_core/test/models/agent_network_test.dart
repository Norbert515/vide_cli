import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';

void main() {
  group('AgentNetwork', () {
    final testDate = DateTime(2024, 1, 15, 10, 30, 0);
    final lastActiveDate = DateTime(2024, 1, 15, 11, 0, 0);

    AgentMetadata createAgent({
      required String id,
      required String name,
      required String type,
    }) {
      return AgentMetadata(id: id, name: name, type: type, createdAt: testDate);
    }

    group('toJson', () {
      test('serializes all fields', () {
        final network = AgentNetwork(
          id: 'network-123',
          goal: 'Implement feature X',
          agents: [
            createAgent(id: 'main-1', name: 'Main', type: 'main'),
            createAgent(id: 'impl-1', name: 'Worker', type: 'implementation'),
          ],
          createdAt: testDate,
          lastActiveAt: lastActiveDate,
          worktreePath: '/path/to/worktree',
        );

        final json = network.toJson();

        expect(json['id'], 'network-123');
        expect(json['goal'], 'Implement feature X');
        expect(json['agents'], isA<List>());
        expect((json['agents'] as List).length, 2);
        expect(json['createdAt'], testDate.toIso8601String());
        expect(json['lastActiveAt'], lastActiveDate.toIso8601String());
        expect(json['worktreePath'], '/path/to/worktree');
      });

      test('omits null worktreePath', () {
        final network = AgentNetwork(
          id: 'network-123',
          goal: 'Test goal',
          agents: [],
          createdAt: testDate,
        );

        final json = network.toJson();

        expect(json.containsKey('worktreePath'), isFalse);
      });

      test('omits null lastActiveAt', () {
        final network = AgentNetwork(
          id: 'network-123',
          goal: 'Test goal',
          agents: [],
          createdAt: testDate,
        );

        final json = network.toJson();

        expect(json['lastActiveAt'], isNull);
      });
    });

    group('fromJson', () {
      test('deserializes new format with full agent metadata', () {
        final json = {
          'id': 'network-123',
          'goal': 'Implement feature X',
          'agents': [
            {
              'id': 'main-1',
              'name': 'Main',
              'type': 'main',
              'createdAt': testDate.toIso8601String(),
            },
            {
              'id': 'impl-1',
              'name': 'Worker',
              'type': 'implementation',
              'createdAt': testDate.toIso8601String(),
            },
          ],
          'createdAt': testDate.toIso8601String(),
          'lastActiveAt': lastActiveDate.toIso8601String(),
          'worktreePath': '/path/to/worktree',
        };

        final network = AgentNetwork.fromJson(json);

        expect(network.id, 'network-123');
        expect(network.goal, 'Implement feature X');
        expect(network.agents.length, 2);
        expect(network.agents[0].id, 'main-1');
        expect(network.agents[0].name, 'Main');
        expect(network.agents[0].type, 'main');
        expect(network.agents[1].id, 'impl-1');
        expect(network.createdAt, testDate);
        expect(network.lastActiveAt, lastActiveDate);
        expect(network.worktreePath, '/path/to/worktree');
      });

      test('handles legacy format with string agent IDs', () {
        final json = {
          'id': 'network-123',
          'goal': 'Legacy network',
          'agents': ['agent-1', 'agent-2'],
          'createdAt': testDate.toIso8601String(),
        };

        final network = AgentNetwork.fromJson(json);

        expect(network.agents.length, 2);
        expect(network.agents[0].id, 'agent-1');
        expect(network.agents[0].name, 'Agent');
        expect(network.agents[0].type, 'unknown');
        expect(network.agents[1].id, 'agent-2');
      });

      test('handles missing optional fields', () {
        final json = {
          'id': 'network-123',
          'goal': 'Test goal',
          'agents': [],
          'createdAt': testDate.toIso8601String(),
        };

        final network = AgentNetwork.fromJson(json);

        expect(network.lastActiveAt, isNull);
        expect(network.worktreePath, isNull);
      });
    });

    group('copyWith', () {
      test('preserves unchanged fields', () {
        final original = AgentNetwork(
          id: 'network-123',
          goal: 'Original goal',
          agents: [createAgent(id: 'main-1', name: 'Main', type: 'main')],
          createdAt: testDate,
          lastActiveAt: lastActiveDate,
          worktreePath: '/original/path',
        );

        final copied = original.copyWith();

        expect(copied.id, original.id);
        expect(copied.goal, original.goal);
        expect(copied.agents.length, original.agents.length);
        expect(copied.createdAt, original.createdAt);
        expect(copied.lastActiveAt, original.lastActiveAt);
        expect(copied.worktreePath, original.worktreePath);
      });

      test('updates specified fields', () {
        final original = AgentNetwork(
          id: 'network-123',
          goal: 'Original goal',
          agents: [],
          createdAt: testDate,
        );

        final newAgents = [
          createAgent(id: 'new-1', name: 'New Agent', type: 'implementation'),
        ];

        final copied = original.copyWith(
          goal: 'Updated goal',
          agents: newAgents,
          worktreePath: '/new/path',
        );

        expect(copied.goal, 'Updated goal');
        expect(copied.agents, newAgents);
        expect(copied.worktreePath, '/new/path');
        // Unchanged
        expect(copied.id, original.id);
        expect(copied.createdAt, original.createdAt);
      });

      test('clears worktreePath when clearWorktreePath is true', () {
        final original = AgentNetwork(
          id: 'network-123',
          goal: 'Test goal',
          agents: [],
          createdAt: testDate,
          worktreePath: '/path/to/clear',
        );

        final copied = original.copyWith(clearWorktreePath: true);

        expect(copied.worktreePath, isNull);
      });

      test('clearWorktreePath takes precedence over worktreePath', () {
        final original = AgentNetwork(
          id: 'network-123',
          goal: 'Test goal',
          agents: [],
          createdAt: testDate,
          worktreePath: '/original/path',
        );

        final copied = original.copyWith(
          clearWorktreePath: true,
          worktreePath: '/new/path',
        );

        expect(copied.worktreePath, isNull);
      });
    });

    group('agentIds', () {
      test('returns list of agent IDs', () {
        final network = AgentNetwork(
          id: 'network-123',
          goal: 'Test goal',
          agents: [
            createAgent(id: 'agent-1', name: 'Agent 1', type: 'main'),
            createAgent(id: 'agent-2', name: 'Agent 2', type: 'implementation'),
            createAgent(
              id: 'agent-3',
              name: 'Agent 3',
              type: 'contextCollection',
            ),
          ],
          createdAt: testDate,
        );

        expect(network.agentIds, ['agent-1', 'agent-2', 'agent-3']);
      });

      test('returns empty list when no agents', () {
        final network = AgentNetwork(
          id: 'network-123',
          goal: 'Test goal',
          agents: [],
          createdAt: testDate,
        );

        expect(network.agentIds, isEmpty);
      });
    });

    test('round-trips through JSON correctly', () {
      final original = AgentNetwork(
        id: 'network-123',
        goal: 'Implement feature X',
        agents: [
          createAgent(id: 'main-1', name: 'Main', type: 'main'),
          AgentMetadata(
            id: 'impl-1',
            name: 'Worker',
            type: 'implementation',
            spawnedBy: 'main-1',
            createdAt: testDate,
            status: AgentStatus.working,
            taskName: 'Fix bug',
          ),
        ],
        createdAt: testDate,
        lastActiveAt: lastActiveDate,
        worktreePath: '/path/to/worktree',
      );

      final json = original.toJson();
      final restored = AgentNetwork.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.goal, original.goal);
      expect(restored.agents.length, original.agents.length);
      expect(restored.agents[0].id, original.agents[0].id);
      expect(restored.agents[1].spawnedBy, 'main-1');
      expect(restored.agents[1].status, AgentStatus.working);
      expect(restored.agents[1].taskName, 'Fix bug');
      expect(restored.createdAt, original.createdAt);
      expect(restored.lastActiveAt, original.lastActiveAt);
      expect(restored.worktreePath, original.worktreePath);
    });
  });
}
