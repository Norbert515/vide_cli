/// Configuration classes for the VideCore API.
///
/// These provide clean configuration without exposing internal types.
library;

import 'vide_agent.dart';

/// Configuration for creating a [VideCore] instance.
///
/// Example:
/// ```dart
/// final core = VideCore(VideCoreConfig(
///   configDir: '~/.vide',
/// ));
/// ```
class VideCoreConfig {
  /// Configuration directory for persisting sessions and settings.
  ///
  /// Defaults to `~/.vide` if not specified.
  final String? configDir;

  const VideCoreConfig({
    this.configDir,
  });
}

/// Configuration for starting a new session.
///
/// Example:
/// ```dart
/// final session = await core.startSession(VideSessionConfig(
///   workingDirectory: '/path/to/project',
///   initialMessage: 'Fix the bug in auth.dart',
///   model: 'sonnet',
/// ));
/// ```
class VideSessionConfig {
  /// Working directory for the session (where agents operate).
  final String workingDirectory;

  /// Initial message to send to the main agent.
  final String initialMessage;

  /// Model to use: 'sonnet', 'opus', or 'haiku'.
  ///
  /// Defaults to Claude's default model if not specified.
  final String? model;

  /// Permission mode: 'accept-edits', 'plan', 'ask', or 'deny'.
  ///
  /// Defaults to 'ask' if not specified.
  final String? permissionMode;

  /// Team to use: 'vide-classic', 'enterprise', 'startup', 'balanced', 'research', 'ideator'.
  ///
  /// Defaults to 'vide-classic' if not specified.
  final String team;

  /// Whether to skip all permission checks.
  ///
  /// DANGEROUS: Only use in sandboxed environments (Docker) where filesystem
  /// isolation protects the host system. This bypasses ALL safety checks.
  final bool dangerouslySkipPermissions;

  const VideSessionConfig({
    required this.workingDirectory,
    required this.initialMessage,
    this.model,
    this.permissionMode,
    this.team = 'vide-classic',
    this.dangerouslySkipPermissions = false,
  });
}

/// Summary information about a session (for listing).
///
/// This provides enough information to display sessions without
/// loading full conversation history.
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

  const VideSessionInfo({
    required this.id,
    required this.goal,
    required this.createdAt,
    this.lastActiveAt,
    required this.agents,
    this.workingDirectory,
  });

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
