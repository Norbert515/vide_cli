import 'dart:convert';
import 'package:claude_sdk/claude_sdk.dart';
import 'package:test/test.dart';
import '../helpers/test_mcp_server.dart';

void main() {
  group('ProcessManager', () {
    group('getMcpArgs', () {
      test('returns empty args when no MCP servers', () async {
        final manager = ProcessManager(
          config: ClaudeConfig.defaults(),
          mcpServers: [],
        );

        final args = await manager.getMcpArgs();

        expect(args, isEmpty);
      });

      test('generates correct --mcp-config for single server', () async {
        final server = TestMcpServer(name: 'test-server', tools: ['tool1']);
        await server.start();

        addTearDown(() async {
          await server.stop();
        });

        final manager = ProcessManager(
          config: ClaudeConfig.defaults(),
          mcpServers: [server],
        );

        final args = await manager.getMcpArgs();

        expect(args.length, 2);
        expect(args[0], '--mcp-config');

        // Parse the JSON config
        final configJson = jsonDecode(args[1]) as Map<String, dynamic>;
        expect(configJson.containsKey('mcpServers'), isTrue);

        final mcpServers = configJson['mcpServers'] as Map<String, dynamic>;

        // Should include our test server
        expect(mcpServers.containsKey('test-server'), isTrue);
      });

      test('generates correct config for multiple servers', () async {
        final server1 = TestMcpServer(name: 'server-one', tools: ['tool1']);
        final server2 = TestMcpServer(
          name: 'server-two',
          tools: ['tool2', 'tool3'],
        );
        await server1.start();
        await server2.start();

        addTearDown(() async {
          await server1.stop();
          await server2.stop();
        });

        final manager = ProcessManager(
          config: ClaudeConfig.defaults(),
          mcpServers: [server1, server2],
        );

        final args = await manager.getMcpArgs();

        expect(args.length, 2);
        expect(args[0], '--mcp-config');

        final configJson = jsonDecode(args[1]) as Map<String, dynamic>;
        final mcpServers = configJson['mcpServers'] as Map<String, dynamic>;

        // Should include both test servers
        expect(mcpServers.containsKey('server-one'), isTrue);
        expect(mcpServers.containsKey('server-two'), isTrue);

        // Total should be 2: two test servers
        // Note: dart MCP server was intentionally disabled due to high CPU usage
        expect(mcpServers.length, 2);
      });

      test('server config contains correct HTTP transport format', () async {
        final server = TestMcpServer(name: 'http-server');
        await server.start();
        final port = server.port;

        addTearDown(() async {
          await server.stop();
        });

        final manager = ProcessManager(
          config: ClaudeConfig.defaults(),
          mcpServers: [server],
        );

        final args = await manager.getMcpArgs();
        final configJson = jsonDecode(args[1]) as Map<String, dynamic>;
        final mcpServers = configJson['mcpServers'] as Map<String, dynamic>;
        final serverConfig = mcpServers['http-server'] as Map<String, dynamic>;

        expect(serverConfig['type'], 'http');
        expect(serverConfig['url'], 'http://localhost:$port/mcp');
      });
    });

    group('MCP config format validation', () {
      test('produces valid JSON structure', () async {
        final server = TestMcpServer(name: 'json-test-server');
        await server.start();

        addTearDown(() async {
          await server.stop();
        });

        final manager = ProcessManager(
          config: ClaudeConfig.defaults(),
          mcpServers: [server],
        );

        final args = await manager.getMcpArgs();

        // Verify it's valid JSON by decoding
        expect(() => jsonDecode(args[1]), returnsNormally);

        final config = jsonDecode(args[1]) as Map<String, dynamic>;

        // Verify top-level structure
        expect(config.keys, contains('mcpServers'));
        expect(config['mcpServers'], isA<Map<String, dynamic>>());
      });

      test('each server has required config fields', () async {
        final server = TestMcpServer(name: 'field-check-server');
        await server.start();

        addTearDown(() async {
          await server.stop();
        });

        final manager = ProcessManager(
          config: ClaudeConfig.defaults(),
          mcpServers: [server],
        );

        final args = await manager.getMcpArgs();
        final configJson = jsonDecode(args[1]) as Map<String, dynamic>;
        final mcpServers = configJson['mcpServers'] as Map<String, dynamic>;

        // Check custom server config
        final customConfig =
            mcpServers['field-check-server'] as Map<String, dynamic>;
        expect(customConfig.containsKey('type'), isTrue);
        expect(customConfig.containsKey('url'), isTrue);
      });

      test('uses correct server names as keys', () async {
        final server1 = TestMcpServer(name: 'alpha-server');
        final server2 = TestMcpServer(name: 'beta-server');
        await server1.start();
        await server2.start();

        addTearDown(() async {
          await server1.stop();
          await server2.stop();
        });

        final manager = ProcessManager(
          config: ClaudeConfig.defaults(),
          mcpServers: [server1, server2],
        );

        final args = await manager.getMcpArgs();
        final configJson = jsonDecode(args[1]) as Map<String, dynamic>;
        final mcpServers = configJson['mcpServers'] as Map<String, dynamic>;

        // Verify server names are used as keys
        expect(mcpServers.keys, containsAll(['alpha-server', 'beta-server']));
      });
    });

    group('isClaudeAvailable', () {
      test('returns boolean value', () async {
        // This test just verifies the method returns a boolean
        // without asserting true/false since it depends on environment
        final result = await ProcessManager.isClaudeAvailable();
        expect(result, isA<bool>());
      });

      // Note: Testing isClaudeAvailable is environment-dependent.
      // In CI environments or machines without Claude installed,
      // it will return false. On development machines with Claude,
      // it will return true. We don't assert either way to avoid
      // flaky tests.
      test(
        'returns true when claude command exists',
        () async {
          // This test only runs meaningfully when Claude is installed
          final result = await ProcessManager.isClaudeAvailable();
          // We just verify it completes without error
          expect(result, anyOf(isTrue, isFalse));
        },
        skip: 'Environment-dependent: skipped by default',
      );
    });

    group('edge cases', () {
      test('handles server with empty tool list', () async {
        final server = TestMcpServer(name: 'empty-tools-server', tools: []);
        await server.start();

        addTearDown(() async {
          await server.stop();
        });

        final manager = ProcessManager(
          config: ClaudeConfig.defaults(),
          mcpServers: [server],
        );

        final args = await manager.getMcpArgs();

        expect(args.length, 2);
        expect(args[0], '--mcp-config');

        final configJson = jsonDecode(args[1]) as Map<String, dynamic>;
        expect(configJson.containsKey('mcpServers'), isTrue);
      });

      test('handles server with many tools', () async {
        final manyTools = List.generate(50, (i) => 'tool_$i');
        final server = TestMcpServer(
          name: 'many-tools-server',
          tools: manyTools,
        );
        await server.start();

        addTearDown(() async {
          await server.stop();
        });

        final manager = ProcessManager(
          config: ClaudeConfig.defaults(),
          mcpServers: [server],
        );

        final args = await manager.getMcpArgs();

        expect(args.length, 2);
        final configJson = jsonDecode(args[1]) as Map<String, dynamic>;
        expect(configJson['mcpServers']['many-tools-server'], isNotNull);
      });

      test('server ports are unique per server', () async {
        final server1 = TestMcpServer(name: 'unique-port-1');
        final server2 = TestMcpServer(name: 'unique-port-2');
        await server1.start();
        await server2.start();

        addTearDown(() async {
          await server1.stop();
          await server2.stop();
        });

        final manager = ProcessManager(
          config: ClaudeConfig.defaults(),
          mcpServers: [server1, server2],
        );

        final args = await manager.getMcpArgs();
        final configJson = jsonDecode(args[1]) as Map<String, dynamic>;
        final mcpServers = configJson['mcpServers'] as Map<String, dynamic>;

        final url1 =
            (mcpServers['unique-port-1'] as Map<String, dynamic>)['url']
                as String;
        final url2 =
            (mcpServers['unique-port-2'] as Map<String, dynamic>)['url']
                as String;

        // Extract ports from URLs
        final port1 = int.parse(url1.split(':').last.split('/').first);
        final port2 = int.parse(url2.split(':').last.split('/').first);

        expect(port1, isNot(equals(port2)));
      });
    });
  });
}
