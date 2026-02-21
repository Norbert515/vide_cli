/// Tests for LocalVideSession conversation streaming and event ordering.
///
/// Verifies that _handleConversation and _emitToolEvents produce correct
/// event sequences, handle streaming deltas, finalize text before tools,
/// and emit proper turn-complete events.
library;

import 'package:agent_sdk/agent_sdk.dart' as agent_sdk;
import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';
import 'package:vide_core/src/agent_network/agent_network_manager.dart';

import '../helpers/session_test_helper.dart';

void main() {
  group('LocalVideSession conversation streaming', () {
    late SessionTestHarness h;

    setUp(() async {
      h = SessionTestHarness();
      await h.setUp();
    });

    tearDown(() => h.dispose());

    test('assistant text response emits MessageEvent', () async {
      final events = h.collectEvents();

      h.mockClient.simulateTextResponse('Hello from Claude');
      await Future<void>.delayed(Duration.zero);

      final msgs = events
          .whereType<MessageEvent>()
          .where((e) => e.role == 'assistant')
          .toList();
      expect(msgs, isNotEmpty);
      expect(msgs.first.content, equals('Hello from Claude'));
    });

    test('tool call emits ToolUseEvent and ToolResultEvent', () async {
      final events = h.collectEvents();

      h.mockClient.simulateAssistantWithToolCall(
        text: 'Let me check...',
        toolName: 'Bash',
        toolInput: {'command': 'ls'},
        toolResult: 'file.txt',
        toolUseId: 'tool-1',
      );
      await Future<void>.delayed(Duration.zero);

      final toolUses = events.whereType<ToolUseEvent>().toList();
      expect(toolUses, hasLength(1));
      expect(toolUses.first.toolName, equals('Bash'));
      expect(toolUses.first.toolInput['command'], equals('ls'));
      expect(toolUses.first.toolUseId, equals('tool-1'));

      final toolResults = events.whereType<ToolResultEvent>().toList();
      expect(toolResults, hasLength(1));
      expect(toolResults.first.toolName, equals('Bash'));
      expect(toolResults.first.result, equals('file.txt'));
      expect(toolResults.first.isError, isFalse);
    });

    test('error tool result reports isError correctly', () async {
      final events = h.collectEvents();

      h.mockClient.simulateAssistantWithToolCall(
        text: 'Running...',
        toolName: 'Bash',
        toolInput: {'command': 'bad-cmd'},
        toolResult: 'command not found',
        toolUseId: 'tool-err',
        isError: true,
      );
      await Future<void>.delayed(Duration.zero);

      final toolResults = events.whereType<ToolResultEvent>().toList();
      expect(toolResults.first.isError, isTrue);
      expect(toolResults.first.result, equals('command not found'));
    });

    test(
      'text block is finalized (isPartial:false) before ToolUseEvent',
      () async {
        final events = h.collectEvents();

        h.mockClient.simulateAssistantWithToolCall(
          text: 'Before tool',
          toolName: 'Read',
          toolInput: {'file_path': '/x.dart'},
          toolResult: 'content',
        );
        await Future<void>.delayed(Duration.zero);

        // Find the sequence: MessageEvent(isPartial:false) before ToolUseEvent
        final allEvents = events.toList();
        final toolUseIndex = allEvents.indexWhere((e) => e is ToolUseEvent);
        expect(toolUseIndex, greaterThan(0));

        // There should be a finalization MessageEvent (isPartial: false) before the tool
        final beforeTool = allEvents.sublist(0, toolUseIndex);
        final finalizations = beforeTool
            .whereType<MessageEvent>()
            .where((e) => e.role == 'assistant' && e.isPartial == false)
            .toList();
        expect(
          finalizations,
          isNotEmpty,
          reason: 'Text block must be finalized before tool event',
        );
      },
    );

    test('streaming text updates emit partial MessageEvents', () async {
      final events = h.collectEvents();

      // First chunk creates a new message
      h.mockClient.simulateStreamingText('Hello ');
      await Future<void>.delayed(Duration.zero);

      // Second chunk appends
      h.mockClient.simulateStreamingText('World');
      await Future<void>.delayed(Duration.zero);

      final msgs = events
          .whereType<MessageEvent>()
          .where((e) => e.role == 'assistant')
          .toList();
      expect(msgs, isNotEmpty);
      // First chunk should appear
      expect(msgs.any((m) => m.content.contains('Hello')), isTrue);
    });

    test('turn complete emits TurnCompleteEvent', () async {
      final events = h.collectEvents();

      h.mockClient.simulateTextResponse('Done');
      h.mockClient.simulateTurnComplete();
      await Future<void>.delayed(Duration.zero);

      final turnEvents = events.whereType<TurnCompleteEvent>().toList();
      expect(turnEvents, hasLength(1));
      expect(turnEvents.first.reason, equals('end_turn'));
    });

    test('turn complete finalizes streaming message', () async {
      final events = h.collectEvents();

      // Start streaming
      h.mockClient.simulateStreamingText('Streaming text...');
      await Future<void>.delayed(Duration.zero);

      // Complete turn - should finalize the message
      h.mockClient.simulateTurnComplete();
      await Future<void>.delayed(Duration.zero);

      final msgs = events
          .whereType<MessageEvent>()
          .where((e) => e.role == 'assistant')
          .toList();

      // The last message event should be a finalization (isPartial: false, empty content)
      final lastMsg = msgs.last;
      expect(lastMsg.isPartial, isFalse);
    });

    test('conversation error emits ErrorEvent', () async {
      // Need at least one message so _handleConversation doesn't skip
      h.mockClient.simulateTextResponse('some response');
      await Future<void>.delayed(Duration.zero);

      final events = h.collectEvents();

      h.mockClient.simulateError('API rate limit exceeded');
      await Future<void>.delayed(Duration.zero);

      final errors = events.whereType<ErrorEvent>().toList();
      expect(errors, hasLength(1));
      expect(errors.first.message, equals('API rate limit exceeded'));
    });

    test('multiple messages in sequence each get their own eventId', () async {
      final events = h.collectEvents();

      h.mockClient.simulateTextResponse('First response');
      await Future<void>.delayed(Duration.zero);

      h.mockClient.simulateTextResponse('Second response');
      await Future<void>.delayed(Duration.zero);

      final msgs = events
          .whereType<MessageEvent>()
          .where((e) => e.role == 'assistant')
          .toList();

      final eventIds = msgs.map((m) => m.eventId).toSet();
      // Should have at least 2 distinct eventIds (one per message)
      expect(eventIds.length, greaterThanOrEqualTo(2));
    });

    test(
      'conversation with user message emitted from client is captured',
      () async {
        final events = h.collectEvents();

        // When sendMessage is called, MockAgentClient adds a user message
        // to the conversation and notifies. The session should detect it.
        h.session.sendMessage(VideMessage(text: 'From user'));
        await Future<void>.delayed(Duration.zero);

        // The session emits its own user MessageEvent synchronously in sendMessage.
        // Plus the conversation stream may deliver the same message from the client.
        // Either way, we should have at least one user message event.
        final userMsgs = events.whereType<MessageEvent>().where(
          (e) => e.role == 'user',
        );
        expect(userMsgs, isNotEmpty);
      },
    );
  });

  group('LocalVideSession agent lifecycle events', () {
    late SessionTestHarness h;

    setUp(() async {
      h = SessionTestHarness();
      await h.setUp();
    });

    tearDown(() => h.dispose());

    test('adding agent emits AgentSpawnedEvent', () async {
      final events = h.collectEvents();

      h.addAgent(id: 'new-agent', name: 'New Agent', type: 'implementer');
      await Future<void>.delayed(Duration.zero);

      final spawnEvents = events.whereType<AgentSpawnedEvent>().toList();
      expect(spawnEvents, hasLength(1));
      expect(spawnEvents.first.agentId, equals('new-agent'));
      expect(spawnEvents.first.agentName, equals('New Agent'));
    });

    test('adding agent emits initial StatusEvent for the new agent', () async {
      final events = h.collectEvents();

      h.addAgent(id: 'agent-2');
      await Future<void>.delayed(Duration.zero);

      final statusEvents = events
          .whereType<StatusEvent>()
          .where((e) => e.agentId == 'agent-2')
          .toList();
      expect(statusEvents, isNotEmpty);
    });

    test('removing agent emits AgentTerminatedEvent', () async {
      // First add an agent
      h.addAgent(id: 'temp-agent');
      await Future<void>.delayed(Duration.zero);

      final events = h.collectEvents();

      // Now remove it from the network
      final manager = h.container.read(agentNetworkManagerProvider.notifier);
      final network = manager.state.currentNetwork!;
      manager.state = AgentNetworkState(
        currentNetwork: network.copyWith(
          agents: network.agents.where((a) => a.id != 'temp-agent').toList(),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final termEvents = events.whereType<AgentTerminatedEvent>().toList();
      expect(termEvents, hasLength(1));
      expect(termEvents.first.agentId, equals('temp-agent'));
    });

    test('goal change emits TaskNameChangedEvent', () async {
      final events = h.collectEvents();

      final manager = h.container.read(agentNetworkManagerProvider.notifier);
      final network = manager.state.currentNetwork!;
      manager.state = AgentNetworkState(
        currentNetwork: network.copyWith(goal: 'New Goal'),
      );
      await Future<void>.delayed(Duration.zero);

      final taskEvents = events.whereType<TaskNameChangedEvent>().toList();
      expect(taskEvents, hasLength(1));
      expect(taskEvents.first.newGoal, equals('New Goal'));
      expect(taskEvents.first.previousGoal, equals('Test'));
    });

    test('state stream emits after agent spawn', () async {
      final states = <VideState>[];
      h.session.stateStream.listen(states.add);

      h.addAgent(id: 'agent-3');
      await Future<void>.delayed(Duration.zero);

      expect(states, isNotEmpty);
      expect(states.last.agents.any((a) => a.id == 'agent-3'), isTrue);
    });
  });

  group('LocalVideSession abort', () {
    late SessionTestHarness h;

    setUp(() async {
      h = SessionTestHarness();
      await h.setUp();
    });

    tearDown(() => h.dispose());

    test('abort() aborts all agents', () async {
      final subClient = h.addAgent(id: 'sub-agent');
      await Future<void>.delayed(Duration.zero);

      await h.session.abort();

      expect(h.mockClient.isAborted, isTrue);
      expect(subClient.isAborted, isTrue);
    });

    test('abortAgent() aborts only the specified agent', () async {
      final subClient = h.addAgent(id: 'sub-agent');
      await Future<void>.delayed(Duration.zero);

      await h.session.abortAgent('sub-agent');

      expect(h.mockClient.isAborted, isFalse);
      expect(subClient.isAborted, isTrue);
    });
  });

  group('LocalVideSession queued messages', () {
    late SessionTestHarness h;

    setUp(() async {
      h = SessionTestHarness();
      await h.setUp();
    });

    tearDown(() => h.dispose());

    test('getQueuedMessage returns null when no queue', () async {
      final msg = await h.session.getQueuedMessage(h.agentId);
      expect(msg, isNull);
    });

    test('clearQueuedMessage clears queued text', () async {
      h.mockClient.setConversationState(
        agent_sdk.AgentConversationState.receivingResponse,
      );
      h.session.sendMessage(VideMessage(text: 'queued'));
      await Future<void>.delayed(Duration.zero);

      expect(h.mockClient.currentQueuedMessage, equals('queued'));

      await h.session.clearQueuedMessage(h.agentId);
      expect(h.mockClient.currentQueuedMessage, isNull);
    });

    test('queuedMessageStream emits changes', () async {
      final messages = <String?>[];
      h.session.queuedMessageStream(h.agentId).listen(messages.add);

      h.mockClient.setConversationState(
        agent_sdk.AgentConversationState.receivingResponse,
      );

      // Queue a message
      h.session.sendMessage(VideMessage(text: 'first'));
      await Future<void>.delayed(Duration.zero);

      // Clear it
      await h.session.clearQueuedMessage(h.agentId);
      await Future<void>.delayed(Duration.zero);

      // Should have the queued text and then null
      expect(messages, contains('first'));
      expect(messages.last, isNull);
    });
  });

  group('LocalVideSession clearConversation', () {
    late SessionTestHarness h;

    setUp(() async {
      h = SessionTestHarness();
      await h.setUp();
    });

    tearDown(() => h.dispose());

    test('clearConversation resets the client conversation', () async {
      // Add a message first
      h.mockClient.simulateTextResponse('something');
      expect(h.mockClient.currentConversation.messages, isNotEmpty);

      await h.session.clearConversation();

      expect(h.mockClient.currentConversation.messages, isEmpty);
    });

    test(
      'clearConversation with specific agentId clears only that agent',
      () async {
        final subClient = h.addAgent(id: 'sub-agent');
        await Future<void>.delayed(Duration.zero);

        h.mockClient.simulateTextResponse('main msg');
        subClient.simulateTextResponse('sub msg');

        await h.session.clearConversation(agentId: 'sub-agent');

        expect(h.mockClient.currentConversation.messages, isNotEmpty);
        expect(subClient.currentConversation.messages, isEmpty);
      },
    );
  });
}
