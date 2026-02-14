import 'package:riverpod/riverpod.dart';
import '../logging/vide_logger.dart';
import '../models/agent_id.dart';
import '../models/agent_status.dart';

/// Provider for managing agent status.
///
/// Each agent has its own status that can be set via the `setAgentStatus` MCP tool.
/// Default status is `idle` since agents may be created during session resume
/// without an active turn. The status sync service will set `working` when
/// a turn begins.
final agentStatusProvider =
    StateNotifierProvider.family<AgentStatusNotifier, AgentStatus, AgentId>(
      (ref, agentId) => AgentStatusNotifier(agentId: agentId),
    );

/// Notifier for a single agent's status.
class AgentStatusNotifier extends StateNotifier<AgentStatus> {
  AgentStatusNotifier({required this.agentId}) : super(AgentStatus.idle);

  final AgentId agentId;

  /// Set the agent's status.
  void setStatus(AgentStatus status) {
    final oldStatus = state;
    if (oldStatus == status) return;
    VideLogger.instance.debug(
      'AgentStatusNotifier',
      'Agent $agentId status: ${oldStatus.name} -> ${status.name}',
    );
    state = status;
  }
}
