/// Tests that expose and verify fixes for production bugs in LocalVideSession.
///
/// Each test documents a specific bug, proves it exists, and verifies the fix.
library;

import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';
import 'package:vide_core/src/agent_network/agent_network_manager.dart';

import '../helpers/session_test_helper.dart';

void main() {
  // =========================================================================
  // Bug 1: _unsubscribeFromAgent doesn't cancel stream subscriptions
  //
  // When an agent is terminated, _unsubscribeFromAgent() only removes the
  // _agentStates entry. It does NOT cancel the conversation, turnComplete,
  // or status stream subscriptions created in _subscribeToAgent(). This
  // means terminated agents keep emitting events.
  // =========================================================================
  group('Bug: terminated agent subscription cleanup', () {
    late SessionTestHarness h;

    setUp(() async {
      h = SessionTestHarness();
      await h.setUp();
    });

    tearDown(() => h.dispose());

    test('terminated agent should NOT emit events after removal', () async {
      // Spawn a sub-agent
      final subClient = h.addAgent(id: 'sub-agent', name: 'Sub Agent');
      await Future<void>.delayed(Duration.zero);

      // Collect events from this point
      final events = h.collectEvents();

      // Terminate the agent by removing it from the network
      final manager = h.container.read(agentNetworkManagerProvider.notifier);
      final network = manager.state.currentNetwork!;
      manager.state = AgentNetworkState(
        currentNetwork: network.copyWith(
          agents: network.agents.where((a) => a.id != 'sub-agent').toList(),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      // Clear events from the termination itself
      events.clear();

      // Now simulate activity on the terminated agent's client.
      // Before the fix, these would still emit events because the
      // subscriptions were never cancelled.
      subClient.simulateTextResponse('Ghost message');
      await Future<void>.delayed(Duration.zero);

      subClient.simulateTurnComplete();
      await Future<void>.delayed(Duration.zero);

      // No events should appear for the terminated agent
      final ghostMessages = events
          .whereType<MessageEvent>()
          .where((e) => e.agentId == 'sub-agent')
          .toList();
      final ghostTurnCompletes = events
          .whereType<TurnCompleteEvent>()
          .where((e) => e.agentId == 'sub-agent')
          .toList();

      expect(
        ghostMessages,
        isEmpty,
        reason:
            'Terminated agent should not emit MessageEvents '
            '(subscription should be cancelled)',
      );
      expect(
        ghostTurnCompletes,
        isEmpty,
        reason:
            'Terminated agent should not emit TurnCompleteEvents '
            '(subscription should be cancelled)',
      );
    });

    test(
      'terminated agent status changes should NOT emit StatusEvents',
      () async {
        h.addAgent(id: 'sub-agent', name: 'Sub Agent');
        await Future<void>.delayed(Duration.zero);

        // Terminate
        final manager = h.container.read(agentNetworkManagerProvider.notifier);
        final network = manager.state.currentNetwork!;
        manager.state = AgentNetworkState(
          currentNetwork: network.copyWith(
            agents: network.agents.where((a) => a.id != 'sub-agent').toList(),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        final events = h.collectEvents();

        // Change status on the terminated agent
        h.container
            .read(agentStatusProvider('sub-agent').notifier)
            .setStatus(AgentStatus.working);
        await Future<void>.delayed(Duration.zero);

        final statusEvents = events
            .whereType<StatusEvent>()
            .where((e) => e.agentId == 'sub-agent')
            .toList();

        expect(
          statusEvents,
          isEmpty,
          reason:
              'Terminated agent should not emit StatusEvents '
              '(provider subscription should be closed)',
        );
      },
    );
  });

  // =========================================================================
  // Bug 2: _handleAskUserQuestion has no _disposed check
  //
  // Unlike _handleExitPlanMode and the permission handler, _handleAskUserQuestion
  // doesn't check if the session is disposed before creating a completer.
  // This can create an orphaned completer if the session is disposing.
  // =========================================================================
  group('Bug: AskUserQuestion disposed check', () {
    late SessionTestHarness h;

    setUp(() async {
      h = SessionTestHarness();
      await h.setUp(dangerouslySkipPermissions: false);
    });

    tearDown(() => h.dispose());

    test('AskUserQuestion on disposed session should deny, not hang', () async {
      final callback = h.session.createPermissionCallback(
        agentId: h.agentId,
        agentName: 'Main Agent',
        agentType: 'main',
        cwd: '/tmp',
      );

      // Dispose the session first
      await h.session.dispose(fireEndTrigger: false);

      // Now call AskUserQuestion — before the fix, this would create
      // an orphaned completer and hang forever.
      final result = await callback('AskUserQuestion', {
        'questions': [
          {
            'question': 'Which option?',
            'header': 'Choice',
            'multiSelect': false,
            'options': [
              {'label': 'A', 'description': 'Option A'},
              {'label': 'B', 'description': 'Option B'},
            ],
          },
        ],
      }, const VidePermissionContext());

      // Should get a deny result, not hang
      expect(result, isA<VidePermissionDeny>());
    });
  });

  // =========================================================================
  // Bug 3: Conversation error is emitted every time _handleConversation runs
  //
  // The error check at the bottom of _handleConversation fires on every
  // conversation update as long as `currentError` is non-null. This means
  // a single error gets emitted as multiple ErrorEvents.
  // =========================================================================
  group('Bug: duplicate error events', () {
    late SessionTestHarness h;

    setUp(() async {
      h = SessionTestHarness();
      await h.setUp();
    });

    tearDown(() => h.dispose());

    test(
      'a single error should emit only one ErrorEvent, not duplicates',
      () async {
        // Need at least one message so _handleConversation doesn't skip
        h.mockClient.simulateTextResponse('some response');
        await Future<void>.delayed(Duration.zero);

        final events = h.collectEvents();

        // Set an error
        h.mockClient.simulateError('Rate limit exceeded');
        await Future<void>.delayed(Duration.zero);

        // Now trigger another conversation update (e.g. streaming text).
        // The error is still on the conversation object.
        h.mockClient.simulateStreamingText('More text after error');
        await Future<void>.delayed(Duration.zero);

        final errorEvents = events.whereType<ErrorEvent>().toList();

        // Before the fix, this would be 2 (or more) because each
        // _handleConversation call re-checks currentError.
        expect(
          errorEvents,
          hasLength(1),
          reason:
              'A single error should only produce one ErrorEvent, '
              'not be re-emitted on every conversation update',
        );
      },
    );
  });

  // =========================================================================
  // Bug 4: queuedMessageStream and getQueuedMessage don't check _disposed
  //
  // Most session methods call _checkNotDisposed(), but getQueuedMessage()
  // and queuedMessageStream() don't. They silently return null/empty stream
  // instead of throwing StateError like every other method.
  // =========================================================================
  group('Bug: missing disposed check on queued message methods', () {
    late SessionTestHarness h;

    setUp(() async {
      h = SessionTestHarness();
      await h.setUp();
    });

    // Don't use h.dispose() in tearDown since we dispose manually
    tearDown(() async {});

    test('getQueuedMessage should throw StateError after dispose', () async {
      await h.session.dispose(fireEndTrigger: false);

      expect(
        () => h.session.getQueuedMessage(h.agentId),
        throwsA(isA<StateError>()),
      );
    });

    test('queuedMessageStream should throw StateError after dispose', () async {
      await h.session.dispose(fireEndTrigger: false);

      expect(
        () => h.session.queuedMessageStream(h.agentId),
        throwsA(isA<StateError>()),
      );
    });
  });
}
