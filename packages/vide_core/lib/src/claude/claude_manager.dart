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

final agentClientManagerProvider =
    StateNotifierProvider<
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
