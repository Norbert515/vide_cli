import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_runtime_mcp/flutter_runtime_mcp.dart';

/// Automated test script for all Flutter Runtime MCP tools
void main() async {
  print('Flutter Runtime MCP - Automated Test');
  print('=' * 60);

  final server = FlutterRuntimeServer();

  try {
    // Start server
    await server.start();
    print('✓ Server started on port ${server.port}\n');

    // Create client
    final client = McpHttpClient('http://localhost:${server.port}');
    await client.initialize();
    print('✓ MCP connection initialized\n');

    // Run all tests
    await _runTests(client);

    // Cleanup
    print('\nShutting down...');
    await client.close();
    await server.stop();
    print('✓ All tests complete!');
    exit(0);
  } catch (e, stackTrace) {
    print('❌ Error: $e');
    print('StackTrace: $stackTrace');
    await server.stop();
    exit(1);
  }
}

Future<void> _runTests(McpHttpClient client) async {
  print('${'=' * 60}');
  print('Running Tests');
  print('=' * 60);

  // Test 1: List (should be empty initially)
  print('\n[Test 1] List instances (should be empty)');
  final listResult1 = await client.callTool('flutterList', {});
  print('Result: $listResult1');
  if (listResult1.contains('No running')) {
    print('✓ Test 1 passed');
  } else {
    print('❌ Test 1 failed');
  }

  // Test 2: Start a Flutter instance
  print('\n[Test 2] Start Flutter instance');
  final startResult = await client.callTool('flutterStart', {
    'command': 'flutter run -d chrome',
    'workingDirectory':
        '/Users/norbertkozsir/IdeaProjects/flutter_dev_web/test_flutter_app',
  });
  print('Result: $startResult');

  // Extract instance ID from response
  final instanceIdMatch = RegExp(
    r'Instance ID: ([a-f0-9-]+)',
  ).firstMatch(startResult);
  if (instanceIdMatch == null) {
    print('❌ Test 2 failed - could not extract instance ID');
    return;
  }
  final instanceId = instanceIdMatch.group(1)!;
  print('✓ Test 2 passed - Instance ID: $instanceId');

  // Wait for Flutter to start
  print('\nWaiting 5 seconds for Flutter to start...');
  await Future.delayed(const Duration(seconds: 5));

  // Test 3: List (should show 1 instance)
  print('\n[Test 3] List instances (should show 1)');
  final listResult2 = await client.callTool('flutterList', {});
  print('Result: $listResult2');
  if (listResult2.contains(instanceId)) {
    print('✓ Test 3 passed');
  } else {
    print('❌ Test 3 failed');
  }

  // Test 4: Get instance info
  print('\n[Test 4] Get instance info');
  final infoResult = await client.callTool('flutterGetInfo', {
    'instanceId': instanceId,
  });
  print('Result: $infoResult');
  if (infoResult.contains(instanceId) && infoResult.contains('Running')) {
    print('✓ Test 4 passed');
  } else {
    print('❌ Test 4 failed');
  }

  // Test 5: Hot reload
  print('\n[Test 5] Hot reload');
  final reloadResult = await client.callTool('flutterReload', {
    'instanceId': instanceId,
    'hot': true,
  });
  print('Result: $reloadResult');
  if (reloadResult.contains('Hot Reload') ||
      reloadResult.contains('triggered')) {
    print('✓ Test 5 passed');
  } else {
    print('❌ Test 5 failed');
  }

  // Wait a bit
  await Future.delayed(const Duration(seconds: 2));

  // Test 6: Hot restart
  print('\n[Test 6] Hot restart');
  final restartResult = await client.callTool('flutterRestart', {
    'instanceId': instanceId,
  });
  print('Result: $restartResult');
  if (restartResult.contains('restart') ||
      restartResult.contains('triggered')) {
    print('✓ Test 6 passed');
  } else {
    print('❌ Test 6 failed');
  }

  // Wait a bit
  await Future.delayed(const Duration(seconds: 2));

  // Test 7: Stop instance
  print('\n[Test 7] Stop instance');
  final stopResult = await client.callTool('flutterStop', {
    'instanceId': instanceId,
  });
  print('Result: $stopResult');
  if (stopResult.contains('stopped')) {
    print('✓ Test 7 passed');
  } else {
    print('❌ Test 7 failed');
  }

  // Wait for cleanup
  await Future.delayed(const Duration(seconds: 1));

  // Test 8: List (should be empty again)
  print('\n[Test 8] List instances (should be empty again)');
  final listResult3 = await client.callTool('flutterList', {});
  print('Result: $listResult3');
  if (listResult3.contains('No running')) {
    print('✓ Test 8 passed');
  } else {
    print('❌ Test 8 failed');
  }

  // Test 9: Error case - get info for non-existent instance
  print('\n[Test 9] Error handling - non-existent instance');
  final errorResult = await client.callTool('flutterGetInfo', {
    'instanceId': 'non-existent-id',
  });
  print('Result: $errorResult');
  if (errorResult.contains('Error') || errorResult.contains('not found')) {
    print('✓ Test 9 passed');
  } else {
    print('❌ Test 9 failed');
  }
}

