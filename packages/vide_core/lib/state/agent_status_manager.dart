import 'package:riverpod/riverpod.dart';
import '../models/agent_id.dart';
import '../models/agent_status.dart';

/// Provider for managing agent status.
///
/// Each agent has its own status that can be set via the `setAgentStatus` MCP tool.
/// Default status is `working` since agents start processing immediately.
final agentStatusProvider =
    StateNotifierProvider.family<AgentStatusNotifier, AgentStatus, AgentId>(
      (ref, agentId) => AgentStatusNotifier(),
    );

/// Notifier for a single agent's status.
class AgentStatusNotifier extends StateNotifier<AgentStatus> {
  AgentStatusNotifier() : super(AgentStatus.working);

  /// Set the agent's status.
  void setStatus(AgentStatus status) {
    state = status;
  }
}
