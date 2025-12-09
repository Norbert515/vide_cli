import 'dart:io';

/// Manages Dart MCP server detection and configuration
class DartMcpManager {
  /// Check if the Dart MCP server is configured in Claude Code
  ///
  /// Returns true if 'dart' MCP server is found in configuration
  static Future<bool> isDartMcpConfigured() async {
    try {
      final result = await Process.run('claude', ['mcp', 'list']);
      if (result.exitCode != 0) return false;

      final output = result.stdout.toString();
      return output.contains('dart');
    } catch (e) {
      // Claude CLI not available or command failed
      return false;
    }
  }

  /// Check if Dart SDK is available and supports MCP server
  ///
  /// Requires Dart SDK 3.9.0 or later
  static Future<bool> isDartSdkAvailable() async {
    try {
      final result = await Process.run('dart', ['--version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Get the command to configure Dart MCP server (user scope)
  static String getUserScopeCommand() {
    return 'claude mcp add dart --scope user -- dart mcp-server';
  }

  /// Get the command to configure Dart MCP server (project scope)
  static String getProjectScopeCommand() {
    return 'claude mcp add dart --scope project -- dart mcp-server';
  }

  /// Get comprehensive status information about Dart MCP
  static Future<DartMcpStatus> getStatus([String? projectPath]) async {
    final dartSdkAvailable = await isDartSdkAvailable();
    final mcpConfigured = await isDartMcpConfigured();
    final projectDetected = projectPath != null;

    return DartMcpStatus(
      isDartSdkAvailable: dartSdkAvailable,
      isMcpConfigured: mcpConfigured,
      isDartProjectDetected: projectDetected,
    );
  }

  /// Create a .mcp.json file in the project root with Dart MCP configuration
  ///
  /// This enables Dart MCP for the entire team when the file is committed
  static Future<void> createProjectMcpConfig(String projectRoot) async {
    final mcpFile = File('$projectRoot/.mcp.json');

    final config = {
      'mcpServers': {
        'dart': {
          'command': 'dart',
          'args': ['mcp-server']
        }
      }
    };

    // Write with pretty formatting
    final tempFile = File('${mcpFile.path}.tmp');
    await tempFile.writeAsString(_prettyPrintJson(config));
    await tempFile.rename(mcpFile.path);
  }

  /// Pretty print JSON with 2-space indentation
  static String _prettyPrintJson(Map<String, dynamic> json) {
    final buffer = StringBuffer();
    _writeJson(json, buffer, 0);
    return buffer.toString();
  }

  static void _writeJson(dynamic value, StringBuffer buffer, int indent) {
    if (value is Map) {
      buffer.writeln('{');
      final entries = value.entries.toList();
      for (var i = 0; i < entries.length; i++) {
        final entry = entries[i];
        buffer.write('  ' * (indent + 1));
        buffer.write('"${entry.key}": ');
        _writeJson(entry.value, buffer, indent + 1);
        if (i < entries.length - 1) {
          buffer.writeln(',');
        } else {
          buffer.writeln();
        }
      }
      buffer.write('  ' * indent);
      buffer.write('}');
    } else if (value is List) {
      buffer.write('[');
      for (var i = 0; i < value.length; i++) {
        if (i > 0) buffer.write(', ');
        _writeJson(value[i], buffer, indent);
      }
      buffer.write(']');
    } else if (value is String) {
      buffer.write('"$value"');
    } else {
      buffer.write(value.toString());
    }
  }
}

/// Status information about Dart MCP server availability
class DartMcpStatus {
  final bool isDartSdkAvailable;
  final bool isMcpConfigured;
  final bool isDartProjectDetected;

  DartMcpStatus({
    required this.isDartSdkAvailable,
    required this.isMcpConfigured,
    required this.isDartProjectDetected,
  });

  /// Check if Dart MCP can be enabled
  bool get canBeEnabled => isDartSdkAvailable && isDartProjectDetected;

  /// Check if everything is ready
  bool get isFullyEnabled => canBeEnabled && isMcpConfigured;

  /// Get a status message for display
  String get statusMessage {
    if (isFullyEnabled) return 'Enabled';
    if (!isDartProjectDetected) return 'Not a Dart project';
    if (!isDartSdkAvailable) return 'Dart SDK not found';
    if (!isMcpConfigured) return 'Available - not configured';
    return 'Unknown';
  }

  /// Get an emoji indicator for the status
  String get statusEmoji {
    if (isFullyEnabled) return '✅';
    if (canBeEnabled && !isMcpConfigured) return '⚠️';
    return '❌';
  }
}
