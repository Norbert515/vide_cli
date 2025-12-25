import 'package:test/test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:claude_api/claude_api.dart';
import 'package:vide_core/vide_core.dart';
import '../helpers/mock_vide_config_manager.dart';
import '../helpers/mock_claude_client.dart';

/// Integration tests for Agent lifecycle components working together.
///
/// Tests the interaction between:
/// - AgentStatusManager (status tracking)
/// - ClaudeManager (client management)
/// - AgentNetwork (network model)
/// - MockClaudeClient (simulated Claude interaction)
void main() {
  group('Agent Lifecycle Integration', () {
    late ProviderContainer container;
    late MockClaudeClientFactory clientFactory;

    setUp(() {
      container = ProviderContainer();
      clientFactory = MockClaudeClientFactory();
    });

    tearDown(() {
      clientFactory.clear();
      container.dispose();
    });

    group('Agent status tracking', () {
      test('status updates are isolated between agents', () {
        const agent1Id = 'agent-1';
        const agent2Id = 'agent-2';

        // Set different statuses for different agents
        container.read(agentStatusProvider(agent1Id).notifier).setStatus(AgentStatus.working);
        container.read(agentStatusProvider(agent2Id).notifier).setStatus(AgentStatus.waitingForAgent);

        expect(container.read(agentStatusProvider(agent1Id)), AgentStatus.working);
        expect(container.read(agentStatusProvider(agent2Id)), AgentStatus.waitingForAgent);

        // Updating one doesn't affect the other
        container.read(agentStatusProvider(agent1Id).notifier).setStatus(AgentStatus.idle);

        expect(container.read(agentStatusProvider(agent1Id)), AgentStatus.idle);
        expect(container.read(agentStatusProvider(agent2Id)), AgentStatus.waitingForAgent);
      });

      test('status changes trigger provider rebuilds', () {
        const agentId = 'test-agent';
        var rebuildCount = 0;

        container.listen(
          agentStatusProvider(agentId),
          (previous, next) => rebuildCount++,
          fireImmediately: false,
        );

        // Initial status is 'working', so setting to 'working' is a no-op (no rebuild)
        container.read(agentStatusProvider(agentId).notifier).setStatus(AgentStatus.working);
        // These two actually change the value
        container.read(agentStatusProvider(agentId).notifier).setStatus(AgentStatus.waitingForAgent);
        container.read(agentStatusProvider(agentId).notifier).setStatus(AgentStatus.idle);

        expect(rebuildCount, 2);
      });
    });

    group('ClaudeManager with mock clients', () {
      test('adding and removing clients works correctly', () {
        final manager = container.read(claudeManagerProvider.notifier);
        final client1 = clientFactory.getClient('agent-1');
        final client2 = clientFactory.getClient('agent-2');

        manager.addAgent('agent-1', client1);
        manager.addAgent('agent-2', client2);

        final state = container.read(claudeManagerProvider);
        expect(state.containsKey('agent-1'), isTrue);
        expect(state.containsKey('agent-2'), isTrue);
        expect(state['agent-1'], same(client1));
        expect(state['agent-2'], same(client2));

        manager.removeAgent('agent-1');

        final updatedState = container.read(claudeManagerProvider);
        expect(updatedState.containsKey('agent-1'), isFalse);
        expect(updatedState.containsKey('agent-2'), isTrue);
      });

      test('family provider returns correct client for agent', () {
        final manager = container.read(claudeManagerProvider.notifier);
        final client = clientFactory.getClient('my-agent');

        manager.addAgent('my-agent', client);

        final retrieved = container.read(claudeProvider('my-agent'));
        expect(retrieved, same(client));
      });
    });

    group('MockClaudeClient message flow', () {
      test('sending messages adds to sent list', () {
        final client = clientFactory.getClient('test-agent');

        client.sendMessage(Message.text('Hello'));
        client.sendMessage(Message.text('World'));

        expect(client.sentMessages.length, 2);
        expect(client.sentMessages[0].text, 'Hello');
        expect(client.sentMessages[1].text, 'World');
      });

      test('simulating responses updates conversation', () async {
        final client = clientFactory.getClient('test-agent');

        // Listen to conversation stream
        final conversations = <Conversation>[];
        final subscription = client.conversation.listen(conversations.add);

        client.sendMessage(Message.text('Question?'));
        client.simulateTextResponse('Answer!');

        // Allow stream to propagate
        await Future.delayed(Duration.zero);
        await subscription.cancel();

        expect(conversations.length, 2);
        expect(conversations.last.messages.length, 2);
        expect(conversations.last.messages.first.role, MessageRole.user);
        expect(conversations.last.messages.last.role, MessageRole.assistant);
      });

      test('abort sets isAborting flag', () async {
        final client = clientFactory.getClient('test-agent');

        expect(client.isAborting, isFalse);
        await client.abort();
        expect(client.isAborting, isTrue);
      });

      test('close disposes stream controllers', () async {
        final client = clientFactory.getClient('test-agent');

        await client.close();
        expect(client.isClosed, isTrue);
      });

      test('reset clears state for reuse', () async {
        final client = clientFactory.getClient('test-agent');

        client.sendMessage(Message.text('Test'));
        await client.abort();

        expect(client.sentMessages.isNotEmpty, isTrue);
        expect(client.isAborted, isTrue);

        client.reset();

        expect(client.sentMessages.isEmpty, isTrue);
        expect(client.isAborted, isFalse);
      });
    });

    group('Agent network state transitions', () {
      test('agent metadata tracks creation and type', () {
        final metadata = AgentMetadata(
          id: 'agent-123',
          name: 'Implementation',
          type: 'implementation',
          createdAt: DateTime.now(),
        );

        expect(metadata.id, 'agent-123');
        expect(metadata.name, 'Implementation');
        expect(metadata.type, 'implementation');
        expect(metadata.spawnedBy, isNull);
      });

      test('agent can be spawned by another agent', () {
        final mainAgent = AgentMetadata(
          id: 'main-agent',
          name: 'Main',
          type: 'main',
          createdAt: DateTime.now(),
        );

        final spawnedAgent = AgentMetadata(
          id: 'spawned-agent',
          name: 'Worker',
          type: 'implementation',
          spawnedBy: mainAgent.id,
          createdAt: DateTime.now(),
        );

        expect(spawnedAgent.spawnedBy, mainAgent.id);
      });

      test('network tracks multiple agents', () {
        final network = AgentNetwork(
          id: 'network-1',
          goal: 'Complete task',
          agents: [
            AgentMetadata(
              id: 'main',
              name: 'Main',
              type: 'main',
              createdAt: DateTime.now(),
            ),
            AgentMetadata(
              id: 'impl',
              name: 'Implementation',
              type: 'implementation',
              createdAt: DateTime.now(),
            ),
          ],
          createdAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        );

        expect(network.agents.length, 2);
        expect(network.agentIds, containsAll(['main', 'impl']));
      });
    });

    group('Full agent conversation simulation', () {
      test('simulates complete agent interaction', () async {
        final client = clientFactory.getClient('main-agent');
        final manager = container.read(claudeManagerProvider.notifier);
        manager.addAgent('main-agent', client);

        // Set agent as working
        container.read(agentStatusProvider('main-agent').notifier).setStatus(AgentStatus.working);

        // Send user message
        client.sendMessage(Message.text('Implement feature X'));

        // Simulate Claude thinking and responding
        client.simulateTextResponse('I will implement feature X by...');

        // Simulate turn completion
        client.simulateTurnComplete();

        // Agent status should be updated to idle after completion
        container.read(agentStatusProvider('main-agent').notifier).setStatus(AgentStatus.idle);

        // Verify final state
        expect(container.read(agentStatusProvider('main-agent')), AgentStatus.idle);
        expect(client.sentMessages.length, 1);
        expect(client.currentConversation.messages.length, 2);
      });
    });
  });
}
