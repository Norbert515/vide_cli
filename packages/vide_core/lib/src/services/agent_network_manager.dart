import 'dart:async';
import 'dart:io';

import 'package:claude_sdk/claude_sdk.dart';
import 'package:uuid/uuid.dart';

import '../models/agent_id.dart';
import '../models/agent_metadata.dart';
import '../models/agent_network.dart';
import '../models/agent_status.dart';
import '../agents/agent_configuration.dart';
import 'agent_network_persistence_manager.dart';
import 'agent_status_registry.dart';
import 'claude_client_factory.dart';
import 'claude_client_registry.dart';
import 'bashboard_service.dart';
import 'team_framework_loader.dart';
import 'trigger_service.dart';

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

class AgentNetworkManager {
  AgentNetworkManager({
    required this.workingDirectory,
    required ClaudeClientFactory clientFactory,
    required ClaudeClientRegistry clientRegistry,
    required AgentStatusRegistry statusRegistry,
    required AgentNetworkPersistenceManager persistenceManager,
    required TriggerService triggerService,
    required TeamFrameworkLoader teamFrameworkLoader,
  }) : _clientFactory = clientFactory,
       _clientRegistry = clientRegistry,
       _statusRegistry = statusRegistry,
       _persistenceManager = persistenceManager,
       _triggerService = triggerService,
       _teamFrameworkLoader = teamFrameworkLoader;

  final String workingDirectory;
  final ClaudeClientFactory _clientFactory;
  final ClaudeClientRegistry _clientRegistry;
  final AgentStatusRegistry _statusRegistry;
  final AgentNetworkPersistenceManager _persistenceManager;
  final TriggerService _triggerService;
  final TeamFrameworkLoader _teamFrameworkLoader;

  /// Current state.
  AgentNetworkState _state = AgentNetworkState();

  /// Stream controller for state changes.
  final _stateController = StreamController<AgentNetworkState>.broadcast();

  /// The current state.
  AgentNetworkState get state => _state;

  /// Stream of state changes.
  Stream<AgentNetworkState> get stateStream => _stateController.stream;

