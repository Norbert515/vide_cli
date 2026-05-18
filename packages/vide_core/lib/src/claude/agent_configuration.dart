import '../mcp/mcp_server_type.dart';

/// High-level configuration for an agent.
///
/// This is a harness-agnostic representation providing:
/// - Agent identity (name, description)
/// - System prompt content
/// - MCP server access control
/// - Tool restrictions
/// - Harness selection and harness-specific config
/// - Permission settings (framework-level)
///
/// Each harness factory (Claude, Codex, etc.) reads its own parameters
/// from [harnessConfig].
class AgentConfiguration {
  /// Human-readable name for this agent type
  final String name;

  /// Description of the agent's purpose and when to use it
  final String? description;

  /// System prompt content for the agent
  final String systemPrompt;

  /// MCP servers this agent has access to
  ///
  /// If null, the agent inherits all MCP servers from its parent.
  /// If empty list, the agent has no MCP servers.
  /// Otherwise, only the specified servers are available.
  final List<McpServerType>? mcpServers;

  /// Individual tools this agent can access (additive - for permission purposes)
  ///
  /// If null, the agent inherits all tools (including MCP tools).
  /// If specified, these tools are added to the allowed list.
  ///
  /// Note: This is ADDITIVE, not restrictive. Use [disallowedTools] to
  /// actually prevent an agent from using certain tools.
  final List<String>? allowedTools;

  /// Tools this agent should NOT have access to (restrictive)
  ///
  /// If specified, these tools are removed from the agent's available tools.
  /// This is the only way to actually prevent an agent from using built-in tools.
  final List<String>? disallowedTools;

  /// Which harness to use for this agent (e.g., 'claude-code', 'codex-cli').
  ///
  /// If null, the session default harness is used.
  /// Resolved from: spawn override > personality default > session default.
  final String? harness;

  /// Harness-specific configuration for the active harness.
  ///
  /// Contains key-value pairs that the selected harness factory interprets.
  /// For example, claude-code reads 'model', 'temperature', 'maxTokens'.
  /// Codex reads 'model', 'sandbox', 'approvalPolicy'.
  final Map<String, dynamic> harnessConfig;

  /// Permission mode for this agent
  ///
  /// Common values: 'acceptEdits', 'ask', 'deny'
  /// Defaults to 'acceptEdits' if not specified.
  ///
  /// This is a framework-level concept: each harness maps it to its own
  /// permission mechanism (Claude: permissionMode, Codex: approvalPolicy).
  final String? permissionMode;

  const AgentConfiguration({
    required this.name,
    required this.systemPrompt,
    this.description,
    this.mcpServers,
    this.allowedTools,
    this.disallowedTools,
    this.harness,
    this.harnessConfig = const {},
    this.permissionMode,
  });

  /// Create a copy with modified fields
  AgentConfiguration copyWith({
    String? name,
    String? description,
    String? systemPrompt,
    List<McpServerType>? mcpServers,
    List<String>? allowedTools,
    List<String>? disallowedTools,
    String? harness,
    Map<String, dynamic>? harnessConfig,
    String? permissionMode,
  }) {
    return AgentConfiguration(
      name: name ?? this.name,
      description: description ?? this.description,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      mcpServers: mcpServers ?? this.mcpServers,
      allowedTools: allowedTools ?? this.allowedTools,
      disallowedTools: disallowedTools ?? this.disallowedTools,
      harness: harness ?? this.harness,
      harnessConfig: harnessConfig ?? this.harnessConfig,
      permissionMode: permissionMode ?? this.permissionMode,
    );
  }

  @override
  String toString() {
    return 'AgentConfiguration('
        'name: $name, '
        'mcpServers: ${mcpServers?.length ?? "inherited"}, '
        'allowedTools: ${allowedTools?.length ?? "inherited"}, '
        'harness: ${harness ?? "default"}'
        ')';
  }
}
