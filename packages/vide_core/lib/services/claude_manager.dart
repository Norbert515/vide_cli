import 'package:claude_api/claude_api.dart';
import '../models/agent_id.dart';
import '../agents/agent_configuration.dart';
import 'package:riverpod/riverpod.dart';

class AgentIdAndClaudeConfig {
  final AgentId agentId;
  final AgentConfiguration config;

  AgentIdAndClaudeConfig({required this.agentId, required this.config});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AgentIdAndClaudeConfig && other.agentId == agentId && other.config == config;
  }

  @override
  int get hashCode => agentId.hashCode ^ config.hashCode;

  @override
  String toString() {
    return 'AgentIdAndClaudeConfig(agentId: $agentId, config: $config)';
  }
}

final claudeProvider = Provider.family<ClaudeClient?, AgentId>((ref, config) {
  return ref.watch(claudeManagerProvider)[config];
});

final claudeManagerProvider = StateNotifierProvider<ClaudeManagerStateNotifier, Map<String, ClaudeClient>>((ref) {
  return ClaudeManagerStateNotifier();
});

class ClaudeManagerStateNotifier extends StateNotifier<Map<String, ClaudeClient>> {
  ClaudeManagerStateNotifier() : super(Map<String, ClaudeClient>());

  void addAgent(String agentId, ClaudeClient client) {
    state = {...state, agentId: client};
  }

  void removeAgent(String agentId) {
    state = {...state}..remove(agentId);
  }
}
