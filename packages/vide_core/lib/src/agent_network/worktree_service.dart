import 'dart:io';

import '../models/agent_network.dart';
import '../claude/agent_config_resolver.dart';
import 'agent_network_persistence_manager.dart';
import 'agent_status_sync_service.dart';
import '../claude/claude_client_factory.dart';
import '../claude/claude_manager.dart';

/// Manages worktree path resolution and switching for agent networks.
///
/// Handles:
/// - Resolving the effective working directory (worktree or fallback)
/// - Clearing stale worktree paths
/// - Switching worktree paths (restarts all agents with new directory)
class WorktreeService {
  WorktreeService({
    required this.baseWorkingDirectory,
    required ClaudeManagerStateNotifier claudeManager,
    required AgentNetworkPersistenceManager persistenceManager,
    required AgentNetwork? Function() getCurrentNetwork,
    required void Function(AgentNetwork) updateState,
    required ClaudeClientFactory clientFactory,
    required AgentStatusSyncService statusSyncService,
    required AgentConfigResolver configResolver,
  }) : _claudeManager = claudeManager,
       _persistenceManager = persistenceManager,
       _getCurrentNetwork = getCurrentNetwork,
       _updateState = updateState,
       _clientFactory = clientFactory,
       _statusSyncService = statusSyncService,
       _configResolver = configResolver;

  final String baseWorkingDirectory;
  final ClaudeManagerStateNotifier _claudeManager;
  final AgentNetworkPersistenceManager _persistenceManager;
  final AgentNetwork? Function() _getCurrentNetwork;
  final void Function(AgentNetwork) _updateState;
  final ClaudeClientFactory _clientFactory;
  final AgentStatusSyncService _statusSyncService;
  final AgentConfigResolver _configResolver;

  /// Get the effective working directory (worktree if set and exists, else original).
  ///
  /// If a worktreePath is set but the directory no longer exists (e.g., worktree was deleted),
  /// automatically clears it and falls back to the original working directory.
  String get effectiveWorkingDirectory {
    final worktreePath = _getCurrentNetwork()?.worktreePath;
    if (worktreePath != null && Directory(worktreePath).existsSync()) {
      return worktreePath;
    }

    // Worktree path is set but no longer exists - clear it and fall back to original
    if (worktreePath != null) {
      // Schedule async cleanup without blocking
      Future.microtask(() => _clearStaleWorktreePath(worktreePath));
    }

    return baseWorkingDirectory;
  }

  /// Clear a stale worktree path from the current network.
  Future<void> _clearStaleWorktreePath(String stalePath) async {
    final network = _getCurrentNetwork();
    if (network != null && network.worktreePath == stalePath) {
      final updated = network.copyWith(
        worktreePath: null,
        clearWorktreePath: true,
      );
      _updateState(updated);
      await _persistenceManager.saveNetwork(updated);
    }
  }

  /// Set worktree path for the current session.
  ///
  /// This will restart all agents so they use the new working directory.
  /// Agent conversation history is cleared since Claude CLI cannot change
  /// its working directory mid-session.
  Future<void> setWorktreePath(String? worktreePath) async {
    final network = _getCurrentNetwork();
    if (network == null) return;

    // 1. Abort and remove all existing Claude clients
    for (final agentId in network.agentIds) {
      final client = _claudeManager.clients[agentId];
      if (client != null) {
        await client.abort();
      }
      // Clean up status sync subscription
      _statusSyncService.cleanupStatusSync(agentId);
      _claudeManager.removeAgent(agentId);
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
    _updateState(updated);

    // 4. Recreate Claude clients for all agents with new working directory
    // Per-agent workingDirectory overrides take precedence over session worktree
    for (final agentMetadata in updated.agents) {
      try {
        final config = await _configResolver.getConfigurationForType(
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
        _claudeManager.addAgent(agentMetadata.id, client);
        // Set up status sync for the recreated client
        _statusSyncService.setupStatusSync(agentMetadata.id, client);
      } catch (e) {
        print(
          '[WorktreeService] Error recreating client for ${agentMetadata.type}: $e',
        );
        rethrow;
      }
    }

    // 5. Persist the updated network
    await _persistenceManager.saveNetwork(updated);
  }
}
