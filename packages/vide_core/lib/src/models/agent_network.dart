import 'agent_id.dart';
import 'agent_metadata.dart';

/// Represents a network of agents working together on a common goal.
///
/// This is a shallow, persistable object that tracks:
/// - The network's unique identifier
/// - The overarching goal all agents are working towards
/// - All agents that are part of this network (flat list, no hierarchy)
/// - Timestamps for creation and last activity
class AgentNetwork {
  AgentNetwork({
    required this.id,
    required this.goal,
    required this.agents,
    required this.createdAt,
    this.lastActiveAt,
    this.worktreePath,
  });

  final AgentNetworkId id;
  final String goal;
  final List<AgentMetadata> agents;
  final DateTime createdAt;
  final DateTime? lastActiveAt;

  /// Optional worktree path for the session. When set, all agents use this directory.
  final String? worktreePath;

  /// Get just the agent IDs for convenience
  List<AgentId> get agentIds => agents.map((a) => a.id).toList();

  /// Total input tokens across all agents in the network
  int get networkTotalInputTokens =>
      agents.fold(0, (sum, agent) => sum + agent.totalInputTokens);

  /// Total output tokens across all agents in the network
  int get networkTotalOutputTokens =>
      agents.fold(0, (sum, agent) => sum + agent.totalOutputTokens);

  /// Total cache read input tokens across all agents in the network
  int get networkTotalCacheReadInputTokens =>
      agents.fold(0, (sum, agent) => sum + agent.totalCacheReadInputTokens);

  /// Total cache creation input tokens across all agents in the network
  int get networkTotalCacheCreationInputTokens =>
      agents.fold(0, (sum, agent) => sum + agent.totalCacheCreationInputTokens);

  /// Total context tokens across all agents (input + cache).
  int get networkTotalContextTokens =>
      agents.fold(0, (sum, agent) => sum + agent.totalContextTokens);

  /// Total cost in USD across all agents in the network
  double get networkTotalCostUsd =>
      agents.fold(0.0, (sum, agent) => sum + agent.totalCostUsd);

  AgentNetwork copyWith({
    AgentNetworkId? id,
    String? goal,
    List<AgentMetadata>? agents,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    String? worktreePath,
    bool clearWorktreePath = false,
  }) {
    return AgentNetwork(
      id: id ?? this.id,
      goal: goal ?? this.goal,
      agents: agents ?? this.agents,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      worktreePath: clearWorktreePath
          ? null
          : (worktreePath ?? this.worktreePath),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'goal': goal,
      'agents': agents.map((a) => a.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'lastActiveAt': lastActiveAt?.toIso8601String(),
      if (worktreePath != null) 'worktreePath': worktreePath,
    };
  }

  factory AgentNetwork.fromJson(Map<String, dynamic> json) {
    // Support both old format (list of strings) and new format (list of objects)
    final agentsJson = json['agents'] as List<dynamic>;
    final agents = agentsJson.map((a) {
      if (a is String) {
        // Legacy format: just agent ID string
        return AgentMetadata(
          id: a,
          name: 'Agent',
          type: 'unknown',
          createdAt: DateTime.now(),
        );
      } else {
        // New format: full metadata object
        return AgentMetadata.fromJson(a as Map<String, dynamic>);
      }
    }).toList();

    return AgentNetwork(
      id: json['id'] as String,
      goal: json['goal'] as String,
      agents: agents,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastActiveAt: json['lastActiveAt'] != null
          ? DateTime.parse(json['lastActiveAt'] as String)
          : null,
      worktreePath: json['worktreePath'] as String?,
    );
  }
}
