import 'dart:io';

import 'package:claude_sdk/claude_sdk.dart';
import 'package:riverpod/riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/agent_id.dart';
import '../models/agent_metadata.dart';
import '../models/agent_network.dart';
import '../agents/agent_configuration.dart';
import '../utils/working_dir_provider.dart';
import 'agent_network_persistence_manager.dart';
import 'claude_client_factory.dart';
import 'claude_manager.dart';
import 'posthog_service.dart';
import 'team_framework_loader.dart';
import '../state/agent_status_manager.dart';

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
    return AgentNetworkState(
      currentNetwork: currentNetwork ?? this.currentNetwork,
    );
  }
}

final agentNetworkManagerProvider =
    StateNotifierProvider<AgentNetworkManager, AgentNetworkState>((ref) {
      return AgentNetworkManager(
        workingDirectory: ref.watch(workingDirProvider),
        ref: ref,
      );
    });

class AgentNetworkManager extends StateNotifier<AgentNetworkState> {
  AgentNetworkManager({required this.workingDirectory, required Ref ref})
    : _ref = ref,
      super(AgentNetworkState()) {
    _clientFactory = ClaudeClientFactoryImpl(
      getWorkingDirectory: () => effectiveWorkingDirectory,
      ref: _ref,
    );
    _teamFrameworkLoader = TeamFrameworkLoader(
      workingDirectory: workingDirectory,
    );
  }

  final String workingDirectory;
  final Ref _ref;
  late final ClaudeClientFactory _clientFactory;
  late final TeamFrameworkLoader _teamFrameworkLoader;

  /// Get the effective working directory (worktree if set and exists, else original).
  ///
  /// If a worktreePath is set but the directory no longer exists (e.g., worktree was deleted),
  /// automatically clears it and falls back to the original working directory.
  String get effectiveWorkingDirectory {
    final worktreePath = state.currentNetwork?.worktreePath;
    if (worktreePath != null && Directory(worktreePath).existsSync()) {
      return worktreePath;
    }

    // Worktree path is set but no longer exists - clear it and fall back to original
    if (worktreePath != null) {
      // Schedule async cleanup without blocking
      Future.microtask(() => _clearStaleWorktreePath(worktreePath));
    }

    return workingDirectory;
  }

  /// Clear a stale worktree path from the current network
  Future<void> _clearStaleWorktreePath(String stalePath) async {
    final network = state.currentNetwork;
    if (network != null && network.worktreePath == stalePath) {
      final updated = network.copyWith(
        worktreePath: null,
        clearWorktreePath: true,
      );
      state = AgentNetworkState(currentNetwork: updated);
      await _ref
          .read(agentNetworkPersistenceManagerProvider)
          .saveNetwork(updated);
    }
  }

  /// Counter for generating "Task X" names
  static int _taskCounter = 0;

