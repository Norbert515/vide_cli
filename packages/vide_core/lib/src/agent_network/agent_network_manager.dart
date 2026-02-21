import 'package:agent_sdk/agent_sdk.dart';
import 'package:claude_sdk/claude_sdk.dart' show McpServerBase;
import 'package:riverpod/riverpod.dart';
import 'package:uuid/uuid.dart';

import '../claude/agent_configuration.dart';
import '../mcp/mcp_provider.dart';
import '../mcp/mcp_server_type.dart';
import '../models/agent_id.dart';
import '../models/agent_metadata.dart';
import '../models/agent_network.dart';
import '../models/agent_status.dart';
import '../models/permission_mode.dart';
import 'agent_status_manager.dart';
import '../configuration/vide_core_config.dart';
import '../claude/agent_config_resolver.dart';
import '../logging/vide_logger.dart';
import 'agent_lifecycle_service.dart';
import 'agent_network_persistence_manager.dart';
import 'agent_status_sync_service.dart';
import '../analytics/bashboard_service.dart';
import '../claude/claude_client_factory.dart';
import '../claude/claude_manager.dart';
import '../permissions/permission_provider.dart';
import '../team_framework/team_framework_loader.dart';
import '../team_framework/trigger_service.dart';
import '../configuration/vide_config_manager.dart';
import 'worktree_service.dart';

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

final StateNotifierProvider<AgentNetworkManager, AgentNetworkState>
    agentNetworkManagerProvider =
    StateNotifierProvider<AgentNetworkManager, AgentNetworkState>((ref) {
      final config = ref.watch(videCoreConfigProvider);
      return AgentNetworkManager(
        workingDirectory: config.workingDirectory,
        claudeManager: ref.read(agentClientManagerProvider.notifier),
        persistenceManager: ref.read(agentNetworkPersistenceManagerProvider),
        getTriggerService: () => ref.read(triggerServiceProvider),
        createMcpServer: (agentId, type, projectPath) => ref.read(
          genericMcpServerProvider(AgentIdAndMcpServerType(
            agentId: agentId,
            mcpServerType: type,
            projectPath: projectPath,
          )),
        ),
        getStatusNotifier: (id) => ref.read(agentStatusProvider(id).notifier),
        getStatus: (id) => ref.read(agentStatusProvider(id)),
        permissionHandler: config.permissionHandler,
        configManager: config.configManager,
        getDangerouslySkipPermissions: () {
          final c = ref.read(videCoreConfigProvider);
          return c.dangerouslySkipPermissions ||
              c.configManager.readGlobalSettings().dangerouslySkipPermissions;
        },
      );
    });

class AgentNetworkManager extends StateNotifier<AgentNetworkState> {
  AgentNetworkManager({
    required this.workingDirectory,
    required AgentClientManagerStateNotifier claudeManager,
    required AgentNetworkPersistenceManager persistenceManager,
    required TriggerService Function() getTriggerService,
    required McpServerBase Function(AgentId, McpServerType, String) createMcpServer,
    required AgentStatusNotifier Function(AgentId) getStatusNotifier,
    required AgentStatus Function(AgentId) getStatus,
    required PermissionHandler permissionHandler,
    required VideConfigManager configManager,
    required bool Function() getDangerouslySkipPermissions,
  }) : _claudeManager = claudeManager,
       _persistenceManager = persistenceManager,
       _getTriggerService = getTriggerService,
       _getStatusNotifier = getStatusNotifier,
       super(AgentNetworkState()) {
    _clientFactory = ClaudeAgentClientFactory(
      getWorkingDirectory: () => effectiveWorkingDirectory,
      configManager: configManager,
      getDangerouslySkipPermissions: getDangerouslySkipPermissions,
      createMcpServer: createMcpServer,
      permissionHandler: permissionHandler,
    );
    _teamFrameworkLoader = TeamFrameworkLoader(
      workingDirectory: workingDirectory,
    );

    _statusSyncService = AgentStatusSyncService(
      getStatusNotifier: getStatusNotifier,
      getStatus: getStatus,
      getTriggerService: getTriggerService,
      getCurrentNetwork: () => state.currentNetwork,
    );
    _configResolver = AgentConfigResolver(_teamFrameworkLoader);
    _worktreeService = WorktreeService(
      baseWorkingDirectory: workingDirectory,
      claudeManager: claudeManager,
      persistenceManager: persistenceManager,
      getCurrentNetwork: () => state.currentNetwork,
      updateState: (network) =>
          state = AgentNetworkState(currentNetwork: network),
      clientFactory: _clientFactory,
      statusSyncService: _statusSyncService,
      configResolver: _configResolver,
    );
    _lifecycleService = AgentLifecycleService(
      claudeManager: claudeManager,
      persistenceManager: persistenceManager,
      getCurrentNetwork: () => state.currentNetwork,
      updateState: (network) =>
          state = AgentNetworkState(currentNetwork: network),
      clientFactory: _clientFactory,
      statusSyncService: _statusSyncService,
      configResolver: _configResolver,
      teamFrameworkLoader: _teamFrameworkLoader,
      sendMessage: sendMessage,
      updateAgentSessionId: updateAgentSessionId,
    );
  }

