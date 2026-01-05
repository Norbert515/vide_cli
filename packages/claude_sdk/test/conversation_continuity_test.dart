@Tags(['e2e'])
library;

import 'dart:async';
import 'dart:io';

import 'package:claude_sdk/claude_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('Conversation Continuity E2E', () {
    late bool claudeAvailable;

    setUpAll(() async {
      // Check if Claude CLI is available
      try {
        final result = await Process.run('which', ['claude']);
        claudeAvailable = result.exitCode == 0;
      } catch (_) {
        claudeAvailable = false;
      }
    });

    test(
      'maintains context across multiple messages',
      () async {
        if (!claudeAvailable) {
          markTestSkipped('Claude CLI not available');
          return;
        }

        final client = await ClaudeClient.create(
          config: ClaudeConfig(verbose: false),
        );
        addTearDown(() => client.close());

        final messages = <String>[];

        client.conversation.listen((conversation) {
          if (conversation.lastMessage != null &&
              conversation.lastMessage!.role == MessageRole.assistant &&
              conversation.lastMessage!.isComplete) {
            messages.add(conversation.lastMessage!.content);
          }
        });

        // Send first message
        client.sendMessage(
          Message.text(
            'Remember the number 42. Reply with just: "I will remember 42"',
          ),
        );

        // Wait for first response
        await client.onTurnComplete.first.timeout(
          const Duration(seconds: 30),
          onTimeout: () => fail('Timeout waiting for first response'),
        );

        expect(messages.length, equals(1));

        // Small delay to avoid session conflict
        await Future.delayed(const Duration(seconds: 2));

        // Send second message to test context
        client.sendMessage(
          Message.text(
            'What number are you remembering? Reply with just the number.',
          ),
        );

        // Wait for second response
        await client.onTurnComplete.first.timeout(
          const Duration(seconds: 30),
          onTimeout: () => fail('Timeout waiting for second response'),
        );

        expect(messages.length, equals(2));
        expect(messages[1].toLowerCase(), contains('42'));
      },
      timeout: Timeout(Duration(minutes: 2)),
    );
  });
}
