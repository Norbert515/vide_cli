import 'dart:async';
import 'package:claude_api/claude_api.dart';

Future<void> main() async {
  print('Testing Claude conversation continuity...\n');

  // Create a new Claude client
  final client = await ClaudeClient.create(
    config: ClaudeConfig(verbose: true, maxTokens: 100),
  );

  // Track conversation for verification
  final messages = <String>[];

  // Listen to conversation updates
  client.conversation.listen((conversation) {
    if (conversation.lastMessage != null &&
        conversation.lastMessage!.role == MessageRole.assistant &&
        conversation.lastMessage!.isComplete) {
      messages.add(conversation.lastMessage!.content);
      print(
        'Assistant response ${messages.length}: ${conversation.lastMessage!.content}\n',
      );
    }
  });

  try {
    // Send first message
    print(
      'Sending message 1: "Remember the number 42. What number should you remember?"',
    );
    client.sendMessage(
      Message.text('Remember the number 42. What number should you remember?'),
    );

    // Wait for response
    await Future.delayed(Duration(seconds: 5));

    // Send second message to test context
    print('Sending message 2: "What number did I ask you to remember?"');
    client.sendMessage(Message.text('What number did I ask you to remember?'));

    // Wait for response
    await Future.delayed(Duration(seconds: 5));

    // Send third message to further test context
    print(
      'Sending message 3: "Add 10 to the number you\'re remembering. What\'s the result?"',
    );
    client.sendMessage(
      Message.text('Add 10 to the number you\'re remembering. What\'s the result?'),
    );

    // Wait for response
    await Future.delayed(Duration(seconds: 5));

    // Verify context was maintained
    print('\n=== Conversation Context Test Results ===');
    if (messages.length >= 2) {
      final secondResponse = messages[1].toLowerCase();
      final hasContext = secondResponse.contains('42');

      if (hasContext) {
        print('✅ SUCCESS: Claude maintained conversation context!');
        print('   Second response correctly referenced the number 42');
      } else {
        print('❌ FAILURE: Claude did not maintain conversation context');
        print('   Second response did not reference the number 42');
      }

      if (messages.length >= 3) {
        final thirdResponse = messages[2].toLowerCase();
        final hasCorrectAnswer = thirdResponse.contains('52');
        if (hasCorrectAnswer) {
          print(
            '✅ SUCCESS: Third response shows continued context (42 + 10 = 52)',
          );
        } else {
          print(
            '⚠️  WARNING: Third response may not have maintained full context',
          );
        }
      }
    } else {
      print('❌ ERROR: Not enough responses received');
    }

    print('\nAll responses:');
    for (int i = 0; i < messages.length; i++) {
      print('  ${i + 1}. ${messages[i]}');
    }
  } finally {
    await client.close();
  }
}
