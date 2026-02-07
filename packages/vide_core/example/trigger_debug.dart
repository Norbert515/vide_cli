// Quick debug script to test trigger flow
//
// Run with: dart run example/trigger_debug.dart

import 'dart:async';
import 'dart:io';

import 'package:riverpod/riverpod.dart';
import 'package:vide_core/vide_core.dart';

void main() async {
  print('=== Trigger Debug Script ===');
  print('Working directory: ${Directory.current.path}');
  print('');

  // Create session manager with isolated containers (each session independent)
  final permissionHandler = PermissionHandler();
  final container = ProviderContainer(
    overrides: [
      videConfigManagerProvider.overrideWithValue(
        VideConfigManager(configRoot: '${Platform.environment['HOME']}/.vide'),
      ),
      workingDirProvider.overrideWithValue(Directory.current.path),
    ],
  );
  final sessionManager = LocalVideSessionManager.isolated(
    container,
    permissionHandler,
  );

  print('Starting session with enterprise team...');

  try {
    // Start a session with the enterprise team
    final session = await sessionManager.createSession(
      workingDirectory: Directory.current.path,
      initialMessage:
          'Say "Hello, triggers are working!" and nothing else. This is a test.',
      team: 'enterprise',
    );

    print('Session started: ${session.id}');
    print('Listening for events...');
    print('');

    // Listen to events
    final completer = Completer<void>();
    int eventCount = 0;

    session.events.listen(
      (event) {
        eventCount++;
        print('[$eventCount] Event: ${event.runtimeType}');

        if (event is MessageEvent) {
          final content = event.content;
          if (content.isNotEmpty) {
            print(
              '   Content: ${content.substring(0, content.length.clamp(0, 100))}${content.length > 100 ? "..." : ""}',
            );
          }
        } else if (event is StatusEvent) {
          print('   Agent ${event.agentId} status: ${event.status}');
        } else if (event is AgentSpawnedEvent) {
          print('   Spawned: ${event.agentName} (${event.agentType})');
        } else if (event is TurnCompleteEvent) {
          print('   Turn complete! Reason: ${event.reason}');
        }
      },
      onError: (e) {
        print('Error: $e');
      },
      onDone: () {
        print('Stream closed');
        completer.complete();
      },
    );

    // Wait for a bit to see events
    print('Waiting 30 seconds for events...');
    await Future.delayed(Duration(seconds: 30));

    print('');
    print('Session complete. Disposing...');
    await session.dispose();

    print('Done!');
  } catch (e, stack) {
    print('Error: $e');
    print(stack);
  } finally {
    sessionManager.dispose();
    container.dispose();
  }

  exit(0);
}
