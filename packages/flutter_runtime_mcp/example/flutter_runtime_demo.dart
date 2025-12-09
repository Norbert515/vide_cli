import 'dart:io';
import 'package:flutter_runtime_mcp/flutter_runtime_mcp.dart';

/// Example demonstrating Flutter Runtime MCP usage
void main() async {
  print('Flutter Runtime MCP Demo');
  print('=' * 50);

  final flutterServer = FlutterRuntimeServer();

  print('Server name: ${flutterServer.name}');
  print('Version: ${flutterServer.version}');
  print('\nAvailable tools:');

  for (final tool in flutterServer.toolNames) {
    print('  • $tool');
  }

  print('\nStarting server on port 8081...');

  try {
    await flutterServer.start();
    print('✓ Server started successfully');
    print('  Configuration: ${flutterServer.toClaudeConfig()}');

    print('\nServer is running. Press Enter to stop...');
    stdin.readLineSync();

    print('Stopping server...');
    await flutterServer.stop();
    print('✓ Server stopped');
  } catch (e) {
    print('Error: $e');
  }

  print('\n${'-' * 50}');
  print('Flutter Runtime MCP Features:');
  print('${'-' * 50}');
  print('''
Instance Management:
  • flutterStart - Start a Flutter app with flutter run command
    - Returns UUID for instance tracking
    - Parses output to extract VM Service URI
    - Tracks device ID and running status

  • flutterReload - Hot reload a running instance
    - Specify hot reload (true) or hot restart (false)
    - Uses instance UUID for targeting

  • flutterRestart - Hot restart (full restart) an instance
    - Convenience wrapper for hot restart
    - Uses instance UUID for targeting

  • flutterStop - Stop a running Flutter instance
    - Graceful shutdown with fallback to force kill
    - Automatic cleanup of instance tracking

  • flutterList - List all running Flutter instances
    - Shows status, start time, directory, command
    - Displays VM Service URI and device ID if available

  • flutterGetInfo - Get detailed info about specific instance
    - Returns complete instance state
    - Includes VM Service URI for debugging

Usage Example (via MCP):
  1. Start instance:
     flutterStart(command: "flutter run -d chrome", workingDirectory: "/path/to/app")
     → Returns UUID: "550e8400-e29b-41d4-a716-446655440000"

  2. Hot reload:
     flutterReload(instanceId: "550e8400-e29b-41d4-a716-446655440000", hot: true)

  3. Hot restart:
     flutterRestart(instanceId: "550e8400-e29b-41d4-a716-446655440000")

  4. List instances:
     flutterList()

  5. Get info:
     flutterGetInfo(instanceId: "550e8400-e29b-41d4-a716-446655440000")

  6. Stop instance:
     flutterStop(instanceId: "550e8400-e29b-41d4-a716-446655440000")

Implementation Details:
  • Command parsing handles quoted arguments
  • Process stdout/stderr streaming for monitoring
  • Automatic VM Service URI extraction from flutter run output
  • Graceful shutdown with timeout and force-kill fallback
  • Process exit code tracking and auto-cleanup
  • Multiple concurrent instances supported via UUID tracking
''');
}
