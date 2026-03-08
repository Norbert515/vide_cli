import 'package:claude_sdk/claude_sdk.dart';

/// Builds `-c` CLI arguments for `codex app-server` so it discovers
/// our MCP servers at startup.
///
/// Codex CLI only reads config from `~/.codex/config.toml` — it does NOT
/// read project-level `.codex/config.toml`. The `-c` flag is the correct
/// way to inject per-process configuration overrides.
///
/// Each running [McpServerBase] becomes a pair of args:
///   `-c`, `mcp_servers.<name>.url="http://localhost:<port>/mcp"`
class CodexMcpRegistry {
  /// Build `-c` CLI arguments that register MCP servers with codex.
  ///
  /// Returns a flat list of strings suitable for passing as `extraArgs`
  /// to [CodexTransport.start].
  ///
  /// Example output for two servers:
  /// ```
  /// ['-c', 'mcp_servers.vide_agent.url="http://localhost:5678/mcp"',
  ///  '-c', 'mcp_servers.flutter_runtime.url="http://localhost:5679/mcp"']
  /// ```
  static List<String> buildArgs({
    required List<McpServerBase> mcpServers,
  }) {
    if (mcpServers.isEmpty) return const [];

    final args = <String>[];

    for (final server in mcpServers) {
      if (!server.isRunning) continue;

      final config = server.toClaudeConfig();
      final url = config['url'] as String;
      final name = _sanitizeName(server.name);

      args.add('-c');
      args.add('mcp_servers.$name.url="$url"');
    }

    return args;
  }

  /// Sanitize server name for use as a TOML key.
  /// Replaces non-alphanumeric characters with underscores.
  static String _sanitizeName(String name) {
    return name.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  }
}
