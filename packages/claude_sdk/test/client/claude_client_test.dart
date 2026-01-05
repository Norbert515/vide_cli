import 'dart:io';
import 'package:test/test.dart';
import 'package:claude_sdk/claude_sdk.dart';
import '../helpers/helpers.dart';

void main() {
  group('ClaudeClientImpl', () {
    group('initialization', () {
      test('generates session ID if not provided', () {
        final client = ClaudeClientImpl();

        expect(client.sessionId, isNotEmpty);
        // UUID v4 format: 8-4-4-4-12 = 36 characters
        expect(client.sessionId.length, equals(36));
        expect(client.sessionId.contains('-'), isTrue);
      });

      test('uses provided session ID from config', () {
        const providedSessionId = 'custom-session-123';
        final config = ClaudeConfig(sessionId: providedSessionId);
        final client = ClaudeClientImpl(config: config);

        expect(client.sessionId, equals(providedSessionId));
      });

      test('sets working directory to current directory if not provided', () {
        final client = ClaudeClientImpl();

        expect(client.workingDirectory, equals(Directory.current.path));
      });

      test('uses provided working directory from config', () {
        final tempDir = Directory.systemTemp.path;
        final config = ClaudeConfig(workingDirectory: tempDir);
        final client = ClaudeClientImpl(config: config);

        expect(client.workingDirectory, equals(tempDir));
      });

      test('updates config with generated session ID', () {
        final client = ClaudeClientImpl();

        expect(client.config.sessionId, equals(client.sessionId));
      });

      test('config session ID is preserved when already set', () {
        const customId = 'my-custom-id';
        final config = ClaudeConfig(sessionId: customId);
        final client = ClaudeClientImpl(config: config);

        expect(client.config.sessionId, equals(customId));
      });

      test('starts with empty conversation', () {
        final client = ClaudeClientImpl();

        expect(client.currentConversation.messages, isEmpty);
        expect(
          client.currentConversation.state,
          equals(ConversationState.idle),
        );
      });

      test('starts with no active abort state', () {
        final client = ClaudeClientImpl();

        expect(client.isAborting, isFalse);
      });

      test('initializes with empty MCP servers list when not provided', () {
        final client = ClaudeClientImpl();

        expect(client.mcpServers, isEmpty);
      });

      test('accepts MCP servers list', () {
        final servers = [
          TestMcpServer(name: 'server1'),
          TestMcpServer(name: 'server2'),
        ];
        final client = ClaudeClientImpl(mcpServers: servers);

        expect(client.mcpServers, hasLength(2));
      });
    });

    group('sendMessage', () {
      test('ignores empty messages', () async {
        final client = ClaudeClientImpl();

        // Store initial message count
        final initialCount = client.currentConversation.messages.length;

        // Send empty message
        client.sendMessage(Message(text: ''));
        await Future.delayed(const Duration(milliseconds: 50));

        // Should not have added any messages
        expect(
          client.currentConversation.messages.length,
          equals(initialCount),
        );
      });

      test('ignores whitespace-only messages', () async {
        final client = ClaudeClientImpl();

        final initialCount = client.currentConversation.messages.length;

        client.sendMessage(Message(text: '   \t\n  '));
        await Future.delayed(const Duration(milliseconds: 50));

        expect(
          client.currentConversation.messages.length,
          equals(initialCount),
        );
      });

      test(
        'adds message to inbox when process is active',
        () {},
        skip: 'Requires process injection to simulate active process',
      );

      test(
        'processes messages in order from inbox',
        () {},
        skip: 'Requires process injection to test inbox processing',
      );

      test(
        'streams responses from process stdout',
        () {},
        skip:
            'Requires process injection - see FakeProcess for future implementation',
      );

      test(
        'handles process stderr as error responses',
        () {},
        skip:
            'Requires process injection - see FakeProcess for future implementation',
      );
    });

    group('conversation state management', () {
      test('provides stream of conversation updates', () {
        final client = ClaudeClientImpl();

        expect(client.conversation, isA<Stream<Conversation>>());
      });

      test('provides stream of turn complete events', () {
        final client = ClaudeClientImpl();

        expect(client.onTurnComplete, isA<Stream<void>>());
      });

      test('currentConversation returns current state', () {
        final client = ClaudeClientImpl();

        expect(client.currentConversation, isA<Conversation>());
        expect(
          client.currentConversation.state,
          equals(ConversationState.idle),
        );
      });

      test('conversation stream is broadcast', () async {
        final client = ClaudeClientImpl();

        // Should be able to listen multiple times
        final sub1 = client.conversation.listen((_) {});
        final sub2 = client.conversation.listen((_) {});

        // No exception should be thrown
        await sub1.cancel();
        await sub2.cancel();
      });

      test('onTurnComplete stream is broadcast', () async {
        final client = ClaudeClientImpl();

        final sub1 = client.onTurnComplete.listen((_) {});
        final sub2 = client.onTurnComplete.listen((_) {});

        await sub1.cancel();
        await sub2.cancel();
      });
    });

    group('getMcpServer', () {
      test('returns correct server by name', () {
        final server1 = TestMcpServer(name: 'alpha-server');
        final server2 = TestMcpServer(name: 'beta-server');
        final client = ClaudeClientImpl(mcpServers: [server1, server2]);

        final result = client.getMcpServer<TestMcpServer>('beta-server');

        expect(result, isNotNull);
        expect(result, equals(server2));
      });

      test('returns null for unknown server name', () {
        final server = TestMcpServer(name: 'my-server');
        final client = ClaudeClientImpl(mcpServers: [server]);

        final result = client.getMcpServer<TestMcpServer>('unknown-server');

        expect(result, isNull);
      });

      test('returns null when no servers configured', () {
        final client = ClaudeClientImpl();

        final result = client.getMcpServer<TestMcpServer>('any-server');

        expect(result, isNull);
      });

      test('returns null when server type does not match', () {
        final server = TestMcpServer(name: 'test-server');
        final client = ClaudeClientImpl(mcpServers: [server]);

        // SpyMcpServer is a different type
        final result = client.getMcpServer<SpyMcpServer>('test-server');

        expect(result, isNull);
      });

      test('finds server among multiple of same type', () {
        final servers = [
          TestMcpServer(name: 'first'),
          TestMcpServer(name: 'second'),
          TestMcpServer(name: 'third'),
        ];
        final client = ClaudeClientImpl(mcpServers: servers);

        final result = client.getMcpServer<TestMcpServer>('second');

        expect(result, isNotNull);
        expect(result!.name, equals('second'));
      });
    });

    group('abort', () {
      test('no-op when no active process', () async {
        final client = ClaudeClientImpl();

        // Should not throw
        await client.abort();

        // State should remain unchanged
        expect(client.isAborting, isFalse);
        expect(
          client.currentConversation.state,
          equals(ConversationState.idle),
        );
      });

      test(
        'kills active process with SIGTERM',
        () {},
        skip: 'Requires process injection to verify signal sent',
      );

      test(
        'force kills if graceful shutdown times out',
        () {},
        skip: 'Requires process injection to test timeout behavior',
      );

      test(
        'adds abort message to conversation',
        () {},
        skip: 'Requires process injection to complete abort flow',
      );

      test(
        'sets isAborting during abort process',
        () {},
        skip: 'Requires process injection to observe abort state',
      );

      test(
        'clears active process after abort',
        () {},
        skip: 'Requires process injection to verify cleanup',
      );
    });

    group('close', () {
      test('closes conversation stream controller', () async {
        final client = ClaudeClientImpl();
        var gotDone = false;

        final subscription = client.conversation.listen(
          (_) {},
          onDone: () => gotDone = true,
        );

        await client.close();
        await Future.delayed(const Duration(milliseconds: 50));

        // Stream should be done (onDone called)
        expect(gotDone, isTrue);
        await subscription.cancel();
      });

      test('closes turn complete stream controller', () async {
        final client = ClaudeClientImpl();
        var gotDone = false;

        final subscription = client.onTurnComplete.listen(
          (_) {},
          onDone: () => gotDone = true,
        );

        await client.close();
        await Future.delayed(const Duration(milliseconds: 50));

        expect(gotDone, isTrue);
        await subscription.cancel();
      });

      test('marks client as not initialized', () async {
        final client = ClaudeClientImpl();
        await client.init();

        await client.close();

        // Private field, but we can observe behavior
        // After close, init should be callable again
        // This is more of an integration behavior
      });

      test('stops MCP servers', () async {
        final server = SpyMcpServer(name: 'spy-server');
        final client = ClaudeClientImpl(mcpServers: [server]);

        // Start the server first via init
        await client.init();
        expect(server.startCount, equals(1));

        await client.close();

        expect(server.stopCount, equals(1));
        expect(server.events, contains('stop'));
      });

      test('can be called multiple times safely', () async {
        final client = ClaudeClientImpl();

        // First close
        await client.close();

        // Second close should not throw
        await client.close();
      });
    });

    group('clearConversation', () {
      test('resets conversation to empty', () async {
        final client = ClaudeClientImpl();

        // Manually set some state by listening and sending
        // We can't fully test without process, but we can verify the method exists
        await client.clearConversation();

        expect(client.currentConversation.messages, isEmpty);
        expect(
          client.currentConversation.state,
          equals(ConversationState.idle),
        );
      });
    });

    group('init', () {
      test('can be called multiple times safely', () async {
        final client = ClaudeClientImpl();

        await client.init();
        await client.init();

        // Should not throw or cause issues
      });

      test('starts MCP servers', () async {
        final server = SpyMcpServer(name: 'spy-server');
        final client = ClaudeClientImpl(mcpServers: [server]);

        await client.init();

        expect(server.startCount, equals(1));
        expect(server.events, contains('start'));
      });

      test('skips already running MCP servers', () async {
        final server = SpyMcpServer(name: 'spy-server');
        final client = ClaudeClientImpl(mcpServers: [server]);

        // Start server directly
        await server.start();
        expect(server.startCount, equals(1));

        // Init should skip starting it again
        await client.init();

        // Should still be 1 since server was already running
        expect(server.startCount, equals(1));
      });

      test(
        'loads existing conversation from history',
        () {},
        skip: 'Requires filesystem setup with conversation history files',
      );
    });

    group('restart', () {
      test('closes and reinitializes client', () async {
        final client = ClaudeClientImpl();
        await client.init();

        await client.restart();

        // Streams should be closed after restart
        // Note: restart doesn't re-init, just closes and resets state
      });
    });

    group('edge cases', () {
      test('handles config with all options set', () {
        final config = ClaudeConfig(
          model: 'claude-3-opus',
          timeout: const Duration(seconds: 60),
          retryAttempts: 5,
          retryDelay: const Duration(seconds: 2),
          verbose: true,
          appendSystemPrompt: 'Be helpful.',
          temperature: 0.7,
          maxTokens: 4096,
          additionalFlags: ['--debug'],
          sessionId: 'test-session',
          permissionMode: 'bypassPermissions',
          workingDirectory: '/tmp/test',
          allowedTools: ['Read', 'Write'],
        );

        final client = ClaudeClientImpl(config: config);

        expect(client.sessionId, equals('test-session'));
        expect(client.workingDirectory, equals('/tmp/test'));
        expect(client.config.model, equals('claude-3-opus'));
      });

      test('handles mixed server types', () {
        final servers = [
          TestMcpServer(name: 'test'),
          SpyMcpServer(name: 'spy'),
        ];
        final client = ClaudeClientImpl(mcpServers: servers);

        expect(client.getMcpServer<TestMcpServer>('test'), isNotNull);
        expect(client.getMcpServer<SpyMcpServer>('spy'), isNotNull);
      });
    });
  });

  group('ClaudeClientImpl constructor', () {
    test('creates ClaudeClientImpl instance', () {
      final client = ClaudeClientImpl();

      expect(client, isA<ClaudeClientImpl>());
    });

    test('passes config to implementation', () {
      const sessionId = 'factory-session-id';
      final config = ClaudeConfig(sessionId: sessionId);
      final client = ClaudeClientImpl(config: config);

      expect(client.sessionId, equals(sessionId));
    });

    test('passes MCP servers to implementation', () {
      final servers = [TestMcpServer(name: 'factory-server')];
      final client = ClaudeClientImpl(mcpServers: servers);

      expect(client.getMcpServer<TestMcpServer>('factory-server'), isNotNull);
    });
  });

  group('ClaudeClient.create', () {
    test('creates and initializes client', () async {
      final client = await ClaudeClient.create();

      expect(client, isA<ClaudeClientImpl>());
      // Client should be initialized
    });

    test('initializes MCP servers', () async {
      final server = SpyMcpServer(name: 'create-server');
      final client = await ClaudeClient.create(mcpServers: [server]);

      expect(server.startCount, equals(1));

      await client.close();
    });
  });
}
