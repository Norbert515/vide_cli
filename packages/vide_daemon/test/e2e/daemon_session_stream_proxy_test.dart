import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:vide_daemon/src/client/daemon_client.dart';
import 'package:vide_daemon/src/daemon/daemon_server.dart';
import 'package:vide_daemon/src/daemon/daemon_starter.dart';
import 'package:vide_daemon/src/daemon/session_registry.dart';

void main() {
  group('Daemon session stream proxy', () {
    Directory? stateDir;
    SessionRegistry? registry;
    DaemonServer? daemonServer;
    DaemonClient? daemonClient;
    late int daemonPort;

    const authToken = 'e2e-auth-token';
    final fakeServerScript = _resolveFakeSessionServerScriptPath();
    final fakeServerWorkingDirectory = p.normalize(
      p.join(p.dirname(fakeServerScript), '..', '..'),
    );

    setUp(() async {
      stateDir = await Directory.systemTemp.createTemp('vide-daemon-e2e-');
      daemonPort = await _findAvailablePort();

      registry = SessionRegistry(
        stateFilePath: p.join(stateDir!.path, 'state.json'),
        spawnConfig: SessionSpawnConfig(
          executable: Platform.resolvedExecutable,
          baseArgs: ['run', fakeServerScript],
        ),
      );

      daemonServer = DaemonServer(
        registry: registry!,
        port: daemonPort,
        authToken: authToken,
      );
      await daemonServer!.start();

      daemonClient = DaemonClient(
        host: '127.0.0.1',
        port: daemonPort,
        authToken: authToken,
      );
    });

    tearDown(() async {
      daemonClient?.close();
      if (daemonServer != null) {
        await daemonServer!.stop();
      }
      if (registry != null) {
        await registry!.dispose();
      }

      if (stateDir != null && stateDir!.existsSync()) {
        await stateDir!.delete(recursive: true);
      }
    });

    test(
      'rewrites session URLs to daemon proxy and forwards websocket data',
      () async {
        final client = daemonClient!;
        final created = await client.createSession(
          initialMessage: 'e2e test',
          workingDirectory: fakeServerWorkingDirectory,
        );

        final createdWsUri = Uri.parse(created.wsUrl);
        expect(createdWsUri.host, equals('127.0.0.1'));
        expect(createdWsUri.port, equals(daemonPort));
        expect(
          createdWsUri.path,
          equals('/sessions/${created.sessionId}/stream'),
        );
        expect(created.httpUrl, equals('http://127.0.0.1:$daemonPort'));

        final details = await client.getSession(created.sessionId);
        final detailsWsUri = Uri.parse(details.wsUrl);
        expect(detailsWsUri.host, equals('127.0.0.1'));
        expect(detailsWsUri.port, equals(daemonPort));
        expect(
          detailsWsUri.path,
          equals('/sessions/${created.sessionId}/stream'),
        );
        expect(details.httpUrl, equals('http://127.0.0.1:$daemonPort'));

        await expectLater(
          WebSocket.connect(details.wsUrl),
          throwsA(
            anyOf(
              isA<WebSocketException>(),
              isA<SocketException>(),
              isA<HttpException>(),
            ),
          ),
        );

        final authedWsUri = detailsWsUri.replace(
          queryParameters: {'token': authToken},
        );
        final socket = await WebSocket.connect(authedWsUri.toString());
        socket.add('ping');

        final echoed = await socket.first.timeout(const Duration(seconds: 5));
        expect(echoed, equals('echo:ping'));

        await socket.close();
        await client.stopSession(created.sessionId, force: true);
      },
    );
  });
}

Future<int> _findAvailablePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

String _resolveFakeSessionServerScriptPath() {
  final candidates = <String>[
    p.join(
      Directory.current.path,
      'packages',
      'vide_daemon',
      'test',
      'helpers',
      'fake_session_server.dart',
    ),
    p.join(
      Directory.current.path,
      'test',
      'helpers',
      'fake_session_server.dart',
    ),
  ];

  for (final candidate in candidates) {
    if (File(candidate).existsSync()) {
      return p.normalize(candidate);
    }
  }

  throw StateError(
    'Could not locate fake_session_server.dart from ${Directory.current.path}',
  );
}
