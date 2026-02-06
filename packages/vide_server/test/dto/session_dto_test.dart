import 'package:test/test.dart';
import 'package:vide_server/dto/session_dto.dart';

void main() {
  group('CreateSessionRequest', () {
    test('fromJson parses kebab-case fields', () {
      final json = {
        'initial-message': 'Hello',
        'working-directory': '/path/to/project',
        'model': 'opus',
        'permission-mode': 'interactive',
      };

      final request = CreateSessionRequest.fromJson(json);

      expect(request.initialMessage, 'Hello');
      expect(request.workingDirectory, '/path/to/project');
      expect(request.model, 'opus');
      expect(request.permissionMode, 'interactive');
    });

    test('fromJson works without optional fields', () {
      final json = {'initial-message': 'Hello', 'working-directory': '/path'};

      final request = CreateSessionRequest.fromJson(json);

      expect(request.initialMessage, 'Hello');
      expect(request.workingDirectory, '/path');
      expect(request.model, isNull);
      expect(request.permissionMode, isNull);
    });
  });

  group('CreateSessionResponse', () {
    test('toJson outputs kebab-case fields', () {
      final response = CreateSessionResponse(
        sessionId: 'sess-123',
        mainAgentId: 'agent-456',
        createdAt: DateTime.utc(2025, 1, 1, 12, 0, 0),
      );

      final json = response.toJson();

      expect(json['session-id'], 'sess-123');
      expect(json['main-agent-id'], 'agent-456');
      expect(json['created-at'], '2025-01-01T12:00:00.000Z');
    });
  });

  group('ClientMessage', () {
    test('fromJson parses user-message', () {
      final json = {
        'type': 'user-message',
        'content': 'Hello there',
        'model': 'haiku',
      };

      final message = ClientMessage.fromJson(json);

      expect(message, isA<UserMessage>());
      final userMsg = message as UserMessage;
      expect(userMsg.content, 'Hello there');
      expect(userMsg.agentId, isNull);
      expect(userMsg.model, 'haiku');
    });

    test('fromJson parses user-message with target agent', () {
      final json = {
        'type': 'user-message',
        'content': 'Hi sub-agent',
        'agent-id': 'agent-2',
      };

      final message = ClientMessage.fromJson(json);

      expect(message, isA<UserMessage>());
      final userMsg = message as UserMessage;
      expect(userMsg.content, 'Hi sub-agent');
      expect(userMsg.agentId, 'agent-2');
    });

    test('fromJson parses permission-response', () {
      final json = {
        'type': 'permission-response',
        'request-id': 'req-123',
        'allow': true,
      };

      final message = ClientMessage.fromJson(json);

      expect(message, isA<PermissionResponse>());
      final permMsg = message as PermissionResponse;
      expect(permMsg.requestId, 'req-123');
      expect(permMsg.allow, true);
      expect(permMsg.message, isNull);
    });

    test('fromJson parses permission-response with deny', () {
      final json = {
        'type': 'permission-response',
        'request-id': 'req-456',
        'allow': false,
        'message': 'User declined',
      };

      final message = ClientMessage.fromJson(json);

      expect(message, isA<PermissionResponse>());
      final permMsg = message as PermissionResponse;
      expect(permMsg.allow, false);
      expect(permMsg.message, 'User declined');
    });

    test('fromJson parses abort', () {
      final json = {'type': 'abort'};

      final message = ClientMessage.fromJson(json);

      expect(message, isA<AbortMessage>());
    });

    test('fromJson parses ask-user-question-response', () {
      final json = {
        'type': 'ask-user-question-response',
        'request-id': 'ask-1',
        'answers': {'Pick one': 'A'},
      };

      final message = ClientMessage.fromJson(json);

      expect(message, isA<AskUserQuestionResponseMessage>());
      final ask = message as AskUserQuestionResponseMessage;
      expect(ask.requestId, 'ask-1');
      expect(ask.answers, {'Pick one': 'A'});
    });

    test('fromJson parses session-command', () {
      final json = {
        'type': 'session-command',
        'request-id': 'cmd-1',
        'command': 'fork-agent',
        'data': {'agent-id': 'main'},
      };

      final message = ClientMessage.fromJson(json);

      expect(message, isA<SessionCommandMessage>());
      final command = message as SessionCommandMessage;
      expect(command.requestId, 'cmd-1');
      expect(command.command, 'fork-agent');
      expect(command.data, {'agent-id': 'main'});
    });

    test('fromJson throws on unknown type', () {
      final json = {'type': 'unknown-type'};

      expect(() => ClientMessage.fromJson(json), throwsA(isA<ArgumentError>()));
    });
  });

  group('SessionEvent', () {
    test('message event has correct kebab-case format', () {
      final event = SessionEvent.message(
        seq: 5,
        eventId: 'evt-123',
        agentId: 'agent-1',
        agentType: 'main',
        agentName: 'Main Agent',
        taskName: 'Test task',
        role: 'assistant',
        content: 'Hello!',
        isPartial: true,
      );

      final json = event.toJson();

      expect(json['seq'], 5);
      expect(json['event-id'], 'evt-123');
      expect(json['type'], 'message');
      expect(json['agent-id'], 'agent-1');
      expect(json['agent-type'], 'main');
      expect(json['agent-name'], 'Main Agent');
      expect(json['task-name'], 'Test task');
      expect(json['is-partial'], true);
      expect(json['data']['role'], 'assistant');
      expect(json['data']['content'], 'Hello!');
      expect(json['timestamp'], isNotEmpty);
    });

    test('tool-use event has correct format', () {
      final event = SessionEvent.toolUse(
        seq: 10,
        agentId: 'agent-1',
        agentType: 'implementation',
        agentName: 'Code Writer',
        toolUseId: 'tool-1',
        toolName: 'Bash',
        toolInput: {'command': 'ls -la'},
      );

      final json = event.toJson();

      expect(json['seq'], 10);
      expect(json['type'], 'tool-use');
      expect(json['data']['tool-use-id'], 'tool-1');
      expect(json['data']['tool-name'], 'Bash');
      expect(json['data']['tool-input'], {'command': 'ls -la'});
    });

    test('tool-result event has correct format', () {
      final event = SessionEvent.toolResult(
        seq: 11,
        agentId: 'agent-1',
        agentType: 'implementation',
        toolUseId: 'tool-1',
        toolName: 'Bash',
        result: 'file1.txt\nfile2.txt',
        isError: false,
      );

      final json = event.toJson();

      expect(json['type'], 'tool-result');
      expect(json['data']['tool-use-id'], 'tool-1');
      expect(json['data']['tool-name'], 'Bash');
      expect(json['data']['result'], 'file1.txt\nfile2.txt');
      expect(json['data']['is-error'], false);
    });

    test('done event has correct format', () {
      final event = SessionEvent.done(
        seq: 20,
        agentId: 'agent-1',
        agentType: 'main',
        agentName: 'Main Agent',
      );

      final json = event.toJson();

      expect(json['type'], 'done');
      expect(json['data']['reason'], 'complete');
    });

    test('agent-spawned event has correct format', () {
      final event = SessionEvent.agentSpawned(
        seq: 7,
        agentId: 'agent-2',
        agentType: 'implementation',
        agentName: 'Code Writer',
        spawnedBy: 'agent-1',
      );

      final json = event.toJson();

      expect(json['type'], 'agent-spawned');
      expect(json['agent-id'], 'agent-2');
      expect(json['data']['spawned-by'], 'agent-1');
    });

    test('agent-terminated event has correct format', () {
      final event = SessionEvent.agentTerminated(
        seq: 15,
        agentId: 'agent-2',
        agentType: 'implementation',
        agentName: 'Code Writer',
        terminatedBy: 'agent-1',
        reason: 'Task complete',
      );

      final json = event.toJson();

      expect(json['type'], 'agent-terminated');
      expect(json['data']['terminated-by'], 'agent-1');
      expect(json['data']['reason'], 'Task complete');
    });

    test('error event has correct format', () {
      final event = SessionEvent.error(
        seq: 12,
        agentId: 'server',
        agentType: 'system',
        message: 'Unknown message type',
        code: 'UNKNOWN_MESSAGE_TYPE',
        originalMessage: {'type': 'foo'},
      );

      final json = event.toJson();

      expect(json['type'], 'error');
      expect(json['data']['message'], 'Unknown message type');
      expect(json['data']['code'], 'UNKNOWN_MESSAGE_TYPE');
      expect(json['data']['original-message'], {'type': 'foo'});
    });
  });

  group('ConnectedEvent', () {
    test('has correct kebab-case format', () {
      final event = ConnectedEvent(
        sessionId: 'sess-123',
        mainAgentId: 'agent-1',
        lastSeq: 0,
        agents: [AgentInfo(id: 'agent-1', type: 'main', name: 'Main Agent')],
        metadata: {'working-directory': '/path/to/project'},
      );

      final json = event.toJson();

      expect(json['type'], 'connected');
      expect(json['session-id'], 'sess-123');
      expect(json['main-agent-id'], 'agent-1');
      expect(json['last-seq'], 0);
      expect(json['agents'], hasLength(1));
      expect(json['agents'][0]['id'], 'agent-1');
      expect(json['agents'][0]['type'], 'main');
      expect(json['agents'][0]['name'], 'Main Agent');
      expect(json['metadata']['working-directory'], '/path/to/project');
    });
  });

  group('HistoryEvent', () {
    test('has correct format', () {
      final event = HistoryEvent(
        lastSeq: 42,
        events: [
          {'seq': 1, 'type': 'message'},
          {'seq': 2, 'type': 'tool-use'},
        ],
      );

      final json = event.toJson();

      expect(json['type'], 'history');
      expect(json['last-seq'], 42);
      expect(json['data']['events'], hasLength(2));
    });
  });

  group('SequenceGenerator', () {
    test('starts at 0 and increments', () {
      final gen = SequenceGenerator();

      expect(gen.current, 0);
      expect(gen.next(), 1);
      expect(gen.current, 1);
      expect(gen.next(), 2);
      expect(gen.next(), 3);
      expect(gen.current, 3);
    });
  });
}