  /// Start a new agent network with the given initial message
  ///
  /// [workingDirectory] - Optional working directory for the network.
  /// If provided, it's atomically set as worktreePath in the network.
  /// If null, effectiveWorkingDirectory falls back to the provider value.
  ///
  /// [model] - Optional model override (e.g., 'sonnet', 'opus', 'haiku').
  /// If provided, overrides the default model for the main agent.
  ///
  /// [permissionMode] - Optional permission mode override (e.g., 'accept-edits', 'plan', 'ask', 'deny').
  /// If provided, overrides the default permission mode for the main agent.
  ///
  /// [team] - The team framework team to use for this network.
  /// Determines which agent personalities are used for each role.
  /// Defaults to 'vide-classic'.
  Future<AgentNetwork> startNew(
    Message initialMessage, {
    String? workingDirectory,
    String? model,
    String? permissionMode,
    String team = 'vide-classic',
  }) async {
    final networkId = const Uuid().v4();

    // Increment task counter for "Task X" naming
    _taskCounter++;

    // Use generic "Task X" as the display name until agent sets it via setTaskName
    final taskDisplayName = 'Task $_taskCounter';

    // Generate a new unique agent ID for this conversation
    // Note: We don't reuse the pre-warmed client's agentId because that would
    // cause a session conflict when creating a new client with a different config
    final mainAgentId = const Uuid().v4();

    // Load the main agent configuration from the selected team
    final teamDef = await _teamFrameworkLoader.getTeam(team);
    if (teamDef == null) {
      throw Exception('Team "$team" not found in team framework');
    }

    final leadAgentName = teamDef.composition['lead'];
    if (leadAgentName == null) {
      throw Exception('Team "$team" has no "lead" agent defined');
    }

    final leadConfig = await _teamFrameworkLoader.buildAgentConfiguration(
      leadAgentName,
      teamName: team,
    );
    if (leadConfig == null) {
      throw Exception('Agent configuration not found for: $leadAgentName');
    }

    // Create client synchronously - initialization happens in background
    // The client queues messages until ready, enabling instant navigation
    final mainAgentClaudeClient = _clientFactory.createSync(
      agentId: mainAgentId,
      config: leadConfig,
      networkId: networkId,
      agentType: 'main',
    );

    // Apply model override if provided (will take effect once client initializes)
    if (model != null) {
      mainAgentClaudeClient.setModel(model);
    }

    final mainAgentMetadata = AgentMetadata(
      id: mainAgentId,
      name: leadConfig.name,  // Use the actual agent personality name (e.g., "cautious-lead")
      type: 'main',
      createdAt: DateTime.now(),
    );

    final network = AgentNetwork(
      id: networkId,
      goal: taskDisplayName,
      agents: [mainAgentMetadata],
      createdAt: DateTime.now(),
      lastActiveAt: DateTime.now(),
      worktreePath:
          workingDirectory, // Atomically set working directory from parameter
      team: team,
    );

    // Set state IMMEDIATELY so UI can navigate right away
    state = AgentNetworkState(currentNetwork: network);

    _ref
        .read(claudeManagerProvider.notifier)
        .addAgent(mainAgentId, mainAgentClaudeClient);

    // Track analytics
    PostHogService.conversationStarted();

    // Do persistence in background
    () async {
      await _ref
          .read(agentNetworkPersistenceManagerProvider)
          .saveNetwork(network);
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
    await _ref
        .read(agentNetworkPersistenceManagerProvider)
        .saveNetwork(updatedNetwork);

    // Recreate ClaudeClients for each agent in the network
    for (final agentMetadata in updatedNetwork.agents) {
      try {
        final config = await _getConfigurationForType(
          agentMetadata.type,
          teamName: updatedNetwork.team,
        );
        // Use sessionId if available (for forked agents), otherwise use agent id
        final sessionIdToUse = agentMetadata.sessionId ?? agentMetadata.id;
        final client = _clientFactory.createSync(
          agentId: sessionIdToUse,
          config: config,
          networkId: updatedNetwork.id,
          agentType: agentMetadata.type,
        );
        _ref
            .read(claudeManagerProvider.notifier)
            .addAgent(agentMetadata.id, client);
      } catch (e) {
        print('[AgentNetworkManager] Error loading config for agent ${agentMetadata.type}: $e');
        rethrow;
      }
    }

    // Restore persisted status for each agent
    for (final agent in updatedNetwork.agents) {
      _ref.read(agentStatusProvider(agent.id).notifier).setStatus(agent.status);
    }
  }

  /// Get the appropriate AgentConfiguration for a given agent type/role string.
  ///
  /// This method should not be called directly - it's for internal use during network resume.
  /// For new agents, use spawnAgent which handles team framework loading.
  ///
  /// [type] - The agent type/role (e.g., 'main', 'implementer', 'thinker-creative')
  /// [teamName] - The team to use for looking up agent configurations.
  Future<AgentConfiguration> _getConfigurationForType(String type, {String? teamName}) async {
    // Special cases for main/fork agents
    final role = switch (type) {
      'main' => 'lead',
      'fork' => 'lead',
      _ => type, // The type IS the role (e.g., 'implementer', 'thinker-creative')
    };

    // Use provided team name, or fall back to network's team
    final effectiveTeamName = teamName ?? state.currentNetwork?.team;
    if (effectiveTeamName == null) {
      throw Exception('No team specified and no current network');
    }

    // Get agent name from team composition
    final team = await _teamFrameworkLoader.getTeam(effectiveTeamName);
    if (team == null) {
      throw Exception('Team "$effectiveTeamName" not found in team framework');
    }

    final agentName = team.composition[role];
    if (agentName == null) {
      throw Exception('Team "$effectiveTeamName" has no agent for role "$role"');
    }

    final config = await _teamFrameworkLoader.buildAgentConfiguration(
      agentName,
      teamName: effectiveTeamName,
    );
    if (config == null) {
      throw Exception('Agent configuration not found for: $agentName (role: $role)');
    }

    return config;
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
      networkId: network.id,
      agentType: metadata.type,
    );
    _ref.read(claudeManagerProvider.notifier).addAgent(agentId, client);

    // Update network with new agent metadata
    final updatedNetwork = network.copyWith(
      agents: [...network.agents, metadata],
      lastActiveAt: DateTime.now(),
    );
    await _ref
        .read(agentNetworkPersistenceManagerProvider)
        .saveNetwork(updatedNetwork);

    state = AgentNetworkState(currentNetwork: updatedNetwork);

    return agentId;
  }

