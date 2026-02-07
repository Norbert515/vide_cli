import 'package:claude_sdk/claude_sdk.dart' as claude;
import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';
import '../helpers/mock_claude_client.dart';

/// Integration tests for Agent lifecycle components working together.
///
/// Tests the interaction between:
/// - AgentStatusRegistry (status tracking)
/// - ClaudeClientRegistry (client management)
/// - AgentNetwork (network model)
/// - MockClaudeClient (simulated Claude interaction)
void main() {
  group('Agent Lifecycle Integration', () {
    late AgentStatusRegistry statusRegistry;
    late ClaudeClientRegistry clientRegistry;
    late MockClaudeClientFactory clientFactory;

    setUp(() {
      statusRegistry = AgentStatusRegistry();
      clientRegistry = ClaudeClientRegistry();
      clientFactory = MockClaudeClientFactory();
    });

    tearDown(() {
      clientFactory.clear();
      statusRegistry.dispose();
      clientRegistry.dispose();
    });

    group('Agent status tracking', () {
      test('status updates are isolated between agents', () {
        const agent1Id = 'agent-1';
        const agent2Id = 'agent-2';

        // Set different statuses for different agents
        statusRegistry.setStatus(agent1Id, AgentStatus.working);
        statusRegistry.setStatus(agent2Id, AgentStatus.waitingForAgent);

        expect(statusRegistry.getStatus(agent1Id), AgentStatus.working);
        expect(statusRegistry.getStatus(agent2Id), AgentStatus.waitingForAgent);

        // Updating one doesn't affect the other
        statusRegistry.setStatus(agent1Id, AgentStatus.idle);

        expect(statusRegistry.getStatus(agent1Id), AgentStatus.idle);
        expect(statusRegistry.getStatus(agent2Id), AgentStatus.waitingForAgent);
      });

      test('status changes trigger stream events', () {
        const agentId = 'test-agent';
        var changeCount = 0;

        statusRegistry.changes.listen((_) => changeCount++);

        // Initial status is 'working', so setting to 'working' is a no-op (no event)
        statusRegistry.setStatus(agentId, AgentStatus.working);
        // These two actually change the value
        statusRegistry.setStatus(agentId, AgentStatus.waitingForAgent);
        statusRegistry.setStatus(agentId, AgentStatus.idle);

        expect(changeCount, 2);
      });
    });

    group('ClaudeClientRegistry with mock clients', () {
      test('adding and removing clients works correctly', () {
        final client1 = clientFactory.getClient('agent-1');
        final client2 = clientFactory.getClient('agent-2');

        clientRegistry.addAgent('agent-1', client1);
        clientRegistry.addAgent('agent-2', client2);

        expect(clientRegistry['agent-1'], same(client1));
        expect(clientRegistry['agent-2'], same(client2));
        expect(clientRegistry.all.length, 2);

        clientRegistry.removeAgent('agent-1');

        expect(clientRegistry['agent-1'], isNull);
        expect(clientRegistry['agent-2'], same(client2));
      });

      test('registry returns correct client for agent', () {
        final client = clientFactory.getClient('my-agent');

        clientRegistry.addAgent('my-agent', client);

        final retrieved = clientRegistry['my-agent'];
        expect(retrieved, same(client));
      });
    });

    group('MockClaudeClient message flow', () {
      test('sending messages adds to sent list', () {
        final client = clientFactory.getClient('test-agent');

        client.sendMessage(claude.Message.text('Hello'));
        client.sendMessage(claude.Message.text('World'));

        expect(client.sentMessages.length, 2);
        expect(client.sentMessages[0].text, 'Hello');
        expect(client.sentMessages[1].text, 'World');
      });

      test('simulating responses updates conversation', () async {
        final client = clientFactory.getClient('test-agent');

        // Listen to conversation stream
        final conversations = <claude.Conversation>[];
        final subscription = client.conversation.listen(conversations.add);

        client.sendMessage(claude.Message.text('Question?'));
        client.simulateTextResponse('Answer!');

        // Allow stream to propagate
        await Future.delayed(Duration.zero);
        await subscription.cancel();

        expect(conversations.length, 2);
        expect(conversations.last.messages.length, 2);
        expect(conversations.last.messages.first.role, claude.MessageRole.user);
        expect(
          conversations.last.messages.last.role,
          claude.MessageRole.assistant,
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

        client.sendMessage(claude.Message.text('Test'));
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
        clientRegistry.addAgent('main-agent', client);

        // Set agent as working
        statusRegistry.setStatus('main-agent', AgentStatus.working);

        // Send user message
        client.sendMessage(claude.Message.text('Implement feature X'));

        // Simulate Claude thinking and responding
        client.simulateTextResponse('I will implement feature X by...');

        // Simulate turn completion
        client.simulateTurnComplete();

        // Agent status should be updated to idle after completion
        statusRegistry.setStatus('main-agent', AgentStatus.idle);

        // Verify final state
        expect(statusRegistry.getStatus('main-agent'), AgentStatus.idle);
        expect(client.sentMessages.length, 1);
        expect(client.currentConversation.messages.length, 2);
      });
    });
  });
}
