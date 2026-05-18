/// Integration tests for session state recovery and reconnection.
///
/// Tests verify:
/// 1. New client receives full history on connect
/// 2. Reconnecting client receives history and deduplicates
/// 3. Sequence numbers are consistent across reconnects
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
  late int port;
  late String baseUrl;

  setUpAll(() async {
    // Start the server
    port = testPortBase + reconnectionTestOffset;
    baseUrl = 'http://127.0.0.1:$port';

    serverProcess = await Process.start('dart', [
      'run',
      'bin/vide_server.dart',
      '--port',
      '$port',
    ], workingDirectory: Directory.current.path);

    // Wait for server to be ready
    final completer = Completer<void>();
    serverProcess.stdout.transform(utf8.decoder).listen((data) {
      stdout.writeln('[Server stdout] $data');
      if (data.contains('Server ready')) {
        if (!completer.isCompleted) completer.complete();
      }
    });
    serverProcess.stderr.transform(utf8.decoder).listen((data) {
      stderr.writeln('[Server stderr] $data');
    });

    await completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw Exception('Server failed to start'),
    );
  });

  tearDownAll(() async {
    serverProcess.kill();
    await serverProcess.exitCode;
  });

  group('Session state recovery', () {
    test('reconnecting client receives history with all events', () async {
      // Step 1: Create a session
      final createResponse = await http.post(
        Uri.parse('$baseUrl/api/v1/sessions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'initial-message': 'Say exactly: Hello World',
          'working-directory': Directory.current.path,
        }),
      );

      expect(createResponse.statusCode, 200);
      final sessionData = jsonDecode(createResponse.body);
      final sessionId = sessionData['session-id'];

      // Step 2: Connect first client and wait for some events
      final wsUrl = 'ws://127.0.0.1:$port/api/v1/sessions/$sessionId/stream';
      final channel1 = WebSocketChannel.connect(Uri.parse(wsUrl));

      final firstClientEvents = <Map<String, dynamic>>[];
      final doneCompleter = Completer<void>();

      channel1.stream.listen(
        (message) {
          final event = jsonDecode(message as String) as Map<String, dynamic>;
          firstClientEvents.add(event);

          // Wait for done event
          if (event['type'] == 'done') {
            if (!doneCompleter.isCompleted) doneCompleter.complete();
          }
        },
        onError: (error) {
          if (!doneCompleter.isCompleted) {
            doneCompleter.completeError(error);
          }
        },
      );

      // Wait for conversation to complete
      await doneCompleter.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw Exception('First client timed out'),
      );

      // Get the last sequence number from first client
      final firstClientLastSeq = firstClientEvents
          .where((e) => e['seq'] != null)
          .map((e) => e['seq'] as int)
          .fold<int>(0, (a, b) => a > b ? a : b);

      // Step 3: Disconnect first client
      await channel1.sink.close();

      // Step 4: Connect second client (simulating reconnect)
      final channel2 = WebSocketChannel.connect(Uri.parse(wsUrl));

      Map<String, dynamic>? historyEvent;
      final reconnectCompleter = Completer<void>();

      channel2.stream.listen(
        (message) {
          final event = jsonDecode(message as String) as Map<String, dynamic>;
          if (event['type'] == 'history') {
            historyEvent = event;
            reconnectCompleter.complete();
          }
        },
        onError: (error) {
          if (!reconnectCompleter.isCompleted) {
            reconnectCompleter.completeError(error);
          }
        },
      );

      await reconnectCompleter.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Reconnecting client timed out'),
      );

      // Verify history event
      expect(historyEvent, isNotNull);
      expect(
        historyEvent!['last-seq'],
        greaterThanOrEqualTo(firstClientLastSeq),
      );

      final historyData = historyEvent!['data'] as Map<String, dynamic>;
      final events = historyData['events'] as List<dynamic>;

      // Verify we got events
      expect(events, isNotEmpty);

      // Verify events have sequence numbers
      for (final e in events) {
        final event = e as Map<String, dynamic>;
        expect(event['seq'], isA<int>());
        expect(event['type'], isA<String>());
      }

      // Verify sequence numbers are sequential
      final seqs = events
          .map((e) => (e as Map<String, dynamic>)['seq'] as int)
          .toList();
      for (var i = 1; i < seqs.length; i++) {
        expect(
          seqs[i],
          greaterThan(seqs[i - 1]),
          reason: 'Sequence numbers should be increasing',
        );
      }

      await channel2.sink.close();
    });

    test('history includes last-seq for client deduplication', () async {
      // Create a session
      final createResponse = await http.post(
        Uri.parse('$baseUrl/api/v1/sessions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'initial-message': 'Reply with just: OK',
          'working-directory': Directory.current.path,
        }),
      );

      expect(createResponse.statusCode, 200);
      final sessionData = jsonDecode(createResponse.body);
      final sessionId = sessionData['session-id'];

      // Connect and wait for done
      final wsUrl = 'ws://127.0.0.1:$port/api/v1/sessions/$sessionId/stream';
      final channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      Map<String, dynamic>? historyEvent;
      Map<String, dynamic>? connectedEvent;
      final doneCompleter = Completer<void>();

      channel.stream.listen(
        (message) {
          final event = jsonDecode(message as String) as Map<String, dynamic>;
          if (event['type'] == 'connected') {
            connectedEvent = event;
          } else if (event['type'] == 'history') {
            historyEvent = event;
          } else if (event['type'] == 'done') {
            if (!doneCompleter.isCompleted) doneCompleter.complete();
          }
        },
        onError: (error) {
          if (!doneCompleter.isCompleted) {
            doneCompleter.completeError(error);
          }
        },
      );

      await doneCompleter.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw Exception('Timed out waiting for done'),
      );

      // Verify connected event has last-seq
      expect(connectedEvent, isNotNull);
      expect(connectedEvent!['last-seq'], isA<int>());

      // Verify history event has last-seq
      expect(historyEvent, isNotNull);
      expect(historyEvent!['last-seq'], isA<int>());

      await channel.sink.close();
    });

    test('new session starts with empty history', () async {
      // Create a fresh session
      final createResponse = await http.post(
        Uri.parse('$baseUrl/api/v1/sessions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'initial-message': 'Say: test',
          'working-directory': Directory.current.path,
        }),
      );

      expect(createResponse.statusCode, 200);
      final sessionData = jsonDecode(createResponse.body);
      final sessionId = sessionData['session-id'];

      // Connect immediately
      final wsUrl = 'ws://127.0.0.1:$port/api/v1/sessions/$sessionId/stream';
      final channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      Map<String, dynamic>? historyEvent;
      final historyCompleter = Completer<void>();

      channel.stream.listen(
        (message) {
          final event = jsonDecode(message as String) as Map<String, dynamic>;
          if (event['type'] == 'history') {
            historyEvent = event;
            historyCompleter.complete();
          }
        },
        onError: (error) {
          if (!historyCompleter.isCompleted) {
            historyCompleter.completeError(error);
          }
        },
      );

      await historyCompleter.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Timed out waiting for history'),
      );

      // For a new session, history should be empty initially
      // (events are added as they occur, not pre-populated)
      expect(historyEvent, isNotNull);
      expect(historyEvent!['last-seq'], 0);

      final historyData = historyEvent!['data'] as Map<String, dynamic>;
      final events = historyData['events'] as List<dynamic>;
      expect(events, isEmpty);

      await channel.sink.close();
    });
  });
}
