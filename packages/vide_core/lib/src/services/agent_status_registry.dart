import 'dart:async';

import '../models/agent_id.dart';
import '../models/agent_status.dart';

/// A change event emitted when an agent's status changes.
class AgentStatusChange {
  final AgentId agentId;
  final AgentStatus previousStatus;
  final AgentStatus newStatus;

  const AgentStatusChange({
    required this.agentId,
    required this.previousStatus,
    required this.newStatus,
  });
}

/// Registry that tracks status for all agents in a session.
///
/// Replaces the Riverpod `agentStatusProvider` (StateNotifierProvider.family).
/// Each agent starts with [AgentStatus.working] by default.
class AgentStatusRegistry {
  final Map<String, AgentStatus> _statuses = {};
  final _controller = StreamController<AgentStatusChange>.broadcast(sync: true);

  /// Stream of status change events.
  Stream<AgentStatusChange> get changes => _controller.stream;

  /// Get the current status for an agent.
  /// Returns [AgentStatus.working] if the agent has no explicitly set status.
  AgentStatus getStatus(AgentId agentId) {
    return _statuses[agentId] ?? AgentStatus.working;
  }

  /// Set the status for an agent.
  void setStatus(AgentId agentId, AgentStatus status) {
    final previous = _statuses[agentId] ?? AgentStatus.working;
    _statuses[agentId] = status;
    if (previous != status) {
      _controller.add(
        AgentStatusChange(
          agentId: agentId,
          previousStatus: previous,
          newStatus: status,
        ),
      );
    }
  }

  /// Remove an agent from the registry.
  void remove(AgentId agentId) {
    _statuses.remove(agentId);
  }

  /// Dispose the registry and close the stream.
  void dispose() {
    _controller.close();
  }
}
