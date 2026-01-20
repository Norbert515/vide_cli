import 'package:claude_sdk/claude_sdk.dart';
import '../mcp/mcp_server_type.dart';

/// High-level configuration for an agent.
///
/// This is a more expressive representation than [ClaudeConfig], providing:
/// - Agent identity (name, description)
/// - System prompt content
/// - MCP server access control
/// - Tool restrictions
/// - Model and permission settings
///
/// Convert to [ClaudeConfig] using [toClaudeConfig] when spawning agents.
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

  /// Model to use for this agent
  ///
  /// Common values: 'sonnet', 'opus', 'haiku'
  /// If null, uses default model.
  final String? model;

  /// Permission mode for this agent
  ///
  /// Common values: 'acceptEdits', 'ask', 'deny'
  /// Defaults to 'acceptEdits' if not specified.
  final String? permissionMode;

  /// Temperature for response generation (0.0 - 1.0)
  final double? temperature;

  /// Maximum tokens for responses
  final int? maxTokens;

  const AgentConfiguration({
    required this.name,
    required this.systemPrompt,
    this.description,
    this.mcpServers,
    this.allowedTools,
    this.disallowedTools,
    this.model,
    this.permissionMode,
    this.temperature,
    this.maxTokens,
  });

  /// Convert to ClaudeConfig for spawning the agent
  ///
  /// This handles:
  /// - Setting system prompt
  /// - Configuring allowed tools (non-MCP)
  /// - Model and permission settings
  /// - Streaming configuration
  ///
  /// Note: MCP server configuration is handled separately in the
  /// client creation process based on [mcpServers].
  ///
  /// [dangerouslySkipPermissions] - If true, skips ALL permission checks.
  /// DANGEROUS: Only use in sandboxed environments (Docker).
  ClaudeConfig toClaudeConfig({
    String? sessionId,
    String? workingDirectory,
    bool enableStreaming = true,
    bool dangerouslySkipPermissions = false,
  }) {
    // Translate client permission modes to valid Claude CLI modes.
    // Valid CLI modes: acceptEdits, bypassPermissions, default, delegate, dontAsk, plan
    // 'ask' is not a valid CLI mode - it's a vide-specific mode that means
    // "prompt the user via WebSocket". We translate it to 'default' for the CLI
    // and let the SDK callback handle the actual permission decisions.
    final cliPermissionMode = switch (permissionMode) {
      'ask' => 'default', // 'ask' is vide-specific, use 'default' for CLI
      null => 'acceptEdits',
      _ => permissionMode,
    };

    return ClaudeConfig(
      appendSystemPrompt: systemPrompt,
      allowedTools: allowedTools,
      disallowedTools: disallowedTools,
      model: model,
      permissionMode: cliPermissionMode,
      temperature: temperature,
      maxTokens: maxTokens,
      sessionId: sessionId,
      workingDirectory: workingDirectory,
      enableStreaming: enableStreaming,
      dangerouslySkipPermissions: dangerouslySkipPermissions,
      // Enable all setting sources:
      // - user: ~/.claude.json (user-level settings)
      // - project: .claude/settings.json (project settings)
      // - local: .mcp.json (MCP server configurations)
      settingSources: ['user', 'project', 'local'],
    );
  }

  /// Create a copy with modified fields
  AgentConfiguration copyWith({
    String? name,
    String? description,
    String? systemPrompt,
    List<McpServerType>? mcpServers,
    List<String>? allowedTools,
    List<String>? disallowedTools,
    String? model,
    String? permissionMode,
    double? temperature,
    int? maxTokens,
  }) {
    return AgentConfiguration(
      name: name ?? this.name,
      description: description ?? this.description,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      mcpServers: mcpServers ?? this.mcpServers,
      allowedTools: allowedTools ?? this.allowedTools,
      disallowedTools: disallowedTools ?? this.disallowedTools,
      model: model ?? this.model,
      permissionMode: permissionMode ?? this.permissionMode,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
    );
  }

  @override
  String toString() {
    return 'AgentConfiguration('
        'name: $name, '
        'mcpServers: ${mcpServers?.length ?? "inherited"}, '
        'allowedTools: ${allowedTools?.length ?? "inherited"}, '
        'model: ${model ?? "default"}'
        ')';
  }
}
