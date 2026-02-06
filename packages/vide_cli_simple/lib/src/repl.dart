import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:vide_core/vide_core.dart';

import 'event_renderer.dart';

/// Runs the interactive REPL.
Future<void> runRepl({
  required VideCore core,
  required String workingDirectory,
  String? model,
  required String team,
  String? initialMessage,
}) async {
  final renderer = EventRenderer(useColors: stdout.hasTerminal);
  VideSession? session;
  StreamSubscription<VideEvent>? eventSub;

  // Pending permission request (if any)
  PermissionRequestEvent? pendingPermission;

  // Completer for waiting for turn to complete
  Completer<void>? turnCompleter;

  void subscribeToSession(VideSession s) {
    eventSub?.cancel();
    eventSub = s.events.listen((event) {
      renderer.render(event);

      // Track permission requests
      if (event is PermissionRequestEvent) {
        pendingPermission = event;
      }

      // Track turn completion
      if (event is TurnCompleteEvent) {
        turnCompleter?.complete();
        turnCompleter = null;
      }
    });
  }

  // Start session if initial message provided
  if (initialMessage != null && initialMessage.isNotEmpty) {
    stdout.writeln('Starting session with team: $team...');
    session = await core.startSession(
      VideSessionConfig(
        workingDirectory: workingDirectory,
        initialMessage: initialMessage,
        model: model,
        team: team,
      ),
    );
    subscribeToSession(session);

    // Wait for turn to complete
    turnCompleter = Completer<void>();
    stdout.writeln();

    // Wait with timeout
    try {
      await turnCompleter!.future.timeout(
        const Duration(minutes: 10),
        onTimeout: () {
          stdout.writeln('\n[Timeout waiting for response]');
        },
      );
    } catch (_) {
      // Ignore timeout errors
    }
  }

  // Print welcome message
  stdout.writeln();
  stdout.writeln(
    '╔════════════════════════════════════════════════════════════╗',
  );
  stdout.writeln(
    '║  vide_cli - Simple CLI for testing vide_core API           ║',
  );
  stdout.writeln(
    '╠════════════════════════════════════════════════════════════╣',
  );
  stdout.writeln(
    '║  Commands:                                                 ║',
  );
  stdout.writeln(
    '║    /help     - Show this help                              ║',
  );
  stdout.writeln(
    '║    /agents   - List agents in session                      ║',
  );
  stdout.writeln(
    '║    /sessions - List all sessions                           ║',
  );
  stdout.writeln(
    '║    /abort    - Abort current operation                     ║',
  );
  stdout.writeln(
    '║    /quit     - Exit the CLI                                ║',
  );
  stdout.writeln(
    '║                                                            ║',
  );
  stdout.writeln(
    '║  Type a message to chat with the agent.                    ║',
  );
  stdout.writeln(
    '╚════════════════════════════════════════════════════════════╝',
  );
  stdout.writeln();

  // Use async stdin reading to allow event processing
  final stdinLines = stdin
      .transform(utf8.decoder)
      .transform(const LineSplitter());

  // REPL loop
  await for (final input in stdinLines) {
    if (input == '/quit' || input == '/q') {
      break;
    }

    // Handle permission response
    if (pendingPermission != null) {
      final allow = input.toLowerCase() == 'y' || input.toLowerCase() == 'yes';
      session?.respondToPermission(
        pendingPermission!.requestId,
        allow: allow,
        message: allow ? null : 'User denied permission',
      );
      pendingPermission = null;
      stdout.write('> ');
      continue;
    }

    // Handle commands
    if (input.startsWith('/')) {
      await _handleCommand(input, core, session, renderer);
      stdout.write('> ');
      continue;
    }

    // Handle empty input
    if (input.trim().isEmpty) {
      stdout.write('> ');
      continue;
    }

    // Send message
    if (session == null) {
      stdout.writeln('Starting new session with team: $team...');
      session = await core.startSession(
        VideSessionConfig(
          workingDirectory: workingDirectory,
          initialMessage: input,
          model: model,
          team: team,
        ),
      );
      subscribeToSession(session);
    } else {
      session.sendMessage(VideMessage(text: input));
    }

    // Wait for turn to complete
    turnCompleter = Completer<void>();
    try {
      await turnCompleter!.future.timeout(
        const Duration(minutes: 10),
        onTimeout: () {
          stdout.writeln('\n[Timeout waiting for response]');
        },
      );
    } catch (_) {
      // Ignore timeout errors
    }
    stdout.write('> ');
  }

  // Cleanup
  stdout.writeln('Goodbye!');
  await eventSub?.cancel();
  await session?.dispose();
  core.dispose();
}

Future<void> _handleCommand(
  String cmd,
  VideCore core,
  VideSession? session,
  EventRenderer renderer,
) async {
  final parts = cmd.split(' ');
  final command = parts[0].toLowerCase();

  switch (command) {
    case '/help':
    case '/h':
      stdout.writeln('Commands:');
      stdout.writeln('  /help, /h     - Show this help');
      stdout.writeln('  /agents, /a   - List agents in session');
      stdout.writeln('  /sessions, /s - List all sessions');
      stdout.writeln('  /abort        - Abort current operation');
      stdout.writeln('  /quit, /q     - Exit the CLI');

    case '/agents':
    case '/a':
      if (session == null) {
        stdout.writeln('No active session. Send a message to start one.');
        return;
      }
      final agents = session.agents;
      if (agents.isEmpty) {
        stdout.writeln('No agents in session.');
      } else {
        stdout.writeln('Agents (${agents.length}):');
        for (final agent in agents) {
          final status = switch (agent.status) {
            VideAgentStatus.working => '⚙ working',
            VideAgentStatus.waitingForAgent => '⏳ waiting for agent',
            VideAgentStatus.waitingForUser => '? waiting for user',
            VideAgentStatus.idle => '✓ idle',
          };
          stdout.writeln('  ${agent.name} (${agent.type}) - $status');
          if (agent.taskName != null) {
            stdout.writeln('    Task: ${agent.taskName}');
          }
        }
      }

    case '/sessions':
    case '/s':
      final sessions = await core.listSessions();
      if (sessions.isEmpty) {
        stdout.writeln('No saved sessions.');
      } else {
        stdout.writeln('Sessions (${sessions.length}):');
        for (final s in sessions) {
          stdout.writeln('  ${s.id.substring(0, 8)}... - ${s.goal}');
          stdout.writeln('    Created: ${s.createdAt}');
          stdout.writeln('    Agents: ${s.agents.length}');
        }
      }

    case '/abort':
      if (session == null) {
        stdout.writeln('No active session.');
        return;
      }
      await session.abort();
      stdout.writeln('Aborted.');

    default:
      stdout.writeln('Unknown command: $command');
      stdout.writeln('Type /help for available commands.');
  }
}
