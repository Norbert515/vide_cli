import 'dart:io';

import 'package:claude_sdk/claude_sdk.dart' as claude;
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';
import 'package:vide_core/src/services/agent_network_manager.dart';
import 'package:vide_core/src/services/claude_manager.dart';

import '../helpers/mock_claude_client.dart';
import '../helpers/mock_vide_config_manager.dart';

void main() {
  group('LocalVideSession.sendMessage() queued message behavior', () {
    late Directory tempDir;
    late MockVideConfigManager configManager;
    late ProviderContainer container;
    late MockClaudeClient mockClient;
    late LocalVideSession session;

    const agentId = 'main-agent';
    const networkId = 'test-network';

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('queued_msg_test_');
      configManager = MockVideConfigManager(tempDir: tempDir);

      container = ProviderContainer(
        overrides: [
          videConfigManagerProvider.overrideWithValue(configManager),
          workingDirProvider.overrideWithValue(tempDir.path),
          permissionHandlerProvider.overrideWithValue(PermissionHandler()),
        ],
      );

      // Set up mock client and register it
      mockClient = MockClaudeClient(sessionId: agentId);
      container
          .read(claudeManagerProvider.notifier)
          .addAgent(agentId, mockClient);

      // Set up a network with one agent
      final manager = container.read(agentNetworkManagerProvider.notifier);
      manager.state = AgentNetworkState(
        currentNetwork: AgentNetwork(
          id: networkId,
          goal: 'Test',
          agents: [
            AgentMetadata(
              id: agentId,
              name: 'Main Agent',
              type: 'main',
              createdAt: DateTime.now(),
            ),
          ],
          createdAt: DateTime.now(),
        ),
      );

      // Create session
      session = LocalVideSession.create(
        networkId: networkId,
        container: container,
      );
    });

    tearDown(() async {
      await session.dispose(fireEndTrigger: false);
      container.dispose();
      await configManager.dispose();
    });

    test('queued messages should NOT appear in chat events', () async {
      // Put agent in processing state so messages will be queued
      mockClient.setConversationState(
        claude.ConversationState.receivingResponse,
      );
      expect(mockClient.currentConversation.isProcessing, isTrue);

      // Collect all events
      final events = <VideEvent>[];
      session.events.listen(events.add);

      // Send message while agent is processing
      session.sendMessage(
        VideMessage(text: 'This should be queued, not shown in chat'),
      );

      // Allow any async events to settle
      await Future<void>.delayed(Duration.zero);

      // Check that no user MessageEvent was emitted
      final userMessages = events
          .whereType<MessageEvent>()
          .where((e) => e.role == 'user')
          .toList();

      expect(
        userMessages,
        isEmpty,
        reason: 'A queued message should NOT appear as a chat event',
      );
    });

    test('non-queued messages should appear in chat events', () async {
      // Agent is idle - messages should NOT be queued
      expect(mockClient.currentConversation.isProcessing, isFalse);

      final events = <VideEvent>[];
      session.events.listen(events.add);

      session.sendMessage(VideMessage(text: 'This should appear in chat'));

      await Future<void>.delayed(Duration.zero);

      final userMessages = events
          .whereType<MessageEvent>()
          .where((e) => e.role == 'user')
          .toList();

      expect(
        userMessages,
        isNotEmpty,
        reason: 'A non-queued message should appear as a chat event',
      );
      expect(userMessages.first.content, 'This should appear in chat');
    });

    test(
      'agent status should NOT be set to working for queued messages',
      () async {
        // Set initial status to something other than working
        container
            .read(agentStatusProvider(agentId).notifier)
            .setStatus(AgentStatus.working);

        // Put agent in processing state
        mockClient.setConversationState(
          claude.ConversationState.receivingResponse,
        );

        // Collect status events
        final statusEvents = <StatusEvent>[];
        session.events.listen((e) {
          if (e is StatusEvent) statusEvents.add(e);
        });

        session.sendMessage(VideMessage(text: 'Queued message'));

        await Future<void>.delayed(Duration.zero);

        // No status change events should have been emitted
        // (the agent was already working, we shouldn't redundantly set it)
        expect(statusEvents, isEmpty);
      },
    );
  });
}
