import 'dart:io';

import 'package:riverpod/riverpod.dart';
import 'package:vide_core/vide_core.dart';
import 'package:vide_core/src/agent_network/agent_network_manager.dart';
import 'mock_agent_client.dart';
import 'mock_vide_config_manager.dart';

/// Standard test harness for LocalVideSession tests.
///
/// Provides a fully wired session with a single main agent backed by
/// a [MockAgentClient]. Call [dispose] in tearDown.
class SessionTestHarness {
  late Directory tempDir;
  late MockVideConfigManager configManager;
  late ProviderContainer container;
  late MockAgentClient mockClient;
  late LocalVideSession session;

  final String agentId;
  final String networkId;

  SessionTestHarness({
    this.agentId = 'main-agent',
    this.networkId = 'test-network',
  });

  /// Set up the harness. Call from setUp().
  Future<void> setUp({bool dangerouslySkipPermissions = false}) async {
    tempDir = await Directory.systemTemp.createTemp('session_test_');
    configManager = MockVideConfigManager(tempDir: tempDir);

    container = ProviderContainer(
      overrides: [
        videCoreConfigProvider.overrideWithValue(VideCoreConfig(
          workingDirectory: tempDir.path,
          configManager: configManager,
          permissionHandler: PermissionHandler(),
          dangerouslySkipPermissions: dangerouslySkipPermissions,
        )),
      ],
    );

    mockClient = MockAgentClient(sessionId: agentId);
    container
        .read(agentClientManagerProvider.notifier)
        .addAgent(agentId, mockClient);

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

    session = LocalVideSession.create(
      networkId: networkId,
      container: container,
    );
  }

  /// Add a second agent to the network with its own MockAgentClient.
  MockAgentClient addAgent({
    required String id,
    String name = 'Sub Agent',
    String type = 'implementation',
    String? spawnedBy,
  }) {
    final client = MockAgentClient(sessionId: id);
    container.read(agentClientManagerProvider.notifier).addAgent(id, client);

    final manager = container.read(agentNetworkManagerProvider.notifier);
    final network = manager.state.currentNetwork!;
    manager.state = AgentNetworkState(
      currentNetwork: network.copyWith(
        agents: [
          ...network.agents,
          AgentMetadata(
            id: id,
            name: name,
            type: type,
            spawnedBy: spawnedBy ?? agentId,
            createdAt: DateTime.now(),
          ),
        ],
      ),
    );

    return client;
  }

  /// Collect all events from the session into a list.
  List<VideEvent> collectEvents() {
    final events = <VideEvent>[];
    session.events.listen(events.add);
    return events;
  }

  /// Tear down the harness. Call from tearDown().
  Future<void> dispose() async {
    await session.dispose(fireEndTrigger: false);
    container.dispose();
    await configManager.dispose();
  }
}
