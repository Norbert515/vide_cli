import 'package:agent_sdk/agent_sdk.dart';
import 'package:test/test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:vide_core/vide_core.dart';
import '../helpers/mock_agent_client.dart';

/// Integration tests for Agent lifecycle components working together.
///
/// Tests the interaction between:
/// - AgentStatusManager (status tracking)
/// - AgentClientManager (client management)
/// - AgentNetwork (network model)
/// - MockAgentClient (simulated agent interaction)
void main() {
  group('Agent Lifecycle Integration', () {
    late ProviderContainer container;
    late MockAgentClientFactory clientFactory;

    setUp(() {
      container = ProviderContainer();
      clientFactory = MockAgentClientFactory();
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
        container
            .read(agentStatusProvider(agent1Id).notifier)
            .setStatus(AgentStatus.working);
        container
            .read(agentStatusProvider(agent2Id).notifier)
            .setStatus(AgentStatus.waitingForAgent);

        expect(
          container.read(agentStatusProvider(agent1Id)),
          AgentStatus.working,
        );
        expect(
          container.read(agentStatusProvider(agent2Id)),
          AgentStatus.waitingForAgent,
        );

        // Updating one doesn't affect the other
        container
            .read(agentStatusProvider(agent1Id).notifier)
            .setStatus(AgentStatus.idle);

        expect(container.read(agentStatusProvider(agent1Id)), AgentStatus.idle);
        expect(
          container.read(agentStatusProvider(agent2Id)),
          AgentStatus.waitingForAgent,
        );
      });

      test('status changes trigger provider rebuilds', () {
        const agentId = 'test-agent';
        var rebuildCount = 0;

        container.listen(
          agentStatusProvider(agentId),
          (previous, next) => rebuildCount++,
          fireImmediately: false,
        );

        // Initial status is 'idle', so setting to 'working' IS a change (rebuild)
        container
            .read(agentStatusProvider(agentId).notifier)
            .setStatus(AgentStatus.working);
        // These two also change the value
        container
            .read(agentStatusProvider(agentId).notifier)
            .setStatus(AgentStatus.waitingForAgent);
        container
            .read(agentStatusProvider(agentId).notifier)
            .setStatus(AgentStatus.idle);

        expect(rebuildCount, 3);
      });
    });

    group('AgentClientManager with mock clients', () {
      test('adding and removing clients works correctly', () {
        final manager = container.read(agentClientManagerProvider.notifier);
        final client1 = clientFactory.getClient('agent-1');
        final client2 = clientFactory.getClient('agent-2');

        manager.addAgent('agent-1', client1);
        manager.addAgent('agent-2', client2);

        final state = container.read(agentClientManagerProvider);
        expect(state.containsKey('agent-1'), isTrue);
        expect(state.containsKey('agent-2'), isTrue);
        expect(state['agent-1'], same(client1));
        expect(state['agent-2'], same(client2));

        manager.removeAgent('agent-1');

        final updatedState = container.read(agentClientManagerProvider);
        expect(updatedState.containsKey('agent-1'), isFalse);
        expect(updatedState.containsKey('agent-2'), isTrue);
      });

      test('family provider returns correct client for agent', () {
        final manager = container.read(agentClientManagerProvider.notifier);
        final client = clientFactory.getClient('my-agent');

        manager.addAgent('my-agent', client);

        final retrieved = container.read(agentClientProvider('my-agent'));
        expect(retrieved, same(client));
      });
    });

    group('MockAgentClient message flow', () {
      test('sending messages adds to sent list', () {
        final client = clientFactory.getClient('test-agent');

        client.sendMessage(const AgentMessage.text('Hello'));
        client.sendMessage(const AgentMessage.text('World'));

        expect(client.sentMessages.length, 2);
        expect(client.sentMessages[0].text, 'Hello');
        expect(client.sentMessages[1].text, 'World');
      });

      test('simulating responses updates conversation', () async {
        final client = clientFactory.getClient('test-agent');

        // Listen to conversation stream
        final conversations = <AgentConversation>[];
        final subscription = client.conversation.listen(conversations.add);

        client.sendMessage(const AgentMessage.text('Question?'));
        client.simulateTextResponse('Answer!');

        // Allow stream to propagate
        await Future.delayed(Duration.zero);
        await subscription.cancel();

        expect(conversations.length, 2);
        expect(conversations.last.messages.length, 2);
        expect(conversations.last.messages.first.role, AgentMessageRole.user);
        expect(
          conversations.last.messages.last.role,
          AgentMessageRole.assistant,
        );
      });

      test('abort can be called without error', () async {
        final client = clientFactory.getClient('test-agent');

        // Should not throw
        await client.abort();
        expect(client.isAborted, isTrue);
      });

      test('close disposes stream controllers', () async {
        final client = clientFactory.getClient('test-agent');

        await client.close();
        expect(client.isClosed, isTrue);
      });

      test('reset clears state for reuse', () async {
        final client = clientFactory.getClient('test-agent');

        client.sendMessage(const AgentMessage.text('Test'));
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
          name: 'Implementer',
          type: 'implementer',
          createdAt: DateTime.now(),
        );

        expect(metadata.id, 'agent-123');
        expect(metadata.name, 'Implementer');
        expect(metadata.type, 'implementer');
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
          type: 'implementer',
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
              name: 'Implementer',
              type: 'implementer',
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
        final manager = container.read(agentClientManagerProvider.notifier);
        manager.addAgent('main-agent', client);

        // Set agent as working
        container
            .read(agentStatusProvider('main-agent').notifier)
            .setStatus(AgentStatus.working);

        // Send user message
        client.sendMessage(const AgentMessage.text('Implement feature X'));

        // Simulate Claude thinking and responding
        client.simulateTextResponse('I will implement feature X by...');

        // Simulate turn completion
        client.simulateTurnComplete();

        // Agent status should be updated to idle after completion
        container
            .read(agentStatusProvider('main-agent').notifier)
            .setStatus(AgentStatus.idle);

        // Verify final state
        expect(
          container.read(agentStatusProvider('main-agent')),
          AgentStatus.idle,
        );
        expect(client.sentMessages.length, 1);
        expect(client.currentConversation.messages.length, 2);
      });
    });
  });
}
