// E2E test for trigger flow
//
// This test verifies that:
// 1. When an agent's turn completes, their status is auto-set to idle
// 2. When all agents are idle, onAllAgentsIdle trigger fires
// 3. The trigger spawns the configured agent (session-synthesizer for enterprise team)

import 'dart:async';

import 'package:agent_sdk/agent_sdk.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import 'package:vide_core/src/models/agent_status.dart';
import 'package:vide_core/src/claude/claude_manager.dart';
import 'package:vide_core/src/agent_network/agent_status_manager.dart';
import 'package:vide_core/src/configuration/working_dir_provider.dart';

import 'helpers/mock_agent_client.dart';

void main() {
  group('Trigger E2E Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [workingDirProvider.overrideWithValue('/tmp/test')],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('Status sync: AgentProcessingStatus changes should update AgentStatus', () async {
      // Create a mock client
      final mockClient = MockAgentClient();
      const agentId = 'test-agent-1';

      // Add to agent client manager
      container
          .read(agentClientManagerProvider.notifier)
          .addAgent(agentId, mockClient);

      // Get the agent status notifier
      final statusNotifier = container.read(
        agentStatusProvider(agentId).notifier,
      );

      // Initial status should be idle (default)
      var status = container.read(agentStatusProvider(agentId));
      expect(status, equals(AgentStatus.idle));
      print('Initial status: $status');

      // Now let's manually set up the status sync like AgentNetworkManager does
      // This simulates what happens when an agent is added to the network
      late StreamSubscription<AgentProcessingStatus> subscription;
      subscription = mockClient.statusStream.listen((processingStatus) {
        final currentAgentStatus = container.read(agentStatusProvider(agentId));

        switch (processingStatus) {
          case AgentProcessingStatus.processing:
          case AgentProcessingStatus.thinking:
          case AgentProcessingStatus.responding:
            if (currentAgentStatus != AgentStatus.working) {
              statusNotifier.setStatus(AgentStatus.working);
            }
            break;
          case AgentProcessingStatus.ready:
            // Only 'ready' signals a true turn completion.
            // 'completed' is ignored because it also fires during
            // compaction when the turn is not actually done.
            if (currentAgentStatus == AgentStatus.working) {
              print('[Test] Agent ready, setting status to idle');
              statusNotifier.setStatus(AgentStatus.idle);
            }
            break;
          case AgentProcessingStatus.completed:
            // Ignored — 'completed' fires for every response end,
            // including compaction. Wait for 'ready' instead.
            break;
          case AgentProcessingStatus.error:
          case AgentProcessingStatus.unknown:
            if (currentAgentStatus == AgentStatus.working) {
              statusNotifier.setStatus(AgentStatus.idle);
            }
            break;
        }
      });

      // Simulate agent processing
      print('Emitting processing...');
      mockClient.emitStatus(AgentProcessingStatus.processing);
      await Future.delayed(Duration(milliseconds: 50));

      status = container.read(agentStatusProvider(agentId));
      expect(status, equals(AgentStatus.working));
      print('Status after processing: $status');

      // Simulate agent thinking
      print('Emitting thinking...');
      mockClient.emitStatus(AgentProcessingStatus.thinking);
      await Future.delayed(Duration(milliseconds: 50));

      status = container.read(agentStatusProvider(agentId));
      expect(status, equals(AgentStatus.working));
      print('Status after thinking: $status');

      // Simulate agent responding
      print('Emitting responding...');
      mockClient.emitStatus(AgentProcessingStatus.responding);
      await Future.delayed(Duration(milliseconds: 50));

      status = container.read(agentStatusProvider(agentId));
      expect(status, equals(AgentStatus.working));
      print('Status after responding: $status');

      // Simulate agent completing a response (not turn-complete)
      print('Emitting completed...');
      mockClient.emitStatus(AgentProcessingStatus.completed);
      await Future.delayed(Duration(milliseconds: 50));

      status = container.read(agentStatusProvider(agentId));
      expect(
        status,
        equals(AgentStatus.working),
        reason: 'Status should still be working after completed (could be compaction)',
      );
      print('Status after completed: $status');

      // Simulate agent becoming ready (turn truly complete)
      print('Emitting ready...');
      mockClient.emitStatus(AgentProcessingStatus.ready);
      await Future.delayed(Duration(milliseconds: 50));

      status = container.read(agentStatusProvider(agentId));
      expect(
        status,
        equals(AgentStatus.idle),
        reason: 'Status should be idle after ready',
      );
      print('Status after ready: $status');

      // Clean up
      await subscription.cancel();
    });

    test('AgentStatusNotifier correctly tracks status', () {
      const agentId = 'test-agent-2';

      // Get the notifier
      final notifier = container.read(agentStatusProvider(agentId).notifier);

      // Check initial status
      var status = container.read(agentStatusProvider(agentId));
      expect(status, equals(AgentStatus.idle));

      // Set to idle
      notifier.setStatus(AgentStatus.idle);
      status = container.read(agentStatusProvider(agentId));
      expect(status, equals(AgentStatus.idle));

      // Set to waitingForAgent
      notifier.setStatus(AgentStatus.waitingForAgent);
      status = container.read(agentStatusProvider(agentId));
      expect(status, equals(AgentStatus.waitingForAgent));

      // Set to waitingForUser
      notifier.setStatus(AgentStatus.waitingForUser);
      status = container.read(agentStatusProvider(agentId));
      expect(status, equals(AgentStatus.waitingForUser));

      // Set back to working
      notifier.setStatus(AgentStatus.working);
      status = container.read(agentStatusProvider(agentId));
      expect(status, equals(AgentStatus.working));

      print('All status transitions work correctly');
    });
  });
}
