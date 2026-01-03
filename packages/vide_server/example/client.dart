#!/usr/bin/env dart

/// Interactive REPL client for Vide Server (Phase 2.5 Session API)
///
/// Usage:
///   dart run example/client.dart --port 63139
///   dart run example/client.dart -p 63139
import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

void main(List<String> args) async {
  // Parse arguments
  final parser = ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show this help message',
    )
    ..addOption(
      'port',
      abbr: 'p',
      help: 'Port number where vide_server is running (required)',
    );

  void printUsage() {
    print('Vide Server Interactive REPL Client');
    print('');
    print('Usage: dart run example/client.dart --port PORT');
    print('');
    print('Options:');
    print(parser.usage);
    print('');
    print('Examples:');
    print('  dart run example/client.dart --port 63139');
    print('  dart run example/client.dart -p 8080');
  }

  ArgResults argResults;
  try {
    argResults = parser.parse(args);
  } catch (e) {
    print('Error: $e');
    print('');
    printUsage();
    exit(1);
  }

  // Show help if requested or no arguments provided
  if (argResults['help'] as bool || args.isEmpty) {
    printUsage();
    exit(args.isEmpty ? 1 : 0);
  }

  // Validate port is provided
  final portStr = argResults['port'] as String?;
  if (portStr == null) {
    print('Error: --port is required');
    print('');
    printUsage();
    exit(1);
  }

  final port = int.tryParse(portStr);
  if (port == null) {
    print('Error: Port must be a valid number, got: $portStr');
    print('');
    printUsage();
    exit(1);
  }

  final workingDir = Directory.current.path;
  final serverUrl = 'http://127.0.0.1:$port';

  print('╔════════════════════════════════════════════════════════════════╗');
  print('║              Vide Interactive REPL Client                      ║');
  print('╚════════════════════════════════════════════════════════════════╝');
  print('');
  print('Server: $serverUrl');
  print('Working Directory: $workingDir');
  print('');
  print('Type /help for available commands.');
  print('');

  // Step 1: Verify server is running
  print('→ Connecting to server...');
  try {
    final healthResponse = await http
        .get(Uri.parse('$serverUrl/health'))
        .timeout(const Duration(seconds: 2));
    if (healthResponse.statusCode != 200 || healthResponse.body != 'OK') {
      print('✗ Error: Server is not responding correctly');
      print('  Please start the server first:');
      print('    cd packages/vide_server && dart run bin/vide_server.dart');
      exit(1);
    }
  } catch (e) {
    print('✗ Error: Could not connect to server at $serverUrl');
    print('  Please check that the server is running on port $port');
    print('  Start the server with:');
    print('    cd packages/vide_server && dart run bin/vide_server.dart');
    exit(1);
  }
  print('✓ Connected to $serverUrl');
  print('');

  // Step 2: Start REPL loop (session will be created on first message)
  await _runRepl(serverUrl, workingDir, port);
}

/// Run the interactive REPL loop
Future<void> _runRepl(String serverUrl, String workingDir, int port) async {
  print('╔════════════════════════════════════════════════════════════════╗');
  print('║                    Interactive Session                         ║');
  print('╚════════════════════════════════════════════════════════════════╝');
  print('');
  print('Type your first message to start the session.');
  print('');
  stdout.write('You: ');

  String? sessionId;
  WebSocketChannel? channel;
  var shouldExit = false;

  await for (final line
      in stdin.transform(utf8.decoder).transform(LineSplitter())) {
    final input = line.trim();

    // Check for commands
    final inputLower = input.toLowerCase();
    if (inputLower == '/exit' ||
        inputLower == '/quit' ||
        inputLower == 'exit' ||
        inputLower == 'quit') {
      print('');
      if (sessionId != null) {
        print('Ending session...');
        shouldExit = true;
        await channel?.sink.close();
      }
      break;
    }

    if (inputLower == '/help') {
      print('');
      print('Available commands:');
      print('  /help       Show this help message');
      print('  /exit       Exit the REPL');
      print('  /quit       Exit the REPL (alias for /exit)');
      print('');
      print('Any other input is sent as a message to the agent.');
      print('');
      stdout.write('You: ');
      continue;
    }

    // Skip empty input
    if (input.isEmpty) {
      stdout.write('You: ');
      continue;
    }

    // First message - create session and connect WebSocket
    if (sessionId == null) {
      print('');
      print('→ Creating session with your message...');

      // Create session with kebab-case JSON (Phase 2.5 format)
      final createResponse = await http.post(
        Uri.parse('$serverUrl/api/v1/sessions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'initial-message': input,
          'working-directory': workingDir,
        }),
      );

      if (createResponse.statusCode != 200) {
        print('✗ Error creating session: ${createResponse.body}');
        stdout.write('\nYou: ');
        continue;
      }

      // Parse kebab-case response
      final sessionData = jsonDecode(createResponse.body);
      sessionId = sessionData['session-id'];

      print('✓ Session created (ID: $sessionId)');
      print('');
      print('→ Connecting to session stream...');

      // Connect to multiplexed WebSocket (all agents)
      final wsUrl = 'ws://127.0.0.1:$port/api/v1/sessions/$sessionId/stream';
      channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // Listen for WebSocket messages in background
      channel.stream.listen(
        (message) {
          final event = jsonDecode(message as String);
          _handleEvent(event);

          // Track when agent is done processing
          if (event['type'] == 'done') {
            if (!shouldExit) {
              stdout.write('\nYou: ');
            }
          }
        },
        onError: (error) {
          print('\n✗ WebSocket error: $error');
          shouldExit = true;
        },
        onDone: () {
          if (!shouldExit) {
            print('\n✗ WebSocket connection closed unexpectedly');
          }
          shouldExit = true;
        },
      );

      print('✓ Connected');
      print('');

      // Wait for first response (event handler will prompt for next input)
    } else {
      // Subsequent messages - send via WebSocket user-message
      print('');

      channel!.sink.add(jsonEncode({'type': 'user-message', 'content': input}));

      // Wait for response (event handler will prompt for next input)
    }
  }

  print('');
  print('╔════════════════════════════════════════════════════════════════╗');
  print('║                    Session Complete                            ║');
  print('╚════════════════════════════════════════════════════════════════╝');
}

