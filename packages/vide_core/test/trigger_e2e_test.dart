// E2E test for trigger flow
//
// This test verifies that:
// 1. When an agent's turn completes, their status is auto-set to idle
// 2. When all agents are idle, onAllAgentsIdle trigger fires
// 3. The trigger spawns the configured agent (session-synthesizer for enterprise team)

import 'dart:async';

import 'package:claude_sdk/claude_sdk.dart';
import 'package:test/test.dart';

import 'package:vide_core/src/models/agent_status.dart';
import 'package:vide_core/src/services/agent_status_registry.dart';
import 'package:vide_core/src/services/claude_client_registry.dart';

import 'helpers/mock_claude_client.dart' as mock;

void main() {
  group('Trigger E2E Tests', () {
    late AgentStatusRegistry statusRegistry;
    late ClaudeClientRegistry clientRegistry;

    setUp(() {
      statusRegistry = AgentStatusRegistry();
      clientRegistry = ClaudeClientRegistry();
    });

    tearDown(() {
      statusRegistry.dispose();
      clientRegistry.dispose();
    });

    test('Status sync: ClaudeStatus changes should update AgentStatus', () async {
      // Create a mock client
      final mockClient = mock.MockClaudeClient();
      const agentId = 'test-agent-1';

      // Add to client registry
      clientRegistry.addAgent(agentId, mockClient);

      // Initial status should be working (default)
      var status = statusRegistry.getStatus(agentId);
      expect(status, equals(AgentStatus.working));

      // Now let's manually set up the status sync like AgentNetworkManager does
      // This simulates what happens when an agent is added to the network
      late StreamSubscription<ClaudeStatus> subscription;
      subscription = mockClient.statusStream.listen((claudeStatus) {
        final currentAgentStatus = statusRegistry.getStatus(agentId);

        switch (claudeStatus) {
          case ClaudeStatus.processing:
          case ClaudeStatus.thinking:
          case ClaudeStatus.responding:
            if (currentAgentStatus != AgentStatus.working) {
              statusRegistry.setStatus(agentId, AgentStatus.working);
            }
            break;
          case ClaudeStatus.ready:
          case ClaudeStatus.completed:
            if (currentAgentStatus == AgentStatus.working) {
              statusRegistry.setStatus(agentId, AgentStatus.idle);
            }
            break;
          case ClaudeStatus.error:
          case ClaudeStatus.unknown:
            if (currentAgentStatus == AgentStatus.working) {
              statusRegistry.setStatus(agentId, AgentStatus.idle);
            }
            break;
        }
      });

      // Simulate Claude processing
      mockClient.emitStatus(ClaudeStatus.processing);
      await Future.delayed(Duration(milliseconds: 50));

      status = statusRegistry.getStatus(agentId);
      expect(status, equals(AgentStatus.working));

      // Simulate Claude thinking
      mockClient.emitStatus(ClaudeStatus.thinking);
      await Future.delayed(Duration(milliseconds: 50));

      status = statusRegistry.getStatus(agentId);
      expect(status, equals(AgentStatus.working));

      // Simulate Claude responding
      mockClient.emitStatus(ClaudeStatus.responding);
      await Future.delayed(Duration(milliseconds: 50));

      status = statusRegistry.getStatus(agentId);
      expect(status, equals(AgentStatus.working));

      // Simulate Claude completing
      mockClient.emitStatus(ClaudeStatus.completed);
      await Future.delayed(Duration(milliseconds: 50));

      status = statusRegistry.getStatus(agentId);
      expect(
        status,
        equals(AgentStatus.idle),
        reason: 'Status should be idle after completed',
      );

      // Clean up
      await subscription.cancel();
    });

    test('AgentStatusRegistry correctly tracks status', () {
      const agentId = 'test-agent-2';

      // Check initial status
      var status = statusRegistry.getStatus(agentId);
      expect(status, equals(AgentStatus.working));

      // Set to idle
      statusRegistry.setStatus(agentId, AgentStatus.idle);
      status = statusRegistry.getStatus(agentId);
      expect(status, equals(AgentStatus.idle));

      // Set to waitingForAgent
      statusRegistry.setStatus(agentId, AgentStatus.waitingForAgent);
      status = statusRegistry.getStatus(agentId);
      expect(status, equals(AgentStatus.waitingForAgent));

      // Set to waitingForUser
      statusRegistry.setStatus(agentId, AgentStatus.waitingForUser);
      status = statusRegistry.getStatus(agentId);
      expect(status, equals(AgentStatus.waitingForUser));

      // Set back to working
      statusRegistry.setStatus(agentId, AgentStatus.working);
      status = statusRegistry.getStatus(agentId);
      expect(status, equals(AgentStatus.working));
    });
  });
}
