import 'package:claude_sdk/claude_sdk.dart';
import '../models/agent_id.dart';
import 'package:riverpod/riverpod.dart';

final claudeProvider = Provider.family<ClaudeClient?, AgentId>((ref, agentId) {
  return ref.watch(claudeManagerProvider)[agentId];
});

/// Provider for watching the current ClaudeStatus from an agent's client.
///
/// This provides real-time status updates (processing, thinking, responding, etc.)
/// from the Claude API, useful for showing activity indicators in the UI.
///
/// Note: Agent status auto-sync is handled by AgentNetworkManager._setupStatusSync()
/// which subscribes to status changes when agents are created. This provider is
/// purely for UI observation.
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