/// Simple HTTP/SSE client for MCP servers
class McpHttpClient {
  final String baseUrl;
  final HttpClient _httpClient = HttpClient();
  String? _sessionId;
  int _requestId = 0;
  StreamSubscription? _sseSubscription;
  final _responseCompleters = <int, Completer<Map<String, dynamic>>>{};

  McpHttpClient(this.baseUrl);

  /// Initialize the MCP connection
  Future<void> initialize() async {
    await _connect();

    final initRequest = {
      'jsonrpc': '2.0',
      'id': _nextRequestId(),
      'method': 'initialize',
      'params': {
        'protocolVersion': '2024-11-05',
        'capabilities': {},
        'clientInfo': {
          'name': 'flutter-runtime-automated-test',
          'version': '1.0.0',
        },
      },
    };

    await _sendRequest(initRequest);

    final initializedNotification = {
      'jsonrpc': '2.0',
      'method': 'notifications/initialized',
    };

    await _sendRequest(initializedNotification);
  }

  /// Establish SSE connection
  Future<void> _connect() async {
    final uri = Uri.parse('$baseUrl/sse');
    final request = await _httpClient.getUrl(uri);
    request.headers.set('Accept', 'text/event-stream');

    final response = await request.close();

    final sessionCompleter = Completer<String>();

    _sseSubscription = response
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            if (!sessionCompleter.isCompleted) {
              if (line.startsWith('event: endpoint')) {
                return;
              } else if (line.startsWith('data: ')) {
                final endpointUrl = line.substring(6);
                final uri = Uri.parse(endpointUrl);
                final sessionId = uri.queryParameters['sessionId'];
                if (sessionId != null) {
                  sessionCompleter.complete(sessionId);
                }
                return;
              }
            }
            _handleSseLine(line);
          },
          onError: (error) {
            if (!sessionCompleter.isCompleted) {
              sessionCompleter.completeError(error);
            }
          },
        );

    _sessionId = await sessionCompleter.future;
  }

  void _handleSseLine(String line) {
    if (line.startsWith('data: ')) {
      final data = line.substring(6);
      try {
        final message = jsonDecode(data) as Map<String, dynamic>;
        final id = message['id'];
        if (id != null && _responseCompleters.containsKey(id)) {
          _responseCompleters[id]!.complete(message);
          _responseCompleters.remove(id);
        }
      } catch (e) {
        // Ignore malformed SSE data
      }
    }
  }

  Future<Map<String, dynamic>> _sendRequest(
    Map<String, dynamic> request,
  ) async {
    if (!request.containsKey('id')) {
      await _postMessage(request);
      return {};
    }

    final id = request['id'] as int;
    final completer = Completer<Map<String, dynamic>>();
    _responseCompleters[id] = completer;

    await _postMessage(request);

    return completer.future.timeout(const Duration(seconds: 30));
  }

  Future<void> _postMessage(Map<String, dynamic> message) async {
    final uri = Uri.parse('$baseUrl/messages?sessionId=$_sessionId');
    final request = await _httpClient.postUrl(uri);
    request.headers.set('Content-Type', 'application/json');
    request.write(jsonEncode(message));
    final response = await request.close();
    await response.drain();
  }

  Future<String> callTool(
    String toolName,
    Map<String, dynamic> arguments,
  ) async {
    final toolRequest = {
      'jsonrpc': '2.0',
      'id': _nextRequestId(),
      'method': 'tools/call',
      'params': {'name': toolName, 'arguments': arguments},
    };

    final response = await _sendRequest(toolRequest);

    if (response['result'] != null) {
      final result = response['result'];
      if (result['content'] is List) {
        final contents = result['content'] as List;
        final textContents = contents
            .where((c) => c['type'] == 'text')
            .map((c) => c['text'] as String)
            .join('\n');
        return textContents;
      }
    }

    return jsonEncode(response);
  }

  Future<void> close() async {
    await _sseSubscription?.cancel();
    _httpClient.close();
  }

  int _nextRequestId() => ++_requestId;
}
