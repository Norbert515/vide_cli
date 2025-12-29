import 'package:claude_sdk/claude_sdk.dart';
import 'package:riverpod/riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/agent_id.dart';
import '../models/agent_metadata.dart';
import '../models/agent_network.dart';
import '../agents/context_collection_agent_config.dart';
import '../agents/flutter_tester_agent_config.dart';
import '../agents/implementation_agent_config.dart';
import '../agents/main_agent_config.dart';
import '../agents/planning_agent_config.dart';
import '../agents/agent_configuration.dart';
import '../utils/project_detector.dart';
import '../utils/working_dir_provider.dart';
import 'agent_network_persistence_manager.dart';
import 'claude_client_factory.dart';
import 'claude_manager.dart';
import 'posthog_service.dart';
import '../state/agent_status_manager.dart';

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
  AgentNetworkManager({required this.workingDirectory, required Ref ref})
      : _ref = ref,
        super(AgentNetworkState()) {
    _clientFactory = ClaudeClientFactoryImpl(
      getWorkingDirectory: () => effectiveWorkingDirectory,
      ref: _ref,
    );
  }

  final String workingDirectory;
  final Ref _ref;
  late final ClaudeClientFactory _clientFactory;

  /// Get the effective working directory (worktree if set, else original).
  String get effectiveWorkingDirectory =>
      state.currentNetwork?.worktreePath ?? workingDirectory;

  /// Counter for generating "Task X" names
  static int _taskCounter = 0;

  /// Start a new agent network with the given initial message
  ///
  /// [workingDirectory] - Optional working directory for the network.
  /// If provided, it's atomically set as worktreePath in the network.
  /// If null, effectiveWorkingDirectory falls back to the provider value.
  Future<AgentNetwork> startNew(Message initialMessage, {String? workingDirectory}) async {
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
      worktreePath: workingDirectory, // Atomically set working directory from parameter
    );

    // Set state IMMEDIATELY so UI can navigate right away
    state = AgentNetworkState(currentNetwork: network);

    // Create and add client SYNCHRONOUSLY so UI has it immediately
    final mainAgentConfig = MainAgentConfig.create();
    final mainAgentClaudeClient = _clientFactory.createSync(
      agentId: mainAgentId,
      config: mainAgentConfig,
    );
    _ref.read(claudeManagerProvider.notifier).addAgent(mainAgentId, mainAgentClaudeClient);

    // Track analytics
    PostHogService.conversationStarted();

    // Do persistence in background
    () async {
      await _ref.read(agentNetworkPersistenceManagerProvider).saveNetwork(network);
    }();

    // Send the initial message - it will be queued until client is ready
    mainAgentClaudeClient.sendMessage(initialMessage);

    return network;
  }

  /// Resume an existing agent network
  Future<void> resume(AgentNetwork network) async {
    // Update last active timestamp
    final updatedNetwork = network.copyWith(lastActiveAt: DateTime.now());

    // Set state IMMEDIATELY before any async work to prevent flash of empty state
    state = AgentNetworkState(currentNetwork: updatedNetwork);

    // Persist in background - UI already has the data
    await _ref.read(agentNetworkPersistenceManagerProvider).saveNetwork(updatedNetwork);

    // Recreate ClaudeClients for each agent in the network
    // Use sync version to avoid blocking on init (same as startNew)
    for (final agentMetadata in updatedNetwork.agents) {
      final config = _getConfigurationForType(agentMetadata.type);
      final client = _clientFactory.createSync(
        agentId: agentMetadata.id,
        config: config,
      );
      _ref.read(claudeManagerProvider.notifier).addAgent(agentMetadata.id, client);
    }

    // Restore persisted status for each agent
    for (final agent in updatedNetwork.agents) {
      _ref.read(agentStatusProvider(agent.id).notifier).setStatus(agent.status);
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
  Future<AgentId> addAgent({
    required AgentId agentId,
    required AgentConfiguration config,
    required AgentMetadata metadata,
  }) async {
    final network = state.currentNetwork;
    if (network == null) {
      throw StateError('No active network to add agent to');
    }

    final client = await _clientFactory.create(
      agentId: agentId,
      config: config,
    );
    _ref.read(claudeManagerProvider.notifier).addAgent(agentId, client);

    // Update network with new agent metadata
    final updatedNetwork = network.copyWith(agents: [...network.agents, metadata], lastActiveAt: DateTime.now());
    await _ref.read(agentNetworkPersistenceManagerProvider).saveNetwork(updatedNetwork);

    state = AgentNetworkState(currentNetwork: updatedNetwork);

    return agentId;
  }

  /// Update the goal of the current network
  Future<void> updateGoal(String newGoal) async {
    final network = state.currentNetwork;
    if (network == null) {
      throw StateError('No active network to update goal for');
    }

    final updatedNetwork = network.copyWith(goal: newGoal, lastActiveAt: DateTime.now());
    await _ref.read(agentNetworkPersistenceManagerProvider).saveNetwork(updatedNetwork);

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
    await _ref.read(agentNetworkPersistenceManagerProvider).saveNetwork(updatedNetwork);

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
    await _ref.read(agentNetworkPersistenceManagerProvider).saveNetwork(updatedNetwork);

    state = AgentNetworkState(currentNetwork: updatedNetwork);
  }

  /// Update token usage stats for an agent.
  ///
  /// Call this when conversation token totals change to keep agent metadata in sync.
  /// Does NOT persist immediately - call is synchronous for performance.
  /// Token stats will be persisted on the next network save (e.g., when agent terminates).
  void updateAgentTokenStats(
    AgentId agentId, {
    required int totalInputTokens,
    required int totalOutputTokens,
    required int totalCacheReadInputTokens,
    required int totalCacheCreationInputTokens,
    required double totalCostUsd,
  }) {
    final network = state.currentNetwork;
    if (network == null) return;

    final updatedAgents = network.agents.map((agent) {
      if (agent.id == agentId) {
        return agent.copyWith(
          totalInputTokens: totalInputTokens,
          totalOutputTokens: totalOutputTokens,
          totalCacheReadInputTokens: totalCacheReadInputTokens,
          totalCacheCreationInputTokens: totalCacheCreationInputTokens,
          totalCostUsd: totalCostUsd,
        );
      }
      return agent;
    }).toList();

    final updatedNetwork = network.copyWith(agents: updatedAgents);
    state = AgentNetworkState(currentNetwork: updatedNetwork);
  }

  /// Set worktree path for the current session. All new agents will use this directory.
  Future<void> setWorktreePath(String? worktreePath) async {
    final network = state.currentNetwork;
    if (network == null) return;

    final updated = worktreePath == null
        ? network.copyWith(clearWorktreePath: true, lastActiveAt: DateTime.now())
        : network.copyWith(worktreePath: worktreePath, lastActiveAt: DateTime.now());
    await _ref.read(agentNetworkPersistenceManagerProvider).saveNetwork(updated);
    state = state.copyWith(currentNetwork: updated);
  }

  void sendMessage(AgentId agentId, Message message) {
    final claudeManager = _ref.read(claudeProvider(agentId));
    if (claudeManager == null) {
      print('[AgentNetworkManager] WARNING: No ClaudeClient found for agent: $agentId');
      return;
    }
    claudeManager.sendMessage(message);
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
    await addAgent(agentId: newAgentId, config: config, metadata: metadata);

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
    final claudeClients = _ref.read(claudeManagerProvider);
    final client = claudeClients[targetAgentId];
    if (client != null) {
      await client.abort();
    }

    // Remove from ClaudeManager
    _ref.read(claudeManagerProvider.notifier).removeAgent(targetAgentId);

    // Remove from network agents list
    final updatedAgents = network.agents.where((a) => a.id != targetAgentId).toList();
    final updatedNetwork = network.copyWith(
      agents: updatedAgents,
      lastActiveAt: DateTime.now(),
    );

    // Persist
    await _ref.read(agentNetworkPersistenceManagerProvider).saveNetwork(updatedNetwork);

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
    final claudeClients = _ref.read(claudeManagerProvider);

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
}
