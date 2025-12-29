/// End-to-end integration tests for the Vide REST API
///
/// These tests start the server as a separate process and verify the full flow:
/// 1. Create a network via POST /api/v1/networks
/// 2. Connect to WebSocket stream
/// 3. Receive events from Claude Code
/// 4. Verify response structure
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
  const port = testPortBase + endToEndTestOffset;

  setUpAll(() async {
    // Kill any leftover server from previous test runs
    if (Platform.isMacOS || Platform.isLinux) {
      await Process.run('pkill', ['-f', 'vide_server.dart']);
      // Give the OS a moment to release the port
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Find the vide_server package directory (works whether run from IDE or CLI)
    final scriptPath = Platform.script.toFilePath();
    if (scriptPath.contains('vide_server')) {
      // Extract path up to and including vide_server
      final idx = scriptPath.indexOf('vide_server');
      serverDir = scriptPath.substring(0, idx + 'vide_server'.length);
    } else {
      // Fallback: assume we're in vide_server directory
      serverDir = Directory.current.path;
      if (!serverDir.endsWith('vide_server')) {
        // Try to find it relative to current directory
        final tryPath = '${Directory.current.path}/packages/vide_server';
        if (Directory(tryPath).existsSync()) {
          serverDir = tryPath;
        }
      }
    }

    // Start the server as a separate process with a fixed port
    serverProcess = await Process.start('dart', [
      'run',
      'bin/vide_server.dart',
      '--port',
      '$port',
    ], workingDirectory: serverDir);

    // Wait for server to be ready
    final completer = Completer<void>();

    serverProcess.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          // Forward all stdout to test output for debugging
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

    // Wait for server to be ready with timeout
    await completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        serverProcess.kill();
        throw StateError('Server failed to start within 30 seconds');
      },
    );
  });

  tearDownAll(() async {
    // Kill the server process
    serverProcess.kill();
    await serverProcess.exitCode;
  });

  group('End-to-end WebSocket API', () {
    test('health check returns OK', () async {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:$port/health'),
      );

      expect(response.statusCode, 200);
      expect(response.body, 'OK');
    });

    test('create network returns networkId and mainAgentId', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:$port/api/v1/networks'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'initialMessage': 'Test message',
          'workingDirectory': Directory.current.path,
        }),
      );

      expect(response.statusCode, 200);

      final data = jsonDecode(response.body);
      expect(data['networkId'], isNotEmpty);
      expect(data['mainAgentId'], isNotEmpty);
      expect(data['createdAt'], isNotEmpty);
    });

    test('create network rejects empty workingDirectory', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:$port/api/v1/networks'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'initialMessage': 'Test message',
          'workingDirectory': '',
        }),
      );

      expect(response.statusCode, 400);

      final data = jsonDecode(response.body);
      expect(data['error'], contains('workingDirectory'));
    });

    test(
      'full flow: create network and receive response from Claude via WebSocket',
      () async {
        // Step 1: Create network
        final createResponse = await http.post(
          Uri.parse('http://127.0.0.1:$port/api/v1/networks'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'initialMessage': 'What is 2+2? Reply with just the number.',
            'workingDirectory': Directory.current.path,
          }),
        );

        expect(createResponse.statusCode, 200);

        final networkData = jsonDecode(createResponse.body);
        final networkId = networkData['networkId'];
        final mainAgentId = networkData['mainAgentId'];

        // Step 2: Connect to WebSocket
        final wsUrl =
            'ws://127.0.0.1:$port/api/v1/networks/$networkId/agents/$mainAgentId/stream';
        final channel = WebSocketChannel.connect(Uri.parse(wsUrl));

        // Step 3: Collect events
        final events = <Map<String, dynamic>>[];
        final completer = Completer<void>();

        final subscription = channel.stream.listen(
          (message) {
            final event = jsonDecode(message as String) as Map<String, dynamic>;
            events.add(event);

            // Complete when we receive 'done' event
            if (event['type'] == 'done') {
              completer.complete();
            }
            // Also complete on error event
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

        // Wait for response with timeout
        await completer.future.timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            fail(
              'Timeout waiting for Claude response. Events received: ${events.map((e) => e['type']).toList()}',
            );
          },
        );

        await subscription.cancel();
        await channel.sink.close();

        // Step 4: Verify events
        expect(events, isNotEmpty, reason: 'Should receive at least one event');

        // Should have connected event first
        final connectedEvents = events.where((e) => e['type'] == 'connected');
        expect(
          connectedEvents,
          isNotEmpty,
          reason: 'Should have connected event',
        );

        // Should have at least one message from assistant
        final messageEvents = events.where((e) => e['type'] == 'message');
        expect(messageEvents, isNotEmpty, reason: 'Should have message event');

        // Verify assistant response contains expected content
        final assistantMessages = messageEvents.where(
          (e) => e['data'] != null && e['data']['role'] == 'assistant',
        );
        expect(
          assistantMessages,
          isNotEmpty,
          reason: 'Should have assistant message',
        );

        // Should have done event
        final doneEvents = events.where((e) => e['type'] == 'done');
        expect(doneEvents, isNotEmpty, reason: 'Should have done event');
      },
      timeout: Timeout(Duration(seconds: 90)),
    );

    test(
      'WebSocket receives events in correct order',
      () async {
        // Create network
        final createResponse = await http.post(
          Uri.parse('http://127.0.0.1:$port/api/v1/networks'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'initialMessage': 'Say "hello" and nothing else.',
            'workingDirectory': Directory.current.path,
          }),
        );

        final networkData = jsonDecode(createResponse.body);
        final networkId = networkData['networkId'];
        final mainAgentId = networkData['mainAgentId'];

        // Connect to WebSocket
        final wsUrl =
            'ws://127.0.0.1:$port/api/v1/networks/$networkId/agents/$mainAgentId/stream';
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

        // Verify order: connected should be first
        expect(
          events.first['type'],
          'connected',
          reason: 'First event should be connected',
        );

        // Verify order: done should be last
        expect(
          events.last['type'],
          'done',
          reason: 'Last event should be done',
        );

        // Should have at least one message event
        final messageEvents = events.where((e) => e['type'] == 'message');
        expect(messageEvents, isNotEmpty, reason: 'Should have message event');
      },
      timeout: Timeout(Duration(seconds: 90)),
    );

    test(
      'multi-turn conversation maintains context across messages',
      () async {
        // Step 1: Create network with initial message introducing information
        final createResponse = await http.post(
          Uri.parse('http://127.0.0.1:$port/api/v1/networks'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'initialMessage':
                'Remember this: my favorite color is blue. Just say OK.',
            'workingDirectory': Directory.current.path,
          }),
        );

        expect(createResponse.statusCode, 200);

        final networkData = jsonDecode(createResponse.body);
        final networkId = networkData['networkId'];
        final mainAgentId = networkData['mainAgentId'];

        // Step 2: Connect to WebSocket
        final wsUrl =
            'ws://127.0.0.1:$port/api/v1/networks/$networkId/agents/$mainAgentId/stream';
        final channel = WebSocketChannel.connect(Uri.parse(wsUrl));

        // Track turns and collect all events
        final allEvents = <Map<String, dynamic>>[];
        var turn1DoneCount = 0;
        var turn2DoneCount = 0;
        final turn1Completer = Completer<void>();
        final turn2Completer = Completer<void>();

        final subscription = channel.stream.listen(
          (message) {
            final event = jsonDecode(message as String) as Map<String, dynamic>;
            allEvents.add(event);

            // Count done events to track turns
            if (event['type'] == 'done') {
              if (turn1DoneCount == 0) {
                turn1DoneCount++;
                if (!turn1Completer.isCompleted) {
                  turn1Completer.complete();
                }
              } else if (turn2DoneCount == 0) {
                turn2DoneCount++;
                if (!turn2Completer.isCompleted) {
                  turn2Completer.complete();
                }
              }
            }

            // Complete on error
            if (event['type'] == 'error') {
              stderr.writeln('[Test] Error event: ${event['data']}');
              if (!turn1Completer.isCompleted) {
                turn1Completer.complete();
              }
              if (!turn2Completer.isCompleted) {
                turn2Completer.complete();
              }
            }
          },
          onError: (error) {
            stderr.writeln('[Test] Stream error: $error');
            if (!turn1Completer.isCompleted) {
              turn1Completer.completeError(error);
            }
            if (!turn2Completer.isCompleted) {
              turn2Completer.completeError(error);
            }
          },
        );

        // Wait for first turn to complete
        await turn1Completer.future.timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            fail(
              'Timeout waiting for first turn. Events: ${allEvents.map((e) => e['type']).toList()}',
            );
          },
        );

        // Verify first turn completed successfully
        expect(
          turn1DoneCount,
          1,
          reason: 'First turn should complete with one done event',
        );

        // Give a small delay to ensure first turn is fully processed
        await Future.delayed(Duration(milliseconds: 500));

        // Step 3: Send second message asking about remembered info
        final sendResponse = await http.post(
          Uri.parse(
            'http://127.0.0.1:$port/api/v1/networks/$networkId/messages',
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'content': 'What is my favorite color? Just tell me the color.',
          }),
        );

        expect(
          sendResponse.statusCode,
          200,
          reason: 'Second message should be accepted',
        );

        // Wait for second turn to complete
        await turn2Completer.future.timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            fail(
              'Timeout waiting for second turn. Events: ${allEvents.map((e) => e['type']).toList()}',
            );
          },
        );

        await subscription.cancel();
        await channel.sink.close();

        // Step 4: Verify second turn completed
        expect(
          turn2DoneCount,
          1,
          reason: 'Second turn should complete with one done event',
        );

        // Extract second turn events (everything after first done event)
        var foundFirstDone = false;
        final turn2Events = <Map<String, dynamic>>[];
        for (final event in allEvents) {
          if (foundFirstDone) {
            turn2Events.add(event);
          } else if (event['type'] == 'done') {
            foundFirstDone = true;
          }
        }

        // Verify we got events for second turn
        expect(
          turn2Events,
          isNotEmpty,
          reason: 'Should receive events for second turn',
        );

        // Get all assistant message content (including deltas) from turn 2
        final assistantContent = StringBuffer();

        for (final event in turn2Events) {
          if (event['type'] == 'message' &&
              event['data'] != null &&
              event['data']['role'] == 'assistant') {
            assistantContent.write(event['data']['content'] ?? '');
          } else if (event['type'] == 'message_delta' &&
              event['data'] != null) {
            assistantContent.write(event['data']['delta'] ?? '');
          }
        }

        final fullResponse = assistantContent.toString().toLowerCase();

        // Verify the response mentions the color from the first turn
        expect(
          fullResponse.contains('blue'),
          isTrue,
          reason:
              'Claude should remember the color from the first turn. Response: $fullResponse',
        );
      },
      timeout: Timeout(Duration(seconds: 180)),
    );

    test(
      'WebSocket streaming does not send duplicate content',
      () async {
        // This test verifies that when the server sends message + message_delta events,
        // the deltas don't overlap with the initial message content.
        //
        // Correct behavior:
        //   message: content="Hello"
        //   message_delta: delta=" world"
        //   Assembled: "Hello world"
        //
        // Incorrect (duplicate) behavior:
        //   message: content="Hello"
        //   message_delta: delta="Hello world"  (duplicates "Hello")
        //   Assembled: "HelloHello world"

        // Create network with a prompt that generates a moderate response
        final createResponse = await http.post(
          Uri.parse('http://127.0.0.1:$port/api/v1/networks'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'initialMessage': 'Count from 1 to 5, one number per line.',
            'workingDirectory': Directory.current.path,
          }),
        );

        expect(createResponse.statusCode, 200);

        final networkData = jsonDecode(createResponse.body);
        final networkId = networkData['networkId'];
        final mainAgentId = networkData['mainAgentId'];

        // Connect to WebSocket
        final wsUrl =
            'ws://127.0.0.1:$port/api/v1/networks/$networkId/agents/$mainAgentId/stream';
        final channel = WebSocketChannel.connect(Uri.parse(wsUrl));

        // Collect all events
        final events = <Map<String, dynamic>>[];
        final completer = Completer<void>();

        final subscription = channel.stream.listen(
          (message) {
            final event = jsonDecode(message as String) as Map<String, dynamic>;
            events.add(event);

            if (event['type'] == 'done' || event['type'] == 'error') {
              if (!completer.isCompleted) {
                completer.complete();
              }
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

        // Analyze streaming behavior for each assistant message
        // We build content incrementally and verify no duplicates
        String? currentMessageContent;
        final assembledContent = StringBuffer();
        var duplicateFound = false;
        String? duplicateDetails;

        for (final event in events) {
          final type = event['type'];
          final data = event['data'];

          if (type == 'message' &&
              data != null &&
              data['role'] == 'assistant') {
            // New assistant message started
            final content = data['content'] as String? ?? '';
            currentMessageContent = content;
            assembledContent.clear();
            assembledContent.write(content);
          } else if (type == 'message_delta' && data != null) {
            // Streaming delta - should NOT contain content already in assembledContent
            final delta = data['delta'] as String? ?? '';

            if (delta.isNotEmpty && currentMessageContent != null) {
              final currentAssembled = assembledContent.toString();

              // Check if the delta starts with any portion of what we already have
              // This would indicate duplicate content being sent
              if (currentAssembled.isNotEmpty &&
                  delta.startsWith(currentAssembled)) {
                duplicateFound = true;
                duplicateDetails =
                    'Delta "$delta" starts with already-received content "$currentAssembled"';
              }

              // Also check if entire delta is contained in what we have
              if (currentAssembled.contains(delta) && delta.length > 3) {
                duplicateFound = true;
                duplicateDetails =
                    'Delta "$delta" is already contained in assembled content "$currentAssembled"';
              }

              assembledContent.write(delta);
            }
          }
        }

        // If duplicates found, print detailed event info for debugging
        if (duplicateFound) {
          stderr.writeln('\n=== DUPLICATE CONTENT DETECTED ===');
          stderr.writeln('Events received (${events.length} total):');
          for (var i = 0; i < events.length; i++) {
            final e = events[i];
            final type = e['type'];
            final data = e['data'];
            if (type == 'message' && data != null) {
              final role = data['role'];
              final content = data['content'] as String? ?? '';
              stderr.writeln(
                '  [$i] message: role=$role, content="${content.replaceAll('\n', '\\n')}" (${content.length} chars)',
              );
            } else if (type == 'message_delta' && data != null) {
              final delta = data['delta'] as String? ?? '';
              stderr.writeln(
                '  [$i] message_delta: delta="${delta.replaceAll('\n', '\\n')}" (${delta.length} chars)',
              );
            } else {
              stderr.writeln('  [$i] $type');
            }
          }
          stderr.writeln('=================================\n');
        }

        // Verify no duplicates were found
        expect(
          duplicateFound,
          isFalse,
          reason: duplicateDetails ?? 'No duplicate content should be sent',
        );

        // Verify we actually received streaming content (message + deltas)
        final messageEvents = events
            .where((e) => e['type'] == 'message')
            .toList();
        final deltaEvents = events
            .where((e) => e['type'] == 'message_delta')
            .toList();

        expect(
          messageEvents,
          isNotEmpty,
          reason: 'Should receive message events',
        );
        // Note: deltas may or may not exist depending on response length and timing
        // The key is that IF deltas exist, they don't duplicate content

        // Final check: if we got both message and deltas, verify assembled content is reasonable
        if (deltaEvents.isNotEmpty) {
          final finalContent = assembledContent.toString().toLowerCase();
          // The response should contain numbers (since we asked to count)
          expect(
            finalContent.contains('1') || finalContent.contains('one'),
            isTrue,
            reason: 'Response should contain counting. Got: $finalContent',
          );
        }
      },
      timeout: Timeout(Duration(seconds: 90)),
    );

    test(
      'streaming with tool use does not produce duplicate content',
      () async {
        // Create network with a prompt that will trigger tool use (file read)
        final createResponse = await http.post(
          Uri.parse('http://127.0.0.1:$port/api/v1/networks'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'initialMessage':
                'Read the first 5 lines of the pubspec.yaml file in this directory and tell me the package name.',
            'workingDirectory': serverDir,
          }),
        );

        expect(createResponse.statusCode, equals(200));
        final networkData = jsonDecode(createResponse.body);
        final networkId = networkData['networkId'];
        final mainAgentId = networkData['mainAgentId'];

        // Connect to WebSocket
        final wsUri = Uri.parse(
          'ws://127.0.0.1:$port/api/v1/networks/$networkId/agents/$mainAgentId/stream',
        );
        final channel = WebSocketChannel.connect(wsUri);

        final events = <Map<String, dynamic>>[];
        final completer = Completer<void>();

        channel.stream.listen(
          (message) {
            final event = jsonDecode(message as String) as Map<String, dynamic>;
            events.add(event);

            if (event['type'] == 'done' || event['type'] == 'error') {
              if (!completer.isCompleted) {
                completer.complete();
              }
            }
          },
          onError: (e) {
            if (!completer.isCompleted) {
              completer.completeError(e);
            }
          },
        );

        await completer.future.timeout(
          const Duration(seconds: 120),
          onTimeout: () => throw StateError('Timeout waiting for response'),
        );

        await channel.sink.close();

        // Verify we received tool_use events
        final toolUseEvents = events
            .where((e) => e['type'] == 'tool_use')
            .toList();
        expect(
          toolUseEvents,
          isNotEmpty,
          reason:
              'Should receive tool_use events when Claude reads a file. Events: ${events.map((e) => e['type']).toList()}',
        );

        // Verify no duplicate content in message/delta events
        final messageEvents = events
            .where((e) => e['type'] == 'message')
            .toList();
        final deltaEvents = events
            .where((e) => e['type'] == 'message_delta')
            .toList();

        // Build content incrementally and check for duplicates
        final assembledContent = StringBuffer();
        var duplicateFound = false;
        String? duplicateDetails;

        for (final event in [...messageEvents, ...deltaEvents]) {
          if (event['type'] == 'message') {
            final content = event['data']?['content'] as String? ?? '';
            if (content.isNotEmpty) {
              if (assembledContent.isNotEmpty &&
                  content.startsWith(assembledContent.toString())) {
                duplicateFound = true;
                duplicateDetails =
                    'Message content appears to duplicate previous content';
                break;
              }
              assembledContent.write(content);
            }
          } else if (event['type'] == 'message_delta') {
            final delta = event['data']?['delta'] as String? ?? '';
            if (delta.isNotEmpty) {
              assembledContent.write(delta);
            }
          }
        }

        expect(
          duplicateFound,
          isFalse,
          reason:
              duplicateDetails ??
              'No duplicate content should be sent during tool use',
        );

        // Verify response mentions the package name
        final finalContent = assembledContent.toString().toLowerCase();
        expect(
          finalContent.contains('vide_server') || finalContent.contains('vide'),
          isTrue,
          reason:
              'Response should mention the package name from pubspec.yaml. Got: $finalContent',
        );
      },
      timeout: Timeout(Duration(seconds: 180)),
    );

    test(
      'streaming handles rapid sequential messages without duplicates',
      () async {
        // Create network
        final createResponse = await http.post(
          Uri.parse('http://127.0.0.1:$port/api/v1/networks'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'initialMessage': 'Say "FIRST" and nothing else.',
            'workingDirectory': serverDir,
          }),
        );

        expect(createResponse.statusCode, equals(200));
        final networkData = jsonDecode(createResponse.body);
        final networkId = networkData['networkId'];
        final mainAgentId = networkData['mainAgentId'];

        // Connect to WebSocket
        final wsUri = Uri.parse(
          'ws://127.0.0.1:$port/api/v1/networks/$networkId/agents/$mainAgentId/stream',
        );
        final channel = WebSocketChannel.connect(wsUri);

        final events = <Map<String, dynamic>>[];
        var doneCount = 0;
        final completer = Completer<void>();

        channel.stream.listen(
          (message) {
            final event = jsonDecode(message as String) as Map<String, dynamic>;
            events.add(event);

            if (event['type'] == 'done') {
              doneCount++;
              // Wait for two "done" events (one per turn)
              if (doneCount >= 2 && !completer.isCompleted) {
                completer.complete();
              }
            }
            if (event['type'] == 'error' && !completer.isCompleted) {
              completer.completeError(
                StateError('Error: ${event['data']?['message']}'),
              );
            }
          },
          onError: (e) {
            if (!completer.isCompleted) {
              completer.completeError(e);
            }
          },
        );

        // Wait for first response
        await Future.delayed(const Duration(seconds: 5));

        // Send second message
        final sendResponse = await http.post(
          Uri.parse(
            'http://127.0.0.1:$port/api/v1/networks/$networkId/messages',
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'content': 'Now say "SECOND" and nothing else.'}),
        );
        expect(sendResponse.statusCode, equals(200));

        await completer.future.timeout(
          const Duration(seconds: 120),
          onTimeout: () => throw StateError('Timeout waiting for responses'),
        );

        await channel.sink.close();

        // Count assistant message events
        final assistantMessages = events
            .where(
              (e) =>
                  e['type'] == 'message' && e['data']?['role'] == 'assistant',
            )
            .toList();

        // Should have at least 2 assistant messages (one per turn)
        expect(
          assistantMessages.length,
          greaterThanOrEqualTo(2),
          reason:
              'Should have at least 2 assistant messages for 2 turns. Got: ${assistantMessages.length}',
        );

        // Verify both responses are present in the assembled content
        final allContent = StringBuffer();
        for (final event in events) {
          if (event['type'] == 'message' &&
              event['data']?['role'] == 'assistant') {
            allContent.write(event['data']?['content'] ?? '');
          } else if (event['type'] == 'message_delta') {
            allContent.write(event['data']?['delta'] ?? '');
          }
        }

        final content = allContent.toString().toUpperCase();
        expect(
          content.contains('FIRST'),
          isTrue,
          reason: 'Should contain FIRST response. Got: $content',
        );
        expect(
          content.contains('SECOND'),
          isTrue,
          reason: 'Should contain SECOND response. Got: $content',
        );
      },
      timeout: Timeout(Duration(seconds: 180)),
    );

    test(
      'streaming with tool result events maintains correct order',
      () async {
        // Create network with a prompt that triggers multiple tool uses
        final createResponse = await http.post(
          Uri.parse('http://127.0.0.1:$port/api/v1/networks'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'initialMessage':
                'List the files in this directory (just the first 3), then tell me how many there are.',
            'workingDirectory': serverDir,
          }),
        );

        expect(createResponse.statusCode, equals(200));
        final networkData = jsonDecode(createResponse.body);
        final networkId = networkData['networkId'];
        final mainAgentId = networkData['mainAgentId'];

        // Connect to WebSocket
        final wsUri = Uri.parse(
          'ws://127.0.0.1:$port/api/v1/networks/$networkId/agents/$mainAgentId/stream',
        );
        final channel = WebSocketChannel.connect(wsUri);

        final events = <Map<String, dynamic>>[];
        final completer = Completer<void>();

        channel.stream.listen(
          (message) {
            final event = jsonDecode(message as String) as Map<String, dynamic>;
            events.add(event);

            if (event['type'] == 'done' || event['type'] == 'error') {
              if (!completer.isCompleted) {
                completer.complete();
              }
            }
          },
          onError: (e) {
            if (!completer.isCompleted) {
              completer.completeError(e);
            }
          },
        );

        await completer.future.timeout(
          const Duration(seconds: 120),
          onTimeout: () => throw StateError('Timeout waiting for response'),
        );

        await channel.sink.close();

        // Verify event ordering: tool_use should come before tool_result
        final toolUseIndices = <int>[];
        final toolResultIndices = <int>[];

        for (var i = 0; i < events.length; i++) {
          if (events[i]['type'] == 'tool_use') {
            toolUseIndices.add(i);
          } else if (events[i]['type'] == 'tool_result') {
            toolResultIndices.add(i);
          }
        }

        // If we have both tool_use and tool_result, verify ordering
        if (toolUseIndices.isNotEmpty && toolResultIndices.isNotEmpty) {
          expect(
            toolUseIndices.first,
            lessThan(toolResultIndices.first),
            reason:
                'First tool_use should come before first tool_result. Events: ${events.map((e) => e['type']).toList()}',
          );
        }

        // Verify we got a done event
        expect(
          events.any((e) => e['type'] == 'done'),
          isTrue,
          reason: 'Should receive done event',
        );
      },
      timeout: Timeout(Duration(seconds: 180)),
    );
  });
}
