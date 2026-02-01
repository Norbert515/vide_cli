import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:claude_sdk/claude_sdk.dart';
import 'package:vide_core/vide_core.dart' show RemoteVideSession;

void main() {
  group('RemoteVideSession conversation handling', () {
    late RemoteVideSession session;
    late String agentId;
    int seq = 0;

    setUp(() {
      session = RemoteVideSession.pending();
      agentId = session.mainAgent!.id;
      seq = 0;
    });

    // Note: We don't dispose in tearDown because some tests check state after
    // the test completes. Instead, each test that needs disposal should handle it.

    group('user messages', () {
      test('addPendingUserMessage adds user message to conversation', () {
        session.addPendingUserMessage('Hello, world!');

        final conversation = session.getConversation(agentId);
        expect(conversation, isNotNull);
        expect(conversation!.messages.length, equals(1));
        expect(conversation.messages[0].role, equals(MessageRole.user));
        expect(conversation.messages[0].content, equals('Hello, world!'));
        expect(conversation.messages[0].isComplete, isTrue);
      });

      test('user message clears assistant message tracking', () {
        // Simulate assistant text
        _simulateMessage(session, agentId, 'assistant', 'Hello!', seq: ++seq);

        // Simulate user message
        _simulateMessage(session, agentId, 'user', 'Hi back!', seq: ++seq);

        // Simulate more assistant text (should create new message)
        _simulateMessage(session, agentId, 'assistant', 'How can I help?', seq: ++seq);

        final conversation = session.getConversation(agentId);
        expect(conversation!.messages.length, equals(3));
        expect(conversation.messages[0].role, equals(MessageRole.assistant));
        expect(conversation.messages[1].role, equals(MessageRole.user));
        expect(conversation.messages[2].role, equals(MessageRole.assistant));
      });
    });

    group('assistant messages', () {
      test('accumulates text in single message during turn', () {
        // Simulate streaming text
        _simulateMessage(session, agentId, 'assistant', 'Hello', seq: ++seq, isPartial: true);
        _simulateMessage(session, agentId, 'assistant', ' world', seq: ++seq, isPartial: true);
        _simulateMessage(session, agentId, 'assistant', '!', seq: ++seq, isPartial: false);

        final conversation = session.getConversation(agentId);
        expect(conversation!.messages.length, equals(1));
        expect(conversation.messages[0].content, equals('Hello world!'));
        // Each text chunk creates a TextResponse
        expect(conversation.messages[0].responses.length, equals(3));
        expect(conversation.messages[0].responses.every((r) => r is TextResponse), isTrue);
      });

      test('marks message complete on done event', () {
        // Simulate text then done
        _simulateMessage(session, agentId, 'assistant', 'Response', seq: ++seq, isPartial: true);
        _simulateDone(session, agentId, seq: ++seq);

        final conversation = session.getConversation(agentId);
        expect(conversation!.messages[0].isStreaming, isFalse);
        expect(conversation.messages[0].isComplete, isTrue);
      });
    });

    group('tool use and result', () {
      test('adds tool use to current assistant message', () {
        // Simulate text then tool use
        _simulateMessage(session, agentId, 'assistant', 'Let me check...', seq: ++seq, isPartial: true);
        _simulateToolUse(session, agentId, 'tool-1', 'Bash', {'command': 'ls'}, seq: ++seq);

        final conversation = session.getConversation(agentId);
        expect(conversation!.messages.length, equals(1));
        expect(conversation.messages[0].responses.length, equals(2));
        expect(conversation.messages[0].responses[0], isA<TextResponse>());
        expect(conversation.messages[0].responses[1], isA<ToolUseResponse>());

        final toolUse = conversation.messages[0].responses[1] as ToolUseResponse;
        expect(toolUse.toolName, equals('Bash'));
        expect(toolUse.parameters['command'], equals('ls'));
      });

      test('adds tool result to current assistant message', () {
        // Simulate tool use then result
        _simulateToolUse(session, agentId, 'tool-1', 'Bash', {'command': 'ls'}, seq: ++seq);
        _simulateToolResult(session, agentId, 'tool-1', 'file1.txt\nfile2.txt', seq: ++seq);

        final conversation = session.getConversation(agentId);
        expect(conversation!.messages.length, equals(1));
        expect(conversation.messages[0].responses.length, equals(2));
        expect(conversation.messages[0].responses[0], isA<ToolUseResponse>());
        expect(conversation.messages[0].responses[1], isA<ToolResultResponse>());

        final toolResult = conversation.messages[0].responses[1] as ToolResultResponse;
        expect(toolResult.content, equals('file1.txt\nfile2.txt'));
        expect(toolResult.isError, isFalse);
      });

      test('handles tool error result', () {
        _simulateToolUse(session, agentId, 'tool-1', 'Bash', {'command': 'invalid'}, seq: ++seq);
        _simulateToolResult(session, agentId, 'tool-1', 'Command not found', seq: ++seq, isError: true);

        final conversation = session.getConversation(agentId);
        final toolResult = conversation!.messages[0].responses[1] as ToolResultResponse;
        expect(toolResult.isError, isTrue);
      });

      test('interleaves text, tool use, result, more text in single message', () {
        // Simulate complex turn: text -> tool -> result -> text -> tool -> result -> text
        _simulateMessage(session, agentId, 'assistant', 'Checking...', seq: ++seq, isPartial: true);
        _simulateToolUse(session, agentId, 'tool-1', 'Bash', {'command': 'ls'}, seq: ++seq);
        _simulateToolResult(session, agentId, 'tool-1', 'file.txt', seq: ++seq);
        _simulateMessage(session, agentId, 'assistant', 'Found file.txt. ', seq: ++seq, isPartial: true);
        _simulateToolUse(session, agentId, 'tool-2', 'Read', {'file_path': '/file.txt'}, seq: ++seq);
        _simulateToolResult(session, agentId, 'tool-2', 'contents', seq: ++seq);
        _simulateMessage(session, agentId, 'assistant', 'Done!', seq: ++seq, isPartial: false);
        _simulateDone(session, agentId, seq: ++seq);

        final conversation = session.getConversation(agentId);
        expect(conversation!.messages.length, equals(1));

        final responses = conversation.messages[0].responses;
        expect(responses.length, equals(7));
        expect(responses[0], isA<TextResponse>()); // Checking...
        expect(responses[1], isA<ToolUseResponse>()); // Bash
        expect(responses[2], isA<ToolResultResponse>()); // file.txt
        expect(responses[3], isA<TextResponse>()); // Found file.txt
        expect(responses[4], isA<ToolUseResponse>()); // Read
        expect(responses[5], isA<ToolResultResponse>()); // contents
        expect(responses[6], isA<TextResponse>()); // Done!

        // Verify the message is complete
        expect(conversation.messages[0].isComplete, isTrue);
        expect(conversation.messages[0].isStreaming, isFalse);
      });

      test('creates assistant message if tool use arrives first', () {
        // Tool use without prior text
        _simulateToolUse(session, agentId, 'tool-1', 'Bash', {'command': 'ls'}, seq: ++seq);

        final conversation = session.getConversation(agentId);
        expect(conversation!.messages.length, equals(1));
        expect(conversation.messages[0].role, equals(MessageRole.assistant));
        expect(conversation.messages[0].responses[0], isA<ToolUseResponse>());
      });

      test('tool result without matching tool use is handled gracefully', () {
        // Send tool result without tool use (edge case)
        _simulateToolResult(session, agentId, 'orphan-tool', 'result', seq: ++seq);

        // Should not crash - result added to empty or created message
        final conversation = session.getConversation(agentId);
        // Graceful handling - might have no messages if there was no assistant message
        expect(conversation, isNotNull);
      });
    });

    group('conversation stream', () {
      test('emits updates when messages change', () async {
        final updates = <Conversation>[];
        final subscription = session.conversationStream(agentId).listen(updates.add);

        // Allow subscription to be set up
        await Future.delayed(Duration.zero);

        _simulateMessage(session, agentId, 'assistant', 'Hello', seq: ++seq, isPartial: true);

        // Allow event to propagate
        await Future.delayed(Duration.zero);

        _simulateMessage(session, agentId, 'assistant', '!', seq: ++seq, isPartial: false);

        await Future.delayed(Duration.zero);

        await subscription.cancel();

        expect(updates.length, greaterThanOrEqualTo(2));
      });
    });

    group('pending session', () {
      test('has placeholder main agent initially', () {
        expect(session.isPending, isTrue);
        expect(session.mainAgent, isNotNull);
        expect(session.mainAgent!.name, equals('Connecting...'));
      });

      // Note: Tests that call completePending are skipped because they attempt
      // to connect to a WebSocket, which causes timeouts in the test environment.
      // The synchronous state changes are tested indirectly through other tests.

      test('failPending sets error state', () {
        session.failPending('Connection refused');

        expect(session.isPending, isFalse);
        expect(session.creationError, equals('Connection refused'));
        expect(session.mainAgent!.name, equals('Error'));
      });

      // completePending callback test removed - triggers WebSocket connection

      test('onPendingComplete callback is called on failure', () {
        var callbackCalled = false;
        session.onPendingComplete = () => callbackCalled = true;

        session.failPending('Error');

        expect(callbackCalled, isTrue);
      });

      // completePending preserves messages test removed - triggers WebSocket connection
    });

    group('multiple turns', () {
      test('handles user -> assistant -> user -> assistant flow', () {
        // First user message
        session.addPendingUserMessage('Question 1?');

        // First assistant response
        _simulateMessage(session, agentId, 'assistant', 'Answer 1', seq: ++seq, isPartial: false);
        _simulateDone(session, agentId, seq: ++seq);

        // Second user message
        _simulateMessage(session, agentId, 'user', 'Question 2?', seq: ++seq);

        // Second assistant response
        _simulateMessage(session, agentId, 'assistant', 'Answer 2', seq: ++seq, isPartial: false);
        _simulateDone(session, agentId, seq: ++seq);

        final conversation = session.getConversation(agentId);
        expect(conversation!.messages.length, equals(4));
        expect(conversation.messages[0].role, equals(MessageRole.user));
        expect(conversation.messages[0].content, equals('Question 1?'));
        expect(conversation.messages[1].role, equals(MessageRole.assistant));
        expect(conversation.messages[1].content, equals('Answer 1'));
        expect(conversation.messages[2].role, equals(MessageRole.user));
        expect(conversation.messages[2].content, equals('Question 2?'));
        expect(conversation.messages[3].role, equals(MessageRole.assistant));
        expect(conversation.messages[3].content, equals('Answer 2'));
      });

      test('each assistant turn is a separate message', () {
        // Turn 1
        _simulateMessage(session, agentId, 'assistant', 'Turn 1', seq: ++seq, isPartial: false);
        _simulateDone(session, agentId, seq: ++seq);

        // User
        _simulateMessage(session, agentId, 'user', 'Follow up', seq: ++seq);

        // Turn 2
        _simulateMessage(session, agentId, 'assistant', 'Turn 2', seq: ++seq, isPartial: false);
        _simulateDone(session, agentId, seq: ++seq);

        final conversation = session.getConversation(agentId);
        expect(conversation!.messages.length, equals(3));

        // Each assistant message should be separate and complete
        expect(conversation.messages[0].isComplete, isTrue);
        expect(conversation.messages[2].isComplete, isTrue);
      });
    });

    group('sequence deduplication', () {
      test('ignores duplicate seq numbers', () {
        // Send same seq twice
        _simulateMessage(session, agentId, 'assistant', 'First', seq: 1, isPartial: true);
        _simulateMessage(session, agentId, 'assistant', 'Duplicate', seq: 1, isPartial: true);

        final conversation = session.getConversation(agentId);
        expect(conversation!.messages.length, equals(1));
        // Only first message should be recorded
        expect(conversation.messages[0].content, equals('First'));
      });

      test('accepts increasing seq numbers', () {
        _simulateMessage(session, agentId, 'assistant', 'A', seq: 1, isPartial: true);
        _simulateMessage(session, agentId, 'assistant', 'B', seq: 2, isPartial: true);
        _simulateMessage(session, agentId, 'assistant', 'C', seq: 3, isPartial: false);

        final conversation = session.getConversation(agentId);
        expect(conversation!.messages[0].content, equals('ABC'));
      });
    });

    group('connection state', () {
      test('connectionStateStream is available', () {
        // Simply verify the stream is accessible without errors
        expect(session.connectionStateStream, isNotNull);
        expect(session.isConnected, isFalse);
      });

      test('isConnected returns false for pending session', () {
        expect(session.isPending, isTrue);
        expect(session.isConnected, isFalse);
      });
    });

    group('agent spawning', () {
      test('agentsStream emits when agent is spawned', () async {
        final updates = <List<dynamic>>[];
        final subscription = session.agentsStream.listen(updates.add);

        // Allow subscription to be set up
        await Future.delayed(Duration.zero);

        _simulateAgentSpawned(
          session,
          'sub-agent-1',
          'implementer',
          'Code Helper',
          seq: ++seq,
        );

        // Allow event to propagate
        await Future.delayed(Duration.zero);

        await subscription.cancel();

        expect(updates.length, greaterThanOrEqualTo(1));
        // The agents list should include both main and spawned agent
        expect(updates.last.length, equals(2));
      });

      test('agents list includes spawned agents', () {
        // Initially has just the placeholder main agent
        expect(session.agents.length, equals(1));

        _simulateAgentSpawned(
          session,
          'sub-agent-1',
          'implementer',
          'Code Helper',
          seq: ++seq,
        );

        expect(session.agents.length, equals(2));
        expect(session.agents.any((a) => a.id == 'sub-agent-1'), isTrue);
        expect(session.agents.any((a) => a.name == 'Code Helper'), isTrue);
      });

      test('agentsStream emits when agent is terminated', () async {
        // First spawn an agent
        _simulateAgentSpawned(
          session,
          'sub-agent-1',
          'implementer',
          'Code Helper',
          seq: ++seq,
        );

        final updates = <List<dynamic>>[];
        final subscription = session.agentsStream.listen(updates.add);

        // Allow subscription to be set up
        await Future.delayed(Duration.zero);

        _simulateAgentTerminated(session, 'sub-agent-1', seq: ++seq);

        // Allow event to propagate
        await Future.delayed(Duration.zero);

        await subscription.cancel();

        expect(updates.length, greaterThanOrEqualTo(1));
        // Should be back to just main agent
        expect(updates.last.length, equals(1));
      });

      test('agents list removes terminated agents', () {
        _simulateAgentSpawned(
          session,
          'sub-agent-1',
          'implementer',
          'Code Helper',
          seq: ++seq,
        );

        expect(session.agents.length, equals(2));

        _simulateAgentTerminated(session, 'sub-agent-1', seq: ++seq);

        expect(session.agents.length, equals(1));
        expect(session.agents.any((a) => a.id == 'sub-agent-1'), isFalse);
      });

      test('multiple spawned agents appear in list', () {
        _simulateAgentSpawned(
          session,
          'agent-1',
          'implementer',
          'Implementer',
          seq: ++seq,
        );
        _simulateAgentSpawned(
          session,
          'agent-2',
          'researcher',
          'Researcher',
          seq: ++seq,
        );
        _simulateAgentSpawned(
          session,
          'agent-3',
          'qa-breaker',
          'Tester',
          seq: ++seq,
        );

        expect(session.agents.length, equals(4)); // main + 3 spawned
        expect(session.agents.any((a) => a.id == 'agent-1'), isTrue);
        expect(session.agents.any((a) => a.id == 'agent-2'), isTrue);
        expect(session.agents.any((a) => a.id == 'agent-3'), isTrue);
      });
    });
  });
}

