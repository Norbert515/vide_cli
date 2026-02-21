/// Tests for LocalVideSession.sendMessage() edge cases and behavior.
library;

import 'package:agent_sdk/agent_sdk.dart' as agent_sdk;
import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';

import '../helpers/session_test_helper.dart';

void main() {
  group('LocalVideSession.sendMessage()', () {
    late SessionTestHarness h;

    setUp(() async {
      h = SessionTestHarness();
      await h.setUp();
    });

    tearDown(() => h.dispose());

    test('sends message to main agent by default', () async {
      final events = h.collectEvents();

      h.session.sendMessage(VideMessage(text: 'Hello'));
      await Future<void>.delayed(Duration.zero);

      // Session emits a user event directly AND _handleConversation emits
      // another one when MockAgentClient adds the message to its conversation.
      // At minimum one user message event with the right content.
      final userMsgs = events
          .whereType<MessageEvent>()
          .where((e) => e.role == 'user')
          .toList();
      expect(userMsgs, isNotEmpty);
      expect(userMsgs.first.content, equals('Hello'));
      expect(userMsgs.first.agentId, equals(h.agentId));

      // Should forward to MockAgentClient
      expect(h.mockClient.sentMessages, hasLength(1));
      expect(h.mockClient.sentMessages.first.text, equals('Hello'));
    });

    test('sends message to specific agent when agentId provided', () async {
      final subClient = h.addAgent(id: 'sub-agent');
      final events = h.collectEvents();

      h.session.sendMessage(VideMessage(text: 'Hey sub'), agentId: 'sub-agent');
      await Future<void>.delayed(Duration.zero);

      final userMsgs = events.whereType<MessageEvent>().where(
        (e) => e.role == 'user',
      );
      expect(userMsgs.first.agentId, equals('sub-agent'));
      expect(subClient.sentMessages.first.text, equals('Hey sub'));
      // Main agent should NOT receive the message
      expect(h.mockClient.sentMessages, isEmpty);
    });

    test('queued messages do NOT emit user event', () async {
      h.mockClient.setConversationState(
        agent_sdk.AgentConversationState.receivingResponse,
      );
      expect(h.mockClient.currentConversation.isProcessing, isTrue);

      final events = h.collectEvents();

      h.session.sendMessage(VideMessage(text: 'While processing'));
      await Future<void>.delayed(Duration.zero);

      final userMsgs = events.whereType<MessageEvent>().where(
        (e) => e.role == 'user',
      );
      expect(
        userMsgs,
        isEmpty,
        reason: 'Queued messages should not appear in events',
      );
    });

    test('queued messages are stored in client', () async {
      h.mockClient.setConversationState(
        agent_sdk.AgentConversationState.receivingResponse,
      );

      h.session.sendMessage(VideMessage(text: 'Queued!'));
      await Future<void>.delayed(Duration.zero);

      expect(h.mockClient.currentQueuedMessage, equals('Queued!'));
    });

    test('non-queued messages set agent status to working', () async {
      final events = h.collectEvents();

      h.session.sendMessage(VideMessage(text: 'Go'));
      await Future<void>.delayed(Duration.zero);

      final statusEvents = events.whereType<StatusEvent>().toList();
      final workingEvents = statusEvents.where(
        (e) => e.status == VideAgentStatus.working,
      );
      expect(workingEvents, isNotEmpty);
    });

    test('queued messages do NOT change agent status', () async {
      // Set agent already working
      h.container
          .read(agentStatusProvider(h.agentId).notifier)
          .setStatus(AgentStatus.working);
      h.mockClient.setConversationState(
        agent_sdk.AgentConversationState.receivingResponse,
      );

      final events = h.collectEvents();

      h.session.sendMessage(VideMessage(text: 'Queued'));
      await Future<void>.delayed(Duration.zero);

      final statusEvents = events.whereType<StatusEvent>();
      expect(statusEvents, isEmpty);
    });

    test('message with attachments forwards them to claude client', () async {
      h.session.sendMessage(
        VideMessage(
          text: 'Check this',
          attachments: [
            VideAttachment(type: 'file', filePath: '/tmp/test.dart'),
            VideAttachment(
              type: 'text',
              content: 'inline content',
              mimeType: 'text/plain',
            ),
          ],
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(h.mockClient.sentMessages, hasLength(1));
      final msg = h.mockClient.sentMessages.first;
      expect(msg.attachments, isNotNull);
      expect(msg.attachments, hasLength(2));
    });

    test('message with attachments includes them in event', () async {
      final events = h.collectEvents();

      h.session.sendMessage(
        VideMessage(
          text: 'Attached',
          attachments: [VideAttachment(type: 'file', filePath: '/tmp/a.dart')],
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final msg = events.whereType<MessageEvent>().first;
      expect(msg.attachments, isNotNull);
      expect(msg.attachments!.first.filePath, equals('/tmp/a.dart'));
    });

    test('multiple rapid messages all produce events', () async {
      final events = h.collectEvents();

      h.session.sendMessage(VideMessage(text: 'msg1'));
      h.session.sendMessage(VideMessage(text: 'msg2'));
      h.session.sendMessage(VideMessage(text: 'msg3'));
      await Future<void>.delayed(Duration.zero);

      // Session emits events directly AND _handleConversation also emits
      // when the mock client adds messages. We expect at least 3 unique
      // user message contents.
      final userMsgs = events
          .whereType<MessageEvent>()
          .where((e) => e.role == 'user')
          .toList();
      final contents = userMsgs.map((m) => m.content).toSet();
      expect(contents, containsAll(['msg1', 'msg2', 'msg3']));
    });

    test('each user message gets a unique eventId', () async {
      final events = h.collectEvents();

      h.session.sendMessage(VideMessage(text: 'msg1'));
      h.session.sendMessage(VideMessage(text: 'msg2'));
      await Future<void>.delayed(Duration.zero);

      final userMsgs = events
          .whereType<MessageEvent>()
          .where((e) => e.role == 'user')
          .toList();
      // We get >=2 events (direct emit + conversation stream).
      // Verify there are at least 2 distinct eventIds.
      final eventIds = userMsgs.map((m) => m.eventId).toSet();
      expect(
        eventIds.length,
        greaterThanOrEqualTo(2),
        reason: 'Each message should have a unique eventId',
      );
    });
  });
}
