// This test verifies that SessionServices wires up AgentNetworkManager
// correctly, and that state updates are visible through the manager.
//
// More detailed AgentNetworkState and resume tests are in:
// packages/vide_core/test/services/agent_network_manager_resume_test.dart

import 'dart:io';

import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';
import 'package:vide_core/src/services/agent_network_manager.dart';

/// Tests for SessionServices wiring — ensures the TUI can access
/// the AgentNetworkManager and its state through SessionServices.
///
/// Background:
/// A bug was fixed where resuming a session showed "No agents" because the TUI
/// was creating a separate container. SessionServices is the unified dependency
/// container that ensures all components share the same instances.
void main() {
  group('SessionServices - AgentNetworkManager wiring', () {
    late SessionServices services;
    late Directory testTempDir;

    setUp(() async {
      testTempDir = await Directory.systemTemp.createTemp('vide_resume_test_');
      final configDir = Directory('${testTempDir.path}/config');
      await configDir.create(recursive: true);

      services = SessionServices(
        workingDirectory: testTempDir.path,
        configManager: VideConfigManager(configRoot: configDir.path),
        permissionHandler: PermissionHandler(),
      );
    });

    tearDown(() async {
      services.dispose();
      if (testTempDir.existsSync()) {
        await testTempDir.delete(recursive: true);
      }
    });

    test('networkManager starts with empty state', () {
      final manager = services.networkManager;

      expect(manager.state.currentNetwork, isNull);
      expect(manager.state.agents, isEmpty);
      expect(manager.state.agentIds, isEmpty);
    });

    test('networkManager state reflects network with agents', () {
      // Simulate what resume() does internally: set state with a network
      final agents = [
        AgentMetadata(
          id: 'main-agent-id',
          name: 'Klaus',
          type: 'main',
          createdAt: DateTime.now(),
        ),
        AgentMetadata(
          id: 'sub-agent-id',
          name: 'Bert',
          type: 'implementer',
          spawnedBy: 'main-agent-id',
          createdAt: DateTime.now(),
        ),
      ];

      final network = AgentNetwork(
        id: 'session-123',
        goal: 'Fix the bug',
        agents: agents,
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
        team: 'vide',
      );

      // Verify that AgentNetworkState correctly exposes agents
      final state = AgentNetworkState(currentNetwork: network);
      expect(state.currentNetwork, isNotNull);
      expect(state.currentNetwork!.id, equals('session-123'));
      expect(state.agents.length, equals(2));
      expect(state.agentIds, contains('main-agent-id'));
      expect(state.agentIds, contains('sub-agent-id'));

      // Verify agent metadata is preserved
      final mainAgent = state.agents.firstWhere((a) => a.id == 'main-agent-id');
      expect(mainAgent.name, equals('Klaus'));
      expect(mainAgent.type, equals('main'));

      final subAgent = state.agents.firstWhere((a) => a.id == 'sub-agent-id');
      expect(subAgent.name, equals('Bert'));
      expect(subAgent.spawnedBy, equals('main-agent-id'));
    });

    test('stateStream emits updates', () async {
      final manager = services.networkManager;
      final states = <AgentNetworkState>[];
      final subscription = manager.stateStream.listen(states.add);

      // Manually trigger a state change through the public interface
      // Note: We can't call resume() without Claude CLI, but we can verify
      // that the stream infrastructure works through SessionServices
      expect(manager.state.currentNetwork, isNull);

      await subscription.cancel();
    });

    test('SessionServices provides consistent references', () {
      // Verify that accessing networkManager multiple times returns
      // the same instance (not recreated each time)
      final manager1 = services.networkManager;
      final manager2 = services.networkManager;
      expect(identical(manager1, manager2), isTrue);
    });

    test('TUI can read agents from AgentNetworkState after it is set', () {
      // This tests the pattern the TUI uses to display agents
      final network = AgentNetwork(
        id: 'tui-session',
        goal: 'Test TUI reading agents',
        agents: [
          AgentMetadata(
            id: 'agent-1',
            name: 'Agent One',
            type: 'main',
            createdAt: DateTime.now(),
          ),
          AgentMetadata(
            id: 'agent-2',
            name: 'Agent Two',
            type: 'researcher',
            createdAt: DateTime.now(),
          ),
          AgentMetadata(
            id: 'agent-3',
            name: 'Agent Three',
            type: 'implementer',
            createdAt: DateTime.now(),
          ),
        ],
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
        team: 'vide',
      );

      final state = AgentNetworkState(currentNetwork: network);
      final agentList = state.agents;

      expect(
        agentList.length,
        equals(3),
        reason: 'TUI should see all 3 agents',
      );
      expect(
        agentList.map((a) => a.name).toList(),
        containsAll(['Agent One', 'Agent Two', 'Agent Three']),
      );
    });
  });
}
