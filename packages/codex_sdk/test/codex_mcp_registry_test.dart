import 'package:claude_sdk/claude_sdk.dart';
import 'package:codex_sdk/codex_sdk.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:test/test.dart';

class FakeMcpServer extends McpServerBase {
  final bool _fakeIsRunning;
  final String _fakeUrl;

  FakeMcpServer({
    required super.name,
    super.version = '0.0.1',
    bool isRunning = true,
    String url = 'http://localhost:1234/mcp',
  }) : _fakeIsRunning = isRunning,
       _fakeUrl = url;

  @override
  bool get isRunning => _fakeIsRunning;

  @override
  Map<String, dynamic> toClaudeConfig() => {'url': _fakeUrl};

  @override
  void registerTools(McpServer server) {}

  @override
  Future<void> start({int? port}) async {}

  @override
  Future<void> stop() async {}
}

void main() {
  group('CodexMcpRegistry.buildArgs', () {
    test('returns empty list when mcpServers is empty', () {
      final args = CodexMcpRegistry.buildArgs(mcpServers: []);
      expect(args, isEmpty);
    });

    test('builds -c args for running servers', () {
      final server = FakeMcpServer(
        name: 'test-server',
        url: 'http://localhost:5678/mcp',
      );

      final args = CodexMcpRegistry.buildArgs(mcpServers: [server]);

      expect(args, [
        '-c',
        'mcp_servers.test_server.url="http://localhost:5678/mcp"',
      ]);
    });

    test('skips non-running servers', () {
      final running = FakeMcpServer(
        name: 'running',
        url: 'http://localhost:1111/mcp',
      );
      final stopped = FakeMcpServer(
        name: 'stopped',
        isRunning: false,
        url: 'http://localhost:2222/mcp',
      );

      final args = CodexMcpRegistry.buildArgs(
        mcpServers: [running, stopped],
      );

      expect(args, [
        '-c',
        'mcp_servers.running.url="http://localhost:1111/mcp"',
      ]);
    });

    test('builds args for multiple servers', () {
      final servers = [
        FakeMcpServer(name: 'alpha', url: 'http://localhost:1001/mcp'),
        FakeMcpServer(name: 'beta', url: 'http://localhost:1002/mcp'),
      ];

      final args = CodexMcpRegistry.buildArgs(mcpServers: servers);

      expect(args, [
        '-c',
        'mcp_servers.alpha.url="http://localhost:1001/mcp"',
        '-c',
        'mcp_servers.beta.url="http://localhost:1002/mcp"',
      ]);
    });

    test('sanitizes server name with special characters', () {
      final server = FakeMcpServer(
        name: 'my-server.v2!',
        url: 'http://localhost:9999/mcp',
      );

      final args = CodexMcpRegistry.buildArgs(mcpServers: [server]);

      expect(args, [
        '-c',
        'mcp_servers.my_server_v2_.url="http://localhost:9999/mcp"',
      ]);
    });
  });
}
