import 'dart:async';
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

    // Collect all MCP tool names to add to allowed tools
    final mcpToolNames = <String>[];

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

          // Add MCP server's tools to the allowed list
          // Format: mcp_<server-name>_<tool-name>
          print('[ProcessManager] VERBOSE: ${server.name} tools: ${server.toolNames.join(", ")}');
          for (final toolName in server.toolNames) {
            final qualifiedName = 'mcp__${server.name}__$toolName';
            print('[ProcessManager] VERBOSE: Adding tool: $qualifiedName');
            mcpToolNames.add(qualifiedName);
          }
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

      // Add Dart MCP tool names to allowed tools
      final dartMcpToolNames = [
        'add_roots',
        'analyze_files',
        'connect_dart_tooling_daemon',
        'create_project',
        'dart_fix',
        'dart_format',
        'flutter_driver',
        'get_active_location',
        'get_app_logs',
        'get_runtime_errors',
        'get_selected_widget',
        'get_widget_tree',
        'hot_reload',
        'hot_restart',
        'hover',
        'launch_app',
        'list_devices',
        'list_running_apps',
        'pub',
        'pub_dev_search',
        'read_package_uris',
        'remove_roots',
        'resolve_workspace_symbol',
        'run_tests',
        'set_widget_selection_mode',
        'signature_help',
        'stop_app',
      ];
      for (final toolName in dartMcpToolNames) {
        mcpToolNames.add('mcp__dart__$toolName');
      }
      print('[ProcessManager] VERBOSE: Added ${dartMcpToolNames.length} Dart MCP tools to allowed list');

      // Create the complete configuration with mcpServers wrapper
      final fullConfig = {'mcpServers': mcpServersConfig};
      print('[ProcessManager] VERBOSE: Full MCP config: ${jsonEncode(fullConfig)}');

      // Write config to a temporary file
      final tempFile = File(
        '${Directory.systemTemp.path}/vide_mcp_config_${DateTime.now().millisecondsSinceEpoch}.json',
      );
      await tempFile.writeAsString(jsonEncode(fullConfig));
      print('[ProcessManager] VERBOSE: Written MCP config to: ${tempFile.path}');

      args.addAll(['--mcp-config', tempFile.path]);

      // Add MCP tools to allowed tools list
      if (mcpToolNames.isNotEmpty) {
        args.addAll(['--allowed-tools', ...mcpToolNames]);
        print('[ProcessManager] VERBOSE: Added ${mcpToolNames.length} tools to allowed-tools');
      }

      print('[ProcessManager] VERBOSE: MCP args: ${args.join(" ")}');
      print('[ProcessManager] VERBOSE: Allowed tools (${mcpToolNames.length}): ${mcpToolNames.join(", ")}');

      // Schedule cleanup after a reasonable delay
      Timer(const Duration(seconds: 10), () {
        try {
          if (tempFile.existsSync()) {
            tempFile.deleteSync();
            print('[ProcessManager] VERBOSE: Cleaned up temp config file: ${tempFile.path}');
          }
        } catch (_) {}
      });
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
