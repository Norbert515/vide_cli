/// Public agent model for the Vide API.
library;

/// Status of an agent in the network.
enum VideAgentStatus {
  /// Agent is actively working on a task.
  working,

  /// Agent is waiting for another agent to respond.
  waitingForAgent,

  /// Agent is waiting for user input (e.g., permission).
  waitingForUser,

  /// Agent has completed its current task and is idle.
  idle;

  static VideAgentStatus fromWireString(String? value) => switch (value) {
    'working' => VideAgentStatus.working,
    'waiting-for-agent' => VideAgentStatus.waitingForAgent,
    'waiting-for-user' => VideAgentStatus.waitingForUser,
    'idle' => VideAgentStatus.idle,
    _ => VideAgentStatus.idle,
  };

  String toWireString() => switch (this) {
    VideAgentStatus.working => 'working',
    VideAgentStatus.waitingForAgent => 'waiting-for-agent',
    VideAgentStatus.waitingForUser => 'waiting-for-user',
    VideAgentStatus.idle => 'idle',
  };
}

/// Immutable snapshot of an agent's state.
class VideAgent {
  /// Unique identifier for this agent.
  final String id;

  /// Human-readable name (e.g., "Main", "Auth Research", "Bug Fix").
  final String name;

  /// Agent type (e.g., "main", "implementation", "contextCollection").
  final String type;

  /// Current status of the agent.
  final VideAgentStatus status;

  /// ID of the agent that spawned this one (null for main agent).
  final String? spawnedBy;

  /// Current task name set by the agent (e.g., "Implementing login form").
  final String? taskName;

  /// When this agent was created.
  final DateTime createdAt;

  /// Token usage statistics.
  final int totalInputTokens;
  final int totalOutputTokens;
  final int totalCacheReadInputTokens;
  final int totalCacheCreationInputTokens;
  final double totalCostUsd;

  const VideAgent({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    this.spawnedBy,
    this.taskName,
    required this.createdAt,
    this.totalInputTokens = 0,
    this.totalOutputTokens = 0,
    this.totalCacheReadInputTokens = 0,
    this.totalCacheCreationInputTokens = 0,
    this.totalCostUsd = 0.0,
  });

  /// Total context tokens (input + cache).
  int get totalContextTokens =>
      totalInputTokens +
      totalCacheReadInputTokens +
      totalCacheCreationInputTokens;

  @override
  String toString() => 'VideAgent($name, $type, $status)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideAgent &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          type == other.type &&
          status == other.status &&
          spawnedBy == other.spawnedBy &&
          taskName == other.taskName;

  @override
  int get hashCode => Object.hash(id, name, type, status, spawnedBy, taskName);
}
