import 'package:claude_sdk/claude_sdk.dart';
import 'package:mcp_dart/mcp_dart.dart';

/// Minimal MCP server for testing lifecycle and integration
class TestMcpServer extends McpServerBase {
  final List<String> _registeredTools;
  bool onStartCalled = false;
  bool onStopCalled = false;

  TestMcpServer({String name = 'test-server', List<String>? tools})
    : _registeredTools = tools ?? ['testTool'],
      super(name: name, version: '1.0.0');

  @override
  List<String> get toolNames => _registeredTools;

  @override
  void registerTools(McpServer server) {
    for (final toolName in _registeredTools) {
      server.tool(
        toolName,
        description: 'Test tool: $toolName',
        toolInputSchema: ToolInputSchema(properties: {}, required: []),
        callback: ({args, extra}) async =>
            CallToolResult.fromContent(content: [TextContent(text: 'OK')]),
      );
    }
  }

  @override
  Future<void> onStart() async {
    onStartCalled = true;
  }

  @override
  Future<void> onStop() async {
    onStopCalled = true;
  }
}

/// MCP server that tracks all lifecycle events
class SpyMcpServer extends McpServerBase {
  int startCount = 0;
  int stopCount = 0;
  final List<String> events = [];

  SpyMcpServer({String name = 'spy-server'})
    : super(name: name, version: '1.0.0');

  @override
  List<String> get toolNames => ['spyTool'];

  @override
  void registerTools(McpServer server) {
    server.tool(
      'spyTool',
      description: 'Spy tool',
      toolInputSchema: ToolInputSchema(properties: {}, required: []),
      callback: ({args, extra}) async =>
          CallToolResult.fromContent(content: [TextContent(text: 'spied')]),
    );
  }

  @override
  Future<void> onStart() async {
    startCount++;
    events.add('start');
  }

  @override
  Future<void> onStop() async {
    stopCount++;
    events.add('stop');
  }
}
