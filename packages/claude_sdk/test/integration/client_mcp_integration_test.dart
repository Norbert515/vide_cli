import 'package:claude_sdk/claude_sdk.dart';
import 'package:test/test.dart';
import '../helpers/helpers.dart';

void main() {
  group('Client + MCP Integration', () {
    test('client accepts MCP servers in constructor', () {
      final server = TestMcpServer(name: 'integration-test-server');

      final client = ClaudeClientImpl(
        config: ClaudeConfig.defaults(),
        mcpServers: [server],
      );

      expect(client, isNotNull);
    });

    test('client provides servers via getMcpServer with type', () async {
      final testServer = TestMcpServer(name: 'test-server');

      final client = ClaudeClientImpl(
        config: ClaudeConfig.defaults(),
        mcpServers: [testServer],
      );

      // Retrieve server by type and name
      final retrieved = client.getMcpServer<TestMcpServer>('test-server');
      expect(retrieved, isNotNull);
      expect(retrieved, same(testServer));
    });

    test('getMcpServer returns null for non-existent server', () {
      final testServer = TestMcpServer(name: 'existing-server');

      final client = ClaudeClientImpl(
        config: ClaudeConfig.defaults(),
        mcpServers: [testServer],
      );

      // Try to retrieve non-existent server
      final retrieved = client.getMcpServer<TestMcpServer>('non-existent');
      expect(retrieved, isNull);
    });

    test('getMcpServer returns null for wrong type', () {
      final testServer = TestMcpServer(name: 'test-server');

      final client = ClaudeClientImpl(
        config: ClaudeConfig.defaults(),
        mcpServers: [testServer],
      );

      // Try to retrieve with wrong type - SpyMcpServer instead of TestMcpServer
      final retrieved = client.getMcpServer<SpyMcpServer>('test-server');
      expect(retrieved, isNull);
    });

    test('multiple servers are all accessible', () {
      final server1 = TestMcpServer(name: 'server-one', tools: ['tool1']);
      final server2 = TestMcpServer(name: 'server-two', tools: ['tool2']);
      final server3 = SpyMcpServer(name: 'spy-server');

      final client = ClaudeClientImpl(
        config: ClaudeConfig.defaults(),
        mcpServers: [server1, server2, server3],
      );

      // All servers should be retrievable
      final retrieved1 = client.getMcpServer<TestMcpServer>('server-one');
      final retrieved2 = client.getMcpServer<TestMcpServer>('server-two');
      final retrieved3 = client.getMcpServer<SpyMcpServer>('spy-server');

      expect(retrieved1, same(server1));
      expect(retrieved2, same(server2));
      expect(retrieved3, same(server3));
    });

    test('server tool names are accessible', () {
      final server = TestMcpServer(
        name: 'tools-server',
        tools: ['Read', 'Write', 'Edit'],
      );

      expect(server.toolNames, hasLength(3));
      expect(server.toolNames, contains('Read'));
      expect(server.toolNames, contains('Write'));
      expect(server.toolNames, contains('Edit'));
    });

    test('client with empty MCP servers list is valid', () {
      final client = ClaudeClientImpl(
        config: ClaudeConfig.defaults(),
        mcpServers: [],
      );

      expect(client, isNotNull);
      final retrieved = client.getMcpServer<TestMcpServer>('any-server');
      expect(retrieved, isNull);
    });

    test('client without explicit MCP servers defaults to empty list', () {
      final client = ClaudeClientImpl(config: ClaudeConfig.defaults());

      expect(client, isNotNull);
      // Should handle missing servers gracefully
      final retrieved = client.getMcpServer<TestMcpServer>('any-server');
      expect(retrieved, isNull);
    });

    group('MCP Server Lifecycle', () {
      test('server tracks start/stop calls', () async {
        final spyServer = SpyMcpServer(name: 'lifecycle-server');

        expect(spyServer.startCount, equals(0));
        expect(spyServer.stopCount, equals(0));
        expect(spyServer.events, isEmpty);

        // Simulate lifecycle
        await spyServer.onStart();
        expect(spyServer.startCount, equals(1));
        expect(spyServer.events, equals(['start']));

        await spyServer.onStop();
        expect(spyServer.stopCount, equals(1));
        expect(spyServer.events, equals(['start', 'stop']));
      });

      test('server lifecycle callbacks are invoked', () async {
        final testServer = TestMcpServer(name: 'callback-server');

        expect(testServer.onStartCalled, isFalse);
        expect(testServer.onStopCalled, isFalse);

        await testServer.onStart();
        expect(testServer.onStartCalled, isTrue);

        await testServer.onStop();
        expect(testServer.onStopCalled, isTrue);
      });
    });
  });
}
