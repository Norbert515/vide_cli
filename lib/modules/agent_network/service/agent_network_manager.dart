import 'package:claude_api/claude_api.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_cli/modules/agent_network/service/claude_manager.dart';
import 'package:vide_cli/modules/haiku/haiku_providers.dart';
import 'package:vide_cli/modules/haiku/message_enhancement_service.dart';
import 'package:vide_cli/services/posthog_service.dart';
import 'package:vide_cli/modules/agent_network/models/agent_id.dart';
import 'package:vide_cli/modules/agent_network/models/agent_metadata.dart';
import 'package:vide_cli/modules/agent_network/models/agent_network.dart';
import 'package:vide_cli/modules/agent_network/service/agent_network_persistence_manager.dart';
import 'package:vide_cli/modules/agents/configs/context_collection_agent_config.dart';
import 'package:vide_cli/modules/agents/configs/flutter_tester_agent_config.dart';
import 'package:vide_cli/modules/agents/configs/implementation_agent_config.dart';
import 'package:vide_cli/modules/agents/configs/main_agent_config.dart';
import 'package:vide_cli/modules/agents/configs/planning_agent_config.dart';
import 'package:vide_cli/modules/agents/models/agent_configuration.dart';
import 'package:vide_cli/modules/agent_network/state/agent_status_manager.dart';
import 'package:vide_cli/modules/mcp/mcp_provider.dart';
import 'package:vide_cli/utils/project_detector.dart';
import 'package:vide_cli/utils/working_dir_provider.dart';
import 'package:uuid/uuid.dart';

/// Agent types that can be spawned via the agent network.
enum SpawnableAgentType { implementation, contextCollection, flutterTester, planning }

extension SpawnableAgentTypeExtension on SpawnableAgentType {
  AgentConfiguration configuration({ProjectType projectType = ProjectType.unknown}) {
    switch (this) {
      case SpawnableAgentType.implementation:
        return ImplementationAgentConfig.create();
      case SpawnableAgentType.contextCollection:
        return ContextCollectionAgentConfig.create();
      case SpawnableAgentType.flutterTester:
        return FlutterTesterAgentConfig.create();
      case SpawnableAgentType.planning:
        return PlanningAgentConfig.create();
    }
  }
}

/// The state of the agent network manager - just tracks the current network
class AgentNetworkState {
  AgentNetworkState({this.currentNetwork});

  /// The currently active agent network (source of truth for agents)
  final AgentNetwork? currentNetwork;

  /// Convenience getter for agent metadata in the current network
  List<AgentMetadata> get agents => currentNetwork?.agents ?? [];

  /// Convenience getter for just agent IDs
  List<AgentId> get agentIds => currentNetwork?.agentIds ?? [];

  AgentNetworkState copyWith({AgentNetwork? currentNetwork}) {
    return AgentNetworkState(currentNetwork: currentNetwork ?? this.currentNetwork);
  }
}

final agentNetworkManagerProvider = StateNotifierProvider<AgentNetworkManager, AgentNetworkState>((ref) {
  return AgentNetworkManager(workingDirectory: ref.watch(workingDirProvider), ref: ref);
});

class AgentNetworkManager extends StateNotifier<AgentNetworkState> {
  AgentNetworkManager({required this.workingDirectory, required this.ref}) : super(AgentNetworkState());

  final String workingDirectory;
  final Ref ref;

  /// Get the effective working directory (worktree if set, else original).
  String get effectiveWorkingDirectory =>
      state.currentNetwork?.worktreePath ?? workingDirectory;

  /// Counter for generating "Task X" names
  static int _taskCounter = 0;

