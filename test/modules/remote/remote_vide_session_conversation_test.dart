import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:vide_client/vide_client.dart';

void main() {
  group('RemoteVideSession conversation handling', () {
    late RemoteVideSession session;
    late String agentId;
    int seq = 0;

    setUp(() {
      session = RemoteVideSession.pending();
      agentId = session.state.mainAgent!.id;
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
        expect(conversation.messages[0].role, equals('user'));
        expect(conversation.messages[0].text, equals('Hello, world!'));
        expect(conversation.messages[0].isStreaming, isFalse);
      });

      test('user message clears assistant message tracking', () {
        // Simulate assistant text
        _simulateMessage(session, agentId, 'assistant', 'Hello!', seq: ++seq);

        // Simulate user message
        _simulateMessage(session, agentId, 'user', 'Hi back!', seq: ++seq);

        // Simulate more assistant text (should create new message)
        _simulateMessage(
          session,
          agentId,
          'assistant',
          'How can I help?',
          seq: ++seq,
        );

        final conversation = session.getConversation(agentId);
        expect(conversation!.messages.length, equals(3));
        expect(conversation.messages[0].role, equals('assistant'));
        expect(conversation.messages[1].role, equals('user'));
        expect(conversation.messages[2].role, equals('assistant'));
      });
    });

    group('assistant messages', () {
      test('accumulates text in single message during turn', () {
        // Simulate streaming text (same event-id = same message)
        _simulateMessage(
          session,
          agentId,
          'assistant',
          'Hello',
          seq: ++seq,
          isPartial: true,
          eventId: 'msg-1',
        );
        _simulateMessage(
          session,
          agentId,
          'assistant',
          ' world',
          seq: ++seq,
          isPartial: true,
          eventId: 'msg-1',
        );
        _simulateMessage(
          session,
          agentId,
          'assistant',
          '!',
          seq: ++seq,
          isPartial: false,
          eventId: 'msg-1',
        );

        final conversation = session.getConversation(agentId);
        expect(conversation!.messages.length, equals(1));
        expect(conversation.messages[0].text, equals('Hello world!'));
        // All text chunks are accumulated into one TextContent
        expect(
          conversation.messages[0].content.whereType<TextContent>().length,
          equals(1),
        );
      });

      test('marks message complete on done event', () {
        // Simulate text then done
        _simulateMessage(
          session,
          agentId,
          'assistant',
          'Response',
          seq: ++seq,
          isPartial: true,
        );
        _simulateDone(session, agentId, seq: ++seq);

        final conversation = session.getConversation(agentId);
        expect(conversation!.messages[0].isStreaming, isFalse);
      });
    });

    group('tool use and result', () {
      test('adds tool use to current assistant message', () {
        // Simulate text then tool use
        _simulateMessage(
          session,
          agentId,
          'assistant',
          'Let me check...',
          seq: ++seq,
          isPartial: true,
        );
        _simulateToolUse(session, agentId, 'tool-1', 'Bash', {
          'command': 'ls',
        }, seq: ++seq);

        final conversation = session.getConversation(agentId);
        expect(conversation!.messages.length, equals(1));
        expect(conversation.messages[0].content.length, equals(2));
        expect(conversation.messages[0].content[0], isA<TextContent>());
        expect(conversation.messages[0].content[1], isA<ToolContent>());

        final toolUse = conversation.messages[0].content[1] as ToolContent;
        expect(toolUse.toolName, equals('Bash'));
        expect(toolUse.toolInput['command'], equals('ls'));
      });

      test('adds tool result to current assistant message', () {
        // Simulate tool use then result
        _simulateToolUse(session, agentId, 'tool-1', 'Bash', {
          'command': 'ls',
        }, seq: ++seq);
        _simulateToolResult(
          session,
          agentId,
          'tool-1',
          'file1.txt\nfile2.txt',
          seq: ++seq,
        );

        final conversation = session.getConversation(agentId);
        expect(conversation!.messages.length, equals(1));
        // ToolContent holds both the invocation and result in one content block
        expect(conversation.messages[0].content.length, equals(1));
        expect(conversation.messages[0].content[0], isA<ToolContent>());

        final toolContent = conversation.messages[0].content[0] as ToolContent;
        expect(toolContent.result, equals('file1.txt\nfile2.txt'));
        expect(toolContent.isError, isFalse);
      });

      test('handles tool error result', () {
        _simulateToolUse(session, agentId, 'tool-1', 'Bash', {
          'command': 'invalid',
        }, seq: ++seq);
        _simulateToolResult(
          session,
          agentId,
          'tool-1',
          'Command not found',
          seq: ++seq,
          isError: true,
        );

        final conversation = session.getConversation(agentId);
        final toolContent = conversation!.messages[0].content[0] as ToolContent;
        expect(toolContent.isError, isTrue);
      });

      test('interleaves text, tool use, result, more text in single message', () {
        // Simulate complex turn: text -> tool -> result -> text -> tool -> result -> text
        // Each text chunk within the same assistant turn uses a different event-id
        // because tool use/result interrupts the streaming. The ConversationStateManager
        // appends new content to the last assistant message when new event-ids arrive.
        _simulateMessage(
          session,
          agentId,
          'assistant',
          'Checking...',
          seq: ++seq,
          isPartial: true,
          eventId: 'msg-1',
        );
        _simulateToolUse(session, agentId, 'tool-1', 'Bash', {
          'command': 'ls',
        }, seq: ++seq);
        _simulateToolResult(session, agentId, 'tool-1', 'file.txt', seq: ++seq);
        _simulateMessage(
          session,
          agentId,
          'assistant',
          'Found file.txt. ',
          seq: ++seq,
          isPartial: true,
          eventId: 'msg-2',
        );
        _simulateToolUse(session, agentId, 'tool-2', 'Read', {
          'file_path': '/file.txt',
        }, seq: ++seq);
        _simulateToolResult(session, agentId, 'tool-2', 'contents', seq: ++seq);
        _simulateMessage(
          session,
          agentId,
          'assistant',
          'Done!',
          seq: ++seq,
          isPartial: false,
          eventId: 'msg-3',
        );
        _simulateDone(session, agentId, seq: ++seq);

        final conversation = session.getConversation(agentId);
        // Each new event-id for an assistant message creates a new ConversationEntry
        // because the ConversationStateManager tracks messages by event-id.
        // So we get 3 assistant messages: one per text event-id.
        // Each message contains: text + tool content blocks that follow it.
        expect(conversation!.messages.length, equals(3));

        // First message: text + tool use + tool result
        expect(conversation.messages[0].content[0], isA<TextContent>());
        expect(
          (conversation.messages[0].content[0] as TextContent).text,
          equals('Checking...'),
        );
        expect(conversation.messages[0].content[1], isA<ToolContent>()); // Bash

        // Second message: text + tool use + tool result
        expect(conversation.messages[1].content[0], isA<TextContent>());
        expect(
          (conversation.messages[1].content[0] as TextContent).text,
          equals('Found file.txt. '),
        );
        expect(conversation.messages[1].content[1], isA<ToolContent>()); // Read

        // Third message: just text
        expect(conversation.messages[2].content[0], isA<TextContent>());
        expect(
          (conversation.messages[2].content[0] as TextContent).text,
          equals('Done!'),
        );

        // Verify the last message is complete
        expect(conversation.messages[2].isStreaming, isFalse);
      });

      test('creates assistant message if tool use arrives first', () {
        // Tool use without prior text
        _simulateToolUse(session, agentId, 'tool-1', 'Bash', {
          'command': 'ls',
        }, seq: ++seq);

        final conversation = session.getConversation(agentId);
        expect(conversation!.messages.length, equals(1));
        expect(conversation.messages[0].role, equals('assistant'));
        expect(conversation.messages[0].content[0], isA<ToolContent>());
      });

      test('tool result without matching tool use is handled gracefully', () {
        // Send tool result without tool use (edge case)
        _simulateToolResult(
          session,
          agentId,
          'orphan-tool',
          'result',
          seq: ++seq,
        );

        // Should not crash - orphan tool results are silently dropped
        // since there's no pending tool use to match against.
        // The conversation may or may not exist depending on whether
        // any prior events created agent state.
      });
    });

    group('conversation stream', () {
      test('emits updates when messages change', () async {
        final updates = <AgentConversationState>[];
        final subscription = session
            .conversationStream(agentId)
            .listen(updates.add);

        // Allow subscription to be set up
        await Future.delayed(Duration.zero);

        _simulateMessage(
          session,
          agentId,
          'assistant',
          'Hello',
          seq: ++seq,
          isPartial: true,
        );

        // Allow event to propagate
        await Future.delayed(Duration.zero);

        _simulateMessage(
          session,
          agentId,
          'assistant',
          '!',
          seq: ++seq,
          isPartial: false,
        );

        await Future.delayed(Duration.zero);

        await subscription.cancel();

        expect(updates.length, greaterThanOrEqualTo(2));
      });
    });

    group('pending session', () {
      test('has placeholder main agent initially', () {
        expect(session.isPending, isTrue);
        expect(session.state.mainAgent, isNotNull);
        expect(session.state.mainAgent!.name, equals('Connecting...'));
      });

      // Note: Tests that call completePending are skipped because they attempt
      // to connect to a WebSocket, which causes timeouts in the test environment.
      // The synchronous state changes are tested indirectly through other tests.

      test('failPending sets error state', () {
        session.failPending('Connection refused');

        expect(session.isPending, isFalse);
        expect(session.creationError, equals('Connection refused'));
        expect(session.state.mainAgent!.name, equals('Error'));
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
        _simulateMessage(
          session,
          agentId,
          'assistant',
          'Answer 1',
          seq: ++seq,
          isPartial: false,
        );
        _simulateDone(session, agentId, seq: ++seq);

        // Second user message
        _simulateMessage(session, agentId, 'user', 'Question 2?', seq: ++seq);

        // Second assistant response
        _simulateMessage(
          session,
          agentId,
          'assistant',
          'Answer 2',
          seq: ++seq,
          isPartial: false,
        );
        _simulateDone(session, agentId, seq: ++seq);

        final conversation = session.getConversation(agentId);
        expect(conversation!.messages.length, equals(4));
        expect(conversation.messages[0].role, equals('user'));
        expect(conversation.messages[0].text, equals('Question 1?'));
        expect(conversation.messages[1].role, equals('assistant'));
        expect(conversation.messages[1].text, equals('Answer 1'));
        expect(conversation.messages[2].role, equals('user'));
        expect(conversation.messages[2].text, equals('Question 2?'));
        expect(conversation.messages[3].role, equals('assistant'));
        expect(conversation.messages[3].text, equals('Answer 2'));
      });

      test('each assistant turn is a separate message', () {
        // Turn 1
        _simulateMessage(
          session,
          agentId,
          'assistant',
          'Turn 1',
          seq: ++seq,
          isPartial: false,
        );
        _simulateDone(session, agentId, seq: ++seq);

        // User
        _simulateMessage(session, agentId, 'user', 'Follow up', seq: ++seq);

        // Turn 2
        _simulateMessage(
          session,
          agentId,
          'assistant',
          'Turn 2',
          seq: ++seq,
          isPartial: false,
        );
        _simulateDone(session, agentId, seq: ++seq);

        final conversation = session.getConversation(agentId);
        expect(conversation!.messages.length, equals(3));

        // Each assistant message should be separate and not streaming
        expect(conversation.messages[0].isStreaming, isFalse);
        expect(conversation.messages[2].isStreaming, isFalse);
      });
    });

    group('sequence deduplication', () {
      test('ignores duplicate seq numbers', () {
        // Send same seq twice
        _simulateMessage(
          session,
          agentId,
          'assistant',
          'First',
          seq: 1,
          isPartial: true,
        );
        _simulateMessage(
          session,
          agentId,
          'assistant',
          'Duplicate',
          seq: 1,
          isPartial: true,
        );

        final conversation = session.getConversation(agentId);
        expect(conversation!.messages.length, equals(1));
        // Only first message should be recorded
        expect(conversation.messages[0].text, equals('First'));
      });

      test('accepts increasing seq numbers', () {
        _simulateMessage(
          session,
          agentId,
          'assistant',
          'A',
          seq: 1,
          isPartial: true,
          eventId: 'msg-1',
        );
        _simulateMessage(
          session,
          agentId,
          'assistant',
          'B',
          seq: 2,
          isPartial: true,
          eventId: 'msg-1',
        );
        _simulateMessage(
          session,
          agentId,
          'assistant',
          'C',
          seq: 3,
          isPartial: false,
          eventId: 'msg-1',
        );

        final conversation = session.getConversation(agentId);
        expect(conversation!.messages[0].text, equals('ABC'));
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

    group('event stream behavior', () {
      test('events are accessible via the broadcast stream', () async {
        // Subscribe first, then emit
        final events = <VideEvent>[];
        final subscription = session.events.listen(events.add);

        _simulateMessage(
          session,
          agentId,
          'assistant',
          'live-event',
          seq: ++seq,
        );

        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();

        final messageEvents = events.whereType<MessageEvent>().toList();
        expect(messageEvents.length, greaterThanOrEqualTo(1));
        expect(messageEvents.first.content, equals('live-event'));
      });
    });

    group('permission callback contract', () {
      test(
        'createPermissionCallback fails closed instead of throwing',
        () async {
          final callback = session.createPermissionCallback(
            agentId: agentId,
            agentName: session.state.mainAgent?.name,
            agentType: session.state.mainAgent?.type,
            cwd: '/tmp',
          );

          final result = await callback(
            'Bash',
            const {},
            const VidePermissionContext(),
          );
          expect(result, isA<VidePermissionDeny>());
        },
      );
    });

    group('agent spawning', () {
      test('agentsStream emits when agent is spawned', () async {
        final updates = <List<dynamic>>[];
        final subscription = session.stateStream
            .map((s) => s.agents)
            .listen(updates.add);

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
        expect(session.state.agents.length, equals(1));

        _simulateAgentSpawned(
          session,
          'sub-agent-1',
          'implementer',
          'Code Helper',
          seq: ++seq,
        );

        expect(session.state.agents.length, equals(2));
        expect(session.state.agents.any((a) => a.id == 'sub-agent-1'), isTrue);
        expect(
          session.state.agents.any((a) => a.name == 'Code Helper'),
          isTrue,
        );
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
        final subscription = session.stateStream
            .map((s) => s.agents)
            .listen(updates.add);

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

        expect(session.state.agents.length, equals(2));

        _simulateAgentTerminated(session, 'sub-agent-1', seq: ++seq);

        expect(session.state.agents.length, equals(1));
        expect(session.state.agents.any((a) => a.id == 'sub-agent-1'), isFalse);
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

        expect(session.state.agents.length, equals(4)); // main + 3 spawned
        expect(session.state.agents.any((a) => a.id == 'agent-1'), isTrue);
        expect(session.state.agents.any((a) => a.id == 'agent-2'), isTrue);
        expect(session.state.agents.any((a) => a.id == 'agent-3'), isTrue);
      });
    });

    group('history replay', () {
      test('connected metadata updates working directory, goal, and team', () {
        final mainAgentIdFromServer = 'main-agent-meta';
        final ts = DateTime.now().toIso8601String();
        final connectedJson = jsonEncode({
          'type': 'connected',
          'seq': 0,
          'session-id': 'test-session-meta',
          'main-agent-id': mainAgentIdFromServer,
          'last-seq': 0,
          'timestamp': ts,
          'agents': [
            {'id': mainAgentIdFromServer, 'type': 'main', 'name': 'Main Agent'},
          ],
          'metadata': {
            'working-directory': '/tmp/test-project',
            'goal': 'Fix flaky tests',
            'team': 'enterprise',
          },
        });

        session.handleWebSocketMessage(connectedJson);

        expect(session.state.workingDirectory, equals('/tmp/test-project'));
        expect(session.state.goal, equals('Fix flaky tests'));
        expect(session.state.team, equals('enterprise'));
      });

      test(
        'task-name-changed updates goal and emits goal stream event',
        () async {
          final emittedGoals = <String>[];
          final goalSub = session.stateStream
              .map((s) => s.goal)
              .distinct()
              .listen(emittedGoals.add);

          final ts = DateTime.now().toIso8601String();
          session.handleWebSocketMessage(
            jsonEncode({
              'type': 'task-name-changed',
              'seq': 1,
              'timestamp': ts,
              'data': {
                'new-goal': 'Ship API cleanup',
                'previous-goal': 'Session',
              },
            }),
          );

          await Future.delayed(Duration(milliseconds: 10));

          expect(session.state.goal, equals('Ship API cleanup'));
          expect(emittedGoals, contains('Ship API cleanup'));

          await goalSub.cancel();
        },
      );

      test('agents from history events are populated', () {
        // First simulate connected event which sets up main agent
        final mainAgentIdFromServer = 'main-agent-123';
        final ts = DateTime.now().toIso8601String();
        final connectedJson = jsonEncode({
          'type': 'connected',
          'seq': 0,
          'session-id': 'test-session-123',
          'main-agent-id': mainAgentIdFromServer,
          'last-seq': 0,
          'timestamp': ts,
          'agents': [
            {'id': mainAgentIdFromServer, 'type': 'main', 'name': 'Main Agent'},
          ],
        });
        session.handleWebSocketMessage(connectedJson);

        // Simulate a history event containing agent-spawned events
        // Note: history events are under 'data.events'
        final historyJson = jsonEncode({
          'type': 'history',
          'seq': 0,
          'last-seq': 5,
          'timestamp': ts,
          'data': {
            'events': [
              {
                'type': 'message',
                'seq': 1,
                'agent-id': mainAgentIdFromServer,
                'event-id': 'evt-1',
                'is-partial': false,
                'timestamp': ts,
                'data': {'role': 'user', 'content': 'Hello'},
              },
              {
                'type': 'agent-spawned',
                'seq': 2,
                'agent-id': 'spawned-1',
                'agent-type': 'implementer',
                'agent-name': 'Implementer',
                'timestamp': ts,
                'data': {'spawned-by': mainAgentIdFromServer},
              },
              {
                'type': 'message',
                'seq': 3,
                'agent-id': 'spawned-1',
                'event-id': 'evt-3',
                'is-partial': false,
                'timestamp': ts,
                'data': {'role': 'assistant', 'content': 'Working on it'},
              },
            ],
          },
        });
        session.handleWebSocketMessage(historyJson);

        // Agents should be populated from history
        // Note: pending session placeholder + main from connected + spawned from history
        // But the pending placeholder should have different ID than main from connected
        expect(
          session.state.agents.any((a) => a.id == mainAgentIdFromServer),
          isTrue,
        );
        expect(session.state.agents.any((a) => a.id == 'spawned-1'), isTrue);
        expect(
          session.state.agents.any((a) => a.name == 'Implementer'),
          isTrue,
        );
      });

      test('connected event emits to agentsStream for UI reactivity', () async {
        // This test verifies that when we receive a connected event with agents,
        // the agentsStream emits so that UI components can react
        final mainAgentIdFromServer = 'main-agent-stream-test';
        final ts = DateTime.now().toIso8601String();

        // Set up a listener for the stream BEFORE the connected event
        List<VideAgent>? emittedAgents;
        final subscription = session.stateStream.map((s) => s.agents).listen((
          agents,
        ) {
          emittedAgents = agents;
        });

        final connectedJson = jsonEncode({
          'type': 'connected',
          'seq': 0,
          'session-id': 'test-session-stream',
          'main-agent-id': mainAgentIdFromServer,
          'last-seq': 0,
          'timestamp': ts,
          'agents': [
            {
              'id': mainAgentIdFromServer,
              'type': 'main',
              'name': 'Stream Test Agent',
            },
          ],
        });
        session.handleWebSocketMessage(connectedJson);

        // Give stream a chance to emit
        await Future.delayed(Duration(milliseconds: 10));

        // Verify the stream emitted with the agents
        expect(emittedAgents, isNotNull);
        expect(
          emittedAgents!.any((a) => a.id == mainAgentIdFromServer),
          isTrue,
        );

        await subscription.cancel();
      });

      test('history events are processed even with lower seq numbers', () {
        // First set up via connected event
        final mainAgentIdFromServer = 'main-agent-456';
        final ts = DateTime.now().toIso8601String();
        final connectedJson = jsonEncode({
          'type': 'connected',
          'seq': 0,
          'session-id': 'test-session-456',
          'main-agent-id': mainAgentIdFromServer,
          'last-seq': 10, // High lastSeq
          'timestamp': ts,
          'agents': [
            {'id': mainAgentIdFromServer, 'type': 'main', 'name': 'Main'},
          ],
        });
        session.handleWebSocketMessage(connectedJson);

        // Now simulate history with lower seq numbers
        // Note: history events are under 'data.events'
        final historyJson = jsonEncode({
          'type': 'history',
          'seq': 0,
          'last-seq': 10,
          'timestamp': ts,
          'data': {
            'events': [
              {
                'type': 'agent-spawned',
                'seq': 2, // Lower than connected's lastSeq
                'agent-id': 'history-agent',
                'agent-type': 'researcher',
                'agent-name': 'From History',
                'timestamp': ts,
                'data': {'spawned-by': mainAgentIdFromServer},
              },
            ],
          },
        });
        session.handleWebSocketMessage(historyJson);

        // Agent from history should still be added (skipSeqCheck for history)
        expect(
          session.state.agents.any((a) => a.id == 'history-agent'),
          isTrue,
        );
      });

      test('history streaming messages are consolidated to avoid duplication', () {
        // This tests that when history contains multiple partial message events
        // with the same eventId (from streaming), they are consolidated into
        // a single message instead of being accumulated multiple times.
        final mainAgentIdFromServer = 'main-agent-stream';
        final ts = DateTime.now().toIso8601String();
        final connectedJson = jsonEncode({
          'type': 'connected',
          'seq': 0,
          'session-id': 'test-session-stream',
          'main-agent-id': mainAgentIdFromServer,
          'last-seq': 0,
          'timestamp': ts,
          'agents': [
            {'id': mainAgentIdFromServer, 'type': 'main', 'name': 'Main'},
          ],
        });
        session.handleWebSocketMessage(connectedJson);

        // Simulate history with streaming message chunks (same event-id)
        final historyJson = jsonEncode({
          'type': 'history',
          'seq': 0,
          'last-seq': 5,
          'timestamp': ts,
          'data': {
            'events': [
              // User message
              {
                'type': 'message',
                'seq': 1,
                'agent-id': mainAgentIdFromServer,
                'event-id': 'user-msg-1',
                'is-partial': false,
                'timestamp': ts,
                'data': {'role': 'user', 'content': 'Hello'},
              },
              // Assistant streaming chunks - same event-id
              {
                'type': 'message',
                'seq': 2,
                'agent-id': mainAgentIdFromServer,
                'event-id': 'assistant-msg-1',
                'is-partial': true,
                'timestamp': ts,
                'data': {'role': 'assistant', 'content': 'Hello! '},
              },
              {
                'type': 'message',
                'seq': 3,
                'agent-id': mainAgentIdFromServer,
                'event-id': 'assistant-msg-1',
                'is-partial': true,
                'timestamp': ts,
                'data': {'role': 'assistant', 'content': 'How can '},
              },
              {
                'type': 'message',
                'seq': 4,
                'agent-id': mainAgentIdFromServer,
                'event-id': 'assistant-msg-1',
                'is-partial': true,
                'timestamp': ts,
                'data': {'role': 'assistant', 'content': 'I help?'},
              },
              // Final message marker (empty content, is-partial: false)
              {
                'type': 'message',
                'seq': 5,
                'agent-id': mainAgentIdFromServer,
                'event-id': 'assistant-msg-1',
                'is-partial': false,
                'timestamp': ts,
                'data': {'role': 'assistant', 'content': ''},
              },
            ],
          },
        });
        session.handleWebSocketMessage(historyJson);

        // Get conversation and verify messages are NOT duplicated
        final conversation = session.getConversation(mainAgentIdFromServer);
        expect(conversation, isNotNull);

        // Should have exactly 2 messages: user + consolidated assistant
        expect(conversation!.messages.length, equals(2));

        // User message should be correct
        expect(conversation.messages[0].role, equals('user'));
        expect(conversation.messages[0].text, equals('Hello'));

        // Assistant message should be consolidated (not "Hello! Hello! How can How can I help?I help?")
        expect(conversation.messages[1].role, equals('assistant'));
        expect(conversation.messages[1].text, equals('Hello! How can I help?'));
      });
    });

    group('optimistic message deduplication', () {
      test(
        'optimistic user message is not duplicated when server echoes it',
        () {
          // Add optimistic message
          session.addPendingUserMessage('Hello server!');

          var conversation = session.getConversation(agentId);
          expect(conversation!.messages.length, equals(1));

          // Server echoes the same message back
          _simulateMessage(
            session,
            agentId,
            'user',
            'Hello server!',
            seq: ++seq,
          );

          // Should still be just one message (deduplicated)
          conversation = session.getConversation(agentId);
          expect(conversation!.messages.length, equals(1));
          expect(conversation.messages[0].text, equals('Hello server!'));
        },
      );

      test('different user message is not deduplicated', () {
        // Add optimistic message
        session.addPendingUserMessage('First message');

        var conversation = session.getConversation(agentId);
        expect(conversation!.messages.length, equals(1));

        // Server sends a different message
        _simulateMessage(
          session,
          agentId,
          'user',
          'Different message',
          seq: ++seq,
        );

        // Should have two messages
        conversation = session.getConversation(agentId);
        expect(conversation!.messages.length, equals(2));
      });

      test('assistant message after optimistic user message is added', () {
        // Add optimistic message
        session.addPendingUserMessage('Hello server!');

        // Server echoes user message (deduplicated)
        _simulateMessage(session, agentId, 'user', 'Hello server!', seq: ++seq);

        // Server sends assistant response
        _simulateMessage(
          session,
          agentId,
          'assistant',
          'Hello human!',
          seq: ++seq,
        );

        final conversation = session.getConversation(agentId);
        expect(conversation!.messages.length, equals(2));
        expect(conversation.messages[0].role, equals('user'));
        expect(conversation.messages[1].role, equals('assistant'));
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
  String? eventId,
}) {
  final json = jsonEncode({
    'type': 'message',
    'seq': seq,
    'agent-id': agentId,
    'event-id': eventId ?? 'evt-$seq',
    'is-partial': isPartial,
    'data': {'role': role, 'content': content},
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
  String toolName = 'test_tool',
}) {
  final json = jsonEncode({
    'type': 'tool-result',
    'seq': seq,
    'agent-id': agentId,
    'data': {
      'tool-use-id': toolUseId,
      'tool-name': toolName,
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
    'data': {'reason': 'complete'},
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
    'data': {'spawned-by': spawnedBy},
  });
  session.handleWebSocketMessage(json);
}

void _simulateAgentTerminated(
  RemoteVideSession session,
  String agentId, {
  required int seq,
  String terminatedBy = 'main',
  String? reason,
}) {
  final json = jsonEncode({
    'type': 'agent-terminated',
    'seq': seq,
    'agent-id': agentId,
    'data': {
      'terminated-by': terminatedBy,
      if (reason != null) 'reason': reason,
    },
  });
  session.handleWebSocketMessage(json);
}
