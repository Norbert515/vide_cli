/// Enumeration of MCP servers available in Vide CLI.
///
/// This enum identifies both built-in MCP servers and custom servers.
/// Built-in servers are managed internally, while custom servers can be
/// referenced by name.
sealed class McpServerType {
  const McpServerType();

  /// Git operations MCP server (vide-git)
  static const git = _BuiltInMcpServer._('vide-git');

  /// Agent network MCP server (vide-agent)
  /// Provides tools for spawning agents and inter-agent communication
  static const agent = _BuiltInMcpServer._('vide-agent');

  /// Memory/context storage MCP server (vide-memory)
  static const memory = _BuiltInMcpServer._('vide-memory');

  /// Task management MCP server (vide-task-management)
  static const taskManagement = _BuiltInMcpServer._('vide-task-management');

  /// Ask user question MCP server (vide-ask-user-question)
  /// Provides structured multiple-choice questions to users
  static const askUserQuestion = _BuiltInMcpServer._('vide-ask-user-question');

  /// Flutter runtime MCP server (flutter-runtime)
  static const flutterRuntime = _BuiltInMcpServer._('flutter-runtime');

  /// Figma design MCP server (figma-remote-mcp)
  static const figma = _BuiltInMcpServer._('figma-remote-mcp');

  /// Custom MCP server referenced by name
  ///
  /// Use this for external MCP servers not managed by Vide CLI.
  /// The name should match the server's identifier in the MCP config.
  static McpServerType custom(String serverName) =>
      _CustomMcpServer._(serverName);

  /// Get the server name/identifier
  String get serverName;
}

/// Built-in MCP server managed by Vide CLI
class _BuiltInMcpServer extends McpServerType {
  @override
  final String serverName;

  const _BuiltInMcpServer._(this.serverName);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _BuiltInMcpServer &&
          runtimeType == other.runtimeType &&
          serverName == other.serverName;

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
      other is _CustomMcpServer &&
          runtimeType == other.runtimeType &&
          serverName == other.serverName;

  @override
  int get hashCode => serverName.hashCode;

  @override
  String toString() => 'McpServerType.custom($serverName)';
}
