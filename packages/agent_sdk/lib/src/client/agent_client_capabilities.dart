/// Extended capability interfaces for agent-specific features.
///
/// Not all agents support the same operations. These interfaces allow
/// consumers to check for specific capabilities using `is` checks:
///
/// ```dart
/// if (client is ModelConfigurable) {
///   await client.setModel('opus');
/// }
/// ```

/// Agent supports changing the model at runtime.
abstract class ModelConfigurable {
  Future<void> setModel(String model);
}

/// Agent supports setting a maximum thinking token budget.
abstract class ThinkingConfigurable {
  Future<void> setMaxThinkingTokens(int maxTokens);
}

/// Agent supports changing permission mode at runtime.
abstract class PermissionModeConfigurable {
  Future<void> setPermissionMode(String mode);
}

/// Agent supports interrupting the current execution
/// (more graceful than abort — marks current message as complete).
abstract class Interruptible {
  Future<void> interrupt();
}

/// Agent supports rewinding files to a previous state.
abstract class FileRewindable {
  Future<void> rewindFiles(String userMessageId);
}

/// Agent supports dynamic MCP server configuration.
abstract class McpConfigurable {
  Future<void> setMcpServers(
    List<AgentMcpServerConfig> servers, {
    bool replace,
  });
  Future<AgentMcpStatusInfo> getMcpStatus();
}

/// Configuration for a dynamically-added MCP server.
class AgentMcpServerConfig {
  final String name;
  final String command;
  final List<String> args;
  final Map<String, String>? env;

  const AgentMcpServerConfig({
    required this.name,
    required this.command,
    this.args = const [],
    this.env,
  });
}

/// Status information for connected MCP servers.
class AgentMcpStatusInfo {
  final List<AgentMcpServerStatus> servers;

  const AgentMcpStatusInfo({required this.servers});
}

/// Status of a single MCP server.
class AgentMcpServerStatus {
  final String name;
  final String status;
  final List<String> tools;

  const AgentMcpServerStatus({
    required this.name,
    required this.status,
    this.tools = const [],
  });
}
