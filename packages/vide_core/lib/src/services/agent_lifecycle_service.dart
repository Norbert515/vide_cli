import 'package:claude_sdk/claude_sdk.dart';
import 'package:riverpod/riverpod.dart';
import 'package:uuid/uuid.dart';

import '../agents/agent_configuration.dart';
import '../models/agent_id.dart';
import '../models/agent_metadata.dart';
import '../models/agent_network.dart';
import 'agent_config_resolver.dart';
import 'agent_network_persistence_manager.dart';
import 'agent_status_sync_service.dart';
import 'bashboard_service.dart';
import 'claude_client_factory.dart';
import 'claude_manager.dart';
import 'team_framework_loader.dart';

/// Manages the lifecycle of agents within a network.
///
/// Handles spawning, adding, terminating, and forking agents.
/// Coordinates with AgentStatusSyncService for status tracking
/// and AgentConfigResolver for configuration loading.
class AgentLifecycleService {
  AgentLifecycleService({
    required Ref ref,
    required AgentNetwork? Function() getCurrentNetwork,
    required void Function(AgentNetwork) updateState,
    required ClaudeClientFactory clientFactory,
    required AgentStatusSyncService statusSyncService,
    required AgentConfigResolver configResolver,
    required TeamFrameworkLoader teamFrameworkLoader,
    required void Function(AgentId, Message) sendMessage,
    required Future<void> Function(AgentId, String) updateAgentSessionId,
  }) : _ref = ref,
       _getCurrentNetwork = getCurrentNetwork,
       _updateState = updateState,
       _clientFactory = clientFactory,
       _statusSyncService = statusSyncService,
       _configResolver = configResolver,
       _teamFrameworkLoader = teamFrameworkLoader,
       _sendMessage = sendMessage,
       _updateAgentSessionId = updateAgentSessionId;

  final Ref _ref;
  final AgentNetwork? Function() _getCurrentNetwork;
  final void Function(AgentNetwork) _updateState;
  final ClaudeClientFactory _clientFactory;
  final AgentStatusSyncService _statusSyncService;
  final AgentConfigResolver _configResolver;
  final TeamFrameworkLoader _teamFrameworkLoader;
  final void Function(AgentId, Message) _sendMessage;
  final Future<void> Function(AgentId, String) _updateAgentSessionId;

  /// Add a new agent to the current network.
  Future<AgentId> addAgent({
    required AgentId agentId,
    required AgentConfiguration config,
    required AgentMetadata metadata,
  }) async {
    final network = _getCurrentNetwork();
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
    _ref.read(claudeManagerProvider.notifier).addAgent(agentId, client);
    // Set up status sync to auto-update agent status when turn completes
    _statusSyncService.setupStatusSync(agentId, client);

    // Update network with new agent metadata
    final updatedNetwork = network.copyWith(
      agents: [...network.agents, metadata],
      lastActiveAt: DateTime.now(),
    );
    await _ref
        .read(agentNetworkPersistenceManagerProvider)
        .saveNetwork(updatedNetwork);

    _updateState(updatedNetwork);

    return agentId;
  }