  /// Update state and notify listeners.
  void _setState(AgentNetworkState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  /// Active subscriptions for agent status sync.
  /// We listen to Claude status changes and auto-set agent status.
  final Map<AgentId, StreamSubscription<ClaudeStatus>>
  _statusSyncSubscriptions = {};

  /// Set up status sync for an agent's Claude client.
  ///
  /// This listens to the Claude status stream and automatically updates
  /// the agent status to idle when the turn completes.
  void _setupStatusSync(AgentId agentId, ClaudeClient client) {
    // Cancel any existing subscription
    _statusSyncSubscriptions[agentId]?.cancel();

    _statusSyncSubscriptions[agentId] = client.statusStream.listen((
      claudeStatus,
    ) {
      final currentAgentStatus = _statusRegistry.getStatus(agentId);

      switch (claudeStatus) {
        case ClaudeStatus.processing:
        case ClaudeStatus.thinking:
        case ClaudeStatus.responding:
          // Claude is working, set agent status to working
          if (currentAgentStatus != AgentStatus.working) {
            _statusRegistry.setStatus(agentId, AgentStatus.working);
          }
          break;
        case ClaudeStatus.ready:
        case ClaudeStatus.completed:
          // Claude is done with this turn
          // Only auto-set to idle if agent was in working state
          // (don't override waitingForAgent/waitingForUser that agent set explicitly)
          if (currentAgentStatus == AgentStatus.working) {
            _statusRegistry.setStatus(agentId, AgentStatus.idle);
            // Check if all agents are now idle
            _checkAllAgentsIdle();
          }
          break;
        case ClaudeStatus.error:
        case ClaudeStatus.unknown:
          // On error, set to idle so triggers can fire
          if (currentAgentStatus == AgentStatus.working) {
            _statusRegistry.setStatus(agentId, AgentStatus.idle);
            _checkAllAgentsIdle();
          }
          break;
      }
    });
  }

  /// Check if all NON-TRIGGERED agents are idle and fire the trigger if so.
  ///
  /// Only considers agents that were NOT spawned by a trigger.
  /// This prevents infinite loops where triggered agents spawn more triggered agents.
  void _checkAllAgentsIdle() {
    final network = _state.currentNetwork;
    if (network == null) return;

    // Only check non-triggered agents
    // Triggered agents are identified by having spawnedBy starting with 'trigger:'
    final nonTriggeredAgents = network.agents
        .where(
          (a) => a.spawnedBy == null || !a.spawnedBy!.startsWith('trigger:'),
        )
        .toList();

    if (nonTriggeredAgents.isEmpty) {
      return;
    }

    // Check if all non-triggered agents are idle
    var allIdle = true;
    for (final agent in nonTriggeredAgents) {
      final status = _statusRegistry.getStatus(agent.id);
      if (status != AgentStatus.idle) {
        allIdle = false;
        break;
      }
    }

    if (allIdle) {
      // Fire trigger in background
      () async {
        try {
          final context = TriggerContext(
            triggerPoint: TriggerPoint.onAllAgentsIdle,
            network: network,
            teamName: network.team,
          );
          await _triggerService.fire(context);
        } catch (e) {
          print(
            '[AgentNetworkManager] Error firing onAllAgentsIdle trigger: $e',
          );
        }
      }();
    }
  }

  /// Clean up status sync subscription for an agent.
  void _cleanupStatusSync(AgentId agentId) {
    _statusSyncSubscriptions[agentId]?.cancel();
    _statusSyncSubscriptions.remove(agentId);
  }

  /// Get the effective working directory (worktree if set and exists, else original).
  ///
  /// If a worktreePath is set but the directory no longer exists (e.g., worktree was deleted),
  /// automatically clears it and falls back to the original working directory.
  String get effectiveWorkingDirectory {
    final worktreePath = _state.currentNetwork?.worktreePath;
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
    final network = _state.currentNetwork;
    if (network != null && network.worktreePath == stalePath) {
      final updated = network.copyWith(
        worktreePath: null,
        clearWorktreePath: true,
      );
      _setState(AgentNetworkState(currentNetwork: updated));
      await _persistenceManager.saveNetwork(updated);
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
    String team = 'vide',
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

    final mainAgentName = teamDef.mainAgent;

    // Load the main agent personality to get display name and description
    final mainAgentPersonality = await _teamFrameworkLoader.getAgent(
      mainAgentName,
    );

    var leadConfig = await _teamFrameworkLoader.buildAgentConfiguration(
      mainAgentName,
      teamName: team,
    );
    if (leadConfig == null) {
      throw Exception('Agent configuration not found for: $mainAgentName');
    }

    // Apply permission mode override if provided
    if (permissionMode != null) {
      const validModes = {
        'ask',
        'acceptEdits',
        'bypassPermissions',
        'default',
        'delegate',
        'dontAsk',
        'plan',
      };
      if (!validModes.contains(permissionMode)) {
        throw ArgumentError(
          'Invalid permission mode: $permissionMode. '
          'Valid modes are: ${validModes.join(", ")}',
        );
      }
      leadConfig = leadConfig.copyWith(permissionMode: permissionMode);
    }

    // Apply model override if provided
    if (model != null) {
      leadConfig = leadConfig.copyWith(model: model);
    }

    // Create client synchronously - initialization happens in background
    // The client queues messages until ready, enabling instant navigation
    final mainAgentClaudeClient = _clientFactory.createSync(
      agentId: mainAgentId,
      config: leadConfig,
      networkId: networkId,
      agentType: 'main',
    );

    // Use display name from personality, fallback to 'Klaus'
    final mainAgentDisplayName =
        mainAgentPersonality?.effectiveDisplayName ?? 'Klaus';

    final mainAgentMetadata = AgentMetadata(
      id: mainAgentId,
      name: mainAgentDisplayName,
      type: 'main',
      createdAt: DateTime.now(),
      shortDescription: mainAgentPersonality?.shortDescription,
      teamTag: mainAgentPersonality?.team,
    );

    final network = AgentNetwork(
      id: networkId,
      goal: taskDisplayName,
      agents: [mainAgentMetadata],
      createdAt: DateTime.now(),
      lastActiveAt: DateTime.now(),
      worktreePath: workingDirectory,
      team: team,
    );

    // Set state IMMEDIATELY so UI can navigate right away
    _setState(AgentNetworkState(currentNetwork: network));

    _clientRegistry.addAgent(mainAgentId, mainAgentClaudeClient);

    // Set up status sync to auto-update agent status when turn completes
    _setupStatusSync(mainAgentId, mainAgentClaudeClient);

    // Track analytics
    BashboardService.conversationStarted();

    // Do persistence in background
    () async {
      await _persistenceManager.saveNetwork(network);
    }();

    // Send the initial message - it will be queued until client is ready
    mainAgentClaudeClient.sendMessage(initialMessage);

    // Fire onSessionStart trigger in background (don't block startup)
    () async {
      try {
        final context = TriggerContext(
          triggerPoint: TriggerPoint.onSessionStart,
          network: network,
          teamName: team,
        );
        await _triggerService.fire(context);
      } catch (e) {
        print('[AgentNetworkManager] Error firing onSessionStart trigger: $e');
      }
    }();

    return network;
  }

  /// Resume an existing agent network
  Future<void> resume(AgentNetwork network) async {
    // Check if the saved team exists, fall back to 'vide' if not
    var effectiveTeam = network.team;
    final team = await _teamFrameworkLoader.getTeam(effectiveTeam);
    if (team == null) {
      print(
        '[AgentNetworkManager] Team "$effectiveTeam" not found, falling back to "vide"',
      );
      effectiveTeam = 'vide';
    }

    // Update last active timestamp and potentially the team
    final updatedNetwork = network.copyWith(
      lastActiveAt: DateTime.now(),
      team: effectiveTeam,
    );

    // Set state IMMEDIATELY before any async work to prevent flash of empty state
    _setState(AgentNetworkState(currentNetwork: updatedNetwork));

    // Persist in background - UI already has the data
    await _persistenceManager.saveNetwork(updatedNetwork);

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
          workingDirectory: agentMetadata.workingDirectory,
        );
        _clientRegistry.addAgent(agentMetadata.id, client);
        // Set up status sync to auto-update agent status when turn completes
        _setupStatusSync(agentMetadata.id, client);
      } catch (e) {
        print(
          '[AgentNetworkManager] Error loading config for agent ${agentMetadata.type}: $e',
        );
        rethrow;
      }
    }
  }

  /// Get the appropriate AgentConfiguration for a given agent type string.
  Future<AgentConfiguration> _getConfigurationForType(
    String type, {
    String? teamName,
  }) async {
    var effectiveTeamName = teamName ?? _state.currentNetwork?.team;
    if (effectiveTeamName == null) {
      throw Exception('No team specified and no current network');
    }

    var team = await _teamFrameworkLoader.getTeam(effectiveTeamName);

    if (team == null) {
      print(
        '[AgentNetworkManager] Team "$effectiveTeamName" not found, falling back to "vide"',
      );
      effectiveTeamName = 'vide';
      team = await _teamFrameworkLoader.getTeam(effectiveTeamName);
      if (team == null) {
        throw Exception('Default team "vide" not found in team framework');
      }
    }

    final agentName = switch (type) {
      'main' => team.mainAgent,
      'fork' => team.mainAgent,
      _ => type,
    };

    final config = await _teamFrameworkLoader.buildAgentConfiguration(
      agentName,
      teamName: effectiveTeamName,
    );
    if (config == null) {
      throw Exception(
        'Agent configuration not found for: $agentName (type: $type)',
      );
    }

    return config;
  }

  /// Add a new agent to the current network
  Future<AgentId> addAgent({
    required AgentId agentId,
    required AgentConfiguration config,
    required AgentMetadata metadata,
  }) async {
    final network = _state.currentNetwork;
    if (network == null) {
      throw StateError('No active network to add agent to');
    }

    final client = await _clientFactory.create(
      agentId: agentId,
      config: config,
      networkId: network.id,
      agentType: metadata.type,
      workingDirectory: metadata.workingDirectory,
    );
    _clientRegistry.addAgent(agentId, client);
    // Set up status sync to auto-update agent status when turn completes
    _setupStatusSync(agentId, client);

    // Update network with new agent metadata
    final updatedNetwork = network.copyWith(
      agents: [...network.agents, metadata],
      lastActiveAt: DateTime.now(),
    );
    await _persistenceManager.saveNetwork(updatedNetwork);

    _setState(AgentNetworkState(currentNetwork: updatedNetwork));

    return agentId;
  }

  /// Update the goal of the current network
  Future<void> updateGoal(String newGoal) async {
    final network = _state.currentNetwork;
    if (network == null) {
      throw StateError('No active network to update goal for');
    }

    final updatedNetwork = network.copyWith(
      goal: newGoal,
      lastActiveAt: DateTime.now(),
    );
    await _persistenceManager.saveNetwork(updatedNetwork);

    _setState(AgentNetworkState(currentNetwork: updatedNetwork));
  }

  /// Update the name of an agent in the current network
  Future<void> updateAgentName(AgentId agentId, String newName) async {
    final network = _state.currentNetwork;
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
    await _persistenceManager.saveNetwork(updatedNetwork);

    _setState(AgentNetworkState(currentNetwork: updatedNetwork));
  }

  /// Update the task name of an agent in the current network
  Future<void> updateAgentTaskName(AgentId agentId, String taskName) async {
    final network = _state.currentNetwork;
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
    await _persistenceManager.saveNetwork(updatedNetwork);

    _setState(AgentNetworkState(currentNetwork: updatedNetwork));
  }

  /// Update the session ID of an agent in the current network.
  Future<void> updateAgentSessionId(AgentId agentId, String sessionId) async {
    final network = _state.currentNetwork;
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
    await _persistenceManager.saveNetwork(updatedNetwork);

    _setState(AgentNetworkState(currentNetwork: updatedNetwork));
  }

  /// Update token usage stats for an agent.
  void updateAgentTokenStats(
    AgentId agentId, {
    required int totalInputTokens,
    required int totalOutputTokens,
    required int totalCacheReadInputTokens,
    required int totalCacheCreationInputTokens,
    required double totalCostUsd,
  }) {
    final network = _state.currentNetwork;
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
    _setState(AgentNetworkState(currentNetwork: updatedNetwork));
  }

  /// Set worktree path for the current session.
  Future<void> setWorktreePath(String? worktreePath) async {
    final network = _state.currentNetwork;
    if (network == null) return;

    // 1. Abort and remove all existing Claude clients
    for (final agentId in network.agentIds) {
      final client = _clientRegistry[agentId];
      if (client != null) {
        await client.abort();
      }
      _cleanupStatusSync(agentId);
      _clientRegistry.removeAgent(agentId);
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
    _setState(_state.copyWith(currentNetwork: updated));

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
          workingDirectory: agentMetadata.workingDirectory,
        );
        _clientRegistry.addAgent(agentMetadata.id, client);
        _setupStatusSync(agentMetadata.id, client);
      } catch (e) {
        print(
          '[AgentNetworkManager] Error recreating client for ${agentMetadata.type}: $e',
        );
        rethrow;
      }
    }

    // 5. Persist the updated network
    await _persistenceManager.saveNetwork(updated);
  }

  void sendMessage(AgentId agentId, Message message) {
    final client = _clientRegistry[agentId];
    if (client == null) {
      print(
        '[AgentNetworkManager] WARNING: No ClaudeClient found for agent: $agentId',
      );
      return;
    }
    client.sendMessage(message);
  }

  /// Spawn a new agent into the current network by agent type.
  Future<AgentId> spawnAgent({
    required String agentType,
    required String name,
    required String initialPrompt,
    required AgentId spawnedBy,
    String? workingDirectory,
  }) async {
    final network = _state.currentNetwork;
    if (network == null) {
      throw StateError('No active network to spawn agent into');
    }

    final teamName = network.team;
    final team = await _teamFrameworkLoader.getTeam(teamName);
    if (team == null) {
      throw Exception('Team "$teamName" not found in team framework');
    }

    if (agentType == team.mainAgent) {
      throw Exception(
        'Cannot spawn the main agent type "$agentType" - use the main agent instead',
      );
    }

    if (!team.agents.contains(agentType)) {
      throw Exception(
        'Team "$teamName" does not have agent type "$agentType". '
        'Available agent types: ${team.agents.join(", ")}',
      );
    }

    final personality = await _teamFrameworkLoader.getAgent(agentType);

    final config = await _teamFrameworkLoader.buildAgentConfiguration(
      agentType,
      teamName: teamName,
    );
    if (config == null) {
      throw Exception('Agent configuration not found for: $agentType');
    }

    final newAgentId = const Uuid().v4();

    final baseName = personality?.effectiveDisplayName ?? name;
    final uniqueName = _generateUniqueName(baseName, network.agents);

    final metadata = AgentMetadata(
      id: newAgentId,
      name: uniqueName,
      type: agentType,
      spawnedBy: spawnedBy,
      createdAt: DateTime.now(),
      shortDescription: personality?.shortDescription,
      teamTag: personality?.team,
      workingDirectory: workingDirectory,
    );

    await addAgent(agentId: newAgentId, config: config, metadata: metadata);

    BashboardService.agentSpawned(agentType);

    final contextualPrompt = '''[SPAWNED BY AGENT: $spawnedBy]

$initialPrompt''';

    sendMessage(newAgentId, Message.text(contextualPrompt));

    print(
      '[AgentNetworkManager] Agent $spawnedBy spawned new "$agentType" agent "$uniqueName": $newAgentId',
    );

    return newAgentId;
  }

  String _generateUniqueName(
    String baseName,
    List<AgentMetadata> existingAgents,
  ) {
    final existingNames = existingAgents.map((a) => a.name).toSet();

    if (!existingNames.contains(baseName)) {
      return baseName;
    }

    var counter = 2;
    while (existingNames.contains('$baseName $counter')) {
      counter++;
    }
    return '$baseName $counter';
  }

  /// Terminate an agent and remove it from the network.
  Future<void> terminateAgent({
    required AgentId targetAgentId,
    required AgentId terminatedBy,
    String? reason,
  }) async {
    final network = _state.currentNetwork;
    if (network == null) {
      throw StateError('No active network');
    }

    final targetAgent = network.agents
        .where((a) => a.id == targetAgentId)
        .firstOrNull;
    if (targetAgent == null) {
      throw Exception('Agent not found in network: $targetAgentId');
    }

    if (network.agents.length <= 1) {
      throw Exception('Cannot terminate the last agent');
    }

    final client = _clientRegistry[targetAgentId];
    if (client != null) {
      await client.abort();
    }

    _cleanupStatusSync(targetAgentId);
    _clientRegistry.removeAgent(targetAgentId);

    final updatedAgents = network.agents
        .where((a) => a.id != targetAgentId)
        .toList();
    final updatedNetwork = network.copyWith(
      agents: updatedAgents,
      lastActiveAt: DateTime.now(),
    );

    await _persistenceManager.saveNetwork(updatedNetwork);

    _setState(AgentNetworkState(currentNetwork: updatedNetwork));

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
  void sendMessageToAgent({
    required AgentId targetAgentId,
    required String message,
    required AgentId sentBy,
  }) {
    final targetClient = _clientRegistry[targetAgentId];
    if (targetClient == null) {
      throw Exception('Agent not found: $targetAgentId');
    }

    final contextualMessage = '''[MESSAGE FROM AGENT: $sentBy]

$message''';

    targetClient.sendMessage(Message.text(contextualMessage));

    print(
      '[AgentNetworkManager] Agent $sentBy sent message to agent $targetAgentId',
    );
  }

  /// Fork an existing agent, creating a new agent with the same conversation context.
  Future<AgentId> forkAgent({
    required AgentId sourceAgentId,
    String? name,
  }) async {
    final network = _state.currentNetwork;
    if (network == null) {
      throw StateError('No active network to fork agent in');
    }

    final sourceAgent = network.agents
        .where((a) => a.id == sourceAgentId)
        .firstOrNull;
    if (sourceAgent == null) {
      throw Exception('Agent not found: $sourceAgentId');
    }

    final sourceClient = _clientRegistry[sourceAgentId];
    if (sourceClient == null) {
      throw Exception('No Claude client found for agent: $sourceAgentId');
    }

    final newAgentId = const Uuid().v4();
    final forkName = name ?? '[Fork] ${sourceAgent.name}';

    final config = await _getConfigurationForType(
      sourceAgent.type,
      teamName: network.team,
    );

    final metadata = AgentMetadata(
      id: newAgentId,
      name: forkName,
      type: 'fork',
      spawnedBy: sourceAgentId,
      createdAt: DateTime.now(),
    );

    final client = await _clientFactory.createForked(
      agentId: newAgentId,
      config: config,
      networkId: network.id,
      agentType: metadata.type,
      resumeSessionId: sourceClient.sessionId,
      sourceConversation: sourceClient.currentConversation,
    );

    _clientRegistry.addAgent(newAgentId, client);
    _setupStatusSync(newAgentId, client);

    client.initDataStream.first.then((metaResponse) {
      if (metaResponse.sessionId != null) {
        updateAgentSessionId(newAgentId, metaResponse.sessionId!);
      }
    });

    final updatedNetwork = network.copyWith(
      agents: [...network.agents, metadata],
      lastActiveAt: DateTime.now(),
    );
    await _persistenceManager.saveNetwork(updatedNetwork);

    _setState(AgentNetworkState(currentNetwork: updatedNetwork));

    return newAgentId;
  }

  /// Fire the onSessionEnd trigger for the current network.
  Future<AgentId?> fireSessionEndTrigger() async {
    final network = _state.currentNetwork;
    if (network == null) {
      print('[AgentNetworkManager] No active network for onSessionEnd trigger');
      return null;
    }

    try {
      final context = TriggerContext(
        triggerPoint: TriggerPoint.onSessionEnd,
        network: network,
        teamName: network.team,
      );
      return await _triggerService.fire(context);
    } catch (e) {
      print('[AgentNetworkManager] Error firing onSessionEnd trigger: $e');
      return null;
    }
  }

  /// Fire the onAllAgentsIdle trigger for the current network.
  Future<AgentId?> fireAllAgentsIdleTrigger() async {
    final network = _state.currentNetwork;
    if (network == null) {
      print(
        '[AgentNetworkManager] No active network for onAllAgentsIdle trigger',
      );
      return null;
    }

    try {
      final context = TriggerContext(
        triggerPoint: TriggerPoint.onAllAgentsIdle,
        network: network,
        teamName: network.team,
      );
      return await _triggerService.fire(context);
    } catch (e) {
      print('[AgentNetworkManager] Error firing onAllAgentsIdle trigger: $e');
      return null;
    }
  }

  /// Dispose the manager and clean up resources.
  void dispose() {
    for (final sub in _statusSyncSubscriptions.values) {
      sub.cancel();
    }
    _statusSyncSubscriptions.clear();
    _stateController.close();
  }
}
