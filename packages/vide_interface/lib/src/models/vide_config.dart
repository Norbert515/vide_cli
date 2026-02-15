/// Configuration classes for the Vide API.
library;

import 'vide_agent.dart';

/// Configuration for starting a new session.
class VideSessionConfig {
  /// Working directory for the session (where agents operate).
  final String workingDirectory;

  /// Initial message to send to the main agent.
  final String initialMessage;

  /// Permission mode: 'accept-edits', 'plan', 'ask', or 'deny'.
  final String? permissionMode;

  /// Team to use for the session.
  final String team;

  /// Whether to skip all permission checks.
  final bool dangerouslySkipPermissions;

  const VideSessionConfig({
    required this.workingDirectory,
    required this.initialMessage,
    this.permissionMode,
    this.team = 'enterprise',
    this.dangerouslySkipPermissions = false,
  });
}

/// Summary information about a session (for listing).
class VideSessionInfo {
  /// Unique session identifier.
  final String id;

  /// Overall goal/task name for the session.
  final String goal;

  /// When the session was created.
  final DateTime createdAt;

  /// When the session was last active.
  final DateTime? lastActiveAt;

  /// Agents in the session.
  final List<VideAgent> agents;

  /// Working directory for the session.
  final String? workingDirectory;

  /// The team framework team used for this session.
  final String? team;

  const VideSessionInfo({
    required this.id,
    required this.goal,
    required this.createdAt,
    this.lastActiveAt,
    required this.agents,
    this.workingDirectory,
    this.team,
  });

  /// Number of agents in the session.
  int get agentCount => agents.length;

  /// Total cost across all agents in USD.
  double get totalCostUsd =>
      agents.fold(0.0, (sum, agent) => sum + agent.totalCostUsd);

  /// Total input tokens across all agents.
  int get totalInputTokens =>
      agents.fold(0, (sum, agent) => sum + agent.totalInputTokens);

  /// Total output tokens across all agents.
  int get totalOutputTokens =>
      agents.fold(0, (sum, agent) => sum + agent.totalOutputTokens);

  @override
  String toString() => 'VideSessionInfo($id, $goal, ${agents.length} agents)';
}
