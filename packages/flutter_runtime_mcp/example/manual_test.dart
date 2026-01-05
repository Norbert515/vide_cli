import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_runtime_mcp/flutter_runtime_mcp.dart';

/// Interactive HTTP/SSE client for testing the Flutter Runtime MCP server
void main() async {
  print('Flutter Runtime MCP - Manual Test Client');
  print('=' * 50);

  // Start the server
  final server = FlutterRuntimeServer();

  try {
    await server.start();
    print('✓ Server started on port ${server.port}\n');

    // Create the client
    final client = McpHttpClient('http://localhost:${server.port}');

    // Initialize the MCP connection
    print('Initializing MCP connection...');
    await client.initialize();
    print('✓ Connection initialized\n');

    // Interactive menu loop
    await _runInteractiveMenu(client);

    // Cleanup
    print('\nShutting down...');
    await client.close();
    await server.stop();
    print('✓ Shutdown complete');
  } catch (e, stackTrace) {
    print('Error: $e');
    print('StackTrace: $stackTrace');
    await server.stop();
  }
}

Future<void> _runInteractiveMenu(McpHttpClient client) async {
  while (true) {
    _printMenu();
    stdout.write('Choice: ');
    final choice = stdin.readLineSync()?.trim() ?? '';

    switch (choice) {
      case '1':
        await _startFlutterInstance(client);
        break;
      case '2':
        await _listInstances(client);
        break;
      case '3':
        await _getInstanceInfo(client);
        break;
      case '4':
        await _hotReload(client);
        break;
      case '5':
        await _hotRestart(client);
        break;
      case '6':
        await _stopInstance(client);
        break;
      case '7':
        print('Exiting...');
        return;
      default:
        print('Invalid choice. Please try again.\n');
    }
  }
}

void _printMenu() {
  print('\n${'=' * 50}');
  print('Menu:');
  print('  1. Start Flutter instance');
  print('  2. List running instances');
  print('  3. Get instance info');
  print('  4. Hot reload');
  print('  5. Hot restart');
  print('  6. Stop instance');
  print('  7. Exit');
  print('=' * 50);
}

Future<void> _startFlutterInstance(McpHttpClient client) async {
  stdout.write('Enter flutter command (e.g., "flutter run -d chrome"): ');
  final command = stdin.readLineSync()?.trim() ?? '';
  if (command.isEmpty) {
    print('Command cannot be empty.');
    return;
  }

  stdout.write('Enter working directory (or press Enter for current): ');
  final workingDir = stdin.readLineSync()?.trim();

  print('\nStarting Flutter instance...');
  try {
    final params = <String, dynamic>{'command': command};
    if (workingDir != null && workingDir.isNotEmpty) {
      params['workingDirectory'] = workingDir;
    }

    final response = await client.callTool('flutterStart', params);
    print('\n${'─' * 50}');
    print('Response:');
    print(response);
    print('─' * 50);
  } catch (e) {
    print('Error: $e');
  }
}

Future<void> _listInstances(McpHttpClient client) async {
  print('\nListing running instances...');
  try {
    final response = await client.callTool('flutterList', {});
    print('\n${'─' * 50}');
    print('Response:');
    print(response);
    print('─' * 50);
  } catch (e) {
    print('Error: $e');
  }
}

Future<void> _getInstanceInfo(McpHttpClient client) async {
  stdout.write('Enter instance ID: ');
  final instanceId = stdin.readLineSync()?.trim() ?? '';
  if (instanceId.isEmpty) {
    print('Instance ID cannot be empty.');
    return;
  }

  print('\nGetting instance info...');
  try {
    final response = await client.callTool('flutterGetInfo', {
      'instanceId': instanceId,
    });
    print('\n${'─' * 50}');
    print('Response:');
    print(response);
    print('─' * 50);
  } catch (e) {
    print('Error: $e');
  }
}

Future<void> _hotReload(McpHttpClient client) async {
  stdout.write('Enter instance ID: ');
  final instanceId = stdin.readLineSync()?.trim() ?? '';
  if (instanceId.isEmpty) {
    print('Instance ID cannot be empty.');
    return;
  }

  print('\nPerforming hot reload...');
  try {
    final response = await client.callTool('flutterReload', {
      'instanceId': instanceId,
      'hot': true,
    });
    print('\n${'─' * 50}');
    print('Response:');
    print(response);
    print('─' * 50);
  } catch (e) {
    print('Error: $e');
  }
}

Future<void> _hotRestart(McpHttpClient client) async {
  stdout.write('Enter instance ID: ');
  final instanceId = stdin.readLineSync()?.trim() ?? '';
  if (instanceId.isEmpty) {
    print('Instance ID cannot be empty.');
    return;
  }

  print('\nPerforming hot restart...');
  try {
    final response = await client.callTool('flutterRestart', {
      'instanceId': instanceId,
    });
    print('\n${'─' * 50}');
    print('Response:');
    print(response);
    print('─' * 50);
  } catch (e) {
    print('Error: $e');
  }
}