  /// Start a new agent network with the given initial message
  Future<AgentNetwork> startNew(Message initialMessage) async {
    final networkId = const Uuid().v4();
    final mainAgentId = const Uuid().v4();

    // Increment task counter for "Task X" naming
    _taskCounter++;

    final mainAgentMetadata = AgentMetadata(
      id: mainAgentId,
      name: 'Main',
      type: 'main',
      createdAt: DateTime.now(),
    );

    // Use generic "Task X" as the display name until agent sets it via setTaskName
    final taskDisplayName = 'Task $_taskCounter';

    final network = AgentNetwork(
      id: networkId,
      goal: taskDisplayName,
      agents: [mainAgentMetadata],
      createdAt: DateTime.now(),
      lastActiveAt: DateTime.now(),
    );

    // Persist the network
    await ref.read(agentNetworkPersistenceManagerProvider).saveNetwork(network);

    // Track analytics
    PostHogService.conversationStarted();

    // Start the main agent
    final mainAgentConfig = MainAgentConfig.create();
    final mainAgentClaudeClient = await _inflateClaudeClient(
      AgentIdAndClaudeConfig(agentId: mainAgentId, config: mainAgentConfig),
    );
    ref.read(claudeManagerProvider.notifier).addAgent(mainAgentId, mainAgentClaudeClient);

    state = AgentNetworkState(currentNetwork: network);

    // Generate loading words in the background (don't await)
    MessageEnhancementService.generateLoadingWords(
      initialMessage.text,
      (words) => ref.read(loadingWordsProvider.notifier).state = words,
    );

    // Send the initial message (preserves attachments)
    ref.read(claudeProvider(mainAgentId))?.sendMessage(initialMessage);

    return network;
  }

  /// Resume an existing agent network
  Future<void> resume(AgentNetwork network) async {
    // Update last active timestamp
    final updatedNetwork = network.copyWith(lastActiveAt: DateTime.now());

    // Set state IMMEDIATELY before any async work to prevent flash of empty state
    state = AgentNetworkState(currentNetwork: updatedNetwork);

    // Persist in background - UI already has the data
    await ref.read(agentNetworkPersistenceManagerProvider).saveNetwork(updatedNetwork);

    // Recreate ClaudeClients for each agent in the network
    for (final agentMetadata in updatedNetwork.agents) {
      final config = _getConfigurationForType(agentMetadata.type);
      final client = await _inflateClaudeClient(
        AgentIdAndClaudeConfig(agentId: agentMetadata.id, config: config),
      );
      ref.read(claudeManagerProvider.notifier).addAgent(agentMetadata.id, client);
    }

    // Restore persisted status for each agent
    for (final agent in updatedNetwork.agents) {
      ref.read(agentStatusProvider(agent.id).notifier).setStatus(agent.status);
    }
  }

  /// Get the appropriate AgentConfiguration for a given agent type string
  AgentConfiguration _getConfigurationForType(String type) {
    switch (type) {
      case 'main':
        return MainAgentConfig.create();
      case 'implementation':
        return ImplementationAgentConfig.create();
      case 'contextCollection':
        return ContextCollectionAgentConfig.create();
      case 'flutterTester':
        return FlutterTesterAgentConfig.create();
      case 'planning':
        return PlanningAgentConfig.create();
      default:
        // Fallback to main agent config for unknown types
        print('[AgentNetworkManager] Warning: Unknown agent type "$type", using main config');
        return MainAgentConfig.create();
    }
  }

  /// Add a new agent to the current network
  Future<AgentId> addAgent(AgentIdAndClaudeConfig config, AgentMetadata metadata) async {
    final network = state.currentNetwork;
    if (network == null) {
      throw StateError('No active network to add agent to');
    }

    final client = await _inflateClaudeClient(config);
    ref.read(claudeManagerProvider.notifier).addAgent(config.agentId, client);

    // Update network with new agent metadata
    final updatedNetwork = network.copyWith(agents: [...network.agents, metadata], lastActiveAt: DateTime.now());
    await ref.read(agentNetworkPersistenceManagerProvider).saveNetwork(updatedNetwork);

    state = AgentNetworkState(currentNetwork: updatedNetwork);

    return config.agentId;
  }