  final String workingDirectory;
  final AgentClientManagerStateNotifier _claudeManager;
  final AgentNetworkPersistenceManager _persistenceManager;
  final TriggerService Function() _getTriggerService;
  final AgentStatusNotifier Function(AgentId) _getStatusNotifier;
  late final AgentClientFactory _clientFactory;
  late final TeamFrameworkLoader _teamFrameworkLoader;
  late final AgentStatusSyncService _statusSyncService;
  late final AgentConfigResolver _configResolver;
  late final WorktreeService _worktreeService;
  late final AgentLifecycleService _lifecycleService;

  /// Public read-only access to the current network state.
  ///
  /// Use this instead of the protected [state] getter when accessing
  /// from outside the StateNotifier subclass.
  AgentNetworkState get currentState => state;

  /// Get the effective working directory (worktree if set and exists, else original).
  String get effectiveWorkingDirectory =>
      _worktreeService.effectiveWorkingDirectory;

  /// Counter for generating "Task X" names
  static int _taskCounter = 0;

  /// Start a new agent network with the given initial message
  ///
  /// [workingDirectory] - Optional working directory for the network.
  /// If provided, it's atomically set as worktreePath in the network.
  /// If null, effectiveWorkingDirectory falls back to the provider value.
  ///
  /// [permissionMode] - Optional permission mode override (e.g., 'accept-edits', 'plan', 'ask', 'deny').
  /// If provided, overrides the default permission mode for the main agent.
  ///
  /// [team] - The team framework team to use for this network.
  /// Determines which agent personalities are used for each role.
  /// Defaults to 'enterprise'.
  Future<AgentNetwork> startNew(
    AgentMessage? initialMessage, {
    String? workingDirectory,
    String? permissionMode,
    String team = 'enterprise',
  }) async {
    final networkId = const Uuid().v4();
    VideLogger.instance.startSession(networkId);
    VideLogger.instance.info('AgentNetworkManager', 'Starting new network', sessionId: networkId);

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

    // Apply permission mode override if provided.
    // Validates against PermissionMode enum to catch typos at startup.
    if (permissionMode != null) {
      PermissionMode.parse(permissionMode); // throws ArgumentError if invalid
      leadConfig = leadConfig.copyWith(permissionMode: permissionMode);
    }

    // Create client synchronously - initialization happens in background
    // The client queues messages until ready, enabling instant navigation
    final mainAgentClient = _clientFactory.createSync(
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
      worktreePath:
          workingDirectory, // Atomically set working directory from parameter
      team: team,
    );

    // Set state IMMEDIATELY so UI can navigate right away
    state = AgentNetworkState(currentNetwork: network);

    _claudeManager.addAgent(mainAgentId, mainAgentClient);

    // Set up status sync to auto-update agent status when turn completes
    _statusSyncService.setupStatusSync(mainAgentId, mainAgentClient);

    // Track analytics
    BashboardService.conversationStarted();

    // Do persistence in background
    () async {
      try {
        await _persistenceManager.saveNetwork(network);
      } catch (e) {
        VideLogger.instance.error('AgentNetworkManager', 'Error saving network: $e', sessionId: networkId);
      }
    }();

    // Send the initial message - it will be queued until client is ready
    if (initialMessage != null) {
      mainAgentClient.sendMessage(initialMessage);
      // Set status to working immediately so the UI shows activity
      // during CLI startup (before AgentProcessingStatus.processing arrives)
      _getStatusNotifier(mainAgentId).setStatus(AgentStatus.working);
    }

    // Fire onSessionStart trigger in background (don't block startup)
    () async {
      try {
        final triggerService = _getTriggerService();
        final context = TriggerContext(
          triggerPoint: TriggerPoint.onSessionStart,
          network: network,
          teamName: team,
        );
        await triggerService.fire(context);
      } catch (e) {
        VideLogger.instance.error('AgentNetworkManager', 'Error firing onSessionStart trigger: $e', sessionId: networkId);
      }
    }();

    return network;
  }

