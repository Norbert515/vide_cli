@Tags(['e2e'])
library;

import 'package:test/test.dart';
import 'package:claude_sdk/claude_sdk.dart';

void main() {
  late bool claudeAvailable;

  setUpAll(() async {
    claudeAvailable = await ProcessManager.isClaudeAvailable();
  });

  group('Claude CLI E2E', () {
    test('Claude CLI is available', () {
      if (!claudeAvailable) {
        markTestSkipped('Claude CLI not installed - skipping E2E tests');
        return;
      }
      expect(claudeAvailable, isTrue);
    }, skip: false); // Always run to report availability

    test('creates client successfully', () async {
      if (!claudeAvailable) {
        markTestSkipped('Claude CLI not available');
        return;
      }

      final client = await ClaudeClient.create();
      addTearDown(() => client.close());

      expect(client.sessionId, isNotEmpty);
      expect(client.currentConversation.messages, isEmpty);
    });

    test(
      'sends simple message and receives response',
      () async {
        if (!claudeAvailable) {
          markTestSkipped('Claude CLI not available');
          return;
        }

        final client = await ClaudeClient.create(
          config: ClaudeConfig(
            model: 'sonnet', // Use faster model alias for tests
          ),
        );
        addTearDown(() => client.close());

        // Send a simple message - use append-system-prompt to limit response
        client.sendMessage(
          Message(text: 'Reply with exactly one word: TEST_OK. Nothing else.'),
        );

        // Wait for response (with timeout)
        await client.onTurnComplete.first.timeout(
          const Duration(seconds: 60),
          onTimeout: () => fail('Timeout waiting for response'),
        );

        // Verify we got a response
        expect(client.currentConversation.messages.length, greaterThan(1));

        // Check the assistant message exists and has content
        final assistantMessage =
            client.currentConversation.lastAssistantMessage;
        expect(assistantMessage, isNotNull);
        expect(assistantMessage!.content, isNotEmpty);
      },
      timeout: Timeout(Duration(seconds: 90)),
    );

    test(
      'handles conversation state transitions',
      () async {
        if (!claudeAvailable) {
          markTestSkipped('Claude CLI not available');
          return;
        }

        final client = await ClaudeClient.create(
          config: ClaudeConfig(model: 'sonnet'),
        );
        addTearDown(() => client.close());

        // Initial state should be idle
        expect(
          client.currentConversation.state,
          equals(ConversationState.idle),
        );

        // Track state changes
        final states = <ConversationState>[];
        final subscription = client.conversation.listen((conv) {
          if (states.isEmpty || states.last != conv.state) {
            states.add(conv.state);
          }
        });
        addTearDown(() => subscription.cancel());

        // Send a message
        client.sendMessage(Message(text: 'Reply with exactly: hi'));

        // Wait for completion
        await client.onTurnComplete.first.timeout(
          const Duration(seconds: 60),
          onTimeout: () => fail('Timeout waiting for response'),
        );

        // Verify we went through expected states
        // Should include: sendingMessage -> receivingResponse -> idle
        expect(states, contains(ConversationState.sendingMessage));
        expect(states.last, equals(ConversationState.idle));
      },
      timeout: Timeout(Duration(seconds: 90)),
    );

    test('maintains message history', () async {
      if (!claudeAvailable) {
        markTestSkipped('Claude CLI not available');
        return;
      }

      final client = await ClaudeClient.create(
        config: ClaudeConfig(model: 'sonnet'),
      );
      addTearDown(() => client.close());

      // Send first message
      client.sendMessage(Message(text: 'Reply with exactly: FIRST'));
      await client.onTurnComplete.first.timeout(
        const Duration(seconds: 60),
        onTimeout: () => fail('Timeout waiting for first response'),
      );

      final messagesAfterFirst = client.currentConversation.messages.length;
      expect(messagesAfterFirst, equals(2)); // user + assistant

      // Add a delay to allow the Claude CLI session to fully release
      // This works around the "Session ID is already in use" race condition
      await Future.delayed(const Duration(seconds: 2));

      // Send second message
      client.sendMessage(Message(text: 'Reply with exactly: SECOND'));
      await client.onTurnComplete.first.timeout(
        const Duration(seconds: 60),
        onTimeout: () => fail('Timeout waiting for second response'),
      );

      // Should now have 4 messages: user, assistant, user, assistant
      expect(client.currentConversation.messages.length, equals(4));

      // Verify message roles alternate
      final messages = client.currentConversation.messages;
      expect(messages[0].role, equals(MessageRole.user));
      expect(messages[1].role, equals(MessageRole.assistant));
      expect(messages[2].role, equals(MessageRole.user));
      expect(messages[3].role, equals(MessageRole.assistant));
    }, timeout: Timeout(Duration(seconds: 180)));
  });
}
