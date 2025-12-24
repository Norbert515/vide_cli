import 'dart:io';
import 'dart:convert';
import '../models/config.dart';
import '../mcp/server/mcp_server_base.dart';

/// Manages MCP server configuration for Claude CLI processes.
class ProcessManager {
  final ClaudeConfig config;
  final List<McpServerBase> mcpServers;

  ProcessManager({required this.config, this.mcpServers = const []});

  /// Generate CLI arguments for MCP server configuration.
  ///
  /// Returns a list of arguments to pass to the Claude CLI, including
  /// the --mcp-config flag with JSON configuration for all registered servers.
  Future<List<String>> getMcpArgs() async {
    if (mcpServers.isEmpty) {
      return [];
    }

    // Create the proper mcpServers configuration object
    final mcpServersConfig = <String, dynamic>{};

    for (final server in mcpServers) {
      final serverConfig = server.toClaudeConfig();
      mcpServersConfig[server.name] = serverConfig;
    }

    // Add Dart MCP server (uses stdio transport, Claude handles it)
    mcpServersConfig['dart'] = {
      'command': 'dart',
      'args': ['mcp-server']
    };

    // Create the complete configuration with mcpServers wrapper
    final fullConfig = {'mcpServers': mcpServersConfig};

    // Note: We do NOT add --allowed-tools here. Adding only MCP tools to
    // --allowed-tools would RESTRICT Claude to ONLY those tools, blocking
    // native tools like Bash, Read, Edit, etc. The permission mode
    // (acceptEdits/default) handles tool permissions appropriately.

    return ['--mcp-config', jsonEncode(fullConfig)];
  }

  /// Check if the Claude CLI is available in the system PATH.
  static Future<bool> isClaudeAvailable() async {
    try {
      final result = await Process.run('which', ['claude']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }
}

