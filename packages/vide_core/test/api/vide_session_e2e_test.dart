/// End-to-end style integration tests for LocalVideSession.
///
/// These tests simulate realistic multi-step agent conversations with
/// mock AI data. They verify that full workflows work correctly, including:
/// - User sends message → agent responds with tool calls → completes
/// - Multi-agent scenarios (spawn, message, terminate)
/// - Permission → approve → continue flow
/// - Conversation state accumulation across multiple turns
/// - Full event history correctness
library;

import 'dart:async';

import 'package:agent_sdk/agent_sdk.dart' hide AgentConversationState;
import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';
import 'package:vide_core/src/agent_network/agent_network_manager.dart';

import '../helpers/session_test_helper.dart';

void main() {
  group('E2E: Simple conversation flow', () {
    late SessionTestHarness h;

    setUp(() async {
      h = SessionTestHarness();
      await h.setUp();
    });

    tearDown(() => h.dispose());

    test('user message → assistant response → turn complete', () async {
      final events = h.collectEvents();

      // Step 1: User sends a message
      h.session.emitInitialUserMessage('What is 2+2?');
      await Future<void>.delayed(Duration.zero);

      // Step 2: Agent responds with text
      h.mockClient.simulateTextResponse('The answer is 4.');
      await Future<void>.delayed(Duration.zero);

      // Step 3: Turn completes
      h.mockClient.simulateTurnComplete();
      await Future<void>.delayed(Duration.zero);

      // Verify complete event sequence
      final messageEvents = events.whereType<MessageEvent>().toList();
      final turnCompletes = events.whereType<TurnCompleteEvent>().toList();

      // User message + assistant message + finalization
      expect(messageEvents.where((m) => m.role == 'user').length, equals(1));
      expect(
        messageEvents.where((m) => m.role == 'assistant').length,
        greaterThanOrEqualTo(1),
      );
      expect(turnCompletes, hasLength(1));

      // Verify event history contains everything
      final history = h.session.eventHistory;
      expect(history.whereType<MessageEvent>(), isNotEmpty);
      expect(history.whereType<TurnCompleteEvent>(), isNotEmpty);
    });

    test('user message → tool call → tool result → text → complete', () async {
      final events = h.collectEvents();

      // User asks to read a file
      h.session.emitInitialUserMessage('Read the main.dart file');
      await Future<void>.delayed(Duration.zero);

      // Agent responds with a tool call
      h.mockClient.simulateAssistantWithToolCall(
        text: 'Let me read that file for you.',
        toolName: 'Read',
        toolInput: {'file_path': '/project/lib/main.dart'},
        toolResult: 'void main() { print("hello"); }',
        toolUseId: 'read-1',
      );
      await Future<void>.delayed(Duration.zero);

      // Agent provides final response after reading
      h.mockClient.simulateTextResponse(
        'The main.dart file contains a simple hello world program.',
      );
      await Future<void>.delayed(Duration.zero);

      h.mockClient.simulateTurnComplete();
      await Future<void>.delayed(Duration.zero);

      // Verify tool events
      final toolUses = events.whereType<ToolUseEvent>().toList();
      expect(toolUses, hasLength(1));
      expect(toolUses.first.toolName, equals('Read'));

      final toolResults = events.whereType<ToolResultEvent>().toList();
      expect(toolResults, hasLength(1));
      expect(toolResults.first.result, contains('void main()'));

      // Verify we have both assistant messages
      final assistantMsgs = events
          .whereType<MessageEvent>()
          .where((e) => e.role == 'assistant')
          .toList();
      expect(assistantMsgs, isNotEmpty);
    });

    test('multiple tool calls in sequence', () async {
      final events = h.collectEvents();

      h.session.emitInitialUserMessage('Analyze the project');
      await Future<void>.delayed(Duration.zero);

      // First tool call: list files
      h.mockClient.simulateAssistantWithToolCall(
        text: 'Let me explore the project structure.',
        toolName: 'Bash',
        toolInput: {'command': 'find . -name "*.dart"'},
        toolResult: './lib/main.dart\n./lib/utils.dart',
        toolUseId: 'bash-1',
      );
      await Future<void>.delayed(Duration.zero);

      // Second tool call: read a file
      h.mockClient.simulateAssistantWithToolCall(
        text: 'Found some files. Let me read main.dart.',
        toolName: 'Read',
        toolInput: {'file_path': './lib/main.dart'},
        toolResult: 'import "utils.dart";',
        toolUseId: 'read-1',
      );
      await Future<void>.delayed(Duration.zero);

      // Final response
      h.mockClient.simulateTextResponse('The project has 2 Dart files.');
      h.mockClient.simulateTurnComplete();
      await Future<void>.delayed(Duration.zero);

      final toolUses = events.whereType<ToolUseEvent>().toList();
      expect(toolUses, hasLength(2));
      expect(toolUses[0].toolName, equals('Bash'));
      expect(toolUses[1].toolName, equals('Read'));

      final toolResults = events.whereType<ToolResultEvent>().toList();
      expect(toolResults, hasLength(2));
    });
  });

  group('E2E: Permission flow in conversation', () {
    late SessionTestHarness h;

    setUp(() async {
      h = SessionTestHarness();
      await h.setUp();
    });

    tearDown(() => h.dispose());

    test(
      'user message → permission request → approve → agent continues',
      () async {
        final events = h.collectEvents();
        final callback = h.session.createAgentPermissionCallback(
          agentId: h.agentId,
          agentName: 'Main Agent',
          agentType: 'main',
          cwd: h.tempDir.path,
        );

        // User asks to edit a file
        h.session.emitInitialUserMessage('Fix the bug in utils.dart');
        await Future<void>.delayed(Duration.zero);

        // Agent tries to write - this triggers permission (async)
        final permFuture = callback('Write', {
          'file_path': '/project/lib/utils.dart',
          'content': 'fixed!',
        }, AgentPermissionContext());

        // Wait for the async permission check to emit the event.
        // checkPermission() is async (reads settings from disk), so we need
        // to allow microtasks/futures to resolve.
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Verify permission was requested
        final permRequests = events
            .whereType<PermissionRequestEvent>()
            .toList();
        expect(permRequests, hasLength(1));
        expect(permRequests.first.toolName, equals('Write'));

        // User approves
        h.session.respondToPermission(
          permRequests.first.requestId,
          allow: true,
          remember: false,
        );

        final result = await permFuture;
        expect(result, isA<AgentPermissionAllow>());

        // Verify permission resolved event
        final resolvedEvents = events
            .whereType<PermissionResolvedEvent>()
            .toList();
        expect(resolvedEvents, hasLength(1));
        expect(resolvedEvents.first.allow, isTrue);
      },
    );

    test('user message → permission → deny → agent receives denial', () async {
      final events = h.collectEvents();
      final callback = h.session.createAgentPermissionCallback(
        agentId: h.agentId,
        agentName: 'Main Agent',
        agentType: 'main',
        cwd: h.tempDir.path,
      );

      h.session.emitInitialUserMessage('Delete all tests');
      await Future<void>.delayed(Duration.zero);

      final permFuture = callback('Bash', {
        'command': 'rm -rf test/',
      }, AgentPermissionContext());

      // Wait for async permission check
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final permReq = events.whereType<PermissionRequestEvent>().first;
      h.session.respondToPermission(
        permReq.requestId,
        allow: false,
        message: 'That is dangerous!',
      );

      final result = await permFuture;
      expect(result, isA<AgentPermissionDeny>());
      expect(
        (result as AgentPermissionDeny).message,
        equals('That is dangerous!'),
      );
    });
  });

  group('E2E: Multi-agent workflow', () {
    late SessionTestHarness h;

    setUp(() async {
      h = SessionTestHarness();
      await h.setUp();
    });

    tearDown(() => h.dispose());

    test(
      'main agent spawns sub-agent, sub-agent works, gets terminated',
      () async {
        final events = h.collectEvents();

        // User sends initial message
        h.session.emitInitialUserMessage('Implement the new feature');
        await Future<void>.delayed(Duration.zero);

        // Main agent decides to spawn a sub-agent
        final subClient = h.addAgent(
          id: 'impl-agent',
          name: 'Implementer',
          type: 'implementation',
          spawnedBy: h.agentId,
        );
        await Future<void>.delayed(Duration.zero);

        // Verify spawn event
        final spawnEvents = events.whereType<AgentSpawnedEvent>().toList();
        expect(spawnEvents, hasLength(1));
        expect(spawnEvents.first.agentId, equals('impl-agent'));
        expect(spawnEvents.first.agentName, equals('Implementer'));

        // Sub-agent does work
        subClient.simulateAssistantWithToolCall(
          text: 'Implementing the feature...',
          toolName: 'Write',
          toolInput: {
            'file_path': '/src/feature.dart',
            'content': 'class Feature {}',
          },
          toolResult: 'File written successfully',
          toolUseId: 'write-1',
        );
        await Future<void>.delayed(Duration.zero);

        // Verify sub-agent events have correct agent attribution
        final subToolUses = events
            .whereType<ToolUseEvent>()
            .where((e) => e.agentId == 'impl-agent')
            .toList();
        expect(subToolUses, hasLength(1));
        expect(subToolUses.first.agentName, equals('Implementer'));

        // Sub-agent completes
        subClient.simulateTurnComplete();
        await Future<void>.delayed(Duration.zero);

        // Terminate sub-agent
        final manager = h.container.read(agentNetworkManagerProvider.notifier);
        final network = manager.state.currentNetwork!;
        manager.state = AgentNetworkState(
          currentNetwork: network.copyWith(
            agents: network.agents.where((a) => a.id != 'impl-agent').toList(),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        // Verify termination event
        final termEvents = events.whereType<AgentTerminatedEvent>().toList();
        expect(termEvents, hasLength(1));
        expect(termEvents.first.agentId, equals('impl-agent'));

        // Main agent should still be working
        expect(h.session.state.agents.length, equals(1));
        expect(h.session.state.agents.first.id, equals(h.agentId));
      },
    );

    test('events from multiple agents are properly interleaved', () async {
      final events = h.collectEvents();

      // Add a second agent
      final subClient = h.addAgent(id: 'agent-2', name: 'Agent 2');
      await Future<void>.delayed(Duration.zero);

      // Both agents produce output
      h.mockClient.simulateTextResponse('Main agent working...');
      subClient.simulateTextResponse('Sub agent working...');
      await Future<void>.delayed(Duration.zero);

      final msgEvents = events
          .whereType<MessageEvent>()
          .where((e) => e.role == 'assistant')
          .toList();

      final mainMsgs = msgEvents.where((e) => e.agentId == h.agentId);
      final subMsgs = msgEvents.where((e) => e.agentId == 'agent-2');

      expect(mainMsgs, isNotEmpty);
      expect(subMsgs, isNotEmpty);
    });
  });

  group('E2E: Conversation state accumulation', () {
    late SessionTestHarness h;

    setUp(() async {
      h = SessionTestHarness();
      await h.setUp();
    });

    tearDown(() => h.dispose());

    test('conversation state builds up across multiple turns', () async {
      // Turn 1: User asks, agent responds
      h.session.emitInitialUserMessage('Hello');
      await Future<void>.delayed(Duration.zero);

      h.mockClient.simulateTextResponse('Hi there!');
      h.mockClient.simulateTurnComplete();
      await Future<void>.delayed(Duration.zero);

      // Check conversation state after turn 1
      var convState = h.session.getConversation(h.agentId);
      expect(convState, isNotNull);
      expect(convState!.messages, isNotEmpty);

      // Turn 2: User follows up
      h.session.sendMessage(VideMessage(text: 'How are you?'));
      await Future<void>.delayed(Duration.zero);

      h.mockClient.simulateTextResponse('I am doing well!');
      h.mockClient.simulateTurnComplete();
      await Future<void>.delayed(Duration.zero);

      // Conversation should have accumulated more messages
      convState = h.session.getConversation(h.agentId);
      expect(convState, isNotNull);
      // Should have both user and assistant messages from both turns
      final userMsgs = convState!.messages.where((m) => m.role == 'user');
      final assistantMsgs = convState.messages.where(
        (m) => m.role == 'assistant',
      );
      expect(userMsgs.length, greaterThanOrEqualTo(2));
      expect(assistantMsgs.length, greaterThanOrEqualTo(2));
    });

    test('event history captures full conversation timeline', () async {
      h.session.emitInitialUserMessage('Start');
      await Future<void>.delayed(Duration.zero);

      h.mockClient.simulateAssistantWithToolCall(
        text: 'Checking...',
        toolName: 'Bash',
        toolInput: {'command': 'echo hi'},
        toolResult: 'hi',
      );
      await Future<void>.delayed(Duration.zero);

      h.mockClient.simulateTextResponse('Done!');
      h.mockClient.simulateTurnComplete();
      await Future<void>.delayed(Duration.zero);

      final history = h.session.eventHistory;

      // Verify history has the expected event types in order
      expect(history.whereType<StatusEvent>(), isNotEmpty);
      expect(history.whereType<MessageEvent>(), isNotEmpty);
      expect(history.whereType<ToolUseEvent>(), isNotEmpty);
      expect(history.whereType<ToolResultEvent>(), isNotEmpty);
      expect(history.whereType<TurnCompleteEvent>(), isNotEmpty);
    });

    test('conversationStream emits updates', () async {
      final states = <AgentConversationState>[];
      h.session.conversationStream(h.agentId).listen(states.add);

      h.session.emitInitialUserMessage('Go');
      await Future<void>.delayed(Duration.zero);

      h.mockClient.simulateTextResponse('Response');
      await Future<void>.delayed(Duration.zero);

      // Should have received at least one state update
      expect(states, isNotEmpty);
    });
  });

  group('E2E: AskUserQuestion in conversation flow', () {
    late SessionTestHarness h;

    setUp(() async {
      h = SessionTestHarness();
      await h.setUp();
    });

    tearDown(() => h.dispose());

    test('full AskUserQuestion flow: question → answer → continue', () async {
      final events = h.collectEvents();
      final callback = h.session.createAgentPermissionCallback(
        agentId: h.agentId,
        agentName: 'Main Agent',
        agentType: 'main',
        cwd: h.tempDir.path,
      );

      // User sends initial request
      h.session.emitInitialUserMessage('Set up my project');
      await Future<void>.delayed(Duration.zero);

      // Agent asks a question via AskUserQuestion tool
      final askFuture = callback('AskUserQuestion', {
        'questions': [
          {
            'question': 'Which framework?',
            'header': 'Framework',
            'multiSelect': false,
            'options': [
              {'label': 'Flutter', 'description': 'Mobile framework'},
              {'label': 'Angular', 'description': 'Web framework'},
            ],
          },
        ],
      }, AgentPermissionContext());
      await Future<void>.delayed(Duration.zero);

      // Verify question event was emitted
      final askEvents = events.whereType<AskUserQuestionEvent>().toList();
      expect(askEvents, hasLength(1));
      expect(
        askEvents.first.questions.first.question,
        equals('Which framework?'),
      );

      // User answers
      h.session.respondToAskUserQuestion(
        askEvents.first.requestId,
        answers: {'0': 'Flutter'},
      );

      final result = await askFuture;
      expect(result, isA<AgentPermissionAllow>());
      final allow = result as AgentPermissionAllow;
      expect(allow.updatedInput!['answers'], equals({'0': 'Flutter'}));

      // Agent continues with the chosen framework
      h.mockClient.simulateTextResponse('Setting up Flutter project...');
      await Future<void>.delayed(Duration.zero);

      // Verify we have both the question event and the follow-up response
      final allMsgs = events.whereType<MessageEvent>().toList();
      expect(allMsgs, isNotEmpty);
    });
  });

  group('E2E: Stress tests', () {
    late SessionTestHarness h;

    setUp(() async {
      h = SessionTestHarness();
      await h.setUp();
    });

    tearDown(() => h.dispose());

    test('rapid message sending does not lose events', () async {
      final events = h.collectEvents();

      // Send many messages rapidly
      for (var i = 0; i < 20; i++) {
        h.session.emitInitialUserMessage('msg-$i');
      }
      await Future<void>.delayed(Duration.zero);

      final userMsgs = events
          .whereType<MessageEvent>()
          .where((e) => e.role == 'user')
          .toList();
      expect(userMsgs.length, equals(20));
    });

    test('many tool calls do not cause event ordering issues', () async {
      final events = h.collectEvents();

      // Simulate 10 sequential tool calls
      for (var i = 0; i < 10; i++) {
        h.mockClient.simulateAssistantWithToolCall(
          text: 'Step $i',
          toolName: 'Read',
          toolInput: {'file_path': '/file$i.dart'},
          toolResult: 'content-$i',
          toolUseId: 'tool-$i',
        );
        await Future<void>.delayed(Duration.zero);
      }

      h.mockClient.simulateTurnComplete();
      await Future<void>.delayed(Duration.zero);

      final toolUses = events.whereType<ToolUseEvent>().toList();
      expect(toolUses.length, equals(10));

      // Verify tool names are in order
      for (var i = 0; i < 10; i++) {
        expect(toolUses[i].toolUseId, equals('tool-$i'));
      }
    });

    test('concurrent operations from multiple agents', () async {
      final events = h.collectEvents();
      final sub1 = h.addAgent(id: 'agent-1', name: 'Agent 1');
      final sub2 = h.addAgent(id: 'agent-2', name: 'Agent 2');
      await Future<void>.delayed(Duration.zero);

      // All three agents produce output concurrently
      h.mockClient.simulateTextResponse('Main output');
      sub1.simulateTextResponse('Agent 1 output');
      sub2.simulateTextResponse('Agent 2 output');
      await Future<void>.delayed(Duration.zero);

      h.mockClient.simulateTurnComplete();
      sub1.simulateTurnComplete();
      sub2.simulateTurnComplete();
      await Future<void>.delayed(Duration.zero);

      // Each agent should have their events
      final mainMsgs = events.whereType<MessageEvent>().where(
        (e) => e.agentId == h.agentId && e.role == 'assistant',
      );
      final agent1Msgs = events.whereType<MessageEvent>().where(
        (e) => e.agentId == 'agent-1' && e.role == 'assistant',
      );
      final agent2Msgs = events.whereType<MessageEvent>().where(
        (e) => e.agentId == 'agent-2' && e.role == 'assistant',
      );

      expect(mainMsgs, isNotEmpty);
      expect(agent1Msgs, isNotEmpty);
      expect(agent2Msgs, isNotEmpty);

      final turnCompletes = events.whereType<TurnCompleteEvent>().toList();
      expect(turnCompletes.length, equals(3));
    });

    test('dispose during active streaming does not throw', () async {
      // Start streaming
      h.mockClient.simulateStreamingText('Streaming...');
      await Future<void>.delayed(Duration.zero);

      // Dispose during stream (should not throw)
      await h.session.dispose(fireEndTrigger: false);
    });

    test('multiple permission requests + dispose cleans up all', () async {
      final callback = h.session.createAgentPermissionCallback(
        agentId: h.agentId,
        agentName: 'Main Agent',
        agentType: 'main',
        cwd: h.tempDir.path,
      );

      // Fire off several permission requests
      final futures = <Future<AgentPermissionResult>>[];
      for (var i = 0; i < 5; i++) {
        futures.add(
          callback('Bash', {
            'command': 'cmd-$i',
          }, AgentPermissionContext()),
        );
      }
      await Future<void>.delayed(Duration.zero);

      // Dispose — all pending permissions should be completed with deny
      await h.session.dispose(fireEndTrigger: false);

      final results = await Future.wait(futures);
      for (final result in results) {
        expect(result, isA<AgentPermissionDeny>());
      }
    });
  });

  group('E2E: Full realistic workflow', () {
    late SessionTestHarness h;

    setUp(() async {
      h = SessionTestHarness();
      await h.setUp(dangerouslySkipPermissions: true);
    });

    tearDown(() => h.dispose());

    test('simulates a real bug-fix session', () async {
      final events = h.collectEvents();

      // === Turn 1: User reports bug ===
      h.session.emitInitialUserMessage(
        'There is a null pointer exception in user_service.dart line 42',
      );
      await Future<void>.delayed(Duration.zero);

      // Agent reads the file
      h.mockClient.simulateAssistantWithToolCall(
        text: 'Let me look at that file.',
        toolName: 'Read',
        toolInput: {'file_path': '/project/lib/user_service.dart'},
        toolResult: '''class UserService {
  User? getUser(String id) {
    final user = _cache[id];
    return user.name.isEmpty ? null : user; // line 42: null pointer if user is null
  }
}''',
        toolUseId: 'read-1',
      );
      await Future<void>.delayed(Duration.zero);

      // Agent analyzes and proposes fix
      h.mockClient.simulateTextResponse(
        'I found the bug. On line 42, `user.name` is called without '
        'a null check. Let me fix this.',
      );
      await Future<void>.delayed(Duration.zero);

      // Agent writes the fix
      h.mockClient.simulateAssistantWithToolCall(
        text: 'Applying the fix:',
        toolName: 'Edit',
        toolInput: {
          'file_path': '/project/lib/user_service.dart',
          'old_string': 'return user.name.isEmpty ? null : user;',
          'new_string': 'return user?.name.isEmpty == true ? null : user;',
        },
        toolResult: 'File edited successfully',
        toolUseId: 'edit-1',
      );
      await Future<void>.delayed(Duration.zero);

      // Agent runs tests
      h.mockClient.simulateAssistantWithToolCall(
        text: 'Running tests to verify the fix:',
        toolName: 'Bash',
        toolInput: {'command': 'dart test test/user_service_test.dart'},
        toolResult: 'All 5 tests passed!',
        toolUseId: 'bash-1',
      );
      await Future<void>.delayed(Duration.zero);

      // Final summary
      h.mockClient.simulateTextResponse(
        'Fixed the null pointer exception. The issue was that `user.name` '
        'was accessed without first checking if `user` is null. All tests pass.',
      );
      h.mockClient.simulateTurnComplete();
      await Future<void>.delayed(Duration.zero);

      // === Verify the full conversation ===
      final toolUses = events.whereType<ToolUseEvent>().toList();
      expect(toolUses.length, equals(3));
      expect(toolUses[0].toolName, equals('Read'));
      expect(toolUses[1].toolName, equals('Edit'));
      expect(toolUses[2].toolName, equals('Bash'));

      final toolResults = events.whereType<ToolResultEvent>().toList();
      expect(toolResults.length, equals(3));

      final turnCompletes = events.whereType<TurnCompleteEvent>().toList();
      expect(turnCompletes.length, equals(1));

      // Verify event history is complete
      expect(h.session.eventHistory.length, greaterThan(10));

      // Verify conversation state
      final convState = h.session.getConversation(h.agentId);
      expect(convState, isNotNull);
      expect(convState!.messages, isNotEmpty);
    });

    test('simulates multi-turn conversation with follow-up', () async {
      // === Turn 1 ===
      h.session.emitInitialUserMessage('Add a new feature');
      await Future<void>.delayed(Duration.zero);

      h.mockClient.simulateTextResponse('What feature would you like?');
      h.mockClient.simulateTurnComplete();
      await Future<void>.delayed(Duration.zero);

      // === Turn 2 (follow-up) ===
      h.session.sendMessage(VideMessage(text: 'A login page'));
      await Future<void>.delayed(Duration.zero);

      h.mockClient.simulateAssistantWithToolCall(
        text: 'Creating login page...',
        toolName: 'Write',
        toolInput: {
          'file_path': '/project/lib/login_page.dart',
          'content': 'class LoginPage extends StatelessWidget { }',
        },
        toolResult: 'File created',
        toolUseId: 'write-1',
      );
      await Future<void>.delayed(Duration.zero);

      h.mockClient.simulateTextResponse('Login page created!');
      h.mockClient.simulateTurnComplete();
      await Future<void>.delayed(Duration.zero);

      // Verify both turns completed
      final turnCompletes = h.session.eventHistory
          .whereType<TurnCompleteEvent>()
          .toList();
      expect(turnCompletes.length, equals(2));

      // Verify conversation accumulation
      final convState = h.session.getConversation(h.agentId);
      expect(convState, isNotNull);
      // At minimum: user msg 1, assistant reply 1, user msg 2, assistant with tool, final text
      expect(convState!.messages.length, greaterThanOrEqualTo(4));
    });
  });
}
