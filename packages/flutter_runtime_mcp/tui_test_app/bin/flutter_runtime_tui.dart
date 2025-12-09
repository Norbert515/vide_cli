import 'package:nocterm/nocterm.dart';
import 'package:flutter_runtime_mcp/flutter_runtime_mcp.dart';
import 'package:flutter_runtime_tui/app.dart';

/// Entry point for Flutter Runtime TUI application
Future<void> main(List<String> arguments) async {
  // Create and start the Flutter Runtime MCP server
  final server = FlutterRuntimeServer();

  await server.start();

  // Run the Nocterm TUI app
  await runApp(FlutterRuntimeApp(server: server));
}
