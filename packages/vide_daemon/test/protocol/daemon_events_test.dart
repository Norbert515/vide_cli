import 'dart:convert';

import 'package:test/test.dart';
import 'package:vide_daemon/src/protocol/daemon_events.dart';
import 'package:vide_daemon/src/protocol/daemon_messages.dart';

void main() {
  group('DaemonEvent.fromJson', () {
    test('parses session-created event', () {
      final json = {
        'type': 'session-created',
        'session-id': 'test-session',
        'working-directory': '/test/dir',
        'ws-url': 'ws://localhost:8080/stream',
        'http-url': 'http://localhost:8080',
        'port': 8080,
        'created-at': '2024-01-15T10:30:00.000Z',
      };

      final event = DaemonEvent.fromJson(json);

      expect(event, isA<SessionCreatedEvent>());
      final created = event as SessionCreatedEvent;
      expect(created.sessionId, 'test-session');
      expect(created.workingDirectory, '/test/dir');
    });

    test('parses session-stopped event', () {
      final json = {
        'type': 'session-stopped',
        'session-id': 'stopped-session',
        'reason': 'user-request',
      };

      final event = DaemonEvent.fromJson(json);

      expect(event, isA<SessionStoppedEvent>());
      final stopped = event as SessionStoppedEvent;
      expect(stopped.sessionId, 'stopped-session');
      expect(stopped.reason, 'user-request');
    });

    test('parses session-health event', () {
      final json = {
        'type': 'session-health',
        'session-id': 'health-session',
        'state': 'ready',
      };

      final event = DaemonEvent.fromJson(json);

      expect(event, isA<SessionHealthEvent>());
      final health = event as SessionHealthEvent;
      expect(health.sessionId, 'health-session');
      expect(health.state, SessionProcessState.ready);
    });

    test('parses daemon-status event', () {
      final json = {
        'type': 'daemon-status',
        'session-count': 5,
        'started-at': '2024-01-01T00:00:00.000Z',
        'version': '0.1.0',
      };

      final event = DaemonEvent.fromJson(json);

      expect(event, isA<DaemonStatusEvent>());
      final status = event as DaemonStatusEvent;
      expect(status.sessionCount, 5);
      expect(status.version, '0.1.0');
    });

    test('throws on unknown event type', () {
      final json = {
        'type': 'unknown-event',
        'data': 'something',
      };

      expect(
        () => DaemonEvent.fromJson(json),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('SessionCreatedEvent', () {
    test('serializes to JSON', () {
      final event = SessionCreatedEvent(
        sessionId: 'created-session',
        workingDirectory: '/work/dir',
        wsUrl: 'ws://localhost:9000/stream',
        httpUrl: 'http://localhost:9000',
        port: 9000,
        createdAt: DateTime.utc(2024, 2, 20, 14, 45),
      );

      final json = event.toJson();

      expect(json['type'], 'session-created');
      expect(json['session-id'], 'created-session');
      expect(json['working-directory'], '/work/dir');
      expect(json['ws-url'], 'ws://localhost:9000/stream');
      expect(json['http-url'], 'http://localhost:9000');
      expect(json['port'], 9000);
      expect(json['created-at'], '2024-02-20T14:45:00.000Z');
    });

    test('deserializes from JSON', () {
      final json = {
        'type': 'session-created',
        'session-id': 'parsed-session',
        'working-directory': '/parsed/dir',
        'ws-url': 'ws://127.0.0.1:5555/stream',
        'http-url': 'http://127.0.0.1:5555',
        'port': 5555,
        'created-at': '2024-03-10T08:00:00.000Z',
      };

      final event = SessionCreatedEvent.fromJson(json);

      expect(event.type, 'session-created');
      expect(event.sessionId, 'parsed-session');
      expect(event.workingDirectory, '/parsed/dir');
      expect(event.wsUrl, 'ws://127.0.0.1:5555/stream');
      expect(event.httpUrl, 'http://127.0.0.1:5555');
      expect(event.port, 5555);
      expect(event.createdAt, DateTime.utc(2024, 3, 10, 8));
    });

    test('toJsonString produces valid JSON', () {
      final event = SessionCreatedEvent(
        sessionId: 'json-string-test',
        workingDirectory: '/json/test',
        wsUrl: 'ws://localhost:1234/stream',
        httpUrl: 'http://localhost:1234',
        port: 1234,
        createdAt: DateTime.utc(2024, 4, 15),
      );

      final jsonString = event.toJsonString();
      final parsed = jsonDecode(jsonString) as Map<String, dynamic>;

      expect(parsed['type'], 'session-created');
      expect(parsed['session-id'], 'json-string-test');
    });

    test('round-trips through JSON', () {
      final original = SessionCreatedEvent(
        sessionId: 'roundtrip-session',
        workingDirectory: '/roundtrip/dir',
        wsUrl: 'ws://localhost:7777/stream',
        httpUrl: 'http://localhost:7777',
        port: 7777,
        createdAt: DateTime.utc(2024, 5, 1, 12, 30),
      );

      final json = original.toJson();
      final restored = SessionCreatedEvent.fromJson(json);

      expect(restored.sessionId, original.sessionId);
      expect(restored.workingDirectory, original.workingDirectory);
      expect(restored.wsUrl, original.wsUrl);
      expect(restored.httpUrl, original.httpUrl);
      expect(restored.port, original.port);
      expect(restored.createdAt, original.createdAt);
    });
  });

  group('SessionStoppedEvent', () {
    test('serializes to JSON with required fields', () {
      final event = SessionStoppedEvent(sessionId: 'stopped-id');

      final json = event.toJson();

      expect(json['type'], 'session-stopped');
      expect(json['session-id'], 'stopped-id');
      expect(json.containsKey('reason'), isFalse);
      expect(json.containsKey('exit-code'), isFalse);
    });

    test('serializes to JSON with all fields', () {
      final event = SessionStoppedEvent(
        sessionId: 'crashed-session',
        reason: 'crash',
        exitCode: 1,
      );

      final json = event.toJson();

      expect(json['type'], 'session-stopped');
      expect(json['session-id'], 'crashed-session');
      expect(json['reason'], 'crash');
      expect(json['exit-code'], 1);
    });

    test('deserializes from JSON with required fields', () {
      final json = {
        'type': 'session-stopped',
        'session-id': 'basic-stop',
      };

      final event = SessionStoppedEvent.fromJson(json);

      expect(event.sessionId, 'basic-stop');
      expect(event.reason, isNull);
      expect(event.exitCode, isNull);
    });

    test('deserializes from JSON with all fields', () {
      final json = {
        'type': 'session-stopped',
        'session-id': 'full-stop',
        'reason': 'health-check-failed',
        'exit-code': 137,
      };

      final event = SessionStoppedEvent.fromJson(json);

      expect(event.sessionId, 'full-stop');
      expect(event.reason, 'health-check-failed');
      expect(event.exitCode, 137);
    });

    test('round-trips through JSON', () {
      final original = SessionStoppedEvent(
        sessionId: 'roundtrip-stop',
        reason: 'user-request',
        exitCode: 0,
      );

      final json = original.toJson();
      final restored = SessionStoppedEvent.fromJson(json);

      expect(restored.sessionId, original.sessionId);
      expect(restored.reason, original.reason);
      expect(restored.exitCode, original.exitCode);
    });
  });

  group('SessionHealthEvent', () {
    test('serializes to JSON with required fields', () {
      final event = SessionHealthEvent(
        sessionId: 'health-session',
        state: SessionProcessState.ready,
      );

      final json = event.toJson();

      expect(json['type'], 'session-health');
      expect(json['session-id'], 'health-session');
      expect(json['state'], 'ready');
      expect(json.containsKey('error'), isFalse);
    });

    test('serializes to JSON with error', () {
      final event = SessionHealthEvent(
        sessionId: 'error-session',
        state: SessionProcessState.error,
        error: 'Health check timeout',
      );

      final json = event.toJson();

      expect(json['type'], 'session-health');
      expect(json['session-id'], 'error-session');
      expect(json['state'], 'error');
      expect(json['error'], 'Health check timeout');
    });

    test('deserializes from JSON', () {
      final json = {
        'type': 'session-health',
        'session-id': 'parsed-health',
        'state': 'starting',
      };

      final event = SessionHealthEvent.fromJson(json);

      expect(event.sessionId, 'parsed-health');
      expect(event.state, SessionProcessState.starting);
      expect(event.error, isNull);
    });

    test('deserializes all states', () {
      for (final state in SessionProcessState.values) {
        final json = {
          'type': 'session-health',
          'session-id': 'state-test',
          'state': state.name,
        };

        final event = SessionHealthEvent.fromJson(json);
        expect(event.state, state);
      }
    });

    test('round-trips through JSON', () {
      final original = SessionHealthEvent(
        sessionId: 'roundtrip-health',
        state: SessionProcessState.stopping,
        error: 'Shutting down gracefully',
      );

      final json = original.toJson();
      final restored = SessionHealthEvent.fromJson(json);

      expect(restored.sessionId, original.sessionId);
      expect(restored.state, original.state);
      expect(restored.error, original.error);
    });
  });

  group('DaemonStatusEvent', () {
    test('serializes to JSON', () {
      final event = DaemonStatusEvent(
        sessionCount: 10,
        startedAt: DateTime.utc(2024, 1, 1, 0, 0),
        version: '1.0.0',
      );

      final json = event.toJson();

      expect(json['type'], 'daemon-status');
      expect(json['session-count'], 10);
      expect(json['started-at'], '2024-01-01T00:00:00.000Z');
      expect(json['version'], '1.0.0');
    });

    test('deserializes from JSON', () {
      final json = {
        'type': 'daemon-status',
        'session-count': 3,
        'started-at': '2024-06-15T18:30:00.000Z',
        'version': '2.0.0',
      };

      final event = DaemonStatusEvent.fromJson(json);

      expect(event.sessionCount, 3);
      expect(event.startedAt, DateTime.utc(2024, 6, 15, 18, 30));
      expect(event.version, '2.0.0');
    });

    test('toJsonString produces valid JSON', () {
      final event = DaemonStatusEvent(
        sessionCount: 0,
        startedAt: DateTime.utc(2024, 7, 1),
        version: '0.1.0',
      );

      final jsonString = event.toJsonString();
      final parsed = jsonDecode(jsonString) as Map<String, dynamic>;

      expect(parsed['type'], 'daemon-status');
      expect(parsed['session-count'], 0);
    });

    test('round-trips through JSON', () {
      final original = DaemonStatusEvent(
        sessionCount: 42,
        startedAt: DateTime.utc(2024, 8, 15, 9, 45, 30),
        version: '3.2.1',
      );

      final json = original.toJson();
      final restored = DaemonStatusEvent.fromJson(json);

      expect(restored.sessionCount, original.sessionCount);
      expect(restored.startedAt, original.startedAt);
      expect(restored.version, original.version);
    });
  });

  group('Event type property', () {
    test('SessionCreatedEvent has correct type', () {
      final event = SessionCreatedEvent(
        sessionId: 'type-test',
        workingDirectory: '/test',
        wsUrl: 'ws://localhost/stream',
        httpUrl: 'http://localhost',
        port: 8080,
        createdAt: DateTime.now(),
      );
      expect(event.type, 'session-created');
    });

    test('SessionStoppedEvent has correct type', () {
      final event = SessionStoppedEvent(sessionId: 'type-test');
      expect(event.type, 'session-stopped');
    });

    test('SessionHealthEvent has correct type', () {
      final event = SessionHealthEvent(
        sessionId: 'type-test',
        state: SessionProcessState.ready,
      );
      expect(event.type, 'session-health');
    });

    test('DaemonStatusEvent has correct type', () {
      final event = DaemonStatusEvent(
        sessionCount: 0,
        startedAt: DateTime.now(),
        version: '0.1.0',
      );
      expect(event.type, 'daemon-status');
    });
  });
}
