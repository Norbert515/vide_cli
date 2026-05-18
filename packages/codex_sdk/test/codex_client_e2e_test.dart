@Tags(['e2e'])
import 'dart:io';

import 'package:claude_sdk/claude_sdk.dart';
import 'package:codex_sdk/codex_sdk.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:test/test.dart';

/// A real MCP server that starts an HTTP endpoint with a single test tool.
class TestMcpServer extends McpServerBase {
  int callCount = 0;

  TestMcpServer() : super(name: 'test-mcp', version: '1.0.0');

  @override
  void registerTools(McpServer server) {
    server.tool(
      'ping',
      description: 'Returns "pong". Use this tool when asked to ping.',
      toolInputSchema: ToolInputSchema(properties: {}, required: []),
      callback: ({args, extra}) async {
        callCount++;
        return CallToolResult.fromContent(
          content: [TextContent(text: 'pong')],
        );
      },
    );
  }

  @override
  List<String> get toolNames => ['ping'];
}

/// E2E tests for [CodexClient] using a real `codex app-server` subprocess.
///
/// Tests the full init sequence: subprocess start → handshake → thread/start →
/// MCP startup wait → ready state.
///
/// Requires:
/// - `codex` CLI installed and on PATH
/// - A git repository as working directory
///
/// Run with: `dart test --tags e2e`
void main() {
  late Directory tempDir;
  final logs = <String>[];

  void log(String level, String component, String message) {
    logs.add('[$level] $component: $message');
  }

  setUpAll(() {
    final result = Process.runSync('which', ['codex']);
    if (result.exitCode != 0) {
      fail('codex CLI not found on PATH — skipping e2e tests');
    }
  });

  setUp(() async {
    logs.clear();
    tempDir = await Directory.systemTemp.createTemp('codex_client_e2e_');

    // codex requires a git repo
    await Process.run('git', ['init'], workingDirectory: tempDir.path);
    await Process.run('git', [
      'commit',
      '--allow-empty',
      '-m',
      'init',
    ], workingDirectory: tempDir.path);
  });

  tearDown(() async {
    // Small delay to let any dangling async handlers settle
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('init lifecycle (no API key needed)', () {
    late CodexClient client;

    setUp(() {
      client = CodexClient(
        codexConfig: CodexConfig(
          workingDirectory: tempDir.path,
          sessionId: 'e2e-test-session',
          approvalPolicy: 'never',
        ),
        log: log,
      );
    });

    tearDown(() async {
      await client.close();
    });

    test(
      'full init sequence completes successfully',
      () async {
        await client.init();

        expect(client.sessionId, 'e2e-test-session');
        expect(client.workingDirectory, tempDir.path);
        expect(client.threadId, isNotNull);
        expect(client.threadId, isNotEmpty);
        expect(client.currentStatus, ClaudeStatus.ready);
        expect(client.currentConversation.messages, isEmpty);

        // Verify logging captured key steps
        expect(
          logs.where((l) => l.contains('Initializing CodexClient')),
          isNotEmpty,
        );
        expect(logs.where((l) => l.contains('Handshake complete')), isNotEmpty);
        expect(logs.where((l) => l.contains('Thread started')), isNotEmpty);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'initialized future completes after init',
      () async {
        await client.init();

        // Should already be completed — calling again returns immediately
        await client.initialized;
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'close after init shuts down cleanly',
      () async {
        await client.init();

        await client.close();

        expect(
          logs.where((l) => l.contains('Closing CodexClient')),
          isNotEmpty,
        );
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'clearConversation starts a new thread',
      () async {
        await client.init();

        final firstThreadId = client.threadId;
        expect(firstThreadId, isNotNull);

        await client.clearConversation();

        final secondThreadId = client.threadId;
        expect(secondThreadId, isNotNull);
        expect(secondThreadId, isNot(equals(firstThreadId)));
        expect(client.currentConversation.messages, isEmpty);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'abort on idle client is a no-op',
      () async {
        await client.init();

        // Should not throw
        await client.abort();

        expect(client.currentStatus, ClaudeStatus.ready);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test('message queued before init shows optimistically', () async {
      // Send message before init — should be queued
      client.sendMessage(const Message(text: 'queued message'));

      // Conversation should show the user message optimistically
      expect(client.currentConversation.messages.length, 1);
      expect(client.currentConversation.messages.first.role, MessageRole.user);
      expect(client.currentStatus, ClaudeStatus.processing);

      expect(
        logs.where((l) => l.contains('Queuing message (not initialized)')),
        isNotEmpty,
      );
    });

    test(
      'message after close is silently ignored',
      () async {
        await client.init();
        await client.close();

        // Should not throw
        client.sendMessage(const Message(text: 'should be ignored'));

        expect(logs.where((l) => l.contains('Ignoring message')), isNotEmpty);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });

  group('MCP server discovery via -c args (no API key needed)', () {
    late CodexClient client;
    late TestMcpServer mcpServer;

    setUp(() {
      mcpServer = TestMcpServer();
      client = CodexClient(
        codexConfig: CodexConfig(
          workingDirectory: tempDir.path,
          sessionId: 'e2e-mcp-test',
          approvalPolicy: 'never',
        ),
        mcpServers: [mcpServer],
        log: log,
      );
    });

    tearDown(() async {
      await client.close();
    });

    test(
      'init completes with MCP startup when server passed via -c args',
      () async {
        await client.init();

        // MCP startup must have completed — codex connected to our server
        expect(
          logs.where((l) => l.contains('MCP startup complete')),
          isNotEmpty,
          reason: 'codex should discover MCP server via -c CLI args',
        );

        expect(client.threadId, isNotNull);
        expect(client.currentStatus, ClaudeStatus.ready);
        expect(mcpServer.isRunning, isTrue);
      },
      timeout: const Timeout(Duration(seconds: 45)),
    );
  });

  group('MCP tool call round-trip (requires OPENAI_API_KEY)', () {
    late CodexClient client;
    late TestMcpServer mcpServer;

    setUp(() {
      if (!Platform.environment.containsKey('OPENAI_API_KEY')) return;

      mcpServer = TestMcpServer();
      client = CodexClient(
        codexConfig: CodexConfig(
          workingDirectory: tempDir.path,
          sessionId: 'e2e-mcp-tool-test',
          approvalPolicy: 'never',
        ),
        mcpServers: [mcpServer],
        log: log,
      );
    });

    tearDown(() async {
      if (Platform.environment.containsKey('OPENAI_API_KEY')) {
        await client.close();
      }
    });

    test(
      'codex calls MCP tool and receives result',
      () async {
        if (!Platform.environment.containsKey('OPENAI_API_KEY')) {
          markTestSkipped('OPENAI_API_KEY not set');
          return;
        }

        await client.init();

        final turnFuture = client.onTurnComplete.first;

        client.sendMessage(
          const Message(
            text: 'Call the "ping" MCP tool from the "test-mcp" server. '
                'Do not use any other tools. Just call ping and tell me the result.',
          ),
        );

        await turnFuture.timeout(
          const Duration(seconds: 60),
          onTimeout: () => fail('Turn did not complete within 60s'),
        );

        // The MCP server should have been called
        expect(
          mcpServer.callCount,
          greaterThan(0),
          reason: 'codex should have called the ping MCP tool',
        );
      },
      timeout: const Timeout(Duration(seconds: 90)),
    );
  });

  group('message round-trip (requires OPENAI_API_KEY)', () {
    late CodexClient client;

    setUp(() {
      if (!Platform.environment.containsKey('OPENAI_API_KEY')) {
        return;
      }

      client = CodexClient(
        codexConfig: CodexConfig(
          workingDirectory: tempDir.path,
          sessionId: 'e2e-message-test',
          approvalPolicy: 'never',
        ),
        log: log,
      );
    });

    tearDown(() async {
      if (Platform.environment.containsKey('OPENAI_API_KEY')) {
        await client.close();
      }
    });

    test(
      'sends message and receives streaming response',
      () async {
        if (!Platform.environment.containsKey('OPENAI_API_KEY')) {
          markTestSkipped('OPENAI_API_KEY not set');
          return;
        }

        await client.init();

        final turnFuture = client.onTurnComplete.first;
        final statuses = <ClaudeStatus>[];
        final sub = client.statusStream.listen(statuses.add);

        client.sendMessage(
          const Message(text: 'Respond with exactly: "hello from codex"'),
        );

        await turnFuture.timeout(
          const Duration(seconds: 60),
          onTimeout: () => fail('Turn did not complete within 60s'),
        );
        await sub.cancel();

        final conv = client.currentConversation;
        expect(conv.messages, isNotEmpty);

        // First message should be the user message
        expect(conv.messages.first.role, MessageRole.user);

        // Should have at least one assistant message
        final assistantMessages = conv.messages
            .where((m) => m.role == MessageRole.assistant)
            .toList();
        expect(assistantMessages, isNotEmpty);

        // Status should have gone through processing → ready
        expect(statuses, contains(ClaudeStatus.processing));
        expect(client.currentStatus, ClaudeStatus.ready);
      },
      timeout: const Timeout(Duration(seconds: 90)),
    );

    test(
      'multi-turn sends follow-up on same thread',
      () async {
        if (!Platform.environment.containsKey('OPENAI_API_KEY')) {
          markTestSkipped('OPENAI_API_KEY not set');
          return;
        }

        await client.init();
        final threadId = client.threadId;

        // Turn 1
        var turnFuture = client.onTurnComplete.first;
        client.sendMessage(
          const Message(
            text: 'Remember this number: 42. Just say "ok, remembered."',
          ),
        );
        await turnFuture.timeout(
          const Duration(seconds: 60),
          onTimeout: () => fail('Timed out on turn 1'),
        );

        // Turn 2
        turnFuture = client.onTurnComplete.first;
        client.sendMessage(
          const Message(
            text: 'What number did I tell you? Reply with just the number.',
          ),
        );
        await turnFuture.timeout(
          const Duration(seconds: 60),
          onTimeout: () => fail('Timed out on turn 2'),
        );

        // Same thread
        expect(client.threadId, equals(threadId));

        // Should have messages from both turns
        final userMessages = client.currentConversation.messages
            .where((m) => m.role == MessageRole.user)
            .toList();
        expect(userMessages.length, greaterThanOrEqualTo(2));
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );
  });
}
