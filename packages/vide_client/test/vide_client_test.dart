import 'package:test/test.dart';
import 'package:vide_client/vide_client.dart';

void main() {
  group('VideClient', () {
    test('can be instantiated with port', () {
      final client = VideClient(port: 8080);
      expect(client.port, equals(8080));
      expect(client.host, equals('127.0.0.1'));
    });

    test('can be instantiated with custom host', () {
      final client = VideClient(host: 'localhost', port: 3000);
      expect(client.host, equals('localhost'));
      expect(client.port, equals(3000));
    });
  });

  group('VideClientException', () {
    test('formats message correctly', () {
      final exception = VideClientException('test error');
      expect(exception.toString(), equals('VideClientException: test error'));
    });
  });

  group('Enums', () {
    test('MessageRole.fromString parses correctly', () {
      expect(MessageRole.fromString('user'), equals(MessageRole.user));
      expect(
        MessageRole.fromString('assistant'),
        equals(MessageRole.assistant),
      );
      expect(MessageRole.fromString('unknown'), equals(MessageRole.assistant));
    });

    test('AgentStatus.fromString parses correctly', () {
      expect(AgentStatus.fromString('working'), equals(AgentStatus.working));
      expect(
        AgentStatus.fromString('waiting-for-agent'),
        equals(AgentStatus.waitingForAgent),
      );
      expect(
        AgentStatus.fromString('waiting-for-user'),
        equals(AgentStatus.waitingForUser),
      );
      expect(AgentStatus.fromString('idle'), equals(AgentStatus.idle));
      expect(AgentStatus.fromString(null), equals(AgentStatus.idle));
    });
  });

  group('AgentInfo', () {
    test('fromJson parses agent event format', () {
      final info = AgentInfo.fromJson({
        'agent-id': 'abc123',
        'agent-type': 'implementer',
        'agent-name': 'Test Agent',
        'task-name': 'My Task',
      });
      expect(info.id, equals('abc123'));
      expect(info.type, equals('implementer'));
      expect(info.name, equals('Test Agent'));
      expect(info.taskName, equals('My Task'));
    });

    test('fromJson parses agents array format', () {
      final info = AgentInfo.fromJson({
        'id': 'def456',
        'type': 'researcher',
        'name': 'Research Agent',
      });
      expect(info.id, equals('def456'));
      expect(info.type, equals('researcher'));
      expect(info.name, equals('Research Agent'));
      expect(info.taskName, isNull);
    });
  });

  group('VideEvent', () {
    test('parses message event', () {
      final event = VideEvent.fromJson({
        'type': 'message',
        'seq': 1,
        'event-id': 'evt-123',
        'timestamp': '2024-01-01T00:00:00Z',
        'is-partial': false,
        'data': {'role': 'assistant', 'content': 'Hello!'},
      });

      expect(event, isA<MessageEvent>());
      final msg = event as MessageEvent;
      expect(msg.seq, equals(1));
      expect(msg.eventId, equals('evt-123'));
      expect(msg.role, equals(MessageRole.assistant));
      expect(msg.content, equals('Hello!'));
      expect(msg.isPartial, isFalse);
    });

    test('parses done event', () {
      final event = VideEvent.fromJson({
        'type': 'done',
        'timestamp': '2024-01-01T00:00:00Z',
        'data': {'reason': 'complete'},
      });

      expect(event, isA<DoneEvent>());
      expect((event as DoneEvent).reason, equals('complete'));
    });

    test('parses unknown event type gracefully', () {
      final event = VideEvent.fromJson({
        'type': 'future-event-type',
        'timestamp': '2024-01-01T00:00:00Z',
      });

      expect(event, isA<UnknownEvent>());
      expect((event as UnknownEvent).type, equals('future-event-type'));
    });
  });

  group('SessionStatus', () {
    test('has expected values', () {
      expect(SessionStatus.values, contains(SessionStatus.open));
      expect(SessionStatus.values, contains(SessionStatus.closed));
      expect(SessionStatus.values, contains(SessionStatus.error));
    });
  });
}
