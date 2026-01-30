// This test file is a reference copy. The actual tests are in:
// packages/vide_core/test/services/agent_network_manager_resume_test.dart
//
// The AgentNetworkManager is part of vide_core, so the tests belong there.
// This file documents the test location for the TUI codebase.

import 'dart:io';

import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';

/// Tests for resuming sessions correctly populating agents in the TUI's container.
///
/// Background:
/// A bug was fixed where resuming a session showed "No agents" because the TUI
/// was calling `videoCoreProvider.resumeSession()` which created a separate container.
/// The fix was to call `agentNetworkManagerProvider.notifier.resume(network)` directly.
///
/// These tests verify the key behavior: after calling `manager.resume(network)`,
/// the `agentNetworkManagerProvider` state should have the network with its agents.
void main() {
  group('Resume Session - Agents Populated in Container', () {
    late ProviderContainer container;
    late Directory testTempDir;

    setUp(() async {
      testTempDir = await Directory.systemTemp.createTemp('vide_resume_test_');
      final configDir = Directory('${testTempDir.path}/config');
      await configDir.create(recursive: true);

      container = ProviderContainer(
        overrides: [
          workingDirProvider.overrideWithValue(testTempDir.path),
          videConfigManagerProvider.overrideWithValue(
            VideConfigManager(configRoot: configDir.path),
          ),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      if (testTempDir.existsSync()) {
        await testTempDir.delete(recursive: true);
      }
    });

    test('resume() sets currentNetwork with agents immediately', () async {
      // This is the core behavior that fixes the "No agents" bug:
      // The state is set IMMEDIATELY in resume(), before any async work.

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

      final networkToResume = AgentNetwork(
        id: 'session-123',
        goal: 'Fix the bug',
        agents: agents,
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
        team: 'vide',
      );

      // Get the manager from the container (same container TUI uses)
      final manager = container.read(agentNetworkManagerProvider.notifier);

      // Verify state is empty before resume
      var state = container.read(agentNetworkManagerProvider);
      expect(state.currentNetwork, isNull);
      expect(state.agents, isEmpty);

      // Resume the network
      // Note: This may throw due to missing dependencies in test environment,
      // but the state update happens FIRST (the fix we're verifying)
      try {
        await manager.resume(networkToResume);
      } catch (e) {
        // Expected - the async client creation will fail in tests
      }

      // KEY ASSERTION: After resume, state.agents should be populated
      state = container.read(agentNetworkManagerProvider);
      expect(state.currentNetwork, isNotNull,
          reason: 'currentNetwork should be set after resume');
      expect(state.currentNetwork!.id, equals('session-123'));
      expect(state.agents.length, equals(2),
          reason: 'Both agents should be in state.agents');

      // Verify specific agents are present
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

    test('TUI can read agents from container after resume', () async {
      // Simulates what the TUI does: reads agent list from the provider

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

      final manager = container.read(agentNetworkManagerProvider.notifier);

      try {
        await manager.resume(network);
      } catch (e) {
        // Expected
      }

      // This is how the TUI reads the agent list
      final state = container.read(agentNetworkManagerProvider);
      final agentList = state.agents;

      expect(agentList.length, equals(3),
          reason: 'TUI should see all 3 agents from resumed session');
      expect(
        agentList.map((a) => a.name).toList(),
        containsAll(['Agent One', 'Agent Two', 'Agent Three']),
      );
    });
  });
}
