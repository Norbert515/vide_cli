import 'package:agent_sdk/agent_sdk.dart';
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
  group('CodexAgentClient', () {
    late CodexClient inner;
    late CodexAgentClient client;

    setUp(() {
      inner = CodexClient(
        codexConfig: const CodexConfig(
          workingDirectory: '/tmp/test',
          sessionId: 'test-session',
        ),
      );
      client = CodexAgentClient(inner);
    });

    test('implements AgentClient', () {
      expect(client, isA<AgentClient>());
    });

    test('implements Interruptible', () {
      expect(client, isA<Interruptible>());
    });

    test('does not implement ModelConfigurable', () {
      expect(client, isNot(isA<ModelConfigurable>()));
    });

    test('does not implement PermissionModeConfigurable', () {
      expect(client, isNot(isA<PermissionModeConfigurable>()));
    });

    test('does not implement ThinkingConfigurable', () {
      expect(client, isNot(isA<ThinkingConfigurable>()));
    });

    test('does not implement FileRewindable', () {
      expect(client, isNot(isA<FileRewindable>()));
    });

    test('does not implement McpConfigurable', () {
      expect(client, isNot(isA<McpConfigurable>()));
    });

    test('exposes innerClient', () {
      expect(client.innerClient, same(inner));
    });

    test('sessionId delegates to inner', () {
      expect(client.sessionId, inner.sessionId);
    });

    test('workingDirectory delegates to inner', () {
      expect(client.workingDirectory, '/tmp/test');
    });

    test('currentConversation returns mapped empty conversation', () {
      final conversation = client.currentConversation;
      expect(conversation, isA<AgentConversation>());
      expect(conversation.messages, isEmpty);
    });

    test('currentStatus returns mapped ready status', () {
      expect(client.currentStatus, AgentProcessingStatus.ready);
    });

    test('initData returns null before init', () {
      expect(client.initData, isNull);
    });

    test('currentQueuedMessage returns null initially', () {
      expect(client.currentQueuedMessage, isNull);
    });

    test('getMcpServer returns null for unknown server', () {
      expect(client.getMcpServer<dynamic>('nonexistent'), isNull);
    });

    group('getMcpServer typed lookup', () {
      late CodexClient innerWithServers;
      late CodexAgentClient clientWithServers;
      late FakeMcpServer genericServer;
      late SpecializedMcpServer specializedServer;

      setUp(() {
        genericServer = FakeMcpServer(name: 'generic');
        specializedServer = SpecializedMcpServer(name: 'specialized');

        innerWithServers = CodexClient(
          codexConfig: const CodexConfig(
            workingDirectory: '/tmp/test',
            sessionId: 'test-session-2',
          ),
          mcpServers: [genericServer, specializedServer],
        );
        clientWithServers = CodexAgentClient(innerWithServers);
      });

      test('returns server by name with dynamic type', () {
        final result = clientWithServers.getMcpServer<dynamic>('generic');
        expect(result, same(genericServer));
      });

      test('returns server by name with concrete type', () {
        final result = clientWithServers.getMcpServer<SpecializedMcpServer>(
          'specialized',
        );
        expect(result, same(specializedServer));
      });

      test('returns null when name matches but type does not', () {
        final result = clientWithServers.getMcpServer<SpecializedMcpServer>(
          'generic',
        );
        expect(result, isNull);
      });

      test('returns null when type matches but name does not', () {
        final result = clientWithServers.getMcpServer<SpecializedMcpServer>(
          'nonexistent',
        );
        expect(result, isNull);
      });

      test(
        'returns FakeMcpServer for specialized name since it is subtype',
        () {
          final result = clientWithServers.getMcpServer<FakeMcpServer>(
            'specialized',
          );
          expect(result, same(specializedServer));
        },
      );
    });
  });
}
