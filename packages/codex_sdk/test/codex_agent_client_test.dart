import 'package:agent_sdk/agent_sdk.dart';
import 'package:codex_sdk/codex_sdk.dart';
import 'package:test/test.dart';

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

    tearDown(() async {
      // Close streams without calling full close (no subprocess to stop)
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
  });
}
