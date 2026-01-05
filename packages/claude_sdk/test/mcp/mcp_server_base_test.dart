import 'package:claude_sdk/src/mcp/utils/port_manager.dart';
import 'package:test/test.dart';

import '../helpers/test_mcp_server.dart';

void main() {
  group('McpServerBase', () {
    group('start', () {
      test('binds to assigned port', () async {
        final server = TestMcpServer();
        addTearDown(() => server.stop());

        await server.start();

        final port = server.port;
        expect(port, greaterThanOrEqualTo(PortManager.startPort));
        expect(port, lessThanOrEqualTo(PortManager.endPort));

        // Verify the port is actually bound
        final isAvailable = await PortManager.isPortAvailable(port);
        expect(isAvailable, isFalse);
      });

      test('uses provided port when specified', () async {
        // Find an available port first
        final availablePort = await PortManager.findAvailablePort();
        PortManager.releasePort(availablePort);

        final server = TestMcpServer();
        addTearDown(() => server.stop());

        await server.start(port: availablePort);

        expect(server.port, equals(availablePort));
      });

      test('sets isRunning to true', () async {
        final server = TestMcpServer();
        addTearDown(() => server.stop());

        expect(server.isRunning, isFalse);

        await server.start();

        expect(server.isRunning, isTrue);
      });

      test('calls onStart lifecycle hook', () async {
        final server = TestMcpServer();
        addTearDown(() => server.stop());

        expect(server.onStartCalled, isFalse);

        await server.start();

        expect(server.onStartCalled, isTrue);
      });

      test('throws on second start call', () async {
        final server = TestMcpServer();
        addTearDown(() => server.stop());

        await server.start();

        expect(() => server.start(), throwsA(isA<StateError>()));
      });
    });

    group('stop', () {
      test('closes HTTP server', () async {
        final server = TestMcpServer();

        await server.start();
        final port = server.port;

        await server.stop();

        // Port should now be available again
        final isAvailable = await PortManager.isPortAvailable(port);
        expect(isAvailable, isTrue);
      });

      test('sets isRunning to false', () async {
        final server = TestMcpServer();

        await server.start();
        expect(server.isRunning, isTrue);

        await server.stop();
        expect(server.isRunning, isFalse);
      });

      test('calls onStop lifecycle hook', () async {
        final server = TestMcpServer();

        await server.start();
        expect(server.onStopCalled, isFalse);

        await server.stop();
        expect(server.onStopCalled, isTrue);
      });

      test('stop without start is safe', () async {
        final server = TestMcpServer();

        // Should not throw
        await server.stop();

        expect(server.onStopCalled, isTrue);
        expect(server.isRunning, isFalse);
      });
    });

    group('toClaudeConfig', () {
      test('returns correct HTTP transport config', () async {
        final server = TestMcpServer();
        addTearDown(() => server.stop());

        await server.start();

        final config = server.toClaudeConfig();

        expect(config['type'], equals('http'));
        expect(config['url'], contains('/mcp'));
      });

      test('includes correct port', () async {
        final server = TestMcpServer();
        addTearDown(() => server.stop());

        await server.start();

        final config = server.toClaudeConfig();
        final url = config['url'] as String;

        expect(url, contains(':${server.port}'));
      });
    });

    group('properties', () {
      test('name returns server name', () {
        final server = TestMcpServer(name: 'my-server');

        expect(server.name, equals('my-server'));
      });

      test('version returns server version', () {
        final server = TestMcpServer();

        expect(server.version, equals('1.0.0'));
      });

      test('toolNames returns registered tools', () {
        final server = TestMcpServer(tools: ['tool1', 'tool2', 'tool3']);

        expect(server.toolNames, equals(['tool1', 'tool2', 'tool3']));
      });
    });

    group('SpyMcpServer', () {
      test('tracks start count', () async {
        final server = SpyMcpServer();
        addTearDown(() => server.stop());

        expect(server.startCount, equals(0));

        await server.start();

        expect(server.startCount, equals(1));
      });

      test('tracks stop count', () async {
        final server = SpyMcpServer();

        await server.start();
        expect(server.stopCount, equals(0));

        await server.stop();

        expect(server.stopCount, equals(1));
      });

      test('records lifecycle events in order', () async {
        final server = SpyMcpServer();

        expect(server.events, isEmpty);

        await server.start();
        await server.stop();

        expect(server.events, equals(['start', 'stop']));
      });
    });

    group('stateStream', () {
      test('emits running state on start', () async {
        final server = TestMcpServer();
        addTearDown(() => server.stop());

        final states = <dynamic>[];
        server.stateStream.listen((state) => states.add(state.name));

        await server.start();

        // Give stream time to emit
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(states, contains('running'));
      });

      test('emits stopped state on stop', () async {
        final server = TestMcpServer();

        final states = <dynamic>[];
        server.stateStream.listen((state) => states.add(state.name));

        await server.start();
        await server.stop();

        // Give stream time to emit
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(states, contains('stopped'));
      });
    });
  });
}