/// Track current streaming message state
String? _currentEventId;
String? _currentStreamRole;
final _currentStreamBuffer = StringBuffer();

/// Handle different WebSocket event types (Phase 2.5 format with kebab-case)
void _handleEvent(Map<String, dynamic> event) {
  final type = event['type'];
  final agentName = event['agent-name'] ?? 'Agent';
  final data = event['data'] as Map<String, dynamic>?;

  switch (type) {
    case 'connected':
      final sessionId = event['session-id'];
      final mainAgentId = event['main-agent-id'];
      print('[$agentName] Connected to session $sessionId');
      print('  Main agent: $mainAgentId');
      break;

    case 'history':
      final lastSeq = event['last-seq'];
      final events = data?['events'] as List? ?? [];
      if (events.isNotEmpty) {
        print(
          '[$agentName] Loaded ${events.length} history events (seq: $lastSeq)',
        );
      }
      break;

    case 'status':
      print('[$agentName] Status: ${data?['status']}');
      break;

    case 'message':
      // Phase 2.5: Single message event with is-partial flag
      final role = data?['role'];
      final content = data?['content'] ?? '';
      final isPartial = event['is-partial'] ?? false;
      final eventId = event['event-id'];

      // Check if this is a new message or continuation of streaming
      if (_currentEventId != eventId) {
        // New message - close any previous streaming message
        if (_currentStreamRole == 'assistant' &&
            _currentStreamBuffer.isNotEmpty) {
          print('');
          print('└─');
        }

        // Start new message
        _currentEventId = eventId;
        _currentStreamRole = role;
        _currentStreamBuffer.clear();
        _currentStreamBuffer.write(content);

        if (role == 'user') {
          print('');
          print('┌─ User');
          print('│ $content');
          print('└─');
        } else {
          print('');
          print('┌─ Assistant');
          stdout.write('│ $content');
        }
      } else {
        // Same message - append delta (streaming)
        // Server sends deltas directly, just append and display
        if (_currentStreamRole == 'assistant' && content.isNotEmpty) {
          _currentStreamBuffer.write(content);
          stdout.write(content);
        }
      }

      // If message is complete, close it
      if (!isPartial && _currentStreamRole == 'assistant') {
        print('');
        print('└─');
        _currentEventId = null;
        _currentStreamRole = null;
        _currentStreamBuffer.clear();
      }
      break;

    case 'tool-use':
      // Close any open streaming message before showing tool use
      if (_currentStreamRole == 'assistant') {
        print('');
        print('└─');
        _currentEventId = null;
        _currentStreamRole = null;
        _currentStreamBuffer.clear();
      }

      final toolName = data?['tool-name'];
      print('');
      print('🔧 Using tool: $toolName');
      break;

    case 'tool-result':
      final toolName = data?['tool-name'];
      final isError = data?['is-error'] ?? false;
      if (isError) {
        print('   ✗ Error from $toolName');
      } else {
        print('   ✓ $toolName completed');
      }
      break;

    case 'agent-spawned':
      final spawnedAgentId = event['agent-id'];
      final spawnedBy = data?['spawned-by'];
      print('');
      print('🚀 Agent spawned: $agentName ($spawnedAgentId)');
      print('   by: $spawnedBy');
      break;

    case 'agent-terminated':
      final reason = data?['reason'];
      print('');
      print('🛑 Agent terminated: $agentName');
      if (reason != null) {
        print('   reason: $reason');
      }
      break;

    case 'permission-request':
      final requestId = data?['request-id'];
      final tool = data?['tool'] as Map<String, dynamic>?;
      final toolName = tool?['name'];
      print('');
      print('⚠️  Permission requested: $toolName');
      print('   Request ID: $requestId');
      print('   (Auto-approving in this client)');
      // TODO: Implement interactive permission handling
      break;

    case 'done':
      // Close any open streaming message
      if (_currentStreamRole == 'assistant') {
        print('');
        print('└─');
      }
      _currentEventId = null;
      _currentStreamRole = null;
      _currentStreamBuffer.clear();

      print('');
      print('✓ Turn complete');
      break;

    case 'error':
      print('');
      print('✗ Error: ${data?['message']}');
      final code = data?['code'];
      if (code != null) {
        print('  Code: $code');
      }
      break;

    default:
      print('[Event: $type]');
  }
}
