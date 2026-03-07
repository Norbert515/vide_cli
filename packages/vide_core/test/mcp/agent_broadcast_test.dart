import 'package:agent_sdk/agent_sdk.dart';
import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';
import 'package:vide_core/src/agent_network/agent_network_manager.dart';
import 'package:vide_core/src/claude/agent_configuration.dart';
import 'package:vide_core/src/team_framework/trigger_service.dart';
import '../helpers/mock_agent_client.dart';

/// A testable subclass that exposes the protected [state] setter.
class _TestableNetworkManager extends AgentNetworkManager {
  _TestableNetworkManager({
    required super.workingDirectory,
    required super.claudeManager,
    required super.persistenceManager,
    required super.getTriggerService,
    required super.factoryRegistry,
    required super.getStatusNotifier,
    required super.getStatus,
  });

  void setNetwork(AgentNetwork network) {
    state = AgentNetworkState(currentNetwork: network);
  }
}

/// Stub [AgentClientFactory] that is never called during broadcast tests.
class _StubClientFactory implements AgentClientFactory {
  @override
  bool get supportsFork => false;

  @override
  AgentClient createSync({
    required AgentId agentId,
    required AgentConfiguration config,
    String? networkId,
    String? agentType,
    String? workingDirectory,
  }) =>
      throw UnimplementedError();

  @override
  Future<AgentClient> create({
    required AgentId agentId,
    required AgentConfiguration config,
    String? networkId,
    String? agentType,
    String? workingDirectory,
  }) =>
      throw UnimplementedError();

  @override
  Future<AgentClient> createForked({
    required AgentId agentId,
    required AgentConfiguration config,
    String? networkId,
    String? agentType,
    required String resumeSessionId,
    AgentConversation? sourceConversation,
    String? workingDirectory,
  }) =>
      throw UnimplementedError();
}

void main() {
  group('@everyone broadcast', () {
    late AgentClientManagerStateNotifier clientManager;
    late _TestableNetworkManager networkManager;
    late MockAgentClientFactory mockFactory;

    setUp(() {
      mockFactory = MockAgentClientFactory();
      clientManager = AgentClientManagerStateNotifier();

      final persistenceManager = AgentNetworkPersistenceManager(
        configManager: VideConfigManager(configRoot: '/tmp/vide_test_config'),
      );

      final factoryRegistry = AgentClientFactoryRegistry(
        factories: {'claude-code': _StubClientFactory()},
        defaultHarness: 'claude-code',
      );

      final statusNotifiers = <String, AgentStatusNotifier>{};

      networkManager = _TestableNetworkManager(
        workingDirectory: '/tmp/vide_test',
        claudeManager: clientManager,
        persistenceManager: persistenceManager,
        getTriggerService: () => TriggerService(
          teamFrameworkLoader: TeamFrameworkLoader(
            workingDirectory: '/tmp/vide_test',
          ),
          getNetworkManager: () => networkManager,
        ),
        factoryRegistry: factoryRegistry,
        getStatusNotifier: (id) => statusNotifiers.putIfAbsent(
          id,
          () => AgentStatusNotifier(agentId: id),
        ),
        getStatus: (_) => AgentStatus.idle,
      );
    });

    tearDown(() {
      mockFactory.clear();
    });

    AgentNetwork createNetwork(List<String> agentIds) {
      return AgentNetwork(
        id: 'test-network',
        goal: 'Test broadcast',
        agents: agentIds
            .map((id) => AgentMetadata(
                  id: id,
                  name: 'Agent $id',
                  type: id == agentIds.first ? 'main' : 'implementer',
                  createdAt: DateTime.now(),
                ))
            .toList(),
        createdAt: DateTime.now(),
      );
    }

    void registerMockClients(List<String> agentIds) {
      for (final id in agentIds) {
        clientManager.addAgent(id, mockFactory.getClient(id));
      }
    }

    test('delivers to all agents except sender', () {
      final agentIds = ['agent-a', 'agent-b', 'agent-c'];
      registerMockClients(agentIds);
      networkManager.setNetwork(createNetwork(agentIds));

      final count = networkManager.broadcastMessage(
        message: 'Hello everyone!',
        sentBy: 'agent-a',
      );

      expect(count, 2);

      // Sender should NOT have received the message
      expect(mockFactory.getClient('agent-a').sentMessages, isEmpty);

      // Other agents should have received it
      expect(mockFactory.getClient('agent-b').sentMessages, hasLength(1));
      expect(mockFactory.getClient('agent-c').sentMessages, hasLength(1));

      // Verify the message content includes system-reminder wrapping
      final msgB = mockFactory.getClient('agent-b').sentMessages.first.text;
      expect(msgB, contains('Hello everyone!'));
      expect(msgB, contains('system-reminder'));
    });

    test('returns 0 when sender is only agent', () {
      registerMockClients(['agent-a']);
      networkManager.setNetwork(createNetwork(['agent-a']));

      final count = networkManager.broadcastMessage(
        message: 'Hello?',
        sentBy: 'agent-a',
      );

      expect(count, 0);
      expect(mockFactory.getClient('agent-a').sentMessages, isEmpty);
    });

    test('throws StateError when no active network', () {
      expect(
        () => networkManager.broadcastMessage(
          message: 'No network',
          sentBy: 'agent-a',
        ),
        throwsStateError,
      );
    });

    test('continues delivery when one target fails', () {
      final agentIds = ['agent-a', 'agent-b', 'agent-c'];
      // Register clients for a and c, but NOT b — sendMessageToAgent will throw
      clientManager.addAgent('agent-a', mockFactory.getClient('agent-a'));
      clientManager.addAgent('agent-c', mockFactory.getClient('agent-c'));
      networkManager.setNetwork(createNetwork(agentIds));

      final count = networkManager.broadcastMessage(
        message: 'Partial delivery test',
        sentBy: 'agent-a',
      );

      // Reports only successful deliveries (1 of 2 targets)
      expect(count, 1);

      // agent-c should still have received the message
      expect(mockFactory.getClient('agent-c').sentMessages, hasLength(1));
    });

    test('regular sendMessageToAgent still works (regression)', () {
      registerMockClients(['agent-a', 'agent-b']);
      networkManager.setNetwork(createNetwork(['agent-a', 'agent-b']));

      networkManager.sendMessageToAgent(
        targetAgentId: 'agent-b',
        message: 'Direct message',
        sentBy: 'agent-a',
      );

      expect(mockFactory.getClient('agent-b').sentMessages, hasLength(1));
      expect(
        mockFactory.getClient('agent-b').sentMessages.first.text,
        contains('Direct message'),
      );
    });
  });
}
