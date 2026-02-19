import 'package:claude_sdk/claude_sdk.dart';
import '../logging/vide_logger.dart';
import '../models/agent_id.dart';
import 'package:riverpod/riverpod.dart';

final claudeProvider = Provider.family<ClaudeClient?, AgentId>((ref, agentId) {
  return ref.watch(claudeManagerProvider)[agentId];
});

/// Provider for watching the current [ClaudeStatus] from an agent's client.
///
/// This is for **UI label text only** (e.g. showing "Processing" / "Thinking" /
/// "Responding" in a loading indicator). It is NOT the source of truth for
/// whether an agent is busy — use [agentStatusProvider] for that.
///
/// [AgentStatusSyncService] bridges ClaudeStatus → [agentStatusProvider]
/// automatically, so consumers should never need to derive agent status from
/// this stream.
final claudeStatusProvider = StreamProvider.family<ClaudeStatus, AgentId>((
  ref,
  agentId,
) {
  final client = ref.watch(claudeProvider(agentId));
  if (client == null) {
    return Stream.value(ClaudeStatus.ready);
  }
  return client.statusStream;
});

final claudeManagerProvider =
    StateNotifierProvider<
      ClaudeManagerStateNotifier,
      Map<String, ClaudeClient>
    >((ref) {
      return ClaudeManagerStateNotifier();
    });

class ClaudeManagerStateNotifier
    extends StateNotifier<Map<String, ClaudeClient>> {
  ClaudeManagerStateNotifier() : super(Map<String, ClaudeClient>());

  /// Public read-only access to the current client map.
  ///
  /// Use this instead of the protected [state] getter when accessing
  /// from outside the StateNotifier subclass.
  Map<String, ClaudeClient> get clients => state;

  void addAgent(String agentId, ClaudeClient client) {
    VideLogger.instance.debug(
      'ClaudeManager',
      'addAgent: id=$agentId (total=${state.length + 1})',
    );
    state = {...state, agentId: client};
  }

  void removeAgent(String agentId) {
    VideLogger.instance.debug(
      'ClaudeManager',
      'removeAgent: id=$agentId (total=${state.length - 1})',
    );
    state = {...state}..remove(agentId);
  }
}
