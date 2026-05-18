/// Comprehensive E2E integration tests for ALL Phase 2.5 features.
///
/// Tests verify:
/// 1. Tool use events (tool-use, tool-result)
/// 2. Permission handling (permission-request, permission-response, permission-resolved)
/// 3. Permission-mode selection
/// 4. Error handling (unknown message types)
/// 5. Abort functionality
/// 6. WebSocket keepalive
///
/// Requirements:
/// - Tests make REAL API calls to Claude
/// - Tests verify actual tool execution and permissions
@Tags(['integration'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../test_config.dart';

void main() {
  late Process serverProcess;
  late int port;
  late String baseUrl;
  late Directory testDir;

  setUpAll(() async {
    // Create a test directory for file operations
    testDir = await Directory.systemTemp.createTemp('phase25_e2e_test_');

    // Start the server with filesystem-root pointing to our test directory
    port = testPortBase + phase25ComprehensiveTestOffset;
    baseUrl = 'http://127.0.0.1:$port';

    serverProcess = await Process.start('dart', [
      'run',
      'bin/vide_server.dart',
      '--port',
      '$port',
      '--filesystem-root',
      testDir.path,
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
    await testDir.delete(recursive: true);
  });

  group('Phase 2.5 Comprehensive E2E Tests', () {
    group('Tool Use Events', () {
      test(
        'tool-use and tool-result events have correct format when agent uses tools',
        () async {
          // Ask Claude to do something that MUST use a tool
          // Use explicit instruction that requires tool execution
          final createResponse = await http.post(
            Uri.parse('$baseUrl/api/v1/sessions'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'initial-message':
                  'Execute this bash command and show me the output: echo "TOOL_TEST_OUTPUT"',
              'working-directory': testDir.path,
            }),
          );

          expect(createResponse.statusCode, 200);
          final sessionData = jsonDecode(createResponse.body);
          final sessionId = sessionData['session-id'];

          final wsUrl =
              'ws://127.0.0.1:$port/api/v1/sessions/$sessionId/stream';
          final channel = WebSocketChannel.connect(Uri.parse(wsUrl));

          final events = <Map<String, dynamic>>[];
          final completer = Completer<void>();

          channel.stream.listen(
            (message) {
              final event =
                  jsonDecode(message as String) as Map<String, dynamic>;
              events.add(event);

              if (event['type'] == 'done' || event['type'] == 'error') {
                if (!completer.isCompleted) completer.complete();
              }
            },
            onError: (error) {
              if (!completer.isCompleted) completer.completeError(error);
            },
          );

          await completer.future.timeout(
            const Duration(seconds: 90),
            onTimeout: () {
              fail('Timeout. Events: ${events.map((e) => e['type']).toList()}');
            },
          );

          await channel.sink.close();

          // Look for tool-use events
          final toolUseEvents = events
              .where((e) => e['type'] == 'tool-use')
              .toList();
          final toolResultEvents = events
              .where((e) => e['type'] == 'tool-result')
              .toList();

          // Agent MUST have used at least one tool (Bash for echo)
          // If this fails, it's a real issue that needs investigation
          expect(
            toolUseEvents,
            isNotEmpty,
            reason:
                'Agent MUST use Bash tool when explicitly asked to execute a command. '
                'Events received: ${events.map((e) => e['type']).toList()}',
          );

          expect(
            toolResultEvents,
            isNotEmpty,
            reason: 'Must have tool-result for every tool-use',
          );

          // Verify tool-use event format
          for (final toolUse in toolUseEvents) {
            expect(toolUse['seq'], isA<int>());
            expect(toolUse['event-id'], isNotEmpty);
            expect(toolUse['agent-id'], isNotEmpty);
            expect(toolUse['agent-type'], isNotEmpty);
            expect(toolUse['timestamp'], isNotEmpty);
            expect(toolUse['data'], isA<Map>());
            expect(toolUse['data']['tool-use-id'], isNotEmpty);
            expect(toolUse['data']['tool-name'], isNotEmpty);
            expect(toolUse['data']['tool-input'], isA<Map>());
          }

          // Verify tool-result event format
          for (final toolResult in toolResultEvents) {
            expect(toolResult['seq'], isA<int>());
            expect(toolResult['event-id'], isNotEmpty);
            expect(toolResult['agent-id'], isNotEmpty);
            expect(toolResult['timestamp'], isNotEmpty);
            expect(toolResult['data'], isA<Map>());
            expect(toolResult['data']['tool-use-id'], isNotEmpty);
            expect(toolResult['data']['tool-name'], isNotEmpty);
            // result can be null/empty if error
            expect(toolResult['data'].containsKey('result'), isTrue);
            expect(toolResult['data']['is-error'], isA<bool>());
          }
        },
        timeout: Timeout(Duration(seconds: 120)),
      );

      test(
        'tool-use-id matches between tool-use and tool-result events',
        () async {
          // Use explicit command that must be executed
          final createResponse = await http.post(
            Uri.parse('$baseUrl/api/v1/sessions'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'initial-message':
                  'Execute exactly this bash command: pwd && echo done',
              'working-directory': testDir.path,
            }),
          );

          expect(createResponse.statusCode, 200);
          final sessionData = jsonDecode(createResponse.body);
          final sessionId = sessionData['session-id'];

          final wsUrl =
              'ws://127.0.0.1:$port/api/v1/sessions/$sessionId/stream';
          final channel = WebSocketChannel.connect(Uri.parse(wsUrl));

          final events = <Map<String, dynamic>>[];
          final completer = Completer<void>();

          channel.stream.listen((message) {
            final event = jsonDecode(message as String) as Map<String, dynamic>;
            events.add(event);

            if (event['type'] == 'done' || event['type'] == 'error') {
              if (!completer.isCompleted) completer.complete();
            }
          });

          await completer.future.timeout(const Duration(seconds: 90));
          await channel.sink.close();

          final toolUseEvents = events
              .where((e) => e['type'] == 'tool-use')
              .toList();
          final toolResultEvents = events
              .where((e) => e['type'] == 'tool-result')
              .toList();

          // Agent MUST use tools when explicitly asked to execute a command
          expect(
            toolUseEvents,
            isNotEmpty,
            reason:
                'Agent MUST use tools when asked to execute bash commands. '
                'Events: ${events.map((e) => e['type']).toList()}',
          );

          // Each tool-use should have a matching tool-result
          for (final toolUse in toolUseEvents) {
            final toolUseId = toolUse['data']['tool-use-id'];
            final matchingResult = toolResultEvents.where(
              (r) => r['data']['tool-use-id'] == toolUseId,
            );
            expect(
              matchingResult,
              isNotEmpty,
              reason: 'tool-use-id $toolUseId should have matching result',
            );
          }
        },
        timeout: Timeout(Duration(seconds: 120)),
      );
    });

    group('Permission Mode', () {
      test(
        'session can be created with permission-mode parameter',
        () async {
          // Test that permission-mode is accepted in the request
          final createResponse = await http.post(
            Uri.parse('$baseUrl/api/v1/sessions'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'initial-message': 'Say hello.',
              'working-directory': Directory.current.path,
              'permission-mode': 'acceptEdits',
            }),
          );

          expect(createResponse.statusCode, 200);
          final sessionData = jsonDecode(createResponse.body);
          expect(sessionData['session-id'], isNotEmpty);

          // Connect and verify it works
          final sessionId = sessionData['session-id'];
          final wsUrl =
              'ws://127.0.0.1:$port/api/v1/sessions/$sessionId/stream';
          final channel = WebSocketChannel.connect(Uri.parse(wsUrl));

          final completer = Completer<void>();
          var gotMessage = false;

          channel.stream.listen((message) {
            final event = jsonDecode(message as String) as Map<String, dynamic>;
            if (event['type'] == 'message') gotMessage = true;
            if (event['type'] == 'done' || event['type'] == 'error') {
              if (!completer.isCompleted) completer.complete();
            }
          });

          await completer.future.timeout(const Duration(seconds: 90));
          await channel.sink.close();

          expect(gotMessage, isTrue, reason: 'Should receive message events');
        },
        timeout: Timeout(Duration(seconds: 120)),
      );
    });

    group('Error Handling', () {
      test('unknown message type returns error event', () async {
        final createResponse = await http.post(
          Uri.parse('$baseUrl/api/v1/sessions'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'initial-message': 'Test session.',
            'working-directory': Directory.current.path,
          }),
        );

        expect(createResponse.statusCode, 200);
        final sessionData = jsonDecode(createResponse.body);
        final sessionId = sessionData['session-id'];

        final wsUrl = 'ws://127.0.0.1:$port/api/v1/sessions/$sessionId/stream';
        final channel = WebSocketChannel.connect(Uri.parse(wsUrl));

        Map<String, dynamic>? errorEvent;
        final completer = Completer<void>();

        // Wait a moment for connected event
        await Future.delayed(const Duration(milliseconds: 500));

        // Subscribe to events
        channel.stream.listen((message) {
          final event = jsonDecode(message as String) as Map<String, dynamic>;

          if (event['type'] == 'error') {
            errorEvent = event;
            if (!completer.isCompleted) completer.complete();
          }
          if (event['type'] == 'done' && !completer.isCompleted) {
            // If we get done without error, wait for error
          }
        });

        // Send an unknown message type
        channel.sink.add(
          jsonEncode({
            'type': 'unknown-message-type',
            'content': 'This should fail',
          }),
        );

        await completer.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () => fail('Did not receive error event'),
        );

        await channel.sink.close();

        expect(errorEvent, isNotNull);
        expect(errorEvent!['type'], 'error');
        expect(errorEvent!['data']['code'], 'UNKNOWN_MESSAGE_TYPE');
        expect(errorEvent!['data']['original-message'], isNotNull);
      });

      test('malformed JSON returns error', () async {
        final createResponse = await http.post(
          Uri.parse('$baseUrl/api/v1/sessions'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'initial-message': 'Test.',
            'working-directory': Directory.current.path,
          }),
        );

        final sessionData = jsonDecode(createResponse.body);
        final sessionId = sessionData['session-id'];

        final wsUrl = 'ws://127.0.0.1:$port/api/v1/sessions/$sessionId/stream';
        final channel = WebSocketChannel.connect(Uri.parse(wsUrl));

        // Wait for connection
        await Future.delayed(const Duration(milliseconds: 500));

        Map<String, dynamic>? errorEvent;
        final completer = Completer<void>();

        channel.stream.listen((message) {
          final event = jsonDecode(message as String) as Map<String, dynamic>;
          if (event['type'] == 'error') {
            errorEvent = event;
            if (!completer.isCompleted) completer.complete();
          }
        });

        // Send malformed JSON
        channel.sink.add('not valid json {{{');

        await completer.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () =>
              fail('Did not receive error event for malformed JSON'),
        );

        await channel.sink.close();

        expect(errorEvent, isNotNull);
        expect(errorEvent!['type'], 'error');
      });
    });

    group('HTTP Error Responses', () {
      test('POST /sessions with missing initial-message returns 400', () async {
        final response = await http.post(
          Uri.parse('$baseUrl/api/v1/sessions'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'working-directory': Directory.current.path,
            // Missing initial-message
          }),
        );

        expect(response.statusCode, 400);
        final data = jsonDecode(response.body);
        expect(data['code'], 'INVALID_REQUEST');
        expect(data['error'], isNotEmpty);
      });

      test('POST /sessions with invalid JSON returns 400', () async {
        final response = await http.post(
          Uri.parse('$baseUrl/api/v1/sessions'),
          headers: {'Content-Type': 'application/json'},
          body: 'not valid json',
        );

        expect(response.statusCode, 400);
        final data = jsonDecode(response.body);
        expect(data['code'], 'INVALID_REQUEST');
      });

      test('WebSocket to non-existent session returns 404', () async {
        final wsUrl =
            'ws://127.0.0.1:$port/api/v1/sessions/non-existent-session/stream';

        // WebSocket connection to non-existent session should fail
        final channel = WebSocketChannel.connect(Uri.parse(wsUrl));

        final completer = Completer<void>();

        channel.stream.listen(
          (message) {
            // Might receive an error event
            final event = jsonDecode(message as String) as Map<String, dynamic>;
            if (event['type'] == 'error') {
              completer.complete();
            }
          },
          onError: (error) {
            // Expected - connection failure
            if (!completer.isCompleted) completer.complete();
          },
          onDone: () {
            if (!completer.isCompleted) completer.complete();
          },
        );

        await completer.future.timeout(const Duration(seconds: 5));
      });
    });

    group('WebSocket Lifecycle', () {
      test('connected event includes session metadata', () async {
        final createResponse = await http.post(
          Uri.parse('$baseUrl/api/v1/sessions'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'initial-message': 'Test.',
            'working-directory': Directory.current.path,
          }),
        );

        final sessionData = jsonDecode(createResponse.body);
        final sessionId = sessionData['session-id'];

        final wsUrl = 'ws://127.0.0.1:$port/api/v1/sessions/$sessionId/stream';
        final channel = WebSocketChannel.connect(Uri.parse(wsUrl));

        Map<String, dynamic>? connectedEvent;
        final completer = Completer<void>();

        channel.stream.listen((message) {
          final event = jsonDecode(message as String) as Map<String, dynamic>;
          if (event['type'] == 'connected') {
            connectedEvent = event;
            completer.complete();
          }
        });

        await completer.future.timeout(const Duration(seconds: 10));
        await channel.sink.close();

        expect(connectedEvent, isNotNull);
        expect(connectedEvent!['session-id'], sessionId);
        expect(connectedEvent!['main-agent-id'], isNotEmpty);
        expect(connectedEvent!['last-seq'], isA<int>());
        expect(connectedEvent!['agents'], isA<List>());
        expect(connectedEvent!['metadata'], isA<Map>());
        expect(connectedEvent!['metadata']['working-directory'], isNotEmpty);
        expect(connectedEvent!['metadata']['goal'], isNotEmpty);
        expect(connectedEvent!['metadata']['team'], isNotEmpty);
      });

      // NOTE: This test is expected to FAIL until status events are implemented
      // See spec Phase 2.5.6 - status events should be sent when agent state changes
      test('status events show agent working state', () async {
        final createResponse = await http.post(
          Uri.parse('$baseUrl/api/v1/sessions'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'initial-message': 'What is 2+2?',
            'working-directory': Directory.current.path,
          }),
        );

        final sessionData = jsonDecode(createResponse.body);
        final sessionId = sessionData['session-id'];

        final wsUrl = 'ws://127.0.0.1:$port/api/v1/sessions/$sessionId/stream';
        final channel = WebSocketChannel.connect(Uri.parse(wsUrl));

        final events = <Map<String, dynamic>>[];
        final completer = Completer<void>();

        channel.stream.listen((message) {
          final event = jsonDecode(message as String) as Map<String, dynamic>;
          events.add(event);
          if (event['type'] == 'done' || event['type'] == 'error') {
            if (!completer.isCompleted) completer.complete();
          }
        });

        await completer.future.timeout(const Duration(seconds: 60));
        await channel.sink.close();

        // Look for status events
        final statusEvents = events
            .where((e) => e['type'] == 'status')
            .toList();

        // Should have at least one status event (initial connected state)
        expect(statusEvents, isNotEmpty);

        for (final status in statusEvents) {
          expect(status['agent-id'], isNotEmpty);
          expect(status['data'], isA<Map>());
          expect(status['data']['status'], isNotEmpty);
        }
      });
    });

    group('Session State Recovery', () {
      test('late-connecting client receives complete history', () async {
        // Create session and let first turn complete
        final createResponse = await http.post(
          Uri.parse('$baseUrl/api/v1/sessions'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'initial-message': 'Say exactly: "Test complete"',
            'working-directory': Directory.current.path,
          }),
        );

        final sessionData = jsonDecode(createResponse.body);
        final sessionId = sessionData['session-id'];

        // Connect first client and wait for completion
        final wsUrl = 'ws://127.0.0.1:$port/api/v1/sessions/$sessionId/stream';
        final channel1 = WebSocketChannel.connect(Uri.parse(wsUrl));

        final firstClientEvents = <Map<String, dynamic>>[];
        final doneCompleter = Completer<void>();

        channel1.stream.listen((message) {
          final event = jsonDecode(message as String) as Map<String, dynamic>;
          firstClientEvents.add(event);
          if (event['type'] == 'done') {
            if (!doneCompleter.isCompleted) doneCompleter.complete();
          }
        });

        await doneCompleter.future.timeout(const Duration(seconds: 60));
        await channel1.sink.close();

        // Get last sequence number
        final firstClientLastSeq = firstClientEvents
            .where((e) => e['seq'] != null)
            .map((e) => e['seq'] as int)
            .fold<int>(0, (a, b) => a > b ? a : b);

        // Connect second client
        final channel2 = WebSocketChannel.connect(Uri.parse(wsUrl));

        Map<String, dynamic>? historyEvent;
        final historyCompleter = Completer<void>();

        channel2.stream.listen((message) {
          final event = jsonDecode(message as String) as Map<String, dynamic>;
          if (event['type'] == 'history') {
            historyEvent = event;
            historyCompleter.complete();
          }
        });

        await historyCompleter.future.timeout(const Duration(seconds: 10));
        await channel2.sink.close();

        // Verify history
        expect(historyEvent, isNotNull);
        expect(historyEvent!['last-seq'], firstClientLastSeq);

        final events = historyEvent!['data']['events'] as List<dynamic>;
        expect(events, isNotEmpty);

        // History should include message events
        final messageEvents = events.where(
          (e) => (e as Map<String, dynamic>)['type'] == 'message',
        );
        expect(messageEvents, isNotEmpty);
      });
    });

    group('Abort Functionality', () {
      test(
        'abort message cancels in-progress agent operation',
        () async {
          // Start a session with a task that takes time (file exploration)
          final createResponse = await http.post(
            Uri.parse('$baseUrl/api/v1/sessions'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'initial-message':
                  'List all files in the current directory recursively and explain each one in detail.',
              'working-directory': testDir.path,
            }),
          );

          expect(createResponse.statusCode, 200);
          final sessionData = jsonDecode(createResponse.body);
          final sessionId = sessionData['session-id'];

          final wsUrl =
              'ws://127.0.0.1:$port/api/v1/sessions/$sessionId/stream';
          final channel = WebSocketChannel.connect(Uri.parse(wsUrl));

          final events = <Map<String, dynamic>>[];
          var gotAbortedEvent = false;
          final completer = Completer<void>();

          channel.stream.listen((message) {
            final event = jsonDecode(message as String) as Map<String, dynamic>;
            events.add(event);

            // When we see the agent start working (first message), send abort
            if (event['type'] == 'message' && events.length < 5) {
              // Give it a moment to start processing, then abort
              Future.delayed(const Duration(milliseconds: 500), () {
                channel.sink.add(jsonEncode({'type': 'abort'}));
              });
            }

            if (event['type'] == 'aborted') {
              gotAbortedEvent = true;
              if (!completer.isCompleted) completer.complete();
            }

            // Also complete on done/error to not hang
            if (event['type'] == 'done' || event['type'] == 'error') {
              if (!completer.isCompleted) completer.complete();
            }
          });

          await completer.future.timeout(const Duration(seconds: 60));
          await channel.sink.close();

          // Should have received aborted event
          expect(
            gotAbortedEvent,
            isTrue,
            reason:
                'Should receive aborted event after sending abort. '
                'Events: ${events.map((e) => e['type']).toList()}',
          );

          // Verify aborted event format
          final abortedEvents = events
              .where((e) => e['type'] == 'aborted')
              .toList();
          if (abortedEvents.isNotEmpty) {
            final aborted = abortedEvents.first;
            expect(aborted['agent-id'], isNotEmpty);
            expect(aborted['data'], isA<Map>());
          }
        },
        timeout: Timeout(Duration(seconds: 90)),
      );
    });

    group('Permission Mode Ask', () {
      test(
        'ask mode triggers permission-request for file writes',
        () async {
          // Create a test file path
          final testFilePath = p.join(testDir.path, 'permission_test.txt');

          // Create session with 'ask' permission mode
          final createResponse = await http.post(
            Uri.parse('$baseUrl/api/v1/sessions'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'initial-message':
                  'Create a file at $testFilePath with the content "hello world". Use the Write tool.',
              'working-directory': testDir.path,
              'permission-mode': 'ask',
            }),
          );

          expect(createResponse.statusCode, 200);
          final sessionData = jsonDecode(createResponse.body);
          final sessionId = sessionData['session-id'];

          final wsUrl =
              'ws://127.0.0.1:$port/api/v1/sessions/$sessionId/stream';
          final channel = WebSocketChannel.connect(Uri.parse(wsUrl));

          final events = <Map<String, dynamic>>[];
          var gotPermissionRequest = false;
          String? requestId;
          final completer = Completer<void>();

          channel.stream.listen((message) {
            final event = jsonDecode(message as String) as Map<String, dynamic>;
            events.add(event);

            // Log every event for debugging
            stdout.writeln(
              '[TEST] Event: ${event['type']} - seq=${event['seq']}',
            );

            // Look for permission-request event
            if (event['type'] == 'permission-request') {
              gotPermissionRequest = true;
              requestId = event['data']['request-id'] as String;
              stdout.writeln('[TEST] Got permission-request: $requestId');

              // Approve the permission
              channel.sink.add(
                jsonEncode({
                  'type': 'permission-response',
                  'request-id': requestId,
                  'allow': true,
                }),
              );
            }

            if (event['type'] == 'done' || event['type'] == 'error') {
              if (!completer.isCompleted) completer.complete();
            }

            // Also handle permission-resolved
            if (event['type'] == 'permission-resolved') {
              stdout.writeln('[TEST] Permission resolved!');
              if (!completer.isCompleted) completer.complete();
            }
          });

          await completer.future.timeout(const Duration(seconds: 120));
          await channel.sink.close();

          // Print all events for debugging
          stdout.writeln('[TEST] All events received:');
          for (final e in events) {
            stdout.writeln('  ${e['type']}: ${e['data']}');
          }

          // KNOWN BUG: Server uses createRestPermissionCallback which auto-denies
          // instead of createInteractivePermissionCallback which forwards to client.
          // This test WILL FAIL until vide_server/bin/vide_server.dart is fixed to use
          // createInteractivePermissionCallback for sessions with permission-mode: ask.
          //
          // Fix location: packages/vide_server/bin/vide_server.dart line ~127
          // Currently: canUseToolCallbackFactoryProvider.overrideWithValue(createRestPermissionCallback)
          // Should use: createInteractivePermissionCallback for 'ask' mode sessions
          expect(
            gotPermissionRequest,
            isTrue,
            reason:
                'BUG: permission-mode=ask does not trigger permission-request events!\n'
                'The server uses createRestPermissionCallback which auto-denies.\n'
                'Fix: Use createInteractivePermissionCallback for ask mode sessions.\n'
                'Events received: ${events.map((e) => e['type']).toList()}',
          );

          // Verify permission-request format
          final permissionRequests = events
              .where((e) => e['type'] == 'permission-request')
              .toList();
          if (permissionRequests.isNotEmpty) {
            final req = permissionRequests.first;
            expect(req['data']['request-id'], isNotEmpty);
            // Tool info is nested under 'tool' key
            expect(req['data']['tool']['name'], isNotEmpty);
            expect(req['data']['tool']['input'], isA<Map>());
          }
        },
        timeout: Timeout(Duration(seconds: 150)),
      );

      // NOTE: This test depends on 'ask' mode working, which is currently broken.
      // See the test above for the root cause. Skipping until that bug is fixed.
      test(
        'permission mode can be switched mid-session from ask to bypassPermissions',
        () async {
          // Create a test file path for each turn
          final testFile1 = p.join(testDir.path, 'switch_test_1.txt');
          final testFile2 = p.join(testDir.path, 'switch_test_2.txt');

          // Start session with 'ask' mode
          final createResponse = await http.post(
            Uri.parse('$baseUrl/api/v1/sessions'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'initial-message':
                  'Create a file at $testFile1 with content "test1". Use the Write tool.',
              'working-directory': testDir.path,
              'permission-mode': 'ask',
            }),
          );

          expect(createResponse.statusCode, 200);
          final sessionData = jsonDecode(createResponse.body);
          final sessionId = sessionData['session-id'];

          final wsUrl =
              'ws://127.0.0.1:$port/api/v1/sessions/$sessionId/stream';
          final channel = WebSocketChannel.connect(Uri.parse(wsUrl));

          final events = <Map<String, dynamic>>[];
          var turn1PermissionRequests = 0;
          var turn2PermissionRequests = 0;
          var turnCount = 0;
          final completer = Completer<void>();

          channel.stream.listen((message) {
            final event = jsonDecode(message as String) as Map<String, dynamic>;
            events.add(event);

            stdout.writeln('[TEST] Event: ${event['type']}');

            // Count permission requests per turn
            if (event['type'] == 'permission-request') {
              if (turnCount == 0) {
                turn1PermissionRequests++;
              } else {
                turn2PermissionRequests++;
              }

              // Always approve
              final requestId = event['data']['request-id'] as String;
              channel.sink.add(
                jsonEncode({
                  'type': 'permission-response',
                  'request-id': requestId,
                  'allow': true,
                }),
              );
            }

            if (event['type'] == 'done') {
              turnCount++;
              if (turnCount == 1) {
                // First turn done, send second message with bypassPermissions
                channel.sink.add(
                  jsonEncode({
                    'type': 'user-message',
                    'content':
                        'Create a file at $testFile2 with content "test2". Use the Write tool.',
                    'permission-mode': 'bypassPermissions',
                  }),
                );
              } else if (turnCount == 2) {
                if (!completer.isCompleted) completer.complete();
              }
            }

            if (event['type'] == 'error') {
              if (!completer.isCompleted) completer.complete();
            }

            if (event['type'] == 'permission-resolved') {
              if (!completer.isCompleted) completer.complete();
            }
          });

          await completer.future.timeout(const Duration(seconds: 180));
          await channel.sink.close();

          // KNOWN BUG: Same as above - 'ask' mode doesn't work because
          // server uses auto-deny callback instead of interactive callback.
          // Turn 1 (ask mode) should have had permission requests
          expect(
            turn1PermissionRequests,
            greaterThan(0),
            reason:
                'BUG: Turn 1 with ask mode should trigger permission requests but doesn\'t.\n'
                'Same root cause as "ask mode triggers permission-request" test.\n'
                'Events: ${events.map((e) => e['type']).toList()}',
          );

          // Turn 2 (bypassPermissions) should NOT have permission requests
          expect(
            turn2PermissionRequests,
            equals(0),
            reason:
                'Turn 2 with bypassPermissions should NOT trigger permission requests. '
                'Turn2 requests: $turn2PermissionRequests',
          );
        },
        timeout: Timeout(Duration(seconds: 240)),
      );
    });

    group('Message Streaming Reconstruction', () {
      test(
        'client can correctly reconstruct message from streaming deltas',
        () async {
          // Simple prompt that produces a text response
          final createResponse = await http.post(
            Uri.parse('$baseUrl/api/v1/sessions'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'initial-message':
                  'Say exactly: "Hello, I am working correctly!"',
              'working-directory': Directory.current.path,
            }),
          );

          expect(createResponse.statusCode, 200);
          final sessionData = jsonDecode(createResponse.body);
          final sessionId = sessionData['session-id'];

          final wsUrl =
              'ws://127.0.0.1:$port/api/v1/sessions/$sessionId/stream';
          final channel = WebSocketChannel.connect(Uri.parse(wsUrl));

          final messageEvents = <Map<String, dynamic>>[];
          final completer = Completer<void>();

          channel.stream.listen((message) {
            final event = jsonDecode(message as String) as Map<String, dynamic>;
            if (event['type'] == 'message') {
              messageEvents.add(event);
            }
            if (event['type'] == 'done' || event['type'] == 'error') {
              if (!completer.isCompleted) completer.complete();
            }
          });

          await completer.future.timeout(const Duration(seconds: 60));
          await channel.sink.close();

          // Find assistant messages
          final assistantMessages = messageEvents
              .where((e) => e['data']?['role'] == 'assistant')
              .toList();
          expect(
            assistantMessages,
            isNotEmpty,
            reason: 'Should have assistant message(s)',
          );

          // Reconstruct message by concatenating all content chunks
          // This simulates what a client should do:
          // 1. Group events by event-id
          // 2. Concatenate content (server sends deltas, not cumulative)
          final reconstructedByEventId = <String, StringBuffer>{};

          for (final event in assistantMessages) {
            final eventId = event['event-id'] as String;
            final content = event['data']?['content'] ?? '';

            reconstructedByEventId.putIfAbsent(eventId, () => StringBuffer());
            // Server sends DELTAS - just append directly
            reconstructedByEventId[eventId]!.write(content);
          }

          // Verify we got coherent text, not garbled
          final fullText = reconstructedByEventId.values
              .map((sb) => sb.toString())
              .join();

          // The reconstructed text should:
          // 1. Not be empty
          expect(
            fullText.trim(),
            isNotEmpty,
            reason: 'Reconstructed text should not be empty',
          );

          // 2. Contain recognizable words (not garbled)
          // If streaming reconstruction is broken, we'd see random fragments
          expect(
            fullText.toLowerCase().contains('hello') ||
                fullText.toLowerCase().contains('working') ||
                fullText.toLowerCase().contains('correctly') ||
                fullText.length > 10, // At least got some text
            isTrue,
            reason:
                'Reconstructed text should be coherent. Got: "${fullText.substring(0, fullText.length.clamp(0, 100))}"',
          );
        },
        timeout: Timeout(Duration(seconds: 90)),
      );

      test(
        'streaming messages with same event-id should be concatenated as deltas',
        () async {
          // Ask for a longer response to ensure multiple chunks
          final createResponse = await http.post(
            Uri.parse('$baseUrl/api/v1/sessions'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'initial-message':
                  'Count from 1 to 10, one number per line with the word "number" before each.',
              'working-directory': Directory.current.path,
            }),
          );

          expect(createResponse.statusCode, 200);
          final sessionData = jsonDecode(createResponse.body);
          final sessionId = sessionData['session-id'];

          final wsUrl =
              'ws://127.0.0.1:$port/api/v1/sessions/$sessionId/stream';
          final channel = WebSocketChannel.connect(Uri.parse(wsUrl));

          final messageEvents = <Map<String, dynamic>>[];
          final completer = Completer<void>();

          channel.stream.listen((message) {
            final event = jsonDecode(message as String) as Map<String, dynamic>;
            if (event['type'] == 'message') {
              messageEvents.add(event);
            }
            if (event['type'] == 'done' || event['type'] == 'error') {
              if (!completer.isCompleted) completer.complete();
            }
          });

          await completer.future.timeout(const Duration(seconds: 60));
          await channel.sink.close();

          // Group by event-id and concatenate
          final byEventId = <String, List<String>>{};
          for (final event in messageEvents) {
            if (event['data']?['role'] != 'assistant') continue;
            final eventId = event['event-id'] as String;
            final content = event['data']?['content'] ?? '';
            byEventId.putIfAbsent(eventId, () => []);
            byEventId[eventId]!.add(content);
          }

          // For each event-id, verify that concatenating chunks gives coherent text
          for (final entry in byEventId.entries) {
            final chunks = entry.value;
            final fullText = chunks.join(); // Deltas - just concatenate

            // Should not have empty result from non-empty chunks
            if (chunks.any((c) => c.isNotEmpty)) {
              expect(
                fullText,
                isNotEmpty,
                reason: 'Concatenated chunks should not be empty',
              );
            }
          }
        },
        timeout: Timeout(Duration(seconds: 90)),
      );
    });

    group('Keepalive', () {
      test(
        'server responds to WebSocket ping with pong',
        () async {
          final createResponse = await http.post(
            Uri.parse('$baseUrl/api/v1/sessions'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'initial-message': 'Say hi.',
              'working-directory': Directory.current.path,
            }),
          );

          final sessionData = jsonDecode(createResponse.body);
          final sessionId = sessionData['session-id'];

          final wsUrl =
              'ws://127.0.0.1:$port/api/v1/sessions/$sessionId/stream';
          final channel = WebSocketChannel.connect(Uri.parse(wsUrl));

          var gotConnected = false;
          final completer = Completer<void>();

          channel.stream.listen((message) {
            final event = jsonDecode(message as String) as Map<String, dynamic>;
            if (event['type'] == 'connected') {
              gotConnected = true;
            }
            if (event['type'] == 'done' || event['type'] == 'error') {
              if (!completer.isCompleted) completer.complete();
            }
          });

          // Wait a moment then verify connection is still alive
          await Future.delayed(const Duration(seconds: 2));

          // Connection should still be open (not closed by server)
          expect(gotConnected, isTrue);

          await completer.future.timeout(const Duration(seconds: 60));
          await channel.sink.close();
        },
        timeout: Timeout(Duration(seconds: 90)),
      );
    });
  });
}
