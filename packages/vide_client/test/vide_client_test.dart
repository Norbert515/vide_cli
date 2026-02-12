import 'dart:convert';

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

    test('VideAgentStatus.fromWireString parses correctly', () {
      expect(
        VideAgentStatus.fromWireString('working'),
        equals(VideAgentStatus.working),
      );
      expect(
        VideAgentStatus.fromWireString('waiting-for-agent'),
        equals(VideAgentStatus.waitingForAgent),
      );
      expect(
        VideAgentStatus.fromWireString('waiting-for-user'),
        equals(VideAgentStatus.waitingForUser),
      );
      expect(
        VideAgentStatus.fromWireString('idle'),
        equals(VideAgentStatus.idle),
      );
      expect(
        VideAgentStatus.fromWireString(null),
        equals(VideAgentStatus.idle),
      );
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
    test('parses connected event metadata', () {
      final event = VideEvent.fromJson({
        'type': 'connected',
        'timestamp': '2024-01-01T00:00:00Z',
        'session-id': 'session-1',
        'main-agent-id': 'agent-1',
        'last-seq': 0,
        'agents': [
          {'id': 'agent-1', 'type': 'main', 'name': 'Main Agent'},
        ],
        'metadata': {
          'working-directory': '/tmp/workspace',
          'goal': 'Fix build',
          'team': 'enterprise',
        },
      });

      expect(event, isA<ConnectedEvent>());
      final connected = event as ConnectedEvent;
      expect(connected.metadata['working-directory'], '/tmp/workspace');
      expect(connected.metadata['goal'], 'Fix build');
      expect(connected.metadata['team'], 'enterprise');
    });

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
      expect(msg.role, equals('assistant'));
      expect(msg.content, equals('Hello!'));
      expect(msg.isPartial, isFalse);
    });

    test('parses done event as TurnCompleteEvent', () {
      final event = VideEvent.fromJson({
        'type': 'done',
        'timestamp': '2024-01-01T00:00:00Z',
        'data': {'reason': 'complete'},
      });

      expect(event, isA<TurnCompleteEvent>());
      expect((event as TurnCompleteEvent).reason, equals('complete'));
    });

    test('parses ask-user-question event', () {
      final event = VideEvent.fromJson({
        'type': 'ask-user-question',
        'timestamp': '2024-01-01T00:00:00Z',
        'data': {
          'request-id': 'ask-1',
          'questions': [
            {
              'question': 'Pick one',
              'options': [
                {'label': 'A', 'description': 'Option A'},
              ],
            },
          ],
        },
      });

      expect(event, isA<AskUserQuestionEvent>());
      final ask = event as AskUserQuestionEvent;
      expect(ask.requestId, equals('ask-1'));
      expect(ask.questions, hasLength(1));
    });

    test('parses task-name-changed event', () {
      final event = VideEvent.fromJson({
        'type': 'task-name-changed',
        'timestamp': '2024-01-01T00:00:00Z',
        'data': {'new-goal': 'Ship v1', 'previous-goal': 'Initial'},
      });

      expect(event, isA<TaskNameChangedEvent>());
      final changed = event as TaskNameChangedEvent;
      expect(changed.newGoal, equals('Ship v1'));
      expect(changed.previousGoal, equals('Initial'));
    });

    test('parses command-result event', () {
      final event = VideEvent.fromJson({
        'type': 'command-result',
        'timestamp': '2024-01-01T00:00:00Z',
        'data': {
          'request-id': 'cmd-1',
          'command': 'fork-agent',
          'success': true,
          'result': {'agent-id': 'agent-2'},
        },
      });

      expect(event, isA<CommandResultEvent>());
      final result = event as CommandResultEvent;
      expect(result.requestId, equals('cmd-1'));
      expect(result.command, equals('fork-agent'));
      expect(result.success, isTrue);
      expect(result.result, equals({'agent-id': 'agent-2'}));
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

  group('RemoteVideSession event forwarding', () {
    test('forwards PlanApprovalRequestEvent through event stream', () async {
      final session = RemoteVideSession.pending();
      addTearDown(session.dispose);

      final events = <VideEvent>[];
      session.events.listen(events.add);

      session.handleWebSocketMessage(jsonEncode({
        'type': 'plan-approval-request',
        'seq': 1,
        'agent-id': 'agent-1',
        'agent-type': 'main',
        'agent-name': 'Elena',
        'timestamp': '2024-01-01T00:00:00Z',
        'data': {
          'request-id': 'plan-1',
          'plan-content': '# My Plan\n\nStep 1: Do things',
          'allowed-prompts': [
            {'tool': 'Bash', 'prompt': 'run tests'},
          ],
        },
      }));

      // Allow the stream event to be delivered.
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first, isA<PlanApprovalRequestEvent>());
      final planEvent = events.first as PlanApprovalRequestEvent;
      expect(planEvent.requestId, equals('plan-1'));
      expect(planEvent.planContent, equals('# My Plan\n\nStep 1: Do things'));
      expect(planEvent.agentName, equals('Elena'));
      expect(planEvent.allowedPrompts, hasLength(1));
    });

    test('forwards PlanApprovalResolvedEvent through event stream', () async {
      final session = RemoteVideSession.pending();
      addTearDown(session.dispose);

      final events = <VideEvent>[];
      session.events.listen(events.add);

      session.handleWebSocketMessage(jsonEncode({
        'type': 'plan-approval-resolved',
        'seq': 2,
        'agent-id': 'agent-1',
        'agent-type': 'main',
        'timestamp': '2024-01-01T00:00:00Z',
        'data': {
          'request-id': 'plan-1',
          'action': 'accept',
        },
      }));

      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first, isA<PlanApprovalResolvedEvent>());
      final resolved = events.first as PlanApprovalResolvedEvent;
      expect(resolved.requestId, equals('plan-1'));
      expect(resolved.action, equals('accept'));
    });
  });
}
