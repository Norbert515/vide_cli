/// Integration tests for Phase 2.5 session-based API
///
/// These tests verify the new session endpoints with:
/// - kebab-case JSON format
/// - Multiplexed WebSocket streaming
/// - Sequence numbers and event IDs
/// - Bidirectional messaging (user-message, abort)
///
/// Requirements:
/// - Tests make real API calls to Claude
@Tags(['integration'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../test_config.dart';

void main() {
  late Process serverProcess;
  late String serverDir;
  const port = testPortBase + sessionApiTestOffset;

  setUpAll(() async {
    // Kill any leftover server from previous test runs
    if (Platform.isMacOS || Platform.isLinux) {
      await Process.run('pkill', ['-f', 'vide_server.dart']);
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Find the vide_server package directory
    final scriptPath = Platform.script.toFilePath();
    if (scriptPath.contains('vide_server')) {
      final idx = scriptPath.indexOf('vide_server');
      serverDir = scriptPath.substring(0, idx + 'vide_server'.length);
    } else {
      serverDir = Directory.current.path;
      if (!serverDir.endsWith('vide_server')) {
        final tryPath = '${Directory.current.path}/packages/vide_server';
        if (Directory(tryPath).existsSync()) {
          serverDir = tryPath;
        }
      }
    }

    // Start the server
    serverProcess = await Process.start('dart', [
      'run',
      'bin/vide_server.dart',
      '--port',
      '$port',
    ], workingDirectory: serverDir);

    final completer = Completer<void>();

    serverProcess.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          stdout.writeln('[Server stdout] $line');
          if (line.contains('Server ready') && !completer.isCompleted) {
            completer.complete();
          }
        });

    serverProcess.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          stderr.writeln('[Server stderr] $line');
        });

    await completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        serverProcess.kill();
        throw StateError('Server failed to start within 30 seconds');
      },
    );
  });

  tearDownAll(() async {
    serverProcess.kill();
    await serverProcess.exitCode;
  });

  group('Phase 2.5 Session API', () {
    test(
      'create session returns session-id and main-agent-id (kebab-case)',
      () async {
        final response = await http.post(
          Uri.parse('http://127.0.0.1:$port/api/v1/sessions'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'initial-message': 'Test message',
            'working-directory': Directory.current.path,
          }),
        );

        expect(response.statusCode, 200);

        final data = jsonDecode(response.body);
        expect(data['session-id'], isNotEmpty);
        expect(data['main-agent-id'], isNotEmpty);
        expect(data['created-at'], isNotEmpty);
      },
    );

    test('create session rejects empty working-directory', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:$port/api/v1/sessions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'initial-message': 'Test message',
          'working-directory': '',
        }),
      );

      expect(response.statusCode, 400);

      final data = jsonDecode(response.body);
      expect(data['error'], contains('working-directory'));
      expect(data['code'], 'INVALID_REQUEST');
    });

    test('create session rejects non-existent working-directory', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:$port/api/v1/sessions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'initial-message': 'Test message',
          'working-directory': '/path/that/does/not/exist',
        }),
      );

      expect(response.statusCode, 400);

      final data = jsonDecode(response.body);
      expect(data['code'], 'INVALID_WORKING_DIRECTORY');
    });

    test(
      'WebSocket stream sends connected and history events with correct format',
      () async {
        // Create session
        final createResponse = await http.post(
          Uri.parse('http://127.0.0.1:$port/api/v1/sessions'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'initial-message': 'What is 2+2? Reply with just the number.',
            'working-directory': Directory.current.path,
          }),
        );

        expect(createResponse.statusCode, 200);

        final sessionData = jsonDecode(createResponse.body);
        final sessionId = sessionData['session-id'];

        // Connect to WebSocket
        final wsUrl = 'ws://127.0.0.1:$port/api/v1/sessions/$sessionId/stream';
        final channel = WebSocketChannel.connect(Uri.parse(wsUrl));

        final events = <Map<String, dynamic>>[];
        final completer = Completer<void>();

        final subscription = channel.stream.listen(
          (message) {
            final event = jsonDecode(message as String) as Map<String, dynamic>;
            events.add(event);

            if (event['type'] == 'done') {
              completer.complete();
            }
            if (event['type'] == 'error') {
              stderr.writeln('[Test] Error event: ${event['data']}');
              completer.complete();
            }
          },
          onError: (error) {
            stderr.writeln('[Test] Stream error: $error');
            if (!completer.isCompleted) {
              completer.completeError(error);
            }
          },
          onDone: () {
            if (!completer.isCompleted) {
              completer.complete();
            }
          },
        );

        await completer.future.timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            fail(
              'Timeout waiting for response. Events received: ${events.map((e) => e['type']).toList()}',
            );
          },
        );

        await subscription.cancel();
        await channel.sink.close();

        // Verify connected event format (kebab-case)
        final connectedEvents = events.where((e) => e['type'] == 'connected');
        expect(connectedEvents, isNotEmpty, reason: 'Should have connected');

        final connected = connectedEvents.first;
        expect(connected['session-id'], isNotEmpty);
        expect(connected['main-agent-id'], isNotEmpty);
        expect(connected['last-seq'], isA<int>());
        expect(connected['agents'], isA<List>());
        expect(connected['metadata'], isA<Map>());
        expect(connected['metadata']['working-directory'], isNotEmpty);
        expect(connected['metadata']['goal'], isNotEmpty);
        expect(connected['metadata']['team'], isNotEmpty);

        // Verify history event format
        final historyEvents = events.where((e) => e['type'] == 'history');
        expect(historyEvents, isNotEmpty, reason: 'Should have history');

        final history = historyEvents.first;
        expect(history['last-seq'], isA<int>());
        expect(history['data'], isA<Map>());
        expect(history['data']['events'], isA<List>());
      },
      timeout: Timeout(Duration(seconds: 90)),
    );

    test(
      'message events have seq, event-id, is-partial, and kebab-case fields',
      () async {
        // Create session
        final createResponse = await http.post(
          Uri.parse('http://127.0.0.1:$port/api/v1/sessions'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'initial-message': 'Say "hello" only.',
            'working-directory': Directory.current.path,
          }),
        );

        final sessionData = jsonDecode(createResponse.body);
        final sessionId = sessionData['session-id'];

        // Connect to WebSocket
        final wsUrl = 'ws://127.0.0.1:$port/api/v1/sessions/$sessionId/stream';
        final channel = WebSocketChannel.connect(Uri.parse(wsUrl));

        final events = <Map<String, dynamic>>[];
        final completer = Completer<void>();

        final subscription = channel.stream.listen(
          (message) {
            final event = jsonDecode(message as String) as Map<String, dynamic>;
            events.add(event);

            if (event['type'] == 'done') {
              completer.complete();
            }
            if (event['type'] == 'error') {
              completer.complete();
            }
          },
          onError: (error) {
            if (!completer.isCompleted) {
              completer.completeError(error);
            }
          },
        );

        await completer.future.timeout(const Duration(seconds: 60));

        await subscription.cancel();
        await channel.sink.close();

        // Find message events (not connected/history)
        final messageEvents = events.where((e) => e['type'] == 'message');
        expect(messageEvents, isNotEmpty, reason: 'Should have message events');

        // Verify message event format
        for (final msg in messageEvents) {
          expect(msg['seq'], isA<int>(), reason: 'seq should be int');
          expect(msg['event-id'], isNotEmpty, reason: 'event-id required');
          expect(msg['is-partial'], isA<bool>(), reason: 'is-partial required');
          expect(msg['agent-id'], isNotEmpty, reason: 'agent-id required');
          expect(msg['agent-type'], isNotEmpty, reason: 'agent-type required');
          expect(msg['timestamp'], isNotEmpty, reason: 'timestamp required');
          expect(msg['data'], isA<Map>(), reason: 'data required');
          expect(msg['data']['role'], isNotEmpty, reason: 'role required');
          expect(msg['data']['content'], isNotNull, reason: 'content required');
        }

        // Verify sequence numbers are monotonically increasing
        final seqEvents = events.where((e) => e['seq'] != null).toList();
        for (var i = 1; i < seqEvents.length; i++) {
          expect(
            seqEvents[i]['seq'] as int,
            greaterThan(seqEvents[i - 1]['seq'] as int),
            reason: 'seq should be monotonically increasing',
          );
        }
      },
      timeout: Timeout(Duration(seconds: 90)),
    );

    test('done event has correct format', () async {
      final createResponse = await http.post(
        Uri.parse('http://127.0.0.1:$port/api/v1/sessions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'initial-message': 'Say "hi".',
          'working-directory': Directory.current.path,
        }),
      );

      final sessionData = jsonDecode(createResponse.body);
      final sessionId = sessionData['session-id'];

      final wsUrl = 'ws://127.0.0.1:$port/api/v1/sessions/$sessionId/stream';
      final channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      final events = <Map<String, dynamic>>[];
      final completer = Completer<void>();

      final subscription = channel.stream.listen((message) {
        final event = jsonDecode(message as String) as Map<String, dynamic>;
        events.add(event);
        if (event['type'] == 'done' || event['type'] == 'error') {
          completer.complete();
        }
      });

      await completer.future.timeout(const Duration(seconds: 60));

      await subscription.cancel();
      await channel.sink.close();

      final doneEvents = events.where((e) => e['type'] == 'done');
      expect(doneEvents, isNotEmpty, reason: 'Should have done event');

      final done = doneEvents.first;
      expect(done['seq'], isA<int>());
      expect(done['event-id'], isNotEmpty);
      expect(done['agent-id'], isNotEmpty);
      expect(done['agent-type'], isNotEmpty);
      expect(done['timestamp'], isNotEmpty);
      expect(done['data'], isA<Map>());
      expect(done['data']['reason'], 'complete');
    }, timeout: Timeout(Duration(seconds: 90)));

    test(
      'WebSocket accepts user-message and continues conversation',
      () async {
        final createResponse = await http.post(
          Uri.parse('http://127.0.0.1:$port/api/v1/sessions'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'initial-message': 'Remember the number 42.',
            'working-directory': Directory.current.path,
          }),
        );

        final sessionData = jsonDecode(createResponse.body);
        final sessionId = sessionData['session-id'];

        final wsUrl = 'ws://127.0.0.1:$port/api/v1/sessions/$sessionId/stream';
        final channel = WebSocketChannel.connect(Uri.parse(wsUrl));

        var turnCount = 0;
        final events = <Map<String, dynamic>>[];
        final completer = Completer<void>();

        final subscription = channel.stream.listen((message) {
          final event = jsonDecode(message as String) as Map<String, dynamic>;
          events.add(event);

          if (event['type'] == 'done') {
            turnCount++;
            if (turnCount == 1) {
              // After first turn completes, send follow-up message
              channel.sink.add(
                jsonEncode({
                  'type': 'user-message',
                  'content': 'What number did I ask you to remember?',
                }),
              );
            } else if (turnCount == 2) {
              // After second turn, we're done
              completer.complete();
            }
          }
          if (event['type'] == 'error') {
            completer.complete();
          }
        });

        await completer.future.timeout(const Duration(seconds: 120));

        await subscription.cancel();
        await channel.sink.close();

        // Should have at least 2 done events (one per turn)
        final doneEvents = events.where((e) => e['type'] == 'done').toList();
        expect(
          doneEvents.length,
          greaterThanOrEqualTo(2),
          reason: 'Should have 2 done events for 2 turns',
        );
      },
      timeout: Timeout(Duration(seconds: 150)),
    );
  });
}
