import 'package:test/test.dart';
import 'package:vide_daemon/src/protocol/daemon_messages.dart';

void main() {
  group('SessionProcessState', () {
    test('has expected values', () {
      expect(SessionProcessState.values, hasLength(4));
      expect(
        SessionProcessState.values,
        contains(SessionProcessState.starting),
      );
      expect(SessionProcessState.values, contains(SessionProcessState.ready));
      expect(SessionProcessState.values, contains(SessionProcessState.error));
      expect(
        SessionProcessState.values,
        contains(SessionProcessState.stopping),
      );
    });
  });

  group('CreateSessionRequest', () {
    test('serializes to JSON with required fields', () {
      final request = CreateSessionRequest(
        initialMessage: 'Hello',
        workingDirectory: '/path/to/project',
      );

      final json = request.toJson();

      expect(json['initial-message'], 'Hello');
      expect(json['working-directory'], '/path/to/project');
      expect(json['model'], isNull);
      expect(json['permission-mode'], isNull);
      expect(json['team'], isNull);
    });

    test('serializes to JSON with all fields', () {
      final request = CreateSessionRequest(
        initialMessage: 'Hello',
        workingDirectory: '/path/to/project',
        model: 'sonnet',
        permissionMode: 'auto',
        team: 'enterprise',
      );

      final json = request.toJson();

      expect(json['initial-message'], 'Hello');
      expect(json['working-directory'], '/path/to/project');
      expect(json['model'], 'sonnet');
      expect(json['permission-mode'], 'auto');
      expect(json['team'], 'enterprise');
    });

    test('deserializes from JSON with required fields', () {
      final json = {
        'initial-message': 'Test message',
        'working-directory': '/test/path',
      };

      final request = CreateSessionRequest.fromJson(json);

      expect(request.initialMessage, 'Test message');
      expect(request.workingDirectory, '/test/path');
      expect(request.model, isNull);
      expect(request.permissionMode, isNull);
      expect(request.team, isNull);
    });

    test('deserializes from JSON with all fields', () {
      final json = {
        'initial-message': 'Test message',
        'working-directory': '/test/path',
        'model': 'opus',
        'permission-mode': 'manual',
        'team': 'startup',
      };

      final request = CreateSessionRequest.fromJson(json);

      expect(request.initialMessage, 'Test message');
      expect(request.workingDirectory, '/test/path');
      expect(request.model, 'opus');
      expect(request.permissionMode, 'manual');
      expect(request.team, 'startup');
    });

    test('round-trips through JSON', () {
      final original = CreateSessionRequest(
        initialMessage: 'Round trip test',
        workingDirectory: '/round/trip',
        model: 'haiku',
        permissionMode: 'auto',
        team: 'balanced',
      );

      final json = original.toJson();
      final restored = CreateSessionRequest.fromJson(json);

      expect(restored.initialMessage, original.initialMessage);
      expect(restored.workingDirectory, original.workingDirectory);
      expect(restored.model, original.model);
      expect(restored.permissionMode, original.permissionMode);
      expect(restored.team, original.team);
    });

    test('serializes without attachments', () {
      final request = CreateSessionRequest(
        initialMessage: 'Hello',
        workingDirectory: '/path',
      );

      final json = request.toJson();

      expect(json['attachments'], isNull);
    });

    test('serializes with attachments', () {
      final request = CreateSessionRequest(
        initialMessage: 'Check this',
        workingDirectory: '/path',
        attachments: [
          {
            'type': 'image',
            'file-path': '/path/to/screenshot.png',
            'mime-type': 'image/png',
          },
        ],
      );

      final json = request.toJson();

      expect(json['attachments'], hasLength(1));
      final att = json['attachments'][0] as Map<String, dynamic>;
      expect(att['type'], 'image');
      expect(att['file-path'], '/path/to/screenshot.png');
      expect(att['mime-type'], 'image/png');
    });

    test('deserializes attachments from JSON', () {
      final json = {
        'initial-message': 'Image attached',
        'working-directory': '/path',
        'attachments': [
          {
            'type': 'image',
            'file-path': '/path/to/img.png',
            'mime-type': 'image/png',
          },
          {
            'type': 'image',
            'content': 'base64data==',
            'mime-type': 'image/jpeg',
          },
        ],
      };

      final request = CreateSessionRequest.fromJson(json);

      expect(request.attachments, hasLength(2));
      expect(request.attachments![0]['type'], 'image');
      expect(request.attachments![0]['file-path'], '/path/to/img.png');
      expect(request.attachments![1]['content'], 'base64data==');
    });

    test('round-trips attachments through JSON', () {
      final original = CreateSessionRequest(
        initialMessage: 'With image',
        workingDirectory: '/path',
        attachments: [
          {
            'type': 'image',
            'file-path': '/screenshot.png',
            'mime-type': 'image/png',
          },
        ],
      );

      final json = original.toJson();
      final restored = CreateSessionRequest.fromJson(json);

      expect(restored.attachments, hasLength(1));
      expect(restored.attachments![0]['type'], 'image');
      expect(restored.attachments![0]['file-path'], '/screenshot.png');
      expect(restored.attachments![0]['mime-type'], 'image/png');
    });
  });

  group('CreateSessionResponse', () {
    test('serializes to JSON', () {
      final createdAt = DateTime.utc(2024, 1, 15, 10, 30);
      final response = CreateSessionResponse(
        sessionId: 'session-123',
        mainAgentId: 'agent-456',
        wsUrl: 'ws://localhost:8080/stream',
        httpUrl: 'http://localhost:8080',
        port: 8080,
        createdAt: createdAt,
      );

      final json = response.toJson();

      expect(json['session-id'], 'session-123');
      expect(json['main-agent-id'], 'agent-456');
      expect(json['ws-url'], 'ws://localhost:8080/stream');
      expect(json['http-url'], 'http://localhost:8080');
      expect(json['port'], 8080);
      expect(json['created-at'], createdAt.toIso8601String());
    });

    test('deserializes from JSON', () {
      final json = {
        'session-id': 'session-789',
        'main-agent-id': 'agent-abc',
        'ws-url': 'ws://localhost:9000/stream',
        'http-url': 'http://localhost:9000',
        'port': 9000,
        'created-at': '2024-02-20T14:45:00.000Z',
      };

      final response = CreateSessionResponse.fromJson(json);

      expect(response.sessionId, 'session-789');
      expect(response.mainAgentId, 'agent-abc');
      expect(response.wsUrl, 'ws://localhost:9000/stream');
      expect(response.httpUrl, 'http://localhost:9000');
      expect(response.port, 9000);
      expect(response.createdAt, DateTime.utc(2024, 2, 20, 14, 45));
    });

    test('round-trips through JSON', () {
      final original = CreateSessionResponse(
        sessionId: 'round-trip-session',
        mainAgentId: 'round-trip-agent',
        wsUrl: 'ws://127.0.0.1:5555/stream',
        httpUrl: 'http://127.0.0.1:5555',
        port: 5555,
        createdAt: DateTime.utc(2024, 3, 10, 8, 0),
      );

      final json = original.toJson();
      final restored = CreateSessionResponse.fromJson(json);

      expect(restored.sessionId, original.sessionId);
      expect(restored.mainAgentId, original.mainAgentId);
      expect(restored.wsUrl, original.wsUrl);
      expect(restored.httpUrl, original.httpUrl);
      expect(restored.port, original.port);
      expect(restored.createdAt, original.createdAt);
    });
  });

  group('SessionSummary', () {
    test('serializes to JSON with required fields', () {
      final summary = SessionSummary(
        sessionId: 'summary-session',
        workingDirectory: '/work/dir',
        createdAt: DateTime.utc(2024, 1, 1),
        state: SessionProcessState.ready,
        connectedClients: 1,
        port: 3000,
      );

      final json = summary.toJson();

      expect(json['session-id'], 'summary-session');
      expect(json['working-directory'], '/work/dir');
      expect(json['created-at'], '2024-01-01T00:00:00.000Z');
      expect(json['state'], 'ready');
      expect(json['connected-clients'], 1);
      expect(json['port'], 3000);
    });

    test('deserializes from JSON', () {
      final json = {
        'session-id': 'parsed-session',
        'working-directory': '/parsed/dir',
        'created-at': '2024-05-15T12:00:00.000Z',
        'state': 'error',
        'connected-clients': 2,
        'port': 6000,
      };

      final summary = SessionSummary.fromJson(json);

      expect(summary.sessionId, 'parsed-session');
      expect(summary.workingDirectory, '/parsed/dir');
      expect(summary.createdAt, DateTime.utc(2024, 5, 15, 12));
      expect(summary.state, SessionProcessState.error);
      expect(summary.connectedClients, 2);
      expect(summary.port, 6000);
    });
  });

  group('ListSessionsResponse', () {
    test('serializes empty list', () {
      final response = ListSessionsResponse(sessions: []);

      final json = response.toJson();

      expect(json['sessions'], isEmpty);
    });

    test('serializes list with sessions', () {
      final response = ListSessionsResponse(
        sessions: [
          SessionSummary(
            sessionId: 'session-1',
            workingDirectory: '/path/1',
            createdAt: DateTime.utc(2024, 1, 1),
            state: SessionProcessState.ready,
            connectedClients: 0,
            port: 8001,
          ),
          SessionSummary(
            sessionId: 'session-2',
            workingDirectory: '/path/2',
            createdAt: DateTime.utc(2024, 1, 2),
            state: SessionProcessState.starting,
            connectedClients: 1,
            port: 8002,
          ),
        ],
      );

      final json = response.toJson();

      expect(json['sessions'], hasLength(2));
      // Note: The generated toJson() returns the List<SessionSummary> directly,
      // not a List<Map>. This is the expected behavior from json_serializable.
      final sessions = json['sessions'] as List<SessionSummary>;
      expect(sessions[0].sessionId, 'session-1');
      expect(sessions[1].sessionId, 'session-2');
    });

    test('deserializes from JSON', () {
      final json = {
        'sessions': [
          {
            'session-id': 'deserialized-1',
            'working-directory': '/des/1',
            'created-at': '2024-06-01T00:00:00.000Z',
            'state': 'ready',
            'connected-clients': 0,
            'port': 9001,
          },
        ],
      };

      final response = ListSessionsResponse.fromJson(json);

      expect(response.sessions, hasLength(1));
      expect(response.sessions[0].sessionId, 'deserialized-1');
      expect(response.sessions[0].state, SessionProcessState.ready);
    });
  });

  group('SessionDetailsResponse', () {
    test('serializes to JSON', () {
      final details = SessionDetailsResponse(
        sessionId: 'details-session',
        workingDirectory: '/details/dir',
        wsUrl: 'ws://localhost:7000/stream',
        httpUrl: 'http://localhost:7000',
        port: 7000,
        createdAt: DateTime.utc(2024, 4, 1),
        state: SessionProcessState.ready,
        connectedClients: 3,
        pid: 12345,
      );

      final json = details.toJson();

      expect(json['session-id'], 'details-session');
      expect(json['working-directory'], '/details/dir');
      expect(json['ws-url'], 'ws://localhost:7000/stream');
      expect(json['http-url'], 'http://localhost:7000');
      expect(json['port'], 7000);
      expect(json['created-at'], '2024-04-01T00:00:00.000Z');
      expect(json['state'], 'ready');
      expect(json['connected-clients'], 3);
      expect(json['pid'], 12345);
    });

    test('deserializes from JSON', () {
      final json = {
        'session-id': 'parsed-details',
        'working-directory': '/parsed/details',
        'ws-url': 'ws://localhost:8888/stream',
        'http-url': 'http://localhost:8888',
        'port': 8888,
        'created-at': '2024-07-01T09:00:00.000Z',
        'state': 'stopping',
        'connected-clients': 0,
        'pid': 54321,
      };

      final details = SessionDetailsResponse.fromJson(json);

      expect(details.sessionId, 'parsed-details');
      expect(details.workingDirectory, '/parsed/details');
      expect(details.wsUrl, 'ws://localhost:8888/stream');
      expect(details.httpUrl, 'http://localhost:8888');
      expect(details.port, 8888);
      expect(details.createdAt, DateTime.utc(2024, 7, 1, 9));
      expect(details.state, SessionProcessState.stopping);
      expect(details.connectedClients, 0);
      expect(details.pid, 54321);
    });
  });

  group('PersistedSessionState', () {
    test('serializes to JSON', () {
      final state = PersistedSessionState(
        sessionId: 'persisted-session',
        port: 5000,
        workingDirectory: '/persisted/dir',
        createdAt: DateTime.utc(2024, 8, 1),
        pid: 99999,
        initialMessage: 'Hello daemon',
        model: 'sonnet',
        permissionMode: 'auto',
        team: 'enterprise',
      );

      final json = state.toJson();

      expect(json['session-id'], 'persisted-session');
      expect(json['port'], 5000);
      expect(json['working-directory'], '/persisted/dir');
      expect(json['created-at'], '2024-08-01T00:00:00.000Z');
      expect(json['pid'], 99999);
      expect(json['initial-message'], 'Hello daemon');
      expect(json['model'], 'sonnet');
      expect(json['permission-mode'], 'auto');
      expect(json['team'], 'enterprise');
    });

    test('deserializes from JSON', () {
      final json = {
        'session-id': 'restored-session',
        'port': 6000,
        'working-directory': '/restored/dir',
        'created-at': '2024-09-15T18:00:00.000Z',
        'pid': 11111,
        'initial-message': 'Restored message',
      };

      final state = PersistedSessionState.fromJson(json);

      expect(state.sessionId, 'restored-session');
      expect(state.port, 6000);
      expect(state.workingDirectory, '/restored/dir');
      expect(state.createdAt, DateTime.utc(2024, 9, 15, 18));
      expect(state.pid, 11111);
      expect(state.initialMessage, 'Restored message');
      expect(state.model, isNull);
      expect(state.permissionMode, isNull);
      expect(state.team, isNull);
    });

    test('round-trips through JSON', () {
      final original = PersistedSessionState(
        sessionId: 'roundtrip-session',
        port: 7777,
        workingDirectory: '/roundtrip',
        createdAt: DateTime.utc(2024, 10, 10, 10, 10),
        pid: 77777,
        initialMessage: 'Round trip',
        model: 'haiku',
        permissionMode: 'manual',
        team: 'startup',
      );

      final json = original.toJson();
      final restored = PersistedSessionState.fromJson(json);

      expect(restored.sessionId, original.sessionId);
      expect(restored.port, original.port);
      expect(restored.workingDirectory, original.workingDirectory);
      expect(restored.createdAt, original.createdAt);
      expect(restored.pid, original.pid);
      expect(restored.initialMessage, original.initialMessage);
      expect(restored.model, original.model);
      expect(restored.permissionMode, original.permissionMode);
      expect(restored.team, original.team);
    });
  });

  group('DaemonState', () {
    test('creates empty state', () {
      final state = DaemonState.empty();

      expect(state.sessions, isEmpty);
      expect(state.lastUpdated, isNotNull);
    });

    test('serializes to JSON', () {
      final state = DaemonState(
        sessions: [
          PersistedSessionState(
            sessionId: 'state-session',
            port: 4444,
            workingDirectory: '/state/dir',
            createdAt: DateTime.utc(2024, 11, 1),
            pid: 44444,
            initialMessage: 'State test',
          ),
        ],
        lastUpdated: DateTime.utc(2024, 11, 1, 12),
      );

      final json = state.toJson();

      expect(json['sessions'], hasLength(1));
      // Note: The generated toJson() returns the List<PersistedSessionState> directly,
      // not a List<Map>. This is the expected behavior from json_serializable.
      final sessions = json['sessions'] as List<PersistedSessionState>;
      expect(sessions[0].sessionId, 'state-session');
      expect(json['last-updated'], '2024-11-01T12:00:00.000Z');
    });

    test('deserializes from JSON', () {
      final json = {
        'sessions': [
          {
            'session-id': 'json-session',
            'port': 3333,
            'working-directory': '/json/dir',
            'created-at': '2024-12-01T00:00:00.000Z',
            'pid': 33333,
            'initial-message': 'JSON test',
          },
        ],
        'last-updated': '2024-12-01T06:00:00.000Z',
      };

      final state = DaemonState.fromJson(json);

      expect(state.sessions, hasLength(1));
      expect(state.sessions[0].sessionId, 'json-session');
      expect(state.lastUpdated, DateTime.utc(2024, 12, 1, 6));
    });
  });
}
