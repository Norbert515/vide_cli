import 'package:agent_sdk/agent_sdk.dart';
import 'package:test/test.dart';

import 'mock_agent_client.dart';

void main() {
  group('MockAgentClient', () {
    late MockAgentClient client;

    setUp(() {
      client = MockAgentClient();
    });

    tearDown(() async {
      await client.close();
    });

    test('uses default sessionId when none provided', () {
      expect(client.sessionId, startsWith('mock-session-'));
    });

    test('uses custom sessionId when provided', () {
      final custom = MockAgentClient(sessionId: 'custom-id');
      expect(custom.sessionId, equals('custom-id'));
      addTearDown(() => custom.close());
    });

    test('uses default workingDirectory', () {
      expect(client.workingDirectory, equals('/mock/working/dir'));
    });

    test('uses custom workingDirectory', () {
      final custom = MockAgentClient(workingDirectory: '/custom/dir');
      expect(custom.workingDirectory, equals('/custom/dir'));
      addTearDown(() => custom.close());
    });

    test('initialized completes immediately', () async {
      await expectLater(client.initialized, completes);
    });

    test('starts with empty conversation', () {
      expect(client.currentConversation.messages, isEmpty);
      expect(
        client.currentConversation.state,
        equals(AgentConversationState.idle),
      );
    });

    test('starts with ready status', () {
      expect(client.currentStatus, equals(AgentProcessingStatus.ready));
    });

    test('starts with null initData', () {
      expect(client.initData, isNull);
    });

    group('sendMessage', () {
      test('adds message to sentMessages', () {
        client.sendMessage(const AgentMessage.text('hello'));
        expect(client.sentMessages, hasLength(1));
        expect(client.sentMessages.first.text, equals('hello'));
      });

      test('ignores empty messages', () {
        client.sendMessage(const AgentMessage.text('  '));
        expect(client.sentMessages, isEmpty);
      });

      test('adds user message to conversation', () async {
        final conversationFuture = client.conversation.first;
        client.sendMessage(const AgentMessage.text('hello'));

        final conv = await conversationFuture;
        expect(conv.messages, hasLength(1));
        expect(conv.messages.first.role, equals(AgentMessageRole.user));
        expect(conv.messages.first.content, equals('hello'));
      });

      test('queues message when conversation is processing', () async {
        client.setConversationState(AgentConversationState.receivingResponse);

        client.sendMessage(const AgentMessage.text('queued msg'));

        expect(client.sentMessages, isEmpty);
        expect(client.currentQueuedMessage, equals('queued msg'));
      });

      test('appends to queued message when already queued', () {
        client.setConversationState(AgentConversationState.processing);

        client.sendMessage(const AgentMessage.text('first'));
        client.sendMessage(const AgentMessage.text('second'));

        expect(client.currentQueuedMessage, equals('first\nsecond'));
      });

      test('emits queued message on stream', () async {
        client.setConversationState(AgentConversationState.processing);

        final queuedFuture = client.queuedMessage.first;
        client.sendMessage(const AgentMessage.text('queued'));

        expect(await queuedFuture, equals('queued'));
      });
    });

    group('clearQueuedMessage', () {
      test('clears queued message', () async {
        client.setConversationState(AgentConversationState.processing);
        client.sendMessage(const AgentMessage.text('queued'));
        expect(client.currentQueuedMessage, equals('queued'));

        final queuedFuture = client.queuedMessage.first;
        client.clearQueuedMessage();

        expect(client.currentQueuedMessage, isNull);
        expect(await queuedFuture, isNull);
      });
    });

    group('simulateTextResponse', () {
      test('adds assistant message to conversation', () async {
        final conversationFuture = client.conversation.first;
        client.simulateTextResponse('Hello there');

        final conv = await conversationFuture;
        expect(conv.messages, hasLength(1));
        expect(conv.messages.first.role, equals(AgentMessageRole.assistant));
        expect(conv.messages.first.content, equals('Hello there'));
      });

      test('creates message with AgentTextResponse', () {
        client.simulateTextResponse('Hello');

        final msg = client.currentConversation.messages.first;
        expect(msg.responses, hasLength(1));
        expect(msg.responses.first, isA<AgentTextResponse>());
        expect(
          (msg.responses.first as AgentTextResponse).content,
          equals('Hello'),
        );
      });

      test('creates complete message', () {
        client.simulateTextResponse('Hello');

        final msg = client.currentConversation.messages.first;
        expect(msg.isComplete, isTrue);
      });
    });

    group('simulateTurnComplete', () {
      test('emits on onTurnComplete stream', () async {
        final turnFuture = client.onTurnComplete.first;
        client.simulateTurnComplete();
        await expectLater(turnFuture, completes);
      });
    });

    group('emitStatus', () {
      test('updates currentStatus', () {
        client.emitStatus(AgentProcessingStatus.processing);
        expect(
          client.currentStatus,
          equals(AgentProcessingStatus.processing),
        );
      });

      test('emits on statusStream', () async {
        final statusFuture = client.statusStream.first;
        client.emitStatus(AgentProcessingStatus.thinking);
        expect(
          await statusFuture,
          equals(AgentProcessingStatus.thinking),
        );
      });
    });

    group('simulateAssistantWithToolCall', () {
      test('creates message with text, tool use, and tool result', () {
        client.simulateAssistantWithToolCall(
          text: 'Let me read that file',
          toolName: 'Read',
          toolInput: {'path': '/foo.dart'},
          toolResult: 'file contents here',
        );

        final msg = client.currentConversation.messages.first;
        expect(msg.role, equals(AgentMessageRole.assistant));
        expect(msg.responses, hasLength(3));
        expect(msg.responses[0], isA<AgentTextResponse>());
        expect(msg.responses[1], isA<AgentToolUseResponse>());
        expect(msg.responses[2], isA<AgentToolResultResponse>());
      });

      test('uses provided toolUseId', () {
        client.simulateAssistantWithToolCall(
          text: 'text',
          toolName: 'Bash',
          toolInput: {'cmd': 'ls'},
          toolResult: 'output',
          toolUseId: 'custom-id',
        );

        final msg = client.currentConversation.messages.first;
        final toolUse = msg.responses[1] as AgentToolUseResponse;
        final toolResult = msg.responses[2] as AgentToolResultResponse;
        expect(toolUse.toolUseId, equals('custom-id'));
        expect(toolResult.toolUseId, equals('custom-id'));
      });

      test('supports isError flag', () {
        client.simulateAssistantWithToolCall(
          text: 'text',
          toolName: 'Bash',
          toolInput: {},
          toolResult: 'error output',
          isError: true,
        );

        final msg = client.currentConversation.messages.first;
        final toolResult = msg.responses[2] as AgentToolResultResponse;
        expect(toolResult.isError, isTrue);
      });

      test('creates complete message', () {
        client.simulateAssistantWithToolCall(
          text: 'text',
          toolName: 'Read',
          toolInput: {},
          toolResult: 'result',
        );

        final msg = client.currentConversation.messages.first;
        expect(msg.isComplete, isTrue);
      });
    });

    group('simulateStreamingText', () {
      test('creates new assistant message when conversation is empty', () {
        client.simulateStreamingText('Hello');

        final msg = client.currentConversation.messages.first;
        expect(msg.role, equals(AgentMessageRole.assistant));
        expect(msg.content, equals('Hello'));
        expect(msg.isStreaming, isTrue);
      });

      test('appends text to existing assistant message', () {
        client.simulateStreamingText('Hello ');
        client.simulateStreamingText('world');

        expect(client.currentConversation.messages, hasLength(1));
        final msg = client.currentConversation.messages.first;
        expect(msg.content, equals('Hello world'));
      });

      test('creates new message with createNew flag', () {
        client.simulateStreamingText('First');
        client.simulateStreamingText('Second', createNew: true);

        expect(client.currentConversation.messages, hasLength(2));
      });

      test('sets conversation state to receivingResponse', () {
        client.simulateStreamingText('streaming');

        expect(
          client.currentConversation.state,
          equals(AgentConversationState.receivingResponse),
        );
      });
    });

    group('simulateError', () {
      test('sets error on conversation', () {
        client.simulateError('Something went wrong');

        expect(
          client.currentConversation.currentError,
          equals('Something went wrong'),
        );
        expect(
          client.currentConversation.state,
          equals(AgentConversationState.error),
        );
      });
    });

    group('simulateIdle', () {
      test('sets conversation state to idle', () {
        client.setConversationState(AgentConversationState.processing);
        client.simulateIdle();

        expect(
          client.currentConversation.state,
          equals(AgentConversationState.idle),
        );
      });
    });

    group('setInitData', () {
      test('sets initData', () {
        final data = AgentInitData(model: 'test-model');
        client.setInitData(data);

        expect(client.initData, isNotNull);
        expect(client.initData!.model, equals('test-model'));
      });

      test('emits on initDataStream', () async {
        final data = AgentInitData(model: 'test-model');
        final initFuture = client.initDataStream.first;
        client.setInitData(data);

        final received = await initFuture;
        expect(received.model, equals('test-model'));
      });
    });

    group('abort', () {
      test('sets isAborted flag', () async {
        await client.abort();
        expect(client.isAborted, isTrue);
      });
    });

    group('close', () {
      test('sets isClosed flag', () async {
        await client.close();
        expect(client.isClosed, isTrue);
      });
    });

    group('clearConversation', () {
      test('resets conversation to empty', () async {
        client.simulateTextResponse('Some text');
        expect(client.currentConversation.messages, isNotEmpty);

        await client.clearConversation();
        expect(client.currentConversation.messages, isEmpty);
      });
    });

    group('reset', () {
      test('clears sentMessages', () {
        client.sendMessage(const AgentMessage.text('hello'));
        expect(client.sentMessages, isNotEmpty);

        client.reset();
        expect(client.sentMessages, isEmpty);
      });

      test('resets conversation', () {
        client.simulateTextResponse('text');
        client.reset();
        expect(client.currentConversation.messages, isEmpty);
      });

      test('resets flags', () async {
        await client.abort();
        expect(client.isAborted, isTrue);

        client.reset();
        expect(client.isAborted, isFalse);
        expect(client.isClosed, isFalse);
      });
    });

    group('injectToolResult', () {
      test('adds tool result to last assistant message', () {
        client.simulateAssistantWithToolCall(
          text: 'calling tool',
          toolName: 'Bash',
          toolInput: {'cmd': 'ls'},
          toolResult: 'first result',
          toolUseId: 'tool-1',
        );

        final injected = AgentToolResultResponse(
          id: 'injected-result',
          timestamp: DateTime.now(),
          toolUseId: 'tool-2',
          content: 'injected content',
        );
        client.injectToolResult(injected);

        final msg = client.currentConversation.messages.last;
        expect(msg.responses, hasLength(4));
        expect(msg.responses.last, isA<AgentToolResultResponse>());
        expect(
          (msg.responses.last as AgentToolResultResponse).content,
          equals('injected content'),
        );
      });

      test('does nothing when conversation is empty', () {
        final injected = AgentToolResultResponse(
          id: 'injected',
          timestamp: DateTime.now(),
          toolUseId: 'tool-1',
          content: 'content',
        );
        client.injectToolResult(injected);
        expect(client.currentConversation.messages, isEmpty);
      });

      test('does nothing when last message is not assistant', () {
        client.sendMessage(const AgentMessage.text('user msg'));
        final injected = AgentToolResultResponse(
          id: 'injected',
          timestamp: DateTime.now(),
          toolUseId: 'tool-1',
          content: 'content',
        );
        client.injectToolResult(injected);

        final msg = client.currentConversation.messages.last;
        expect(msg.role, equals(AgentMessageRole.user));
      });
    });

    group('getMcpServer', () {
      test('returns null', () {
        expect(client.getMcpServer<Object>('test'), isNull);
      });
    });
  });

  group('MockAgentClientFactory', () {
    late MockAgentClientFactory factory;

    setUp(() {
      factory = MockAgentClientFactory();
    });

    tearDown(() {
      factory.clear();
    });

    test('creates client for new agentId', () {
      final client = factory.getClient('agent-1');
      expect(client, isA<MockAgentClient>());
      expect(client.sessionId, equals('agent-1'));
    });

    test('returns same client for same agentId', () {
      final client1 = factory.getClient('agent-1');
      final client2 = factory.getClient('agent-1');
      expect(identical(client1, client2), isTrue);
    });

    test('returns different clients for different agentIds', () {
      final client1 = factory.getClient('agent-1');
      final client2 = factory.getClient('agent-2');
      expect(identical(client1, client2), isFalse);
    });

    test('hasClient returns true for existing client', () {
      factory.getClient('agent-1');
      expect(factory.hasClient('agent-1'), isTrue);
    });

    test('hasClient returns false for non-existing client', () {
      expect(factory.hasClient('agent-1'), isFalse);
    });

    test('clients returns unmodifiable map', () {
      factory.getClient('agent-1');
      expect(factory.clients, hasLength(1));
      expect(() => (factory.clients as Map)['new'] = 'val', throwsA(anything));
    });

    test('clear removes all clients', () {
      factory.getClient('agent-1');
      factory.getClient('agent-2');
      expect(factory.clients, hasLength(2));

      factory.clear();
      expect(factory.clients, isEmpty);
    });
  });
}
