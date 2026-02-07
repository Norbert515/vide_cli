import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vide_mobile/domain/models/models.dart';
import 'package:vide_mobile/features/chat/chat_state.dart';

void main() {
  late ProviderContainer container;
  late ChatNotifier notifier;

  const sessionId = 'test-session';
  const agentId = 'agent-1';
  const agentType = 'main';
  final timestamp = DateTime(2024, 1, 1);

  setUp(() {
    container = ProviderContainer();
    // Read notifier to initialize it
    notifier = container.read(chatNotifierProvider(sessionId).notifier);
  });

  tearDown(() {
    container.dispose();
  });

  ChatState readState() =>
      container.read(chatNotifierProvider(sessionId));

  group('handleMessageEvent', () {
    test('accumulates partial streaming chunks into a single message', () {
      // Simulate 3 partial chunks with the same eventId, then a final
      notifier.handleMessageEvent(
        eventId: 'evt-1',
        agentId: agentId,
        agentType: agentType,
        agentName: null,
        content: 'Hello ',
        role: MessageRole.assistant,
        isPartial: true,
        timestamp: timestamp,
      );
      notifier.handleMessageEvent(
        eventId: 'evt-1',
        agentId: agentId,
        agentType: agentType,
        agentName: null,
        content: 'world',
        role: MessageRole.assistant,
        isPartial: true,
        timestamp: timestamp,
      );
      notifier.handleMessageEvent(
        eventId: 'evt-1',
        agentId: agentId,
        agentType: agentType,
        agentName: null,
        content: '!',
        role: MessageRole.assistant,
        isPartial: true,
        timestamp: timestamp,
      );

      final state = readState();
      expect(state.messages, hasLength(1),
          reason: 'All chunks should accumulate into one message');
      expect(state.messages.first.content, 'Hello world!');
      expect(state.messages.first.isStreaming, isTrue);
    });

    test('finalizes streaming message when isPartial becomes false', () {
      notifier.handleMessageEvent(
        eventId: 'evt-1',
        agentId: agentId,
        agentType: agentType,
        agentName: null,
        content: 'Hello ',
        role: MessageRole.assistant,
        isPartial: true,
        timestamp: timestamp,
      );
      notifier.handleMessageEvent(
        eventId: 'evt-1',
        agentId: agentId,
        agentType: agentType,
        agentName: null,
        content: 'world!',
        role: MessageRole.assistant,
        isPartial: true,
        timestamp: timestamp,
      );
      // Final chunk (isPartial: false) with empty content
      notifier.handleMessageEvent(
        eventId: 'evt-1',
        agentId: agentId,
        agentType: agentType,
        agentName: null,
        content: '',
        role: MessageRole.assistant,
        isPartial: false,
        timestamp: timestamp,
      );

      final state = readState();
      expect(state.messages, hasLength(1));
      expect(state.messages.first.content, 'Hello world!');
      expect(state.messages.first.isStreaming, isFalse);
    });

    test('handles multiple concurrent streams with different eventIds', () {
      notifier.handleMessageEvent(
        eventId: 'evt-1',
        agentId: agentId,
        agentType: agentType,
        agentName: null,
        content: 'First ',
        role: MessageRole.assistant,
        isPartial: true,
        timestamp: timestamp,
      );
      notifier.handleMessageEvent(
        eventId: 'evt-2',
        agentId: 'agent-2',
        agentType: agentType,
        agentName: null,
        content: 'Second ',
        role: MessageRole.assistant,
        isPartial: true,
        timestamp: timestamp,
      );
      notifier.handleMessageEvent(
        eventId: 'evt-1',
        agentId: agentId,
        agentType: agentType,
        agentName: null,
        content: 'message',
        role: MessageRole.assistant,
        isPartial: true,
        timestamp: timestamp,
      );
      notifier.handleMessageEvent(
        eventId: 'evt-2',
        agentId: 'agent-2',
        agentType: agentType,
        agentName: null,
        content: 'message',
        role: MessageRole.assistant,
        isPartial: true,
        timestamp: timestamp,
      );

      final state = readState();
      expect(state.messages, hasLength(2));
      expect(state.messages[0].content, 'First message');
      expect(state.messages[1].content, 'Second message');
    });

    test('non-partial message with content is added directly', () {
      notifier.handleMessageEvent(
        eventId: 'evt-1',
        agentId: agentId,
        agentType: agentType,
        agentName: null,
        content: 'Complete message',
        role: MessageRole.assistant,
        isPartial: false,
        timestamp: timestamp,
      );

      final state = readState();
      expect(state.messages, hasLength(1));
      expect(state.messages.first.content, 'Complete message');
      expect(state.messages.first.isStreaming, isFalse);
    });

    test('non-partial message with empty content is ignored', () {
      notifier.handleMessageEvent(
        eventId: 'evt-1',
        agentId: agentId,
        agentType: agentType,
        agentName: null,
        content: '',
        role: MessageRole.assistant,
        isPartial: false,
        timestamp: timestamp,
      );

      final state = readState();
      expect(state.messages, isEmpty);
    });

    test('deduplicates user messages by content', () {
      notifier.addMessage(ChatMessage(
        eventId: 'optimistic-1',
        role: MessageRole.user,
        content: 'Hey',
        agentId: 'user',
        agentType: 'user',
        timestamp: timestamp,
      ));

      // Server echoes the same user message with a different eventId
      notifier.handleMessageEvent(
        eventId: 'server-evt-1',
        agentId: agentId,
        agentType: 'user',
        agentName: null,
        content: 'Hey',
        role: MessageRole.user,
        isPartial: false,
        timestamp: timestamp,
      );

      final state = readState();
      expect(state.messages, hasLength(1),
          reason: 'Duplicate user message should be skipped');
      expect(state.messages.first.eventId, 'optimistic-1');
    });

    test('second stream after tool call uses new eventId correctly', () {
      // First message stream (before tool call)
      notifier.handleMessageEvent(
        eventId: 'evt-1',
        agentId: agentId,
        agentType: agentType,
        agentName: null,
        content: 'Let me ',
        role: MessageRole.assistant,
        isPartial: true,
        timestamp: timestamp,
      );
      notifier.handleMessageEvent(
        eventId: 'evt-1',
        agentId: agentId,
        agentType: agentType,
        agentName: null,
        content: 'check that.',
        role: MessageRole.assistant,
        isPartial: true,
        timestamp: timestamp,
      );
      // Finalize first message (server sends isPartial: false before tool)
      notifier.handleMessageEvent(
        eventId: 'evt-1',
        agentId: agentId,
        agentType: agentType,
        agentName: null,
        content: '',
        role: MessageRole.assistant,
        isPartial: false,
        timestamp: timestamp,
      );

      // Tool use + result would happen here (not message events)

      // Second message stream AFTER tool call — new eventId
      notifier.handleMessageEvent(
        eventId: 'evt-2',
        agentId: agentId,
        agentType: agentType,
        agentName: null,
        content: 'There ',
        role: MessageRole.assistant,
        isPartial: true,
        timestamp: timestamp,
      );
      notifier.handleMessageEvent(
        eventId: 'evt-2',
        agentId: agentId,
        agentType: agentType,
        agentName: null,
        content: 'you ',
        role: MessageRole.assistant,
        isPartial: true,
        timestamp: timestamp,
      );
      notifier.handleMessageEvent(
        eventId: 'evt-2',
        agentId: agentId,
        agentType: agentType,
        agentName: null,
        content: 'go!',
        role: MessageRole.assistant,
        isPartial: true,
        timestamp: timestamp,
      );

      final state = readState();
      expect(state.messages, hasLength(2),
          reason: 'Should have 2 messages: pre-tool and post-tool');
      expect(state.messages[0].content, 'Let me check that.');
      expect(state.messages[0].isStreaming, isFalse);
      expect(state.messages[1].content, 'There you go!');
      expect(state.messages[1].isStreaming, isTrue);
    });

    group('history replay (rapid synchronous calls)', () {
      test('accumulates streaming chunks correctly during synchronous replay',
          () {
        // Simulate what happens during HistoryEvent processing:
        // all events are fed synchronously in a tight loop.
        final events = [
          (eventId: 'evt-1', content: 'Hello ', isPartial: true),
          (eventId: 'evt-1', content: 'world', isPartial: true),
          (eventId: 'evt-1', content: '!', isPartial: true),
          (eventId: 'evt-1', content: '', isPartial: false),
        ];

        for (final e in events) {
          notifier.handleMessageEvent(
            eventId: e.eventId,
            agentId: agentId,
            agentType: agentType,
            agentName: null,
            content: e.content,
            role: MessageRole.assistant,
            isPartial: e.isPartial,
            timestamp: timestamp,
          );
        }

        final state = readState();
        expect(state.messages, hasLength(1),
            reason: 'History replay should produce exactly one message');
        expect(state.messages.first.content, 'Hello world!');
        expect(state.messages.first.isStreaming, isFalse);
      });

      test('handles mixed messages during synchronous replay', () {
        // Simulate history with: user message, then assistant streaming
        final events = <Map<String, dynamic>>[
          {
            'eventId': 'user-evt',
            'content': 'Hey',
            'role': MessageRole.user,
            'isPartial': false,
          },
          {
            'eventId': 'asst-evt',
            'content': 'How can ',
            'role': MessageRole.assistant,
            'isPartial': true,
          },
          {
            'eventId': 'asst-evt',
            'content': 'I help?',
            'role': MessageRole.assistant,
            'isPartial': true,
          },
          {
            'eventId': 'asst-evt',
            'content': '',
            'role': MessageRole.assistant,
            'isPartial': false,
          },
        ];

        for (final e in events) {
          notifier.handleMessageEvent(
            eventId: e['eventId'] as String,
            agentId: agentId,
            agentType: agentType,
            agentName: null,
            content: e['content'] as String,
            role: e['role'] as MessageRole,
            isPartial: e['isPartial'] as bool,
            timestamp: timestamp,
          );
        }

        final state = readState();
        expect(state.messages, hasLength(2));
        expect(state.messages[0].role, MessageRole.user);
        expect(state.messages[0].content, 'Hey');
        expect(state.messages[1].role, MessageRole.assistant);
        expect(state.messages[1].content, 'How can I help?');
      });
    });
  });
}
