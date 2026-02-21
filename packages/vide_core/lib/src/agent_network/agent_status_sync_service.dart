import 'dart:async';

import 'package:agent_sdk/agent_sdk.dart';

import '../logging/vide_logger.dart';
import '../models/agent_id.dart';
import '../models/agent_metadata.dart';
import '../models/agent_network.dart';
import '../models/agent_status.dart';
import 'agent_status_manager.dart';
import '../team_framework/trigger_service.dart';

/// Manages synchronization between agent client status streams and agent status.
///
/// Listens to processing status changes and automatically updates agent status
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
  final Map<AgentId, StreamSubscription<AgentProcessingStatus>>
  _statusSyncSubscriptions = {};

  String? get _networkId => _getCurrentNetwork()?.id;

  /// Set up status sync for an agent's client.
  ///
  /// Listens to the processing status stream and automatically updates
  /// the agent status to idle when the turn completes.
  void setupStatusSync(AgentId agentId, AgentClient client) {
    // Cancel any existing subscription
    _statusSyncSubscriptions[agentId]?.cancel();

    _statusSyncSubscriptions[agentId] = client.statusStream.listen((
      processingStatus,
    ) {
      VideLogger.instance.debug(
        'AgentStatusSyncService',
        'Agent $agentId: received AgentProcessingStatus.${processingStatus.name}',
        sessionId: _networkId,
      );
      final agentStatusNotifier = _getStatusNotifier(agentId);
      final currentAgentStatus = _getStatus(agentId);

      switch (processingStatus) {
        case AgentProcessingStatus.processing:
        case AgentProcessingStatus.thinking:
        case AgentProcessingStatus.responding:
          // Agent is working, set agent status to working
          if (currentAgentStatus != AgentStatus.working) {
            VideLogger.instance.debug(
              'AgentStatusSyncService',
              'Agent $agentId: AgentProcessingStatus.${processingStatus.name} -> setting working (was ${currentAgentStatus.name})',
              sessionId: _networkId,
            );
            agentStatusNotifier.setStatus(AgentStatus.working);
          }
          break;
        case AgentProcessingStatus.ready:
          // Agent's turn is truly complete.
          // Only react to 'ready' (not 'completed') because 'completed' is
          // emitted for every response end, including compaction. 'ready' is
          // only emitted when turnComplete is true, so it correctly skips
          // compaction.
          if (currentAgentStatus == AgentStatus.working) {
            final effectiveStatus = effectiveIdleStatus(agentId);
            VideLogger.instance.debug(
              'AgentStatusSyncService',
              'Agent $agentId: AgentProcessingStatus.ready -> setting ${effectiveStatus.name} (was working)',
              sessionId: _networkId,
            );
            agentStatusNotifier.setStatus(effectiveStatus);
            // If truly idle, cascade up to parent
            if (effectiveStatus == AgentStatus.idle) {
              cascadeIdleToParent(agentId);
            }
            // Check if all agents are now idle
            checkAllAgentsIdle();
          } else {
            VideLogger.instance.debug(
              'AgentStatusSyncService',
              'Agent $agentId: AgentProcessingStatus.ready ignored (status is ${currentAgentStatus.name}, not working)',
              sessionId: _networkId,
            );
          }
          break;
        case AgentProcessingStatus.completed:
          // 'completed' means a response finished, but NOT necessarily
          // the turn. During compaction, 'completed' fires but the turn
          // continues. We ignore it here and wait for 'ready' instead.
          VideLogger.instance.debug(
            'AgentStatusSyncService',
            'Agent $agentId: AgentProcessingStatus.completed ignored (waiting for ready)',
            sessionId: _networkId,
          );
          break;
        case AgentProcessingStatus.error:
          // On error, set to idle so triggers can fire
          if (currentAgentStatus == AgentStatus.working) {
            final effectiveStatus = effectiveIdleStatus(agentId);
            VideLogger.instance.debug(
              'AgentStatusSyncService',
              'Agent $agentId: AgentProcessingStatus.error -> setting ${effectiveStatus.name} (was ${currentAgentStatus.name})',
              sessionId: _networkId,
            );
            agentStatusNotifier.setStatus(effectiveStatus);
            if (effectiveStatus == AgentStatus.idle) {
              cascadeIdleToParent(agentId);
            }
            checkAllAgentsIdle();
          }
          break;
        case AgentProcessingStatus.unknown:
          // 'unknown' means a status string we don't recognize — often
          // caused by unhandled system message subtypes during compaction.
          // Do NOT set idle here; the agent is likely still working.
          // Only 'ready' (true turn completion) should transition to idle.
          VideLogger.instance.warn(
            'AgentStatusSyncService',
            'Agent $agentId: AgentProcessingStatus.unknown ignored (was ${currentAgentStatus.name}) — likely unrecognized system message during compaction',
            sessionId: _networkId,
          );
          break;
      }
    }, onError: (Object error) {
      VideLogger.instance.error(
        'AgentStatusSyncService',
        'Agent $agentId: statusStream error: $error',
        sessionId: _networkId,
      );
    }, onDone: () {
      VideLogger.instance.warn(
        'AgentStatusSyncService',
        'Agent $agentId: statusStream closed (process may have exited)',
        sessionId: _networkId,
      );
    });
  }

  /// Clean up status sync subscription for an agent.
  void cleanupStatusSync(AgentId agentId) {
    _statusSyncSubscriptions[agentId]?.cancel();
    _statusSyncSubscriptions.remove(agentId);
  }

  /// Returns [AgentStatus.idle] if the agent has no active children,
  /// or [AgentStatus.waitingForAgent] if it still has running sub-agents.
  ///
  /// This prevents a parent agent from appearing "done" while its children
  /// are still working.
  AgentStatus effectiveIdleStatus(AgentId agentId) {
    if (_hasActiveChildren(agentId)) {
      VideLogger.instance.debug(
        'AgentStatusSyncService',
        'Agent $agentId has active children, using waitingForAgent instead of idle',
        sessionId: _networkId,
      );
      return AgentStatus.waitingForAgent;
    }
    return AgentStatus.idle;
  }

  /// Returns true if [agentId] has any sub-agents that are not idle.
  bool _hasActiveChildren(AgentId agentId) {
    final network = _getCurrentNetwork();
    if (network == null) return false;

    return network.agents.any(
      (a) => a.spawnedBy == agentId && _getStatus(a.id) != AgentStatus.idle,
    );
  }

  /// Called when an agent transitions to idle or is terminated.
  ///
  /// Checks if the agent's parent was held in [waitingForAgent] only because
  /// of active children. If all children are now idle (or removed),
  /// transitions the parent to idle as well (cascading up the tree).
  void cascadeIdleToParent(AgentId childAgentId) {
    final network = _getCurrentNetwork();
    if (network == null) return;

    // Find the child's parent
    final childMeta = network.agents.cast<AgentMetadata?>().firstWhere(
      (a) => a!.id == childAgentId,
      orElse: () => null,
    );
    if (childMeta == null || childMeta.spawnedBy == null) return;

    _tryTransitionParentToIdle(childMeta.spawnedBy!);
  }

  /// Called when a child agent is terminated and removed from the network.
  ///
  /// Since the child no longer exists in the network, we pass the parent ID
  /// directly instead of looking up the child's metadata.
  void onChildTerminated(AgentId parentId) {
    _tryTransitionParentToIdle(parentId);
  }

  /// Check if [parentId] can transition from waitingForAgent to idle.
  void _tryTransitionParentToIdle(AgentId parentId) {
    // Skip trigger-spawned agents
    if (parentId.startsWith('trigger:')) return;

    final parentStatus = _getStatus(parentId);
    if (parentStatus != AgentStatus.waitingForAgent) return;

    if (!_hasActiveChildren(parentId)) {
      VideLogger.instance.debug(
        'AgentStatusSyncService',
        'All children of $parentId are idle/terminated, cascading idle to parent',
        sessionId: _networkId,
      );
      _getStatusNotifier(parentId).setStatus(AgentStatus.idle);
      checkAllAgentsIdle();
      // Recurse up the tree
      cascadeIdleToParent(parentId);
    }
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
    final statusDetails = <String>[];
    for (final agent in nonTriggeredAgents) {
      final status = _getStatus(agent.id);
      statusDetails.add('${agent.id}=${status.name}');
      if (status != AgentStatus.idle) {
        allIdle = false;
      }
    }

    VideLogger.instance.debug(
      'AgentStatusSyncService',
      'checkAllAgentsIdle: allIdle=$allIdle agents=[${statusDetails.join(', ')}]',
      sessionId: network.id,
    );

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
          VideLogger.instance.error(
            'AgentStatusSyncService',
            'Error firing onAllAgentsIdle trigger: $e',
            sessionId: network.id,
          );
        }
      }();
    }
  }
}