  /// Resume an existing agent network
  Future<void> resume(AgentNetwork network) async {
    VideLogger.instance.startSession(network.id);
    VideLogger.instance.info('AgentNetworkManager', 'Resuming network', sessionId: network.id);

    // Check if the saved team exists, fall back to 'enterprise' if not
    var effectiveTeam = network.team;
    final team = await _teamFrameworkLoader.getTeam(effectiveTeam);
    if (team == null) {
      VideLogger.instance.warn(
        'AgentNetworkManager',
        'Team "$effectiveTeam" not found, falling back to "enterprise"',
        sessionId: network.id,
      );
      effectiveTeam = 'enterprise';
    }

    // Update last active timestamp and potentially the team
    final updatedNetwork = network.copyWith(
      lastActiveAt: DateTime.now(),
      team: effectiveTeam,
    );

    // Set state IMMEDIATELY before any async work to prevent flash of empty state
    state = AgentNetworkState(currentNetwork: updatedNetwork);

    // Persist in background - UI already has the data
    await _persistenceManager.saveNetwork(updatedNetwork);

    // Recreate agent clients for each agent in the network
    for (final agentMetadata in updatedNetwork.agents) {
      try {
        final config = await _configResolver.getConfigurationForType(
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
        _claudeManager.addAgent(agentMetadata.id, client);
        // Set up status sync to auto-update agent status when turn completes
        _statusSyncService.setupStatusSync(agentMetadata.id, client);
      } catch (e) {
        VideLogger.instance.error(
          'AgentNetworkManager',
          'Error loading config for agent ${agentMetadata.type}: $e',
          sessionId: updatedNetwork.id,
        );
        rethrow;
      }
    }

    // Agent status is purely runtime state. On resume, all agents start as idle
    // (the AgentStatusNotifier default) since no turns are running yet.
    // The status sync service will set them to working when a turn begins.
  }

  /// Add a new agent to the current network
  Future<AgentId> addAgent({
    required AgentId agentId,
    required AgentConfiguration config,
    required AgentMetadata metadata,
  }) {
    return _lifecycleService.addAgent(
      agentId: agentId,
      config: config,
      metadata: metadata,
    );
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
    await _persistenceManager.saveNetwork(updatedNetwork);

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
    await _persistenceManager.saveNetwork(updatedNetwork);

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
    await _persistenceManager.saveNetwork(updatedNetwork);

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
    await _persistenceManager.saveNetwork(updatedNetwork);

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
  Future<void> setWorktreePath(String? worktreePath) {
    return _worktreeService.setWorktreePath(worktreePath);
  }

  void sendMessage(AgentId agentId, AgentMessage message) {
    final client = _claudeManager.clients[agentId];
    if (client == null) {
      VideLogger.instance.error(
        'AgentNetworkManager',
        'No AgentClient found for agent: $agentId',
        sessionId: state.currentNetwork?.id,
      );
      return;
    }
    client.sendMessage(message);
  }

  /// Spawn a new agent into the current network by agent type.
  ///
  /// [agentType] - The agent personality name from the team's agents list (e.g., 'solid-implementer', 'deep-researcher')
  /// [name] - A short, human-readable name for the agent (required)
  /// [initialPrompt] - The initial message/task to send to the new agent
  /// [spawnedBy] - The ID of the agent that is spawning this one (for context)
  /// [workingDirectory] - Optional working directory for this agent.
  /// If null, uses the session's effective working directory.
  ///
  /// Returns the ID of the newly spawned agent.
  ///
  /// Throws an exception if the agent type doesn't exist in the current team's agents list.
  Future<AgentId> spawnAgent({
    required String agentType,
    required String name,
    required String initialPrompt,
    required AgentId spawnedBy,
    String? workingDirectory,
  }) {
    return _lifecycleService.spawnAgent(
      agentType: agentType,
      name: name,
      initialPrompt: initialPrompt,
      spawnedBy: spawnedBy,
      workingDirectory: workingDirectory,
    );
  }

  /// Terminate an agent and remove it from the network.
  ///
  /// This will:
  /// 1. Abort the agent's client
  /// 2. Remove the agent from the client manager
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
  }) {
    return _lifecycleService.terminateAgent(
      targetAgentId: targetAgentId,
      terminatedBy: terminatedBy,
      reason: reason,
    );
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
    // Check if target agent exists
    final targetClient = _claudeManager.clients[targetAgentId];
    if (targetClient == null) {
      throw Exception('Agent not found: $targetAgentId');
    }

    // Wrap in <system-reminder> to distinguish from regular user messages
    // and reduce hallucination risk (Claude treats system-reminder as
    // authoritative system-injected content)
    final contextualMessage =
        '''<system-reminder>
AGENT MESSAGE DELIVERY — The following message was delivered by the agent system from agent $sentBy. This is real, system-delivered content.
</system-reminder>

$message''';

    // Send the message - fire and forget
    targetClient.sendMessage(AgentMessage.text(contextualMessage));

    VideLogger.instance.debug(
      'AgentNetworkManager',
      'Agent $sentBy sent message to agent $targetAgentId',
      sessionId: state.currentNetwork?.id,
    );
  }

