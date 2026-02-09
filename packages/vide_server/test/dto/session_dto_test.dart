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
      expect(request.attachments, isNull);
    });

    test('fromJson parses attachments', () {
      final json = {
        'initial-message': 'Check this image',
        'working-directory': '/path',
        'attachments': [
          {
            'type': 'image',
            'file-path': '/path/to/screenshot.png',
            'mime-type': 'image/png',
          },
        ],
      };

      final request = CreateSessionRequest.fromJson(json);

      expect(request.attachments, isNotNull);
      expect(request.attachments, hasLength(1));
      expect(request.attachments![0].type, 'image');
      expect(request.attachments![0].filePath, '/path/to/screenshot.png');
      expect(request.attachments![0].mimeType, 'image/png');
      expect(request.attachments![0].content, isNull);
    });

    test('fromJson parses multiple attachments including base64', () {
      final json = {
        'initial-message': 'Multiple images',
        'working-directory': '/path',
        'attachments': [
          {
            'type': 'image',
            'file-path': '/path/to/a.png',
            'mime-type': 'image/png',
          },
          {
            'type': 'image',
            'content': 'iVBORw0KGgo=',
            'mime-type': 'image/jpeg',
          },
        ],
      };

      final request = CreateSessionRequest.fromJson(json);

      expect(request.attachments, hasLength(2));
      expect(request.attachments![0].filePath, '/path/to/a.png');
      expect(request.attachments![0].content, isNull);
      expect(request.attachments![1].filePath, isNull);
      expect(request.attachments![1].content, 'iVBORw0KGgo=');
      expect(request.attachments![1].mimeType, 'image/jpeg');
    });

    test('fromJson with empty attachments list', () {
      final json = {
        'initial-message': 'Hello',
        'working-directory': '/path',
        'attachments': <Map<String, dynamic>>[],
      };

      final request = CreateSessionRequest.fromJson(json);

      expect(request.attachments, isNotNull);
      expect(request.attachments, isEmpty);
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

    test('fromJson parses user-message without attachments', () {
      final json = {
        'type': 'user-message',
        'content': 'No attachments here',
      };

      final message = ClientMessage.fromJson(json) as UserMessage;

      expect(message.content, 'No attachments here');
      expect(message.attachments, isNull);
    });

    test('fromJson parses user-message with image attachment', () {
      final json = {
        'type': 'user-message',
        'content': 'Check this image',
        'attachments': [
          {
            'type': 'image',
            'file-path': '/path/to/screenshot.png',
            'mime-type': 'image/png',
          },
        ],
      };

      final message = ClientMessage.fromJson(json) as UserMessage;

      expect(message.content, 'Check this image');
      expect(message.attachments, isNotNull);
      expect(message.attachments, hasLength(1));
      expect(message.attachments![0].type, 'image');
      expect(message.attachments![0].filePath, '/path/to/screenshot.png');
      expect(message.attachments![0].mimeType, 'image/png');
      expect(message.attachments![0].content, isNull);
    });

    test('fromJson parses user-message with base64 image attachment', () {
      final json = {
        'type': 'user-message',
        'content': 'Pasted image',
        'attachments': [
          {
            'type': 'image',
            'content': 'iVBORw0KGgoAAAANS',
            'mime-type': 'image/png',
          },
        ],
      };

      final message = ClientMessage.fromJson(json) as UserMessage;

      expect(message.attachments, hasLength(1));
      expect(message.attachments![0].type, 'image');
      expect(message.attachments![0].filePath, isNull);
      expect(message.attachments![0].content, 'iVBORw0KGgoAAAANS');
      expect(message.attachments![0].mimeType, 'image/png');
    });

    test('fromJson parses user-message with multiple attachments', () {
      final json = {
        'type': 'user-message',
        'content': 'Multiple images',
        'attachments': [
          {
            'type': 'image',
            'file-path': '/path/to/a.png',
            'mime-type': 'image/png',
          },
          {
            'type': 'image',
            'file-path': '/path/to/b.jpg',
            'mime-type': 'image/jpeg',
          },
        ],
      };

      final message = ClientMessage.fromJson(json) as UserMessage;

      expect(message.attachments, hasLength(2));
      expect(message.attachments![0].filePath, '/path/to/a.png');
      expect(message.attachments![1].filePath, '/path/to/b.jpg');
      expect(message.attachments![1].mimeType, 'image/jpeg');
    });

    test('fromJson parses user-message with empty attachments list', () {
      final json = {
        'type': 'user-message',
        'content': 'Empty list',
        'attachments': <Map<String, dynamic>>[],
      };

      final message = ClientMessage.fromJson(json) as UserMessage;

      expect(message.attachments, isNotNull);
      expect(message.attachments, isEmpty);
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

  group('Attachment round-trip (client serialization → server deserialization)',
      () {
    test('image file attachment survives round-trip', () {
      // Simulate what vide_client Session.sendMessage() produces
      final clientJson = {
        'type': 'user-message',
        'content': 'Check this',
        'attachments': [
          {
            'type': 'image',
            'file-path': '/Users/me/screenshot.png',
            'mime-type': 'image/png',
          },
        ],
      };

      // Server parses it
      final message = ClientMessage.fromJson(clientJson) as UserMessage;

      expect(message.attachments, hasLength(1));
      final att = message.attachments![0];
      expect(att.type, 'image');
      expect(att.filePath, '/Users/me/screenshot.png');
      expect(att.mimeType, 'image/png');
      expect(att.content, isNull);
    });

    test('base64 image attachment survives round-trip', () {
      final clientJson = {
        'type': 'user-message',
        'content': 'Pasted',
        'attachments': [
          {
            'type': 'image',
            'content': 'base64encodeddata==',
            'mime-type': 'image/jpeg',
          },
        ],
      };

      final message = ClientMessage.fromJson(clientJson) as UserMessage;

      expect(message.attachments, hasLength(1));
      final att = message.attachments![0];
      expect(att.type, 'image');
      expect(att.filePath, isNull);
      expect(att.content, 'base64encodeddata==');
      expect(att.mimeType, 'image/jpeg');
    });

    test('attachment with only required type field survives round-trip', () {
      final clientJson = {
        'type': 'user-message',
        'content': 'Minimal',
        'attachments': [
          {'type': 'file'},
        ],
      };

      final message = ClientMessage.fromJson(clientJson) as UserMessage;

      expect(message.attachments, hasLength(1));
      final att = message.attachments![0];
      expect(att.type, 'file');
      expect(att.filePath, isNull);
      expect(att.content, isNull);
      expect(att.mimeType, isNull);
    });

    test('no attachments field results in null', () {
      final clientJson = {
        'type': 'user-message',
        'content': 'Just text',
      };

      final message = ClientMessage.fromJson(clientJson) as UserMessage;

      expect(message.attachments, isNull);
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
