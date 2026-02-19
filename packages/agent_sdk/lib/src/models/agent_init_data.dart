/// Initialization data received from the agent CLI after startup.
///
/// Contains information about the agent's capabilities, model,
/// and session configuration. Agent-specific data that doesn't
/// have a dedicated field is available via [metadata].
class AgentInitData {
  /// The model being used (e.g., 'claude-sonnet-4-5-20250929').
  final String? model;

  /// The session ID assigned by the agent.
  final String? sessionId;

  /// The working directory the agent is operating in.
  final String? cwd;

  /// The version of the agent CLI.
  final String? cliVersion;

  /// The current permission mode (e.g., 'default', 'plan', 'acceptEdits').
  final String? permissionMode;

  /// Available tools the agent can use.
  final List<String>? tools;

  /// Available skills (slash commands) the agent supports.
  final List<String>? skills;

  /// Catch-all for agent-specific data that doesn't have a dedicated field.
  final Map<String, dynamic> metadata;

  const AgentInitData({
    this.model,
    this.sessionId,
    this.cwd,
    this.cliVersion,
    this.permissionMode,
    this.tools,
    this.skills,
    this.metadata = const {},
  });
}