  /// Update the goal of the current network
  Future<void> updateGoal(String newGoal) async {
    final network = state.currentNetwork;
    if (network == null) {
      throw StateError('No active network to update goal for');
    }

    final updatedNetwork = network.copyWith(
      goal: newGoal,
      lastActiveAt: DateTime.now(),
    );
    await _ref
        .read(agentNetworkPersistenceManagerProvider)
        .saveNetwork(updatedNetwork);

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

    final updatedNetwork = network.copyWith(
      agents: updatedAgents,
      lastActiveAt: DateTime.now(),
    );
    await _ref
        .read(agentNetworkPersistenceManagerProvider)
        .saveNetwork(updatedNetwork);

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

    final updatedNetwork = network.copyWith(
      agents: updatedAgents,
      lastActiveAt: DateTime.now(),
    );
    await _ref
        .read(agentNetworkPersistenceManagerProvider)
        .saveNetwork(updatedNetwork);

    state = AgentNetworkState(currentNetwork: updatedNetwork);
  }

  /// Update the session ID of an agent in the current network.
  ///
  /// This is called when Claude assigns a new session ID (e.g., during fork).
  /// The session ID may differ from the agent's id and is needed to properly
  /// resume conversations.
  Future<void> updateAgentSessionId(AgentId agentId, String sessionId) async {
    final network = state.currentNetwork;
    if (network == null) return;

    final updatedAgents = network.agents.map((agent) {
      if (agent.id == agentId) {
        return agent.copyWith(sessionId: sessionId);
      }
      return agent;
    }).toList();

    final updatedNetwork = network.copyWith(
      agents: updatedAgents,
      lastActiveAt: DateTime.now(),
    );
    await _ref
        .read(agentNetworkPersistenceManagerProvider)
        .saveNetwork(updatedNetwork);

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

  /// Set worktree path for the current session.
  ///
  /// This will restart all agents so they use the new working directory.
  /// Agent conversation history is cleared since Claude CLI cannot change
  /// its working directory mid-session.
  Future<void> setWorktreePath(String? worktreePath) async {
    final network = state.currentNetwork;
    if (network == null) return;

    // 1. Abort and remove all existing Claude clients
    final claudeManagerNotifier = _ref.read(claudeManagerProvider.notifier);
    final claudeClients = _ref.read(claudeManagerProvider);
    for (final agentId in network.agentIds) {
      final client = claudeClients[agentId];
      if (client != null) {
        await client.abort();
      }
      claudeManagerNotifier.removeAgent(agentId);
    }

    // 2. Update network with new worktree path
    final updated = worktreePath == null
        ? network.copyWith(
            clearWorktreePath: true,
            lastActiveAt: DateTime.now(),
          )
        : network.copyWith(
            worktreePath: worktreePath,
            lastActiveAt: DateTime.now(),
          );

    // 3. Update state first so effectiveWorkingDirectory returns new path
    state = state.copyWith(currentNetwork: updated);

    // 4. Recreate Claude clients for all agents with new working directory
    for (final agentMetadata in updated.agents) {
      try {
        final config = await _getConfigurationForType(
          agentMetadata.type,
          teamName: updated.team,
        );
        final client = _clientFactory.createSync(
          agentId: agentMetadata.id,
          config: config,
          networkId: updated.id,
          agentType: agentMetadata.type,
        );
        claudeManagerNotifier.addAgent(agentMetadata.id, client);
      } catch (e) {
        print('[AgentNetworkManager] Error recreating client for ${agentMetadata.type}: $e');
        rethrow;
      }
    }

    // 5. Persist the updated network
    await _ref
        .read(agentNetworkPersistenceManagerProvider)
        .saveNetwork(updated);
  }

  void sendMessage(AgentId agentId, Message message) {
    final claudeManager = _ref.read(claudeProvider(agentId));
    if (claudeManager == null) {
      print(
        '[AgentNetworkManager] WARNING: No ClaudeClient found for agent: $agentId',
      );
      return;
    }
    claudeManager.sendMessage(message);
  }

  /// Spawn a new agent into the current network by role name.
  ///
  /// [role] - The role name from the team's composition (e.g., 'implementer', 'thinker-creative')
  /// [name] - A short, human-readable name for the agent (required)
  /// [initialPrompt] - The initial message/task to send to the new agent
  /// [spawnedBy] - The ID of the agent that is spawning this one (for context)
  ///
  /// Returns the ID of the newly spawned agent.
  ///
  /// Throws an exception if the role doesn't exist in the current team's composition.
  Future<AgentId> spawnAgent({
    required String role,
    required String name,
    required String initialPrompt,
    required AgentId spawnedBy,
  }) async {
    final network = state.currentNetwork;
    if (network == null) {
      throw StateError('No active network to spawn agent into');
    }

    // Prevent spawning the lead role (that's the main agent)
    if (role == 'lead') {
      throw Exception('Cannot spawn a lead agent - use the main agent instead');
    }

    // Load configuration from team framework using the network's team
    final teamName = network.team;
    final team = await _teamFrameworkLoader.getTeam(teamName);
    if (team == null) {
      throw Exception('Team "$teamName" not found in team framework');
    }

    // Get agent name from team composition
    final agentPersonalityName = team.composition[role];
    if (agentPersonalityName == null) {
      // List available roles for helpful error message
      final availableRoles = team.composition.entries
          .where((e) => e.value != null && e.key != 'lead')
          .map((e) => e.key)
          .toList();
      throw Exception(
        'Team "$teamName" has no agent for role "$role". '
        'Available roles: ${availableRoles.join(", ")}',
      );
    }

    final config = await _teamFrameworkLoader.buildAgentConfiguration(
      agentPersonalityName,
      teamName: teamName,
    );
    if (config == null) {
      throw Exception('Agent configuration not found for: $agentPersonalityName (role: $role)');
    }

    // Generate new agent ID
    final newAgentId = const Uuid().v4();

    // Create metadata for the new agent
    final metadata = AgentMetadata(
      id: newAgentId,
      name: name,
      type: role, // Store the role as the type
      spawnedBy: spawnedBy,
      createdAt: DateTime.now(),
    );

    // Add agent to network with metadata
    await addAgent(agentId: newAgentId, config: config, metadata: metadata);

    // Track analytics
    PostHogService.agentSpawned(role);

    // Prepend context about who spawned this agent
    final contextualPrompt = '''[SPAWNED BY AGENT: $spawnedBy]

$initialPrompt''';

    // Send initial message to the new agent
    sendMessage(newAgentId, Message.text(contextualPrompt));

    print(
      '[AgentNetworkManager] Agent $spawnedBy spawned new $role agent "$name" ($agentPersonalityName): $newAgentId',
    );

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
    final targetAgent = network.agents
        .where((a) => a.id == targetAgentId)
        .firstOrNull;
    if (targetAgent == null) {
      throw Exception('Agent not found in network: $targetAgentId');
    }

    // Prevent terminating if this is the last agent
    if (network.agents.length <= 1) {
      throw Exception('Cannot terminate the last agent');
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
    final updatedAgents = network.agents
        .where((a) => a.id != targetAgentId)
        .toList();
    final updatedNetwork = network.copyWith(
      agents: updatedAgents,
      lastActiveAt: DateTime.now(),
    );

    // Persist
    await _ref
        .read(agentNetworkPersistenceManagerProvider)
        .saveNetwork(updatedNetwork);

    // Update state
    state = AgentNetworkState(currentNetwork: updatedNetwork);

    final reasonStr = reason != null ? ': $reason' : '';
    final selfTerminated = targetAgentId == terminatedBy;
    if (selfTerminated) {
      print(
        '[AgentNetworkManager] Agent $targetAgentId self-terminated$reasonStr',
      );
    } else {
      print(
        '[AgentNetworkManager] Agent $terminatedBy terminated agent $targetAgentId$reasonStr',
      );
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
  void sendMessageToAgent({
    required AgentId targetAgentId,
    required String message,
    required AgentId sentBy,
  }) {
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

    print(
      '[AgentNetworkManager] Agent $sentBy sent message to agent $targetAgentId',
    );
  }

  /// Fork an existing agent, creating a new agent with the same conversation context.
  ///
  /// Uses Claude Code's native --fork-session capability to branch the conversation.
  /// The new agent will start with the full conversation history from the source.
  ///
  /// [sourceAgentId] - The agent to fork from
  /// [name] - Optional name for the forked agent (defaults to "Fork of {original}")
  ///
  /// Returns the ID of the newly forked agent.
  Future<AgentId> forkAgent({
    required AgentId sourceAgentId,
    String? name,
  }) async {
    final network = state.currentNetwork;
    if (network == null) {
      throw StateError('No active network to fork agent in');
    }

    // Find source agent metadata
    final sourceAgent =
        network.agents.where((a) => a.id == sourceAgentId).firstOrNull;
    if (sourceAgent == null) {
      throw Exception('Agent not found: $sourceAgentId');
    }

    // Get source agent's Claude client to get the session ID
    final sourceClient = _ref.read(claudeManagerProvider)[sourceAgentId];
    if (sourceClient == null) {
      throw Exception('No Claude client found for agent: $sourceAgentId');
    }

    // Generate new agent ID (which will also be the new session ID)
    final newAgentId = const Uuid().v4();
    final forkName = name ?? '[Fork] ${sourceAgent.name}';

    // Get the configuration for this agent type
    final config = await _getConfigurationForType(
      sourceAgent.type,
      teamName: network.team,
    );

    // Create metadata for the forked agent
    final metadata = AgentMetadata(
      id: newAgentId,
      name: forkName,
      type: 'fork',
      spawnedBy: sourceAgentId, // Track that this was forked from source
      createdAt: DateTime.now(),
    );

    // Create the Claude client with fork configuration
    // Pass the source conversation so the forked agent shows the same history immediately
    final client = await _clientFactory.createForked(
      agentId: newAgentId,
      config: config,
      networkId: network.id,
      agentType: metadata.type,
      resumeSessionId: sourceClient.sessionId,
      sourceConversation: sourceClient.currentConversation,
    );

    _ref.read(claudeManagerProvider.notifier).addAgent(newAgentId, client);

    // Listen for MetaResponse to capture the actual session ID from Claude
    // When forking, Claude assigns a new session ID which we need to persist
    client.initDataStream.first.then((metaResponse) {
      if (metaResponse.sessionId != null) {
        updateAgentSessionId(newAgentId, metaResponse.sessionId!);
      }
    });

    // Update network with new agent metadata
    final updatedNetwork = network.copyWith(
      agents: [...network.agents, metadata],
      lastActiveAt: DateTime.now(),
    );
    await _ref
        .read(agentNetworkPersistenceManagerProvider)
        .saveNetwork(updatedNetwork);

    state = AgentNetworkState(currentNetwork: updatedNetwork);

    return newAgentId;
  }
}
