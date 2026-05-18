import 'package:claude_sdk/claude_sdk.dart';
import 'package:codex_sdk/codex_sdk.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:test/test.dart';

class FakeMcpServer extends McpServerBase {
  final bool _fakeIsRunning;

  FakeMcpServer({
    required super.name,
    super.version = '0.0.1',
    bool isRunning = true,
  }) : _fakeIsRunning = isRunning;

  @override
  bool get isRunning => _fakeIsRunning;

  @override
  Map<String, dynamic> toClaudeConfig() => {'url': 'http://localhost:0000/mcp'};

  @override
  void registerTools(McpServer server) {}

  @override
  Future<void> start({int? port}) async {}

  @override
  Future<void> stop() async {}
}

class SpecializedMcpServer extends FakeMcpServer {
  SpecializedMcpServer({required super.name});
}

void main() {
  group('CodexClient', () {
    group('constructor', () {
      test('uses provided sessionId', () {
        final client = CodexClient(
          codexConfig: const CodexConfig(
            sessionId: 'my-session',
            workingDirectory: '/tmp/test',
          ),
        );

        expect(client.sessionId, 'my-session');
      });

      test('generates sessionId when not provided', () {
        final client = CodexClient(
          codexConfig: const CodexConfig(workingDirectory: '/tmp/test'),
        );

        expect(client.sessionId, isNotEmpty);
      });

      test('uses provided workingDirectory', () {
        final client = CodexClient(
          codexConfig: const CodexConfig(workingDirectory: '/custom/dir'),
        );

        expect(client.workingDirectory, '/custom/dir');
      });
    });

    group('initial state', () {
      late CodexClient client;

      setUp(() {
        client = CodexClient(
          codexConfig: const CodexConfig(
            workingDirectory: '/tmp/test',
            sessionId: 'test-session',
          ),
        );
      });

      test('currentConversation is empty', () {
        expect(client.currentConversation.messages, isEmpty);
      });

      test('currentStatus is ready', () {
        expect(client.currentStatus, ClaudeStatus.ready);
      });

      test('initData is null', () {
        expect(client.initData, isNull);
      });

      test('currentQueuedMessage is null', () {
        expect(client.currentQueuedMessage, isNull);
      });

      test('threadId is null', () {
        expect(client.threadId, isNull);
      });
    });

    group('sendMessage', () {
      late CodexClient client;

      setUp(() {
        client = CodexClient(
          codexConfig: const CodexConfig(
            workingDirectory: '/tmp/test',
            sessionId: 'test-session',
          ),
        );
      });

      test('ignores empty text message', () async {
        final conversationUpdates = <Conversation>[];
        client.conversation.listen(conversationUpdates.add);

        client.sendMessage(const Message(text: '   '));

        await Future.delayed(Duration.zero);
        expect(conversationUpdates, isEmpty);
      });

      test('ignores whitespace-only message', () async {
        final conversationUpdates = <Conversation>[];
        client.conversation.listen(conversationUpdates.add);

        client.sendMessage(const Message(text: '\t\n  '));

        await Future.delayed(Duration.zero);
        expect(conversationUpdates, isEmpty);
      });
    });

    group('after close', () {
      late CodexClient client;

      setUp(() async {
        client = CodexClient(
          codexConfig: const CodexConfig(
            workingDirectory: '/tmp/test',
            sessionId: 'test-session',
          ),
        );
        await client.close();
      });

      test('sendMessage is silently ignored', () async {
        // Should not throw
        client.sendMessage(const Message(text: 'hello'));
      });
    });

    group('clearQueuedMessage', () {
      test('sets queued message to null', () async {
        final client = CodexClient(
          codexConfig: const CodexConfig(
            workingDirectory: '/tmp/test',
            sessionId: 'test-session',
          ),
        );

        String? lastQueued = 'initial';
        client.queuedMessage.listen((msg) => lastQueued = msg);

        client.clearQueuedMessage();

        await Future.delayed(Duration.zero);
        expect(client.currentQueuedMessage, isNull);
        expect(lastQueued, isNull);
      });
    });

    group('getMcpServer', () {
      test('returns server by name and type', () {
        final server = FakeMcpServer(name: 'my-server');
        final client = CodexClient(
          codexConfig: const CodexConfig(
            workingDirectory: '/tmp/test',
            sessionId: 'test-session',
          ),
          mcpServers: [server],
        );

        final result = client.getMcpServer<FakeMcpServer>('my-server');
        expect(result, same(server));
      });

      test('returns null for non-existent server', () {
        final client = CodexClient(
          codexConfig: const CodexConfig(
            workingDirectory: '/tmp/test',
            sessionId: 'test-session',
          ),
          mcpServers: [FakeMcpServer(name: 'other')],
        );

        final result = client.getMcpServer<FakeMcpServer>('nonexistent');
        expect(result, isNull);
      });

      test('returns null when type does not match', () {
        final client = CodexClient(
          codexConfig: const CodexConfig(
            workingDirectory: '/tmp/test',
            sessionId: 'test-session',
          ),
          mcpServers: [FakeMcpServer(name: 'generic')],
        );

        final result = client.getMcpServer<SpecializedMcpServer>('generic');
        expect(result, isNull);
      });

      test('returns specialized server as base type', () {
        final specialized = SpecializedMcpServer(name: 'special');
        final client = CodexClient(
          codexConfig: const CodexConfig(
            workingDirectory: '/tmp/test',
            sessionId: 'test-session',
          ),
          mcpServers: [specialized],
        );

        final result = client.getMcpServer<FakeMcpServer>('special');
        expect(result, same(specialized));
      });

      test('returns null when no mcpServers', () {
        final client = CodexClient(
          codexConfig: const CodexConfig(
            workingDirectory: '/tmp/test',
            sessionId: 'test-session',
          ),
        );

        final result = client.getMcpServer<FakeMcpServer>('any');
        expect(result, isNull);
      });
    });
  });
}
