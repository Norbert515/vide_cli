/// Enumeration of MCP servers available in Parott.
///
/// This enum identifies both built-in MCP servers and custom servers.
/// Built-in servers are managed internally, while custom servers can be
/// referenced by name.
sealed class McpServerType {
  const McpServerType();

  /// Git operations MCP server (parott-git)
  static const git = _BuiltInMcpServer._('parott-git');

  /// Agent network MCP server (parott-agent)
  /// Provides tools for spawning agents and inter-agent communication
  static const agent = _BuiltInMcpServer._('parott-agent');

  /// Memory/context storage MCP server (parott-memory)
  static const memory = _BuiltInMcpServer._('parott-memory');

  /// Task management MCP server (parott-task-management)
  static const taskManagement = _BuiltInMcpServer._('parott-task-management');

  /// Flutter runtime MCP server (flutter-runtime)
  static const flutterRuntime = _BuiltInMcpServer._('flutter-runtime');

  /// Figma design MCP server (figma-remote-mcp)
  static const figma = _BuiltInMcpServer._('figma-remote-mcp');

  /// Custom MCP server referenced by name
  ///
  /// Use this for external MCP servers not managed by Parott.
  /// The name should match the server's identifier in the MCP config.
  static McpServerType custom(String serverName) => _CustomMcpServer._(serverName);

  /// Get the server name/identifier
  String get serverName;
}

/// Built-in MCP server managed by Parott
class _BuiltInMcpServer extends McpServerType {
  @override
  final String serverName;

  const _BuiltInMcpServer._(this.serverName);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _BuiltInMcpServer && runtimeType == other.runtimeType && serverName == other.serverName;

  @override
  int get hashCode => serverName.hashCode;

  @override
  String toString() => 'McpServerType.builtin($serverName)';
}

/// Custom MCP server referenced by name
class _CustomMcpServer extends McpServerType {
  @override
  final String serverName;

  const _CustomMcpServer._(this.serverName);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _CustomMcpServer && runtimeType == other.runtimeType && serverName == other.serverName;

  @override
  int get hashCode => serverName.hashCode;

  @override
  String toString() => 'McpServerType.custom($serverName)';
}
