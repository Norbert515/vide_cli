import 'package:flutter_runtime_mcp/flutter_runtime_mcp.dart';
import 'package:mcp_dart/mcp_dart.dart';

void main() async {
  final flutterRuntime = FlutterRuntimeServer();

  final mcpServer = McpServer(
    Implementation(name: FlutterRuntimeServer.serverName, version: '1.0.0'),
    options: ServerOptions(
      capabilities: ServerCapabilities(tools: ServerCapabilitiesTools()),
    ),
  );

  flutterRuntime.registerTools(mcpServer);

  final transport = StdioServerTransport();
  await mcpServer.connect(transport);
}
