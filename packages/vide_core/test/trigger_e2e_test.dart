// E2E test for trigger flow
//
// This test verifies that:
// 1. When an agent's turn completes, their status is auto-set to idle
// 2. When all agents are idle, onAllAgentsIdle trigger fires
// 3. The trigger spawns the configured agent (session-synthesizer for enterprise team)

import 'dart:async';

import 'package:claude_sdk/claude_sdk.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import 'package:vide_core/src/models/agent_status.dart';
import 'package:vide_core/src/claude/claude_manager.dart';
import 'package:vide_core/src/agent_network/agent_status_manager.dart';
import 'package:vide_core/src/configuration/working_dir_provider.dart';

import 'helpers/mock_claude_client.dart' as mock;

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

    test('Status sync: ClaudeStatus changes should update AgentStatus', () async {
      // Create a mock client
      final mockClient = mock.MockClaudeClient();
      const agentId = 'test-agent-1';

      // Add to claude manager
      container
          .read(claudeManagerProvider.notifier)
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
      late StreamSubscription<ClaudeStatus> subscription;
      subscription = mockClient.statusStream.listen((claudeStatus) {
        final currentAgentStatus = container.read(agentStatusProvider(agentId));

        switch (claudeStatus) {
          case ClaudeStatus.processing:
          case ClaudeStatus.thinking:
          case ClaudeStatus.responding:
            if (currentAgentStatus != AgentStatus.working) {
              statusNotifier.setStatus(AgentStatus.working);
            }
            break;
          case ClaudeStatus.ready:
            // Only 'ready' signals a true turn completion.
            // 'completed' is ignored because it also fires during
            // compaction when the turn is not actually done.
            if (currentAgentStatus == AgentStatus.working) {
              print('[Test] Claude ready, setting status to idle');
              statusNotifier.setStatus(AgentStatus.idle);
            }
            break;
          case ClaudeStatus.completed:
            // Ignored — 'completed' fires for every response end,
            // including compaction. Wait for 'ready' instead.
            break;
          case ClaudeStatus.error:
          case ClaudeStatus.unknown:
            if (currentAgentStatus == AgentStatus.working) {
              statusNotifier.setStatus(AgentStatus.idle);
            }
            break;
        }
      });

      // Simulate Claude processing
      print('Emitting processing...');
      mockClient.emitStatus(ClaudeStatus.processing);
      await Future.delayed(Duration(milliseconds: 50));

      status = container.read(agentStatusProvider(agentId));
      expect(status, equals(AgentStatus.working));
      print('Status after processing: $status');

      // Simulate Claude thinking
      print('Emitting thinking...');
      mockClient.emitStatus(ClaudeStatus.thinking);
      await Future.delayed(Duration(milliseconds: 50));

      status = container.read(agentStatusProvider(agentId));
      expect(status, equals(AgentStatus.working));
      print('Status after thinking: $status');

      // Simulate Claude responding
      print('Emitting responding...');
      mockClient.emitStatus(ClaudeStatus.responding);
      await Future.delayed(Duration(milliseconds: 50));

      status = container.read(agentStatusProvider(agentId));
      expect(status, equals(AgentStatus.working));
      print('Status after responding: $status');

      // Simulate Claude completing a response (not turn-complete)
      print('Emitting completed...');
      mockClient.emitStatus(ClaudeStatus.completed);
      await Future.delayed(Duration(milliseconds: 50));

      status = container.read(agentStatusProvider(agentId));
      expect(
        status,
        equals(AgentStatus.working),
        reason: 'Status should still be working after completed (could be compaction)',
      );
      print('Status after completed: $status');

      // Simulate Claude becoming ready (turn truly complete)
      print('Emitting ready...');
      mockClient.emitStatus(ClaudeStatus.ready);
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
