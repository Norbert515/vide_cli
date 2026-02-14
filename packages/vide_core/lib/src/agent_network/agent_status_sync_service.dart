import 'dart:async';

import 'package:claude_sdk/claude_sdk.dart';

import '../models/agent_id.dart';
import '../models/agent_network.dart';
import '../models/agent_status.dart';
import 'agent_status_manager.dart';
import '../team_framework/trigger_service.dart';

/// Manages synchronization between Claude client status streams and agent status.
///
/// Listens to Claude status changes and automatically updates agent status
/// (e.g., setting to idle when a turn completes). Also fires the
/// onAllAgentsIdle trigger when all non-triggered agents become idle.
class AgentStatusSyncService {
  AgentStatusSyncService({
    required AgentStatusNotifier Function(AgentId) getStatusNotifier,
    required AgentStatus Function(AgentId) getStatus,
    required TriggerService Function() getTriggerService,
    required AgentNetwork? Function() getCurrentNetwork,
  }) : _getStatusNotifier = getStatusNotifier,
       _getStatus = getStatus,
       _getTriggerService = getTriggerService,
       _getCurrentNetwork = getCurrentNetwork;

  final AgentStatusNotifier Function(AgentId) _getStatusNotifier;
  final AgentStatus Function(AgentId) _getStatus;
  final TriggerService Function() _getTriggerService;
  final AgentNetwork? Function() _getCurrentNetwork;
  final Map<AgentId, StreamSubscription<ClaudeStatus>>
  _statusSyncSubscriptions = {};

  /// Set up status sync for an agent's Claude client.
  ///
  /// Listens to the Claude status stream and automatically updates
  /// the agent status to idle when the turn completes.
  void setupStatusSync(AgentId agentId, ClaudeClient client) {
    // Cancel any existing subscription
    _statusSyncSubscriptions[agentId]?.cancel();

    _statusSyncSubscriptions[agentId] = client.statusStream.listen((
      claudeStatus,
    ) {
      final agentStatusNotifier = _getStatusNotifier(agentId);
      final currentAgentStatus = _getStatus(agentId);

      switch (claudeStatus) {
        case ClaudeStatus.processing:
        case ClaudeStatus.thinking:
        case ClaudeStatus.responding:
          // Claude is working, set agent status to working
          if (currentAgentStatus != AgentStatus.working) {
            agentStatusNotifier.setStatus(AgentStatus.working);
          }
          break;
        case ClaudeStatus.ready:
          // Claude's turn is truly complete.
          // Only react to 'ready' (not 'completed') because 'completed' is
          // emitted by the CLI's StatusResponse for every response end,
          // including compaction. 'ready' is only emitted by ClaudeClient
          // when turnComplete is true, so it correctly skips compaction.
          if (currentAgentStatus == AgentStatus.working) {
            agentStatusNotifier.setStatus(AgentStatus.idle);
            // Check if all agents are now idle
            checkAllAgentsIdle();
          }
          break;
        case ClaudeStatus.completed:
          // 'completed' means a response finished, but NOT necessarily
          // the turn. During compaction, 'completed' fires but the turn
          // continues. We ignore it here and wait for 'ready' instead.
          break;
        case ClaudeStatus.error:
        case ClaudeStatus.unknown:
          // On error, set to idle so triggers can fire
          if (currentAgentStatus == AgentStatus.working) {
            agentStatusNotifier.setStatus(AgentStatus.idle);
            checkAllAgentsIdle();
          }
          break;
      }
    });
  }

  /// Clean up status sync subscription for an agent.
  void cleanupStatusSync(AgentId agentId) {
    _statusSyncSubscriptions[agentId]?.cancel();
    _statusSyncSubscriptions.remove(agentId);
  }

  /// Check if all NON-TRIGGERED agents are idle and fire the trigger if so.
  ///
  /// Only considers agents that were NOT spawned by a trigger.
  /// This prevents infinite loops where triggered agents spawn more triggered agents.
  void checkAllAgentsIdle() {
    final network = _getCurrentNetwork();
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
      final status = _getStatus(agent.id);
      if (status != AgentStatus.idle) {
        allIdle = false;
        break;
      }
    }

    if (allIdle) {
      // Fire trigger in background
      () async {
        try {
          final triggerService = _getTriggerService();
          final context = TriggerContext(
            triggerPoint: TriggerPoint.onAllAgentsIdle,
            network: network,
            teamName: network.team,
          );
          await triggerService.fire(context);
        } catch (e) {
          print(
            '[AgentStatusSyncService] Error firing onAllAgentsIdle trigger: $e',
          );
        }
      }();
    }
  }
}
