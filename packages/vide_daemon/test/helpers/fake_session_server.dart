import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Future<void> main(List<String> args) async {
  final port = _parseRequiredIntArg(args, '--port');
  var sessionCounter = 0;

  final router = Router();

  router.get('/health', (Request _) {
    return Response.ok(
      jsonEncode({'status': 'ok'}),
      headers: {'Content-Type': 'application/json'},
    );
  });

  router.post('/api/v1/sessions', (Request request) async {
    final payload =
        jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    if (!payload.containsKey('initial-message') ||
        !payload.containsKey('working-directory')) {
      return Response(
        400,
        body: jsonEncode({'error': 'missing required fields'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    sessionCounter += 1;
    final sessionId = 'fake-session-$sessionCounter';

    return Response(
      201,
      body: jsonEncode({
        'session-id': sessionId,
        'main-agent-id': 'fake-main-agent',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  });

  router.get('/api/v1/sessions/<sessionId>/stream', (
    Request request,
    String _,
  ) {
    return webSocketHandler((WebSocketChannel channel, String? protocol) {
      channel.stream.listen(
        (message) {
          channel.sink.add('echo:$message');
        },
        onDone: () {
          channel.sink.close();
        },
        onError: (_) {
          channel.sink.close();
        },
      );
    })(request);
  });

  final server = await shelf_io.serve(
    router.call,
    InternetAddress.loopbackIPv4,
    port,
  );

  await Future.any([
    ProcessSignal.sigterm.watch().first,
    ProcessSignal.sigint.watch().first,
  ]);
  await server.close(force: true);
}

int _parseRequiredIntArg(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) {
    stderr.writeln('Missing required argument: $name');
    exit(64);
  }
  return int.parse(args[index + 1]);
}