// Helper functions to simulate WebSocket events through the test hook

void _simulateMessage(
  RemoteVideSession session,
  String agentId,
  String role,
  String content, {
  required int seq,
  bool isPartial = false,
}) {
  final json = jsonEncode({
    'type': 'message',
    'seq': seq,
    'agent-id': agentId,
    'event-id': 'evt-$seq',
    'is-partial': isPartial,
    'data': {
      'role': role,
      'content': content,
    },
  });
  session.handleWebSocketMessage(json);
}

void _simulateToolUse(
  RemoteVideSession session,
  String agentId,
  String toolUseId,
  String toolName,
  Map<String, dynamic> toolInput, {
  required int seq,
}) {
  final json = jsonEncode({
    'type': 'tool-use',
    'seq': seq,
    'agent-id': agentId,
    'data': {
      'tool-use-id': toolUseId,
      'tool-name': toolName,
      'tool-input': toolInput,
    },
  });
  session.handleWebSocketMessage(json);
}

void _simulateToolResult(
  RemoteVideSession session,
  String agentId,
  String toolUseId,
  String result, {
  required int seq,
  bool isError = false,
}) {
  final json = jsonEncode({
    'type': 'tool-result',
    'seq': seq,
    'agent-id': agentId,
    'data': {
      'tool-use-id': toolUseId,
      'result': result,
      'is-error': isError,
    },
  });
  session.handleWebSocketMessage(json);
}

void _simulateDone(
  RemoteVideSession session,
  String agentId, {
  required int seq,
}) {
  final json = jsonEncode({
    'type': 'done',
    'seq': seq,
    'agent-id': agentId,
    'data': {
      'reason': 'complete',
    },
  });
  session.handleWebSocketMessage(json);
}

void _simulateAgentSpawned(
  RemoteVideSession session,
  String agentId,
  String agentType,
  String? agentName, {
  required int seq,
  String spawnedBy = 'main',
}) {
  final json = jsonEncode({
    'type': 'agent-spawned',
    'seq': seq,
    'agent-id': agentId,
    'agent-type': agentType,
    'agent-name': agentName,
    'data': {
      'spawned-by': spawnedBy,
    },
  });
  session.handleWebSocketMessage(json);
}

void _simulateAgentTerminated(
  RemoteVideSession session,
  String agentId, {
  required int seq,
}) {
  final json = jsonEncode({
    'type': 'agent-terminated',
    'seq': seq,
    'agent-id': agentId,
    'data': {},
  });
  session.handleWebSocketMessage(json);
}
