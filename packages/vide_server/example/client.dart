#!/usr/bin/env dart

/// Interactive REPL client for Vide Server (Phase 2.5 Session API)
///
/// Usage:
///   dart run example/client.dart --port 63139
///   dart run example/client.dart -p 63139
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

import 'lib/vide_client.dart';

void main(List<String> args) async {
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

  if (argResults['help'] as bool || args.isEmpty) {
    printUsage();
    exit(args.isEmpty ? 1 : 0);
  }

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
  final client = VideClient(port: port);

  print('╔════════════════════════════════════════════════════════════════╗');
  print('║              Vide Interactive REPL Client                      ║');
  print('╚════════════════════════════════════════════════════════════════╝');
  print('');
  print('Server: http://127.0.0.1:$port');
  print('Working Directory: $workingDir');
  print('');
  print('Type /help for available commands.');
  print('');

  print('→ Connecting to server...');
  try {
    await client.checkHealth();
  } on VideClientException catch (e) {
    print('✗ Error: ${e.message}');
    print('  Please start the server first:');
    print('    cd packages/vide_server && dart run bin/vide_server.dart');
    exit(1);
  } catch (e) {
    print('✗ Error: Could not connect to server on port $port');
    print('  Please check that the server is running.');
    print('  Start the server with:');
    print('    cd packages/vide_server && dart run bin/vide_server.dart');
    exit(1);
  }
  print('✓ Connected');
  print('');

  await _runRepl(client, workingDir);
}

Future<void> _runRepl(VideClient client, String workingDir) async {
  print('╔════════════════════════════════════════════════════════════════╗');
  print('║                    Interactive Session                         ║');
  print('╚════════════════════════════════════════════════════════════════╝');
  print('');
  print('Type your first message to start the session.');
  print('');
  stdout.write('You: ');

  Session? session;
  final eventHandler = _EventHandler();

  await for (final line
      in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    final input = line.trim();
    final inputLower = input.toLowerCase();

    if (inputLower == '/exit' ||
        inputLower == '/quit' ||
        inputLower == 'exit' ||
        inputLower == 'quit') {
      print('');
      if (session != null) {
        print('Ending session...');
        await session.close();
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

    if (input.isEmpty) {
      stdout.write('You: ');
      continue;
    }

    if (session == null) {
      print('');
      print('→ Creating session with your message...');

      try {
        session = await client.createSession(
          initialMessage: input,
          workingDirectory: workingDir,
        );
      } on VideClientException catch (e) {
        print('✗ Error creating session: ${e.message}');
        stdout.write('\nYou: ');
        continue;
      }

      print('✓ Session created (ID: ${session.id})');
      print('');

      final s = session;
      s.events.listen(
        (event) {
          eventHandler.handle(event);

          if (event is DoneEvent && s.status == SessionStatus.open) {
            stdout.write('\nYou: ');
          }
        },
        onError: (error) {
          print('\n✗ Stream error: $error');
        },
        onDone: () {
          if (s.status == SessionStatus.error) {
            print('\n✗ Connection error: ${s.error}');
          }
        },
      );
    } else {
      print('');
      session.send(input);
    }
  }

  print('');
  print('╔════════════════════════════════════════════════════════════════╗');
  print('║                    Session Complete                            ║');
  print('╚════════════════════════════════════════════════════════════════╝');
}

/// Handles incoming events with streaming message support.
class _EventHandler {
  String? _currentEventId;
  MessageRole? _currentStreamRole;
  final _buffer = StringBuffer();

  void handle(VideEvent event) {
    final agentName = event.agent?.name ?? 'Agent';

    switch (event) {
      case ConnectedEvent(:final sessionId, :final mainAgentId):
        print('[$agentName] Connected to session $sessionId');
        print('  Main agent: $mainAgentId');

      case HistoryEvent(:final lastSeq, :final events):
        if (events.isNotEmpty) {
          print(
            '[$agentName] Loaded ${events.length} history events (seq: $lastSeq)',
          );
        }

      case StatusEvent(:final status):
        print('[$agentName] Status: ${status.name}');

      case MessageEvent(
        :final role,
        :final content,
        :final isPartial,
        :final eventId,
      ):
        _handleMessage(role, content, isPartial, eventId);

      case ToolUseEvent(:final toolName):
        _closeStreamingMessage();
        print('');
        print('🔧 Using tool: $toolName');

      case ToolResultEvent(:final toolName, :final isError):
        if (isError) {
          print('   ✗ Error from $toolName');
        } else {
          print('   ✓ $toolName completed');
        }

      case AgentSpawnedEvent(:final spawnedBy):
        print('');
        print('🚀 Agent spawned: $agentName (${event.agent?.id})');
        print('   by: $spawnedBy');

      case AgentTerminatedEvent(:final reason):
        print('');
        print('🛑 Agent terminated: $agentName');
        if (reason != null) {
          print('   reason: $reason');
        }

      case PermissionRequestEvent(:final requestId, :final toolName):
        print('');
        print('⚠️  Permission requested: $toolName');
        print('   Request ID: $requestId');
        print('   (Auto-approving in this client)');

      case PermissionResolvedEvent(
        :final requestId,
        :final allow,
        :final message,
      ):
        print('');
        print(
          '${allow ? '✅' : '❌'} Permission ${allow ? 'allowed' : 'denied'}: $requestId',
        );
        if (message != null) {
          print('   message: $message');
        }

      case DoneEvent():
        _closeStreamingMessage();
        print('');
        print('✓ Turn complete');

      case AbortedEvent():
        _closeStreamingMessage();
        print('');
        print('🛑 Aborted');

      case ErrorEvent(:final message, :final code):
        print('');
        print('✗ Error: $message');
        if (code != null) {
          print('  Code: $code');
        }

      case UnknownEvent(:final type):
        print('[Event: $type]');
    }
  }

  void _handleMessage(
    MessageRole role,
    String content,
    bool isPartial,
    String? eventId,
  ) {
    if (_currentEventId != eventId) {
      if (_currentStreamRole == MessageRole.assistant && _buffer.isNotEmpty) {
        print('');
        print('└─');
      }

      _currentEventId = eventId;
      _currentStreamRole = role;
      _buffer.clear();
      _buffer.write(content);

      if (role == MessageRole.user) {
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
      if (_currentStreamRole == MessageRole.assistant && content.isNotEmpty) {
        _buffer.write(content);
        stdout.write(content);
      }
    }

    if (!isPartial && _currentStreamRole == MessageRole.assistant) {
      print('');
      print('└─');
      _currentEventId = null;
      _currentStreamRole = null;
      _buffer.clear();
    }
  }

  void _closeStreamingMessage() {
    if (_currentStreamRole == MessageRole.assistant && _buffer.isNotEmpty) {
      print('');
      print('└─');
    }
    _currentEventId = null;
    _currentStreamRole = null;
    _buffer.clear();
  }
}