  /// Update the goal of the current network
  Future<void> updateGoal(String newGoal) async {
    final network = state.currentNetwork;
    if (network == null) {
      throw StateError('No active network to update goal for');
    }

    final updatedNetwork = network.copyWith(goal: newGoal, lastActiveAt: DateTime.now());
    await ref.read(agentNetworkPersistenceManagerProvider).saveNetwork(updatedNetwork);

    state = AgentNetworkState(currentNetwork: updatedNetwork);
  }

  /// Update the name of an agent in the current network
  Future<void> updateAgentName(AgentId agentId, String newName) async {
    final network = state.currentNetwork;
    if (network == null) {
      throw StateError('No active network to update agent name in');
    }

    final updatedAgents = network.agents.map((agent) {
      if (agent.id == agentId) {
        return agent.copyWith(name: newName);
      }
      return agent;
    }).toList();

    final updatedNetwork = network.copyWith(agents: updatedAgents, lastActiveAt: DateTime.now());
    await ref.read(agentNetworkPersistenceManagerProvider).saveNetwork(updatedNetwork);

    state = AgentNetworkState(currentNetwork: updatedNetwork);
  }

  /// Update the task name of an agent in the current network
  Future<void> updateAgentTaskName(AgentId agentId, String taskName) async {
    final network = state.currentNetwork;
    if (network == null) {
      throw StateError('No active network to update agent task name in');
    }

    final updatedAgents = network.agents.map((agent) {
      if (agent.id == agentId) {
        return agent.copyWith(taskName: taskName);
      }
      return agent;
    }).toList();

    final updatedNetwork = network.copyWith(agents: updatedAgents, lastActiveAt: DateTime.now());
    await ref.read(agentNetworkPersistenceManagerProvider).saveNetwork(updatedNetwork);

    state = AgentNetworkState(currentNetwork: updatedNetwork);
  }

  /// Set worktree path for the current session. All new agents will use this directory.
  Future<void> setWorktreePath(String? worktreePath) async {
    final network = state.currentNetwork;
    if (network == null) return;

    final updated = worktreePath == null
        ? network.copyWith(clearWorktreePath: true, lastActiveAt: DateTime.now())
        : network.copyWith(worktreePath: worktreePath, lastActiveAt: DateTime.now());
    await ref.read(agentNetworkPersistenceManagerProvider).saveNetwork(updated);
    state = state.copyWith(currentNetwork: updated);
  }

  void sendMessage(AgentId agentId, Message message) {
    final claudeManager = ref.read(claudeProvider(agentId));
    claudeManager?.sendMessage(message);
  }

  /// Spawn a new agent into the current network.
  ///
  /// [agentType] - The type of agent to spawn
  /// [name] - A short, human-readable name for the agent (required)
  /// [initialPrompt] - The initial message/task to send to the new agent
  /// [spawnedBy] - The ID of the agent that is spawning this one (for context)
  ///
  /// Returns the ID of the newly spawned agent.
  Future<AgentId> spawnAgent({
    required SpawnableAgentType agentType,
    required String name,
    required String initialPrompt,
    required AgentId spawnedBy,
  }) async {
    final network = state.currentNetwork;
    if (network == null) {
      throw StateError('No active network to spawn agent into');
    }

    // Detect project type for proper configuration
    final projectType = ProjectType.unknown; // TODO: Get from context if available

    // Create agent configuration based on type
    final AgentConfiguration config = agentType.configuration(projectType: projectType);

    // Generate new agent ID
    final newAgentId = const Uuid().v4();

    // Create metadata for the new agent
    final metadata = AgentMetadata(
      id: newAgentId,
      name: name,
      type: agentType.name,
      spawnedBy: spawnedBy,
      createdAt: DateTime.now(),
    );

    // Add agent to network with metadata
    await addAgent(AgentIdAndClaudeConfig(agentId: newAgentId, config: config), metadata);

    // Track analytics
    PostHogService.agentSpawned(agentType.name);

    // Prepend context about who spawned this agent
    final contextualPrompt = '''[SPAWNED BY AGENT: $spawnedBy]

$initialPrompt''';

    // Send initial message to the new agent
    sendMessage(newAgentId, Message.text(contextualPrompt));

    print('[AgentNetworkManager] Agent $spawnedBy spawned new ${agentType.name} agent "$name": $newAgentId');

    return newAgentId;
  }

