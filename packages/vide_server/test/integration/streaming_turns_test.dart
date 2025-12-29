@Tags(['integration'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../test_config.dart';

/// Test to verify streaming behavior - counts how many updates arrive
/// for a prompt that should generate multiple streaming chunks.
void main() {
  late Process serverProcess;
  late int port;
  late String baseUrl;

  setUpAll(() async {
    // Start the server
    port = testPortBase + streamingTurnsTestOffset;
    baseUrl = 'http://127.0.0.1:$port';

    serverProcess = await Process.start(
      'dart',
      ['run', 'bin/vide_server.dart', '--port', '$port'],
      workingDirectory: Directory.current.path,
    );

    // Wait for server to be ready
    final completer = Completer<void>();
    serverProcess.stdout.transform(utf8.decoder).listen((data) {
      print('[Server] $data');
      if (data.contains('Server ready')) {
        if (!completer.isCompleted) completer.complete();
      }
    });
    serverProcess.stderr.transform(utf8.decoder).listen((data) {
      print('[Server stderr] $data');
    });

    await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('Server failed to start'),
    );
  });

  tearDownAll(() async {
    serverProcess.kill();
    await serverProcess.exitCode;
  });

  test('streaming response generates multiple updates', () async {
    // Create network with haiku prompt
    final createResponse = await http.post(
      Uri.parse('$baseUrl/api/v1/networks'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'initialMessage': '5 haikus on the fall of the US empire',
        'workingDirectory': Directory.current.path,
      }),
    );

    expect(createResponse.statusCode, equals(200));
    final networkData = jsonDecode(createResponse.body);
    final networkId = networkData['networkId'];
    final mainAgentId = networkData['mainAgentId'];

    // Connect to WebSocket
    final wsUrl =
        'ws://127.0.0.1:$port/api/v1/networks/$networkId/agents/$mainAgentId/stream';
    final channel = WebSocketChannel.connect(Uri.parse(wsUrl));

    // Track events
    var messageEvents = 0;
    var messageDeltaEvents = 0;
    var totalEvents = 0;
    final allEvents = <Map<String, dynamic>>[];
    final completer = Completer<void>();

    channel.stream.listen(
      (message) {
        final event = jsonDecode(message as String) as Map<String, dynamic>;
        allEvents.add(event);
        totalEvents++;

        final type = event['type'];
        if (type == 'message') {
          final role = event['data']?['role'];
          if (role == 'assistant') {
            messageEvents++;
          }
        } else if (type == 'message_delta') {
          messageDeltaEvents++;
        } else if (type == 'done') {
          if (!completer.isCompleted) completer.complete();
        }
      },
      onError: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
    );

    // Wait for response with timeout
    await completer.future.timeout(
      const Duration(seconds: 120),
      onTimeout: () => throw Exception('Timeout waiting for response'),
    );

    await channel.sink.close();

    // Report results
    print('');
    print('═══════════════════════════════════════════════════════════');
    print('STREAMING TEST RESULTS');
    print('═══════════════════════════════════════════════════════════');
    print('Total events received: $totalEvents');
    print('Assistant message events: $messageEvents');
    print('Message delta events: $messageDeltaEvents');
    print('Total streaming updates: ${messageEvents + messageDeltaEvents}');
    print('');
    print('Event breakdown:');
    final eventCounts = <String, int>{};
    for (final event in allEvents) {
      final type = event['type'] as String;
      eventCounts[type] = (eventCounts[type] ?? 0) + 1;
    }
    for (final entry in eventCounts.entries) {
      print('  ${entry.key}: ${entry.value}');
    }
    print('═══════════════════════════════════════════════════════════');

    // The key assertion: there should be more than 1 streaming update
    // (either multiple message events or message + deltas)
    final streamingUpdates = messageEvents + messageDeltaEvents;
    expect(
      streamingUpdates,
      greaterThan(1),
      reason: 'Expected multiple streaming updates, got $streamingUpdates. '
          'This indicates responses are not being streamed incrementally.',
    );
  }, timeout: Timeout(Duration(seconds: 180)));
}
