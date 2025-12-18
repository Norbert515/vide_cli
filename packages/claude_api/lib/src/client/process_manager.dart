import 'dart:io';
import 'dart:convert';
import '../models/config.dart';
import '../mcp/server/mcp_server_base.dart';

class ProcessManager {
  final ClaudeConfig config;
  final List<McpServerBase> mcpServers;

  ProcessManager({required this.config, this.mcpServers = const []});

  Future<List<String>> getMcpArgs() async {
    print('[ProcessManager] VERBOSE: ========================================');
    print('[ProcessManager] VERBOSE: Generating MCP args');
    print('[ProcessManager] VERBOSE: Total MCP servers: ${mcpServers.length}');

    final args = <String>[];

    // Add MCP server configurations
    if (mcpServers.isNotEmpty) {
      print('[ProcessManager] VERBOSE: Processing ${mcpServers.length} MCP servers...');

      // Create the proper mcpServers configuration object
      final mcpServersConfig = <String, dynamic>{};

      for (int i = 0; i < mcpServers.length; i++) {
        final server = mcpServers[i];
        print('[ProcessManager] VERBOSE: Processing server ${i + 1}/${mcpServers.length}: ${server.name}');
        print('[ProcessManager] VERBOSE: Server ${server.name} isRunning: ${server.isRunning}');

        try {
          print('[ProcessManager] VERBOSE: Getting config for ${server.name}...');
          final serverConfig = server.toClaudeConfig();
          print('[ProcessManager] VERBOSE: ${server.name} config: ${jsonEncode(serverConfig)}');
          mcpServersConfig[server.name] = serverConfig;
          print('[ProcessManager] VERBOSE: ${server.name} tools: ${server.toolNames.join(", ")}');
          print('[ProcessManager] VERBOSE: ✓ Successfully processed ${server.name}');
        } catch (e, stackTrace) {
          print('[ProcessManager] VERBOSE: ❌ Failed to get config for ${server.name}: $e');
          print('[ProcessManager] VERBOSE: Stack trace: $stackTrace');
        }
      }

      // Add Dart MCP server (uses stdio transport, Claude handles it)
      print('[ProcessManager] VERBOSE: Adding Dart MCP server configuration...');
      mcpServersConfig['dart'] = {
        'command': 'dart',
        'args': ['mcp-server']
      };
      print('[ProcessManager] VERBOSE: ✓ Added Dart MCP server');

      // Create the complete configuration with mcpServers wrapper
      final fullConfig = {'mcpServers': mcpServersConfig};
      print('[ProcessManager] VERBOSE: Full MCP config: ${jsonEncode(fullConfig)}');
      print('[ProcessManager] VERBOSE: Using inline MCP config');

      args.addAll(['--mcp-config', jsonEncode(fullConfig)]);

      // Note: We do NOT add --allowed-tools here. Adding only MCP tools to
      // --allowed-tools would RESTRICT Claude to ONLY those tools, blocking
      // native tools like Bash, Read, Edit, etc. The permission mode
      // (acceptEdits/default) handles tool permissions appropriately.

      print('[ProcessManager] VERBOSE: MCP args: ${args.join(" ")}');
    } else {
      print('[ProcessManager] VERBOSE: No MCP servers to configure');
    }

    print('[ProcessManager] VERBOSE: ========================================');
    return args;
  }

  static Future<bool> isClaudeAvailable() async {
    try {
      final result = await Process.run('which', ['claude']);
      final available = result.exitCode == 0;
      return available;
    } catch (e) {
      return false;
    }
  }
}

class ClaudeNotFoundError extends Error {
  final String message;
  ClaudeNotFoundError(this.message);

  @override
  String toString() => 'ClaudeNotFoundError: $message';
}

class ClaudeProcessError extends Error {
  final String message;
  ClaudeProcessError(this.message);

  @override
  String toString() => 'ClaudeProcessError: $message';
}
