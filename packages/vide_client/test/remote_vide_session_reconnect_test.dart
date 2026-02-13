/// Tests for RemoteVideSession reconnection and status restoration.
///
/// Verifies that:
/// - History replay correctly reconstructs agent status
/// - The reconnect() method preserves session instance identity
/// - isProcessing reflects the final status after history replay
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:vide_client/vide_client.dart';

/// Helper to find an agent by ID in the session state.
VideAgent _agent(RemoteVideSession session, String id) =>
    session.state.agents.firstWhere((a) => a.id == id);

void main() {
  group('History replay correctly reconstructs agent status', () {
    test('agent ends up working when last status event is working', () async {
      final session = RemoteVideSession.pending();
      addTearDown(session.dispose);

      session.handleWebSocketMessage(
        jsonEncode({
          'type': 'connected',
          'session-id': 'session-1',
          'main-agent-id': 'agent-1',
          'last-seq': 3,
          'agents': [
            {'id': 'agent-1', 'type': 'main', 'name': 'Main'},
          ],
          'metadata': {},
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
      await Future<void>.delayed(Duration.zero);

      // After ConnectedEvent, agent defaults to idle
      expect(_agent(session, 'agent-1').status, equals(VideAgentStatus.idle));

      // History replay includes a status(working) event
      session.handleWebSocketMessage(
        jsonEncode({
          'type': 'history',
          'last-seq': 3,
          'timestamp': DateTime.now().toIso8601String(),
          'data': {
            'events': [
              {
                'type': 'message',
                'seq': 1,
                'event-id': 'msg-1',
                'agent-id': 'agent-1',
                'agent-type': 'main',
                'is-partial': false,
                'timestamp': DateTime.now().toIso8601String(),
                'data': {'role': 'user', 'content': 'Do something'},
              },
              {
                'type': 'status',
                'seq': 2,
                'agent-id': 'agent-1',
                'agent-type': 'main',
                'timestamp': DateTime.now().toIso8601String(),
                'data': {'status': 'working'},
              },
              {
                'type': 'message',
                'seq': 3,
                'event-id': 'msg-2',
                'agent-id': 'agent-1',
                'agent-type': 'main',
                'is-partial': false,
                'timestamp': DateTime.now().toIso8601String(),
                'data': {'role': 'assistant', 'content': 'Working on it...'},
              },
            ],
          },
        }),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        _agent(session, 'agent-1').status,
        equals(VideAgentStatus.working),
        reason:
            'History replay should set status to working since that is the '
            'last status event in history',
      );
    });

    test(
      'agent ends up idle when history has done event after working',
      () async {
        final session = RemoteVideSession.pending();
        addTearDown(session.dispose);

        session.handleWebSocketMessage(
          jsonEncode({
            'type': 'connected',
            'session-id': 'session-1',
            'main-agent-id': 'agent-1',
            'last-seq': 3,
            'agents': [
              {'id': 'agent-1', 'type': 'main', 'name': 'Main'},
            ],
            'metadata': {},
            'timestamp': DateTime.now().toIso8601String(),
          }),
        );
        await Future<void>.delayed(Duration.zero);

        // History has working → done, so final status should be idle
        session.handleWebSocketMessage(
          jsonEncode({
            'type': 'history',
            'last-seq': 3,
            'timestamp': DateTime.now().toIso8601String(),
            'data': {
              'events': [
                {
                  'type': 'status',
                  'seq': 1,
                  'agent-id': 'agent-1',
                  'agent-type': 'main',
                  'timestamp': DateTime.now().toIso8601String(),
                  'data': {'status': 'working'},
                },
                {
                  'type': 'message',
                  'seq': 2,
                  'event-id': 'msg-1',
                  'agent-id': 'agent-1',
                  'agent-type': 'main',
                  'is-partial': false,
                  'timestamp': DateTime.now().toIso8601String(),
                  'data': {'role': 'assistant', 'content': 'Done'},
                },
                {
                  'type': 'done',
                  'seq': 3,
                  'agent-id': 'agent-1',
                  'agent-type': 'main',
                  'timestamp': DateTime.now().toIso8601String(),
                  'data': {'reason': 'end_turn'},
                },
              ],
            },
          }),
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          _agent(session, 'agent-1').status,
          equals(VideAgentStatus.idle),
          reason: 'History replay with done event should leave agent as idle',
        );
      },
    );

    test('isProcessing reflects mixed agent statuses from history', () async {
      final session = RemoteVideSession.pending();
      addTearDown(session.dispose);

      session.handleWebSocketMessage(
        jsonEncode({
          'type': 'connected',
          'session-id': 'session-1',
          'main-agent-id': 'agent-1',
          'last-seq': 4,
          'agents': [
            {'id': 'agent-1', 'type': 'main', 'name': 'Main'},
            {'id': 'agent-2', 'type': 'impl', 'name': 'Worker'},
          ],
          'metadata': {},
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
      await Future<void>.delayed(Duration.zero);

      // History: agent-1 completes (done), agent-2 is still working
      session.handleWebSocketMessage(
        jsonEncode({
          'type': 'history',
          'last-seq': 4,
          'timestamp': DateTime.now().toIso8601String(),
          'data': {
            'events': [
              {
                'type': 'status',
                'seq': 1,
                'agent-id': 'agent-1',
                'agent-type': 'main',
                'timestamp': DateTime.now().toIso8601String(),
                'data': {'status': 'working'},
              },
              {
                'type': 'status',
                'seq': 2,
                'agent-id': 'agent-2',
                'agent-type': 'impl',
                'timestamp': DateTime.now().toIso8601String(),
                'data': {'status': 'working'},
              },
              {
                'type': 'done',
                'seq': 3,
                'agent-id': 'agent-1',
                'agent-type': 'main',
                'timestamp': DateTime.now().toIso8601String(),
                'data': {'reason': 'end_turn'},
              },
              {
                'type': 'status',
                'seq': 4,
                'agent-id': 'agent-2',
                'agent-type': 'impl',
                'timestamp': DateTime.now().toIso8601String(),
                'data': {'status': 'waiting-for-agent'},
              },
            ],
          },
        }),
      );
      await Future<void>.delayed(Duration.zero);

      expect(_agent(session, 'agent-1').status, equals(VideAgentStatus.idle));
      expect(
        _agent(session, 'agent-2').status,
        equals(VideAgentStatus.waitingForAgent),
      );
    });

    test('live events after history continue to update status', () async {
      final session = RemoteVideSession.pending();
      addTearDown(session.dispose);

      session.handleWebSocketMessage(
        jsonEncode({
          'type': 'connected',
          'session-id': 'session-1',
          'main-agent-id': 'agent-1',
          'last-seq': 2,
          'agents': [
            {'id': 'agent-1', 'type': 'main', 'name': 'Main'},
          ],
          'metadata': {},
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      // History sets agent to working
      session.handleWebSocketMessage(
        jsonEncode({
          'type': 'history',
          'last-seq': 2,
          'timestamp': DateTime.now().toIso8601String(),
          'data': {
            'events': [
              {
                'type': 'status',
                'seq': 1,
                'agent-id': 'agent-1',
                'agent-type': 'main',
                'timestamp': DateTime.now().toIso8601String(),
                'data': {'status': 'working'},
              },
              {
                'type': 'message',
                'seq': 2,
                'event-id': 'msg-1',
                'agent-id': 'agent-1',
                'agent-type': 'main',
                'is-partial': false,
                'timestamp': DateTime.now().toIso8601String(),
                'data': {'role': 'assistant', 'content': 'Working...'},
              },
            ],
          },
        }),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        _agent(session, 'agent-1').status,
        equals(VideAgentStatus.working),
      );

      // Live event (seq > lastSeq) completes the turn
      session.handleWebSocketMessage(
        jsonEncode({
          'type': 'done',
          'seq': 3,
          'agent-id': 'agent-1',
          'agent-type': 'main',
          'timestamp': DateTime.now().toIso8601String(),
          'data': {'reason': 'end_turn'},
        }),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        _agent(session, 'agent-1').status,
        equals(VideAgentStatus.idle),
        reason: 'Live done event after history should update status to idle',
      );
    });

    test('empty history leaves agents at default idle status', () async {
      final session = RemoteVideSession.pending();
      addTearDown(session.dispose);

      session.handleWebSocketMessage(
        jsonEncode({
          'type': 'connected',
          'session-id': 'session-1',
          'main-agent-id': 'agent-1',
          'last-seq': 0,
          'agents': [
            {'id': 'agent-1', 'type': 'main', 'name': 'Main'},
          ],
          'metadata': {},
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      session.handleWebSocketMessage(
        jsonEncode({
          'type': 'history',
          'last-seq': 0,
          'timestamp': DateTime.now().toIso8601String(),
          'data': {'events': []},
        }),
      );
      await Future<void>.delayed(Duration.zero);

      expect(_agent(session, 'agent-1').status, equals(VideAgentStatus.idle));
    });
  });

  group('reconnect() preserves session identity', () {
    test('reconnect method preserves the same session object', () async {
      final session = RemoteVideSession.pending();
      addTearDown(session.dispose);

      final idBefore = session.id;

      // Connect via ConnectedEvent
      session.handleWebSocketMessage(
        jsonEncode({
          'type': 'connected',
          'session-id': 'session-1',
          'main-agent-id': 'agent-1',
          'last-seq': 0,
          'agents': [
            {'id': 'agent-1', 'type': 'main', 'name': 'Main'},
          ],
          'metadata': {},
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
      await Future<void>.delayed(Duration.zero);

      // Session ID stays stable (set at construction for pending sessions,
      // updated by completePending() in production)
      expect(session.id, equals(idBefore));

      // Agent was correctly registered from ConnectedEvent
      expect(_agent(session, 'agent-1').name, equals('Main'));
    });
  });

  group('Optimistic working guard prevents loading flicker', () {
    /// Helper to create a connected session with an idle main agent.
    RemoteVideSession _connectedSession() {
      final session = RemoteVideSession.pending();
      session.handleWebSocketMessage(
        jsonEncode({
          'type': 'connected',
          'session-id': 'session-1',
          'main-agent-id': 'agent-1',
          'last-seq': 0,
          'agents': [
            {'id': 'agent-1', 'type': 'main', 'name': 'Main'},
          ],
          'metadata': {},
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
      session.handleWebSocketMessage(
        jsonEncode({
          'type': 'history',
          'last-seq': 0,
          'timestamp': DateTime.now().toIso8601String(),
          'data': {'events': []},
        }),
      );
      return session;
    }

    test(
      'stale StatusEvent(idle) is ignored after optimistic working',
      () async {
        final session = _connectedSession();
        addTearDown(session.dispose);
        await Future<void>.delayed(Duration.zero);

        expect(_agent(session, 'agent-1').status, equals(VideAgentStatus.idle));

        // User sends a message → optimistic working
        session.sendMessage(VideMessage(text: 'Hello'));
        await Future<void>.delayed(Duration.zero);

        expect(
          _agent(session, 'agent-1').status,
          equals(VideAgentStatus.working),
        );

        // Server sends a stale StatusEvent(idle) — from before it processed
        // the user's message. This should be ignored.
        session.handleWebSocketMessage(
          jsonEncode({
            'type': 'status',
            'seq': 1,
            'agent-id': 'agent-1',
            'agent-type': 'main',
            'timestamp': DateTime.now().toIso8601String(),
            'data': {'status': 'idle'},
          }),
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          _agent(session, 'agent-1').status,
          equals(VideAgentStatus.working),
          reason:
              'Stale idle status should be ignored during optimistic window',
        );
      },
    );

    test(
      'StatusEvent(working) from server clears the optimistic guard',
      () async {
        final session = _connectedSession();
        addTearDown(session.dispose);
        await Future<void>.delayed(Duration.zero);

        // Send message → optimistic working
        session.sendMessage(VideMessage(text: 'Hello'));
        await Future<void>.delayed(Duration.zero);

        // Server confirms working
        session.handleWebSocketMessage(
          jsonEncode({
            'type': 'status',
            'seq': 1,
            'agent-id': 'agent-1',
            'agent-type': 'main',
            'timestamp': DateTime.now().toIso8601String(),
            'data': {'status': 'working'},
          }),
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          _agent(session, 'agent-1').status,
          equals(VideAgentStatus.working),
        );

        // Now a subsequent idle status should NOT be ignored (guard was cleared)
        session.handleWebSocketMessage(
          jsonEncode({
            'type': 'status',
            'seq': 2,
            'agent-id': 'agent-1',
            'agent-type': 'main',
            'timestamp': DateTime.now().toIso8601String(),
            'data': {'status': 'idle'},
          }),
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          _agent(session, 'agent-1').status,
          equals(VideAgentStatus.idle),
          reason:
              'After server confirms working, idle status should be accepted',
        );
      },
    );

    test('TurnCompleteEvent clears optimistic guard and sets idle', () async {
      final session = _connectedSession();
      addTearDown(session.dispose);
      await Future<void>.delayed(Duration.zero);

      // Send message → optimistic working
      session.sendMessage(VideMessage(text: 'Hello'));
      await Future<void>.delayed(Duration.zero);

      expect(
        _agent(session, 'agent-1').status,
        equals(VideAgentStatus.working),
      );

      // Server sends TurnCompleteEvent (agent genuinely finished)
      session.handleWebSocketMessage(
        jsonEncode({
          'type': 'done',
          'seq': 1,
          'agent-id': 'agent-1',
          'agent-type': 'main',
          'timestamp': DateTime.now().toIso8601String(),
          'data': {'reason': 'end_turn'},
        }),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        _agent(session, 'agent-1').status,
        equals(VideAgentStatus.idle),
        reason: 'TurnCompleteEvent should always set idle, even during guard',
      );
    });

    test(
      'full realistic sequence: optimistic → stale idle → server working → done',
      () async {
        final session = _connectedSession();
        addTearDown(session.dispose);
        await Future<void>.delayed(Duration.zero);

        // 1. User sends message → optimistic working
        session.sendMessage(VideMessage(text: 'Hello'));
        await Future<void>.delayed(Duration.zero);
        expect(
          _agent(session, 'agent-1').status,
          equals(VideAgentStatus.working),
        );

        // 2. Stale StatusEvent(idle) arrives → ignored
        session.handleWebSocketMessage(
          jsonEncode({
            'type': 'status',
            'seq': 1,
            'agent-id': 'agent-1',
            'agent-type': 'main',
            'timestamp': DateTime.now().toIso8601String(),
            'data': {'status': 'idle'},
          }),
        );
        await Future<void>.delayed(Duration.zero);
        expect(
          _agent(session, 'agent-1').status,
          equals(VideAgentStatus.working),
          reason: 'Stale idle ignored',
        );

        // 3. Server confirms working → guard cleared
        session.handleWebSocketMessage(
          jsonEncode({
            'type': 'status',
            'seq': 2,
            'agent-id': 'agent-1',
            'agent-type': 'main',
            'timestamp': DateTime.now().toIso8601String(),
            'data': {'status': 'working'},
          }),
        );
        await Future<void>.delayed(Duration.zero);
        expect(
          _agent(session, 'agent-1').status,
          equals(VideAgentStatus.working),
        );

        // 4. Streaming message from assistant
        session.handleWebSocketMessage(
          jsonEncode({
            'type': 'message',
            'seq': 3,
            'event-id': 'msg-1',
            'agent-id': 'agent-1',
            'agent-type': 'main',
            'is-partial': false,
            'timestamp': DateTime.now().toIso8601String(),
            'data': {'role': 'assistant', 'content': 'Here is my response'},
          }),
        );
        await Future<void>.delayed(Duration.zero);
        expect(
          _agent(session, 'agent-1').status,
          equals(VideAgentStatus.working),
        );

        // 5. Turn completes → idle
        session.handleWebSocketMessage(
          jsonEncode({
            'type': 'done',
            'seq': 4,
            'agent-id': 'agent-1',
            'agent-type': 'main',
            'timestamp': DateTime.now().toIso8601String(),
            'data': {'reason': 'end_turn'},
          }),
        );
        await Future<void>.delayed(Duration.zero);
        expect(_agent(session, 'agent-1').status, equals(VideAgentStatus.idle));
      },
    );

    test('multiple stale idle events are all ignored during guard', () async {
      final session = _connectedSession();
      addTearDown(session.dispose);
      await Future<void>.delayed(Duration.zero);

      session.sendMessage(VideMessage(text: 'Hello'));
      await Future<void>.delayed(Duration.zero);

      // Multiple stale idles
      for (var i = 1; i <= 3; i++) {
        session.handleWebSocketMessage(
          jsonEncode({
            'type': 'status',
            'seq': i,
            'agent-id': 'agent-1',
            'agent-type': 'main',
            'timestamp': DateTime.now().toIso8601String(),
            'data': {'status': 'idle'},
          }),
        );
      }
      await Future<void>.delayed(Duration.zero);

      expect(
        _agent(session, 'agent-1').status,
        equals(VideAgentStatus.working),
        reason: 'All stale idle events should be ignored',
      );
    });

    test('waitingForAgent status clears the optimistic guard', () async {
      final session = _connectedSession();
      addTearDown(session.dispose);
      await Future<void>.delayed(Duration.zero);

      session.sendMessage(VideMessage(text: 'Hello'));
      await Future<void>.delayed(Duration.zero);

      // Server sends waitingForAgent (non-idle, non-working)
      session.handleWebSocketMessage(
        jsonEncode({
          'type': 'status',
          'seq': 1,
          'agent-id': 'agent-1',
          'agent-type': 'main',
          'timestamp': DateTime.now().toIso8601String(),
          'data': {'status': 'waiting-for-agent'},
        }),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        _agent(session, 'agent-1').status,
        equals(VideAgentStatus.waitingForAgent),
        reason: 'Non-idle status should clear guard and be accepted',
      );
    });

    test('AbortedEvent clears optimistic guard', () async {
      final session = _connectedSession();
      addTearDown(session.dispose);
      await Future<void>.delayed(Duration.zero);

      session.sendMessage(VideMessage(text: 'Hello'));
      await Future<void>.delayed(Duration.zero);

      session.handleWebSocketMessage(
        jsonEncode({
          'type': 'aborted',
          'seq': 1,
          'agent-id': 'agent-1',
          'agent-type': 'main',
          'timestamp': DateTime.now().toIso8601String(),
          'data': {},
        }),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        _agent(session, 'agent-1').status,
        equals(VideAgentStatus.idle),
        reason: 'Abort should clear guard and set idle',
      );
    });

    test('ConnectedEvent clears all optimistic guards', () async {
      final session = _connectedSession();
      addTearDown(session.dispose);
      await Future<void>.delayed(Duration.zero);

      session.sendMessage(VideMessage(text: 'Hello'));
      await Future<void>.delayed(Duration.zero);

      // Reconnect event arrives (e.g. from WebSocket reconnection)
      session.handleWebSocketMessage(
        jsonEncode({
          'type': 'connected',
          'session-id': 'session-1',
          'main-agent-id': 'agent-1',
          'last-seq': 1,
          'agents': [
            {'id': 'agent-1', 'type': 'main', 'name': 'Main'},
          ],
          'metadata': {},
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
      await Future<void>.delayed(Duration.zero);

      // Agent reverts to idle (from ConnectedEvent defaults, no initial message)
      expect(
        _agent(session, 'agent-1').status,
        equals(VideAgentStatus.idle),
        reason: 'ConnectedEvent should clear guards and reset status',
      );
    });

    test('guard only applies to the agent that was sent a message', () async {
      final session = RemoteVideSession.pending();
      addTearDown(session.dispose);

      session.handleWebSocketMessage(
        jsonEncode({
          'type': 'connected',
          'session-id': 'session-1',
          'main-agent-id': 'agent-1',
          'last-seq': 0,
          'agents': [
            {'id': 'agent-1', 'type': 'main', 'name': 'Main'},
            {'id': 'agent-2', 'type': 'impl', 'name': 'Worker'},
          ],
          'metadata': {},
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
      session.handleWebSocketMessage(
        jsonEncode({
          'type': 'history',
          'last-seq': 0,
          'timestamp': DateTime.now().toIso8601String(),
          'data': {'events': []},
        }),
      );
      await Future<void>.delayed(Duration.zero);

      // Set agent-2 to working first so we can test idle transition
      session.handleWebSocketMessage(
        jsonEncode({
          'type': 'status',
          'seq': 1,
          'agent-id': 'agent-2',
          'agent-type': 'impl',
          'timestamp': DateTime.now().toIso8601String(),
          'data': {'status': 'working'},
        }),
      );
      await Future<void>.delayed(Duration.zero);

      // Send message to agent-1 only
      session.sendMessage(VideMessage(text: 'Hello'));
      await Future<void>.delayed(Duration.zero);

      expect(
        _agent(session, 'agent-1').status,
        equals(VideAgentStatus.working),
      );
      expect(
        _agent(session, 'agent-2').status,
        equals(VideAgentStatus.working),
      );

      // StatusEvent(idle) for agent-2 should NOT be blocked by agent-1's guard
      session.handleWebSocketMessage(
        jsonEncode({
          'type': 'status',
          'seq': 2,
          'agent-id': 'agent-2',
          'agent-type': 'impl',
          'timestamp': DateTime.now().toIso8601String(),
          'data': {'status': 'idle'},
        }),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        _agent(session, 'agent-2').status,
        equals(VideAgentStatus.idle),
        reason: 'Guard on agent-1 should not affect agent-2',
      );
      expect(
        _agent(session, 'agent-1').status,
        equals(VideAgentStatus.working),
        reason: 'Agent-1 still has optimistic guard',
      );
    });
  });
}
