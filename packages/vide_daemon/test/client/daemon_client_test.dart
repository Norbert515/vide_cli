import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:vide_daemon/src/client/daemon_client.dart';
import 'package:vide_daemon/src/protocol/daemon_messages.dart';

void main() {
  group('DaemonClient', () {
    group('URL construction', () {
      test('constructs correct base URL', () {
        final client = DaemonClient(host: '127.0.0.1', port: 8080);
        expect(client.host, '127.0.0.1');
        expect(client.port, 8080);
        client.close();
      });

      test('allows custom host', () {
        final client = DaemonClient(host: '192.168.1.100', port: 9000);
        expect(client.host, '192.168.1.100');
        expect(client.port, 9000);
        client.close();
      });
    });

    group('isHealthy', () {
      test('returns true when server responds with 200', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, '/health');
          return http.Response('{"status": "ok"}', 200);
        });

        final daemonClient = DaemonClient(port: 8080, httpClient: mockClient);

        final result = await daemonClient.isHealthy();

        expect(result, isTrue);
        daemonClient.close();
      });

      test('returns false when server responds with error', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"error": "internal"}', 500);
        });

        final daemonClient = DaemonClient(port: 8080, httpClient: mockClient);

        final result = await daemonClient.isHealthy();

        expect(result, isFalse);
        daemonClient.close();
      });

      test('returns false when connection fails', () async {
        final mockClient = MockClient((request) async {
          throw const SocketException('Connection refused');
        });

        final daemonClient = DaemonClient(port: 8080, httpClient: mockClient);

        final result = await daemonClient.isHealthy();

        expect(result, isFalse);
        daemonClient.close();
      });
    });

    group('getHealth', () {
      test('returns health data on success', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, '/health');
          return http.Response(
            jsonEncode({
              'status': 'ok',
              'version': '0.1.0',
              'session-count': 3,
              'uptime-seconds': 1000,
            }),
            200,
          );
        });

        final daemonClient = DaemonClient(port: 8080, httpClient: mockClient);

        final health = await daemonClient.getHealth();

        expect(health['status'], 'ok');
        expect(health['version'], '0.1.0');
        expect(health['session-count'], 3);
        expect(health['uptime-seconds'], 1000);
        daemonClient.close();
      });

      test('throws on non-200 response', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"error": "not found"}', 404);
        });

        final daemonClient = DaemonClient(port: 8080, httpClient: mockClient);

        expect(
          () => daemonClient.getHealth(),
          throwsA(isA<DaemonClientException>()),
        );
        daemonClient.close();
      });
    });

    group('createSession', () {
      test('creates session successfully', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, '/sessions');
          expect(request.method, 'POST');

          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['initial-message'], 'Hello');
          expect(body['working-directory'], '/test/dir');

          return http.Response(
            jsonEncode({
              'session-id': 'new-session-123',
              'main-agent-id': 'agent-456',
              'ws-url':
                  'ws://127.0.0.1:8080/api/v1/sessions/new-session-123/stream',
              'http-url': 'http://127.0.0.1:8080',
              'port': 8080,
              'created-at': '2024-01-15T10:30:00.000Z',
            }),
            201,
          );
        });

        final daemonClient = DaemonClient(port: 8080, httpClient: mockClient);

        final response = await daemonClient.createSession(
          initialMessage: 'Hello',
          workingDirectory: '/test/dir',
        );

        expect(response.sessionId, 'new-session-123');
        expect(response.mainAgentId, 'agent-456');
        expect(response.port, 8080);
        daemonClient.close();
      });

      test('includes optional parameters', () async {
        final mockClient = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['model'], 'sonnet');
          expect(body['permission-mode'], 'auto');
          expect(body['team'], 'enterprise');

          return http.Response(
            jsonEncode({
              'session-id': 'session-with-options',
              'main-agent-id': 'agent-789',
              'ws-url': 'ws://127.0.0.1:9000/stream',
              'http-url': 'http://127.0.0.1:9000',
              'port': 9000,
              'created-at': '2024-02-20T14:45:00.000Z',
            }),
            200,
          );
        });

        final daemonClient = DaemonClient(port: 9000, httpClient: mockClient);

        final response = await daemonClient.createSession(
          initialMessage: 'Test',
          workingDirectory: '/work',
          model: 'sonnet',
          permissionMode: 'auto',
          team: 'enterprise',
        );

        expect(response.sessionId, 'session-with-options');
        daemonClient.close();
      });

      test('throws on error response', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"error": "Invalid request"}', 400);
        });

        final daemonClient = DaemonClient(port: 8080, httpClient: mockClient);

        expect(
          () => daemonClient.createSession(
            initialMessage: 'Test',
            workingDirectory: '/test',
          ),
          throwsA(isA<DaemonClientException>()),
        );
        daemonClient.close();
      });
    });

    group('listSessions', () {
      test('returns empty list when no sessions', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, '/sessions');
          expect(request.method, 'GET');

          return http.Response(jsonEncode({'sessions': []}), 200);
        });

        final daemonClient = DaemonClient(port: 8080, httpClient: mockClient);

        final sessions = await daemonClient.listSessions();

        expect(sessions, isEmpty);
        daemonClient.close();
      });

      test('returns list of sessions', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'sessions': [
                {
                  'session-id': 'session-1',
                  'working-directory': '/path/1',
                  'created-at': '2024-01-01T00:00:00.000Z',
                  'agent-count': 1,
                  'state': 'ready',
                  'connected-clients': 0,
                  'port': 8001,
                },
                {
                  'session-id': 'session-2',
                  'working-directory': '/path/2',
                  'created-at': '2024-01-02T00:00:00.000Z',
                  'agent-count': 3,
                  'state': 'starting',
                  'connected-clients': 2,
                  'port': 8002,
                },
              ],
            }),
            200,
          );
        });

        final daemonClient = DaemonClient(port: 8080, httpClient: mockClient);

        final sessions = await daemonClient.listSessions();

        expect(sessions, hasLength(2));
        expect(sessions[0].sessionId, 'session-1');
        expect(sessions[0].state, SessionProcessState.ready);
        expect(sessions[1].sessionId, 'session-2');
        expect(sessions[1].agentCount, 3);
        daemonClient.close();
      });

      test('throws on error response', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"error": "Internal error"}', 500);
        });

        final daemonClient = DaemonClient(port: 8080, httpClient: mockClient);

        expect(
          () => daemonClient.listSessions(),
          throwsA(isA<DaemonClientException>()),
        );
        daemonClient.close();
      });
    });

    group('getSession', () {
      test('returns session details', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, '/sessions/test-session-id');
          expect(request.method, 'GET');

          return http.Response(
            jsonEncode({
              'session-id': 'test-session-id',
              'working-directory': '/test/path',
              'goal': 'Fix the bug',
              'ws-url': 'ws://127.0.0.1:8080/stream',
              'http-url': 'http://127.0.0.1:8080',
              'port': 8080,
              'created-at': '2024-03-15T10:00:00.000Z',
              'last-active-at': '2024-03-15T12:30:00.000Z',
              'state': 'ready',
              'connected-clients': 1,
              'pid': 12345,
            }),
            200,
          );
        });

        final daemonClient = DaemonClient(port: 8080, httpClient: mockClient);

        final details = await daemonClient.getSession('test-session-id');

        expect(details.sessionId, 'test-session-id');
        expect(details.goal, 'Fix the bug');
        expect(details.state, SessionProcessState.ready);
        expect(details.pid, 12345);
        daemonClient.close();
      });

      test('throws SessionNotFoundException on 404', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"error": "Session not found"}', 404);
        });

        final daemonClient = DaemonClient(port: 8080, httpClient: mockClient);

        expect(
          () => daemonClient.getSession('nonexistent-id'),
          throwsA(isA<SessionNotFoundException>()),
        );
        daemonClient.close();
      });

      test('throws DaemonClientException on other errors', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"error": "Internal error"}', 500);
        });

        final daemonClient = DaemonClient(port: 8080, httpClient: mockClient);

        expect(
          () => daemonClient.getSession('some-id'),
          throwsA(isA<DaemonClientException>()),
        );
        daemonClient.close();
      });
    });

    group('stopSession', () {
      test('stops session with graceful shutdown', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, '/sessions/session-to-stop');
          expect(request.method, 'DELETE');
          expect(request.url.queryParameters.containsKey('force'), isFalse);

          return http.Response(
            jsonEncode({'status': 'stopped', 'session-id': 'session-to-stop'}),
            200,
          );
        });

        final daemonClient = DaemonClient(port: 8080, httpClient: mockClient);

        // Should not throw
        await daemonClient.stopSession('session-to-stop');
        daemonClient.close();
      });

      test('stops session with force flag', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, '/sessions/session-to-kill');
          expect(request.url.queryParameters['force'], 'true');

          return http.Response(
            jsonEncode({'status': 'stopped', 'session-id': 'session-to-kill'}),
            200,
          );
        });

        final daemonClient = DaemonClient(port: 8080, httpClient: mockClient);

        await daemonClient.stopSession('session-to-kill', force: true);
        daemonClient.close();
      });

      test('throws SessionNotFoundException on 404', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"error": "Session not found"}', 404);
        });

        final daemonClient = DaemonClient(port: 8080, httpClient: mockClient);

        expect(
          () => daemonClient.stopSession('nonexistent'),
          throwsA(isA<SessionNotFoundException>()),
        );
        daemonClient.close();
      });

      test('throws DaemonClientException on other errors', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"error": "Internal error"}', 500);
        });

        final daemonClient = DaemonClient(port: 8080, httpClient: mockClient);

        expect(
          () => daemonClient.stopSession('some-id'),
          throwsA(isA<DaemonClientException>()),
        );
        daemonClient.close();
      });
    });

    group('authentication', () {
      test('includes auth token in headers when provided', () async {
        final mockClient = MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer test-token-123');

          return http.Response(jsonEncode({'sessions': []}), 200);
        });

        final daemonClient = DaemonClient(
          port: 8080,
          httpClient: mockClient,
          authToken: 'test-token-123',
        );

        await daemonClient.listSessions();
        daemonClient.close();
      });

      test('does not include auth header when token is null', () async {
        final mockClient = MockClient((request) async {
          expect(request.headers.containsKey('Authorization'), isFalse);

          return http.Response(jsonEncode({'sessions': []}), 200);
        });

        final daemonClient = DaemonClient(port: 8080, httpClient: mockClient);

        await daemonClient.listSessions();
        daemonClient.close();
      });
    });
  });

  group('DaemonClientException', () {
    test('toString includes message', () {
      final exception = DaemonClientException('Test error message');
      expect(exception.toString(), contains('Test error message'));
      expect(exception.toString(), contains('DaemonClientException'));
    });

    test('message is accessible', () {
      final exception = DaemonClientException('Specific error');
      expect(exception.message, 'Specific error');
    });
  });

  group('SessionNotFoundException', () {
    test('toString includes session ID', () {
      final exception = SessionNotFoundException('missing-session-id');
      expect(exception.toString(), contains('missing-session-id'));
    });

    test('sessionId is accessible', () {
      final exception = SessionNotFoundException('test-id');
      expect(exception.sessionId, 'test-id');
    });
  });
}