  /// Set an agent to idle, guarding against active children.
  ///
  /// If the agent still has running sub-agents, sets [AgentStatus.waitingForAgent]
  /// instead of idle. If truly idle, cascades up the parent chain and checks
  /// the all-agents-idle trigger.
  ///
  /// Returns the effective status that was set.
  AgentStatus setAgentIdleStatus(AgentId agentId) {
    final effective = _statusSyncService.effectiveIdleStatus(agentId);
    _getStatusNotifier(agentId).setStatus(effective);
    if (effective == AgentStatus.idle) {
      _statusSyncService.cascadeIdleToParent(agentId);
      _statusSyncService.checkAllAgentsIdle();
    }
    return effective;
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
  Future<AgentId> forkAgent({required AgentId sourceAgentId, String? name}) {
    return _lifecycleService.forkAgent(
      sourceAgentId: sourceAgentId,
      name: name,
    );
  }

  /// Fire the onSessionEnd trigger for the current network.
  ///
  /// Call this when the session is being closed or disposed.
  /// This will spawn any configured agents (e.g., session-synthesizer).
  ///
  /// Returns the spawned agent ID if a trigger was configured and fired,
  /// or null if no trigger was configured or firing failed.
  Future<AgentId?> fireSessionEndTrigger() async {
    final network = state.currentNetwork;
    if (network == null) {
      VideLogger.instance.warn('AgentNetworkManager', 'No active network for onSessionEnd trigger');
      return null;
    }

    try {
      final triggerService = _getTriggerService();
      final context = TriggerContext(
        triggerPoint: TriggerPoint.onSessionEnd,
        network: network,
        teamName: network.team,
      );
      return await triggerService.fire(context);
    } catch (e) {
      VideLogger.instance.error('AgentNetworkManager', 'Error firing onSessionEnd trigger: $e', sessionId: network.id);
      return null;
    }
  }

  /// Fire the onAllAgentsIdle trigger for the current network.
  ///
  /// Call this when all agents in the network have become idle.
  /// This can spawn agents for coordination/synthesis checkpoints.
  ///
  /// Returns the spawned agent ID if a trigger was configured and fired,
  /// or null if no trigger was configured or firing failed.
  Future<AgentId?> fireAllAgentsIdleTrigger() async {
    final network = state.currentNetwork;
    if (network == null) {
      VideLogger.instance.warn('AgentNetworkManager', 'No active network for onAllAgentsIdle trigger');
      return null;
    }

    try {
      final triggerService = _getTriggerService();
      final context = TriggerContext(
        triggerPoint: TriggerPoint.onAllAgentsIdle,
        network: network,
        teamName: network.team,
      );
      return await triggerService.fire(context);
    } catch (e) {
      VideLogger.instance.error('AgentNetworkManager', 'Error firing onAllAgentsIdle trigger: $e', sessionId: network.id);
      return null;
    }
  }
}
