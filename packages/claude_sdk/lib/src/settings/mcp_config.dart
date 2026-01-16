import 'package:json_annotation/json_annotation.dart';

part 'mcp_config.g.dart';

/// Rule for allowing or denying MCP servers.
///
/// Used in `allowedMcpServers` and `deniedMcpServers` arrays.
@JsonSerializable(includeIfNull: false)
class McpServerRule {
  /// The name of the MCP server to match.
  final String serverName;

  const McpServerRule({required this.serverName});

  factory McpServerRule.fromJson(Map<String, dynamic> json) =>
      _$McpServerRuleFromJson(json);

  Map<String, dynamic> toJson() => _$McpServerRuleToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is McpServerRule &&
          runtimeType == other.runtimeType &&
          serverName == other.serverName;

  @override
  int get hashCode => serverName.hashCode;
}

/// MCP server configuration stored in .mcp.json files.
///
/// This is separate from ClaudeSettings and represents the
/// server definitions in .mcp.json files.
@JsonSerializable(explicitToJson: true, includeIfNull: false)
class McpJsonConfig {
  /// Map of server name to server configuration.
  final Map<String, McpServerDefinition>? mcpServers;

  const McpJsonConfig({this.mcpServers});

  factory McpJsonConfig.fromJson(Map<String, dynamic> json) {
    final servers = json['mcpServers'] as Map<String, dynamic>?;
    if (servers == null) {
      return const McpJsonConfig();
    }

    return McpJsonConfig(
      mcpServers: servers.map(
        (key, value) => MapEntry(
          key,
          McpServerDefinition.fromJson(value as Map<String, dynamic>),
        ),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    if (mcpServers == null) return {};
    return {
      'mcpServers': mcpServers!.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
    };
  }

  /// Get all server names defined in the config.
  Set<String> get serverNames => mcpServers?.keys.toSet() ?? {};

  /// Check if a server is defined.
  bool hasServer(String name) => mcpServers?.containsKey(name) ?? false;

  /// Get a server definition by name.
  McpServerDefinition? getServer(String name) => mcpServers?[name];
}

/// Definition of an MCP server in .mcp.json.
@JsonSerializable(includeIfNull: false)
class McpServerDefinition {
  /// Command to run the server.
  final String command;

  /// Arguments to pass to the command.
  final List<String>? args;

  /// Environment variables for the server process.
  final Map<String, String>? env;

  /// Working directory for the server.
  final String? cwd;

  const McpServerDefinition({
    required this.command,
    this.args,
    this.env,
    this.cwd,
  });

  factory McpServerDefinition.fromJson(Map<String, dynamic> json) =>
      _$McpServerDefinitionFromJson(json);

  Map<String, dynamic> toJson() => _$McpServerDefinitionToJson(this);

  McpServerDefinition copyWith({
    String? command,
    List<String>? args,
    Map<String, String>? env,
    String? cwd,
  }) {
    return McpServerDefinition(
      command: command ?? this.command,
      args: args ?? this.args,
      env: env ?? this.env,
      cwd: cwd ?? this.cwd,
    );
  }
}
