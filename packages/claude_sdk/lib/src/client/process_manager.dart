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
  /// the --mcp-config flag with JSON configuration for vide's managed servers.
  /// Claude CLI automatically merges this with .mcp.json, ~/.claude.json, etc.
  Future<List<String>> getMcpArgs() async {
    if (mcpServers.isEmpty) {
      return [];
    }

    // Create config for vide's managed MCP servers only
    final mcpServersConfig = <String, dynamic>{};
    for (final server in mcpServers) {
      mcpServersConfig[server.name] = server.toClaudeConfig();
    }

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
      // Use 'where' on Windows, 'which' on Unix
      final command = Platform.isWindows ? 'where' : 'which';
      final result = await Process.run(command, ['claude']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Get the Claude executable name for the current platform.
  ///
  /// On Windows, checks for both 'claude.exe' (standalone installer) and
  /// 'claude.cmd' (npm installation), preferring .exe if both exist.
  /// On other platforms, returns 'claude'.
  static Future<String> getClaudeExecutable() async {
    if (!Platform.isWindows) {
      return 'claude';
    }

    // On Windows, check for standalone installer (.exe) first, then npm (.cmd)
    // Use 'where' to check if executables exist in PATH
    for (final exe in ['claude.exe', 'claude.cmd']) {
      try {
        final result = await Process.run('where', [exe]);
        if (result.exitCode == 0) {
          return exe;
        }
      } catch (_) {
        // Continue to next option
      }
    }

    // Fallback to 'claude' and let the system resolve it
    return 'claude';
  }
}