Future<void> _stopInstance(McpHttpClient client) async {
  stdout.write('Enter instance ID: ');
  final instanceId = stdin.readLineSync()?.trim() ?? '';
  if (instanceId.isEmpty) {
    print('Instance ID cannot be empty.');
    return;
  }

  print('\nStopping instance...');
  try {
    final response = await client.callTool('flutterStop', {
      'instanceId': instanceId,
    });
    print('\n${'─' * 50}');
    print('Response:');
    print(response);
    print('─' * 50);
  } catch (e) {
    print('Error: $e');
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

  /// Establish SSE connection by doing GET to /sse
  Future<void> _connect() async {
    final uri = Uri.parse('$baseUrl/sse');
    final request = await _httpClient.getUrl(uri);
    request.headers.set('Accept', 'text/event-stream');
    request.headers.set('MCP-Protocol-Version', '2024-11-05');

    final response = await request.close();

    // Wait for session ID from 'endpoint' SSE event
    final sessionCompleter = Completer<String>();

    // Listen to SSE stream continuously
    _sseSubscription = response
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            if (!sessionCompleter.isCompleted) {
              // During connection, look for endpoint event to get session ID
              if (line.startsWith('event: endpoint')) {
                // Next line will have the data
                return;
              } else if (line.startsWith('data: ') &&
                  !sessionCompleter.isCompleted) {
                final endpointUrl = line.substring(6);
                // Extract sessionId from URL like "/messages?sessionId=xxx"
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
            print('SSE stream error: $error');
            if (!sessionCompleter.isCompleted) {
              sessionCompleter.completeError(error);
            }
            // Complete all pending requests with error
            for (final completer in _responseCompleters.values) {
              if (!completer.isCompleted) {
                completer.completeError(error);
              }
            }
            _responseCompleters.clear();
          },
          onDone: () {
            print('SSE stream closed');
            if (!sessionCompleter.isCompleted) {
              sessionCompleter.completeError(
                'SSE stream closed before session ID received',
              );
            }
            // Complete all pending requests with error
            for (final completer in _responseCompleters.values) {
              if (!completer.isCompleted) {
                completer.completeError('SSE stream closed unexpectedly');
              }
            }
            _responseCompleters.clear();
          },
        );

    // Wait for session ID
    _sessionId = await sessionCompleter.future;
  }

  /// Handle individual SSE line
  void _handleSseLine(String line) {
    if (line.startsWith('data: ')) {
      final data = line.substring(6); // Remove "data: " prefix
      try {
        final message = jsonDecode(data) as Map<String, dynamic>;

        // Match response by JSON-RPC id field
        final id = message['id'];
        if (id != null && _responseCompleters.containsKey(id)) {
          _responseCompleters[id]!.complete(message);
          _responseCompleters.remove(id);
        }
        // Ignore notifications and other messages without matching IDs
      } catch (e) {
        // Ignore parse errors for non-JSON lines
      }
    }
  }

  /// Initialize the MCP connection
  Future<void> initialize() async {
    // Establish SSE connection first
    await _connect();

    final initRequest = {
      'jsonrpc': '2.0',
      'id': _nextRequestId(),
      'method': 'initialize',
      'params': {
        'protocolVersion': '2024-11-05',
        'capabilities': {},
        'clientInfo': {
          'name': 'flutter-runtime-manual-test',
          'version': '1.0.0',
        },
      },
    };

    await _sendRequest(initRequest);

    // Send initialized notification
    final initializedNotification = {
      'jsonrpc': '2.0',
      'method': 'notifications/initialized',
    };

    await _sendRequest(initializedNotification);
  }

  /// Call an MCP tool
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

    // Extract text content from response
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

  /// Send a JSON-RPC request via POST to /messages?sessionId=xxx
  Future<Map<String, dynamic>> _sendRequest(
    Map<String, dynamic> request,
  ) async {
    // Check if this is a notification (no 'id' field)
    if (!request.containsKey('id')) {
      // Notification, no response expected
      await _postMessage(request);
      return {};
    }

    final id = request['id'] as int;
    final completer = Completer<Map<String, dynamic>>();
    _responseCompleters[id] = completer;

    // POST to /messages?sessionId=xxx
    await _postMessage(request);

    // Wait for response via SSE stream
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _responseCompleters.remove(id);
        throw TimeoutException('Request timed out after 30 seconds');
      },
    );
  }

  /// POST a message to /messages?sessionId=xxx
  Future<void> _postMessage(Map<String, dynamic> message) async {
    if (_sessionId == null) {
      throw Exception('Not connected - session ID is null');
    }

    final uri = Uri.parse('$baseUrl/messages?sessionId=$_sessionId');
    final request = await _httpClient.postUrl(uri);
    request.headers.set('Content-Type', 'application/json');
    request.write(jsonEncode(message));

    final response = await request.close();
    await response.drain(); // Consume response body
  }

  int _nextRequestId() => ++_requestId;

  Future<void> close() async {
    await _sseSubscription?.cancel();
    _httpClient.close();
  }
}