  /// Terminate an agent and remove it from the network.
  ///
  /// This will:
  /// 1. Abort the agent's ClaudeClient
  /// 2. Remove the agent from the ClaudeManager
  /// 3. Remove the agent from the network's agents list
  /// 4. Persist the updated network
  ///
  /// [targetAgentId] - The ID of the agent to terminate
  /// [terminatedBy] - The ID of the agent requesting termination
  /// [reason] - Optional reason for termination (for logging)
  Future<void> terminateAgent({
    required AgentId targetAgentId,
    required AgentId terminatedBy,
    String? reason,
  }) async {
    final network = state.currentNetwork;
    if (network == null) {
      throw StateError('No active network');
    }

    // Check if target agent exists in network
    final targetAgent = network.agents.where((a) => a.id == targetAgentId).firstOrNull;
    if (targetAgent == null) {
      throw Exception('Agent not found in network: $targetAgentId');
    }

    // Prevent terminating the main agent
    if (targetAgent.type == 'main') {
      throw Exception('Cannot terminate the main agent');
    }

    // Get and abort the ClaudeClient
    final claudeClients = ref.read(claudeManagerProvider);
    final client = claudeClients[targetAgentId];
    if (client != null) {
      await client.abort();
    }

    // Remove from ClaudeManager
    ref.read(claudeManagerProvider.notifier).removeAgent(targetAgentId);

    // Remove from network agents list
    final updatedAgents = network.agents.where((a) => a.id != targetAgentId).toList();
    final updatedNetwork = network.copyWith(
      agents: updatedAgents,
      lastActiveAt: DateTime.now(),
    );

    // Persist
    await ref.read(agentNetworkPersistenceManagerProvider).saveNetwork(updatedNetwork);

    // Update state
    state = AgentNetworkState(currentNetwork: updatedNetwork);

    final reasonStr = reason != null ? ': $reason' : '';
    final selfTerminated = targetAgentId == terminatedBy;
    if (selfTerminated) {
      print('[AgentNetworkManager] Agent $targetAgentId self-terminated$reasonStr');
    } else {
      print('[AgentNetworkManager] Agent $terminatedBy terminated agent $targetAgentId$reasonStr');
    }
  }

  /// Send a message to another agent asynchronously (fire-and-forget).
  ///
  /// The message is sent and the caller continues immediately.
  /// The target agent will process the message and can respond back by
  /// sending a message to the caller, which will "wake up" the caller.
  ///
  /// [targetAgentId] - The ID of the agent to send the message to
  /// [message] - The message to send
  /// [sentBy] - The ID of the agent sending the message (for context)
  void sendMessageToAgent({required AgentId targetAgentId, required String message, required AgentId sentBy}) {
    final claudeClients = ref.read(claudeManagerProvider);

    // Check if target agent exists
    final targetClient = claudeClients[targetAgentId];
    if (targetClient == null) {
      throw Exception('Agent not found: $targetAgentId');
    }

    // Prepend context about who is sending this message
    final contextualMessage = '''[MESSAGE FROM AGENT: $sentBy]

$message''';

    // Send the message - fire and forget
    targetClient.sendMessage(Message.text(contextualMessage));

    print('[AgentNetworkManager] Agent $sentBy sent message to agent $targetAgentId');
  }

  Future<ClaudeClient> _inflateClaudeClient(AgentIdAndClaudeConfig config) async {
    final claudeConfig = config.config.toClaudeConfig(
      workingDirectory: effectiveWorkingDirectory,
      sessionId: config.agentId.toString(),
    );
    final mcpServers = config.config.mcpServers!
        .map(
          (server) => ref.watch(
            genericMcpServerProvider(AgentIdAndMcpServerType(agentId: config.agentId, mcpServerType: server)),
          ),
        )
        .toList();
    return await ClaudeClient.create(config: claudeConfig, mcpServers: mcpServers);
  }
}
