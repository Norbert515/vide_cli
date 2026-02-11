/// Unit tests for SessionBroadcaster.
///
/// Verifies that the broadcaster correctly seeds from event history
/// and broadcasts live events to connected clients.
///
/// This is the core test for the daemon resume fix: when a session
/// is loaded from persistence and a broadcaster is created after
/// events have already been emitted, the broadcaster must seed its
/// stored events from the session's authoritative event history.
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:vide_interface/vide_interface.dart';
import 'package:vide_server/services/session_broadcaster.dart';

/// Minimal stub of VideSession for testing SessionBroadcaster.
///
/// Only implements the members that SessionBroadcaster actually uses
/// (id, events, eventHistory). All other VideSession members fall through
/// to noSuchMethod.
class _StubSession implements VideSession {
  final List<VideEvent> _eventHistory;
  final StreamController<VideEvent> _eventController =
      StreamController<VideEvent>.broadcast(sync: true);

  _StubSession({List<VideEvent>? eventHistory})
    : _eventHistory = eventHistory ?? [];

  @override
  String get id => 'test-session';

  @override
  List<VideEvent> get eventHistory => List.unmodifiable(_eventHistory);

  @override
  Stream<VideEvent> get events => _eventController.stream;

  /// Emit a live event (simulates new activity on the session).
  void emitLive(VideEvent event) {
    _eventHistory.add(event);
    _eventController.add(event);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('SessionBroadcaster', () {
    test('seeds history from session eventHistory on creation', () {
      // Simulate a session that already has events (e.g. resumed from persistence)
      final preExistingEvents = <VideEvent>[
        StatusEvent(
          agentId: 'agent-1',
          agentType: 'main',
          agentName: 'Main',
          status: VideAgentStatus.working,
        ),
        MessageEvent(
          agentId: 'agent-1',
          agentType: 'main',
          agentName: 'Main',
          eventId: 'msg-1',
          role: 'user',
          content: 'Hello world',
          isPartial: false,
        ),
        MessageEvent(
          agentId: 'agent-1',
          agentType: 'main',
          agentName: 'Main',
          eventId: 'msg-2',
          role: 'assistant',
          content: 'Hi there!',
          isPartial: false,
        ),
        ToolUseEvent(
          agentId: 'agent-1',
          agentType: 'main',
          agentName: 'Main',
          toolUseId: 'tool-1',
          toolName: 'Read',
          toolInput: {'file_path': '/tmp/test.txt'},
        ),
        ToolResultEvent(
          agentId: 'agent-1',
          agentType: 'main',
          agentName: 'Main',
          toolUseId: 'tool-1',
          toolName: 'Read',
          result: 'file contents',
          isError: false,
        ),
      ];

      final session = _StubSession(eventHistory: preExistingEvents);

      // Create broadcaster AFTER events exist — this is the scenario
      // that was broken before the fix (SessionBroadcaster was created
      // after PermissionHandler.setSession() drained the BufferedEventStream).
      final broadcaster = SessionBroadcaster(session);

      // Verify: broadcaster has seeded all pre-existing events
      expect(broadcaster.history.length, 5);

      // Verify sequence numbers are assigned
      expect(broadcaster.history[0]['seq'], 1);
      expect(broadcaster.history[1]['seq'], 2);
      expect(broadcaster.history[2]['seq'], 3);
      expect(broadcaster.history[3]['seq'], 4);
      expect(broadcaster.history[4]['seq'], 5);

      // Verify event types are preserved
      expect(broadcaster.history[0]['type'], 'status');
      expect(broadcaster.history[1]['type'], 'message');
      expect(broadcaster.history[2]['type'], 'message');
      expect(broadcaster.history[3]['type'], 'tool-use');
      expect(broadcaster.history[4]['type'], 'tool-result');

      // Verify content is preserved
      expect(broadcaster.history[1]['data']['content'], 'Hello world');
      expect(broadcaster.history[2]['data']['content'], 'Hi there!');

      broadcaster.dispose();
    });

    test('live events continue sequence after seeded history', () {
      final preExistingEvents = <VideEvent>[
        MessageEvent(
          agentId: 'agent-1',
          agentType: 'main',
          eventId: 'msg-1',
          role: 'user',
          content: 'Initial message',
          isPartial: false,
        ),
      ];

      final session = _StubSession(eventHistory: preExistingEvents);
      final broadcaster = SessionBroadcaster(session);

      // Verify seeded event
      expect(broadcaster.history.length, 1);
      expect(broadcaster.history[0]['seq'], 1);

      // Emit a live event
      session.emitLive(
        MessageEvent(
          agentId: 'agent-1',
          agentType: 'main',
          eventId: 'msg-2',
          role: 'assistant',
          content: 'Live response',
          isPartial: false,
        ),
      );

      // Verify live event is appended with correct sequence
      expect(broadcaster.history.length, 2);
      expect(broadcaster.history[1]['seq'], 2);
      expect(broadcaster.history[1]['data']['content'], 'Live response');

      broadcaster.dispose();
    });

    test('clients receive live events but not seeded history', () {
      final preExistingEvents = <VideEvent>[
        MessageEvent(
          agentId: 'agent-1',
          agentType: 'main',
          eventId: 'msg-1',
          role: 'user',
          content: 'Historical message',
          isPartial: false,
        ),
      ];

      final session = _StubSession(eventHistory: preExistingEvents);
      final broadcaster = SessionBroadcaster(session);

      // Add a client
      final clientEvents = <Map<String, dynamic>>[];
      broadcaster.addClient((event) => clientEvents.add(event));

      // Client should not receive seeded history
      expect(clientEvents, isEmpty);

      // Emit a live event
      session.emitLive(
        MessageEvent(
          agentId: 'agent-1',
          agentType: 'main',
          eventId: 'msg-2',
          role: 'assistant',
          content: 'Live event',
          isPartial: false,
        ),
      );

      // Client should receive only the live event
      expect(clientEvents.length, 1);
      expect(clientEvents[0]['data']['content'], 'Live event');

      // But history has both
      expect(broadcaster.history.length, 2);

      broadcaster.dispose();
    });

    test('empty session has no seeded history', () {
      final session = _StubSession(eventHistory: []);
      final broadcaster = SessionBroadcaster(session);

      expect(broadcaster.history, isEmpty);

      broadcaster.dispose();
    });

    test('seeded events get event-id assigned if missing', () {
      final session = _StubSession(
        eventHistory: [
          StatusEvent(
            agentId: 'agent-1',
            agentType: 'main',
            status: VideAgentStatus.idle,
          ),
        ],
      );
      final broadcaster = SessionBroadcaster(session);

      // StatusEvent doesn't have an inherent event-id, so broadcaster should assign one
      expect(broadcaster.history[0]['event-id'], isNotNull);
      expect(broadcaster.history[0]['event-id'], isNotEmpty);

      broadcaster.dispose();
    });

    test('registry returns same broadcaster for same session', () {
      final session = _StubSession();
      final registry = SessionBroadcasterRegistry.instance;

      final b1 = registry.getOrCreate(session);
      final b2 = registry.getOrCreate(session);

      expect(identical(b1, b2), isTrue);

      // Clean up
      registry.remove(session.id);
    });
  });
}
