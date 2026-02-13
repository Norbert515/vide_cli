import 'package:claude_sdk/claude_sdk.dart';
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

  void addAgent(String agentId, ClaudeClient client) {
    state = {...state, agentId: client};
  }

  void removeAgent(String agentId) {
    state = {...state}..remove(agentId);
  }
}
