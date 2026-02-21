import 'package:agent_sdk/agent_sdk.dart';
import '../logging/vide_logger.dart';
import '../models/agent_id.dart';
import 'package:riverpod/riverpod.dart';

final agentClientProvider = Provider.family<AgentClient?, AgentId>((
  ref,
  agentId,
) {
  return ref.watch(agentClientManagerProvider)[agentId];
});

/// Provider for watching the current [AgentProcessingStatus] from an agent's
/// client.
///
/// This is for **UI label text only** (e.g. showing "Processing" / "Thinking" /
/// "Responding" in a loading indicator). It is NOT the source of truth for
/// whether an agent is busy — use [agentStatusProvider] for that.
///
/// [AgentStatusSyncService] bridges AgentProcessingStatus →
/// [agentStatusProvider] automatically, so consumers should never need to
/// derive agent status from this stream.
final agentProcessingStatusProvider = StreamProvider.family<
  AgentProcessingStatus,
  AgentId
>((ref, agentId) {
  final client = ref.watch(agentClientProvider(agentId));
  if (client == null) {
    return Stream.value(AgentProcessingStatus.ready);
  }
  return client.statusStream;
});

final agentClientManagerProvider = StateNotifierProvider<
  AgentClientManagerStateNotifier,
  Map<String, AgentClient>
>((ref) {
  return AgentClientManagerStateNotifier();
});

class AgentClientManagerStateNotifier
    extends StateNotifier<Map<String, AgentClient>> {
  AgentClientManagerStateNotifier() : super(Map<String, AgentClient>());

  /// Public read-only access to the current client map.
  ///
  /// Use this instead of the protected [state] getter when accessing
  /// from outside the StateNotifier subclass.
  Map<String, AgentClient> get clients => state;

  void addAgent(String agentId, AgentClient client) {
    VideLogger.instance.debug(
      'AgentClientManager',
      'addAgent: id=$agentId (total=${state.length + 1})',
    );
    state = {...state, agentId: client};
  }

  void removeAgent(String agentId) {
    VideLogger.instance.debug(
      'AgentClientManager',
      'removeAgent: id=$agentId (total=${state.length - 1})',
    );
    state = {...state}..remove(agentId);
  }
}