  /// Spawn a new agent into the current network by agent type.
  ///
  /// [agentType] - The agent personality name from the team's agents list
  /// [name] - A short, human-readable name for the agent (required)
  /// [initialPrompt] - The initial message/task to send to the new agent
  /// [spawnedBy] - The ID of the agent that is spawning this one
  /// [workingDirectory] - Optional working directory for this agent.
  ///
  /// Returns the ID of the newly spawned agent.
  Future<AgentId> spawnAgent({
    required String agentType,
    required String name,
    required String initialPrompt,
    required AgentId spawnedBy,
    String? workingDirectory,
  }) async {
    final network = _getCurrentNetwork();
    if (network == null) {
      throw StateError('No active network to spawn agent into');
    }

    // Load configuration from team framework using the network's team
    final teamName = network.team;
    final team = await _teamFrameworkLoader.getTeam(teamName);
    if (team == null) {
      throw Exception('Team "$teamName" not found in team framework');
    }

    // Prevent spawning the main agent type
    if (agentType == team.mainAgent) {
      throw Exception(
        'Cannot spawn the main agent type "$agentType" - use the main agent instead',
      );
    }

    // Validate that the agent type is in the team's agents list
    if (!team.agents.contains(agentType)) {
      throw Exception(
        'Team "$teamName" does not have agent type "$agentType". '
        'Available agent types: ${team.agents.join(", ")}',
      );
    }

    // Load the agent personality to get display name and short description
    final personality = await _teamFrameworkLoader.getAgent(agentType);

    final config = await _teamFrameworkLoader.buildAgentConfiguration(
      agentType,
      teamName: teamName,
    );
    if (config == null) {
      throw Exception('Agent configuration not found for: $agentType');
    }

    // Generate new agent ID
    final newAgentId = const Uuid().v4();

    // Use display name from personality, fallback to provided name
    final baseName = personality?.effectiveDisplayName ?? name;
    final uniqueName = _configResolver.generateUniqueName(
      baseName,
      network.agents,
    );

    // Create metadata for the new agent
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

    // Add agent to network with metadata
    await addAgent(agentId: newAgentId, config: config, metadata: metadata);

    // Track analytics
    BashboardService.agentSpawned(agentType);

    // Prepend context about who spawned this agent
    final contextualPrompt = '''[SPAWNED BY AGENT: $spawnedBy]

$initialPrompt''';

    // Send initial message to the new agent
    _sendMessage(newAgentId, Message.text(contextualPrompt));

    print(
      '[AgentLifecycleService] Agent $spawnedBy spawned new "$agentType" agent "$uniqueName": $newAgentId',
    );

    return newAgentId;
  }

  /// Terminate an agent and remove it from the network.
  Future<void> terminateAgent({
    required AgentId targetAgentId,
    required AgentId terminatedBy,
    String? reason,
  }) async {
    final network = _getCurrentNetwork();
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

    // Clean up status sync subscription
    _statusSyncService.cleanupStatusSync(targetAgentId);

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
    _updateState(updatedNetwork);

    final reasonStr = reason != null ? ': $reason' : '';
    final selfTerminated = targetAgentId == terminatedBy;
    if (selfTerminated) {
      print(
        '[AgentLifecycleService] Agent $targetAgentId self-terminated$reasonStr',
      );
    } else {
      print(
        '[AgentLifecycleService] Agent $terminatedBy terminated agent $targetAgentId$reasonStr',
      );
    }
  }

  /// Fork an existing agent, creating a new agent with the same conversation context.
  Future<AgentId> forkAgent({
    required AgentId sourceAgentId,
    String? name,
  }) async {
    final network = _getCurrentNetwork();
    if (network == null) {
      throw StateError('No active network to fork agent in');
    }

    // Find source agent metadata
    final sourceAgent = network.agents
        .where((a) => a.id == sourceAgentId)
        .firstOrNull;
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
    final config = await _configResolver.getConfigurationForType(
      sourceAgent.type,
      teamName: network.team,
    );

    // Create metadata for the forked agent
    final metadata = AgentMetadata(
      id: newAgentId,
      name: forkName,
      type: 'fork',
      spawnedBy: sourceAgentId,
      createdAt: DateTime.now(),
    );

    // Create the Claude client with fork configuration
    final client = await _clientFactory.createForked(
      agentId: newAgentId,
      config: config,
      networkId: network.id,
      agentType: metadata.type,
      resumeSessionId: sourceClient.sessionId,
      sourceConversation: sourceClient.currentConversation,
    );

    _ref.read(claudeManagerProvider.notifier).addAgent(newAgentId, client);
    // Set up status sync for the forked agent
    _statusSyncService.setupStatusSync(newAgentId, client);

    // Listen for MetaResponse to capture the actual session ID from Claude
    client.initDataStream.first.then((metaResponse) {
      if (metaResponse.sessionId != null) {
        _updateAgentSessionId(newAgentId, metaResponse.sessionId!);
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

    _updateState(updatedNetwork);

    return newAgentId;
  }
}
