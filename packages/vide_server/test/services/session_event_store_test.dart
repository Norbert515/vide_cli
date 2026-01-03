import 'package:test/test.dart';
import 'package:vide_server/services/session_event_store.dart';

void main() {
  group('SessionEventStore', () {
    late SessionEventStore store;

    setUp(() {
      store = SessionEventStore.instance;
      // Clean up any existing test sessions
      store.clearSession('test-session');
      store.clearSession('session-1');
      store.clearSession('session-2');
    });

    tearDown(() {
      store.clearSession('test-session');
      store.clearSession('session-1');
      store.clearSession('session-2');
    });

    group('sequence numbers', () {
      test('getCurrentSeq returns 0 for new session', () {
        expect(store.getCurrentSeq('test-session'), 0);
      });

      test('nextSeq increments and returns sequence number', () {
        expect(store.nextSeq('test-session'), 1);
        expect(store.nextSeq('test-session'), 2);
        expect(store.nextSeq('test-session'), 3);
        expect(store.getCurrentSeq('test-session'), 3);
      });

      test('sequence numbers are independent per session', () {
        expect(store.nextSeq('session-1'), 1);
        expect(store.nextSeq('session-1'), 2);
        expect(store.nextSeq('session-2'), 1);
        expect(store.getCurrentSeq('session-1'), 2);
        expect(store.getCurrentSeq('session-2'), 1);
      });
    });

    group('storeEvent', () {
      test('stores event and updates sequence', () {
        final event = {'type': 'message', 'seq': 1, 'content': 'hello'};
        store.storeEvent('test-session', 1, event);

        expect(store.eventCount('test-session'), 1);
        expect(store.getLastSeq('test-session'), 1);
      });

      test('stores multiple events in order', () {
        store.storeEvent('test-session', 1, {'type': 'message', 'seq': 1});
        store.storeEvent('test-session', 2, {'type': 'tool-use', 'seq': 2});
        store.storeEvent('test-session', 3, {'type': 'tool-result', 'seq': 3});

        expect(store.eventCount('test-session'), 3);
        expect(store.getLastSeq('test-session'), 3);
      });
    });

    group('getEvents', () {
      test('returns empty list for new session', () {
        expect(store.getEvents('test-session'), isEmpty);
      });

      test('returns all stored events in order', () {
        final event1 = {'type': 'message', 'seq': 1};
        final event2 = {'type': 'tool-use', 'seq': 2};
        final event3 = {'type': 'done', 'seq': 3};

        store.storeEvent('test-session', 1, event1);
        store.storeEvent('test-session', 2, event2);
        store.storeEvent('test-session', 3, event3);

        final events = store.getEvents('test-session');
        expect(events.length, 3);
        expect(events[0]['type'], 'message');
        expect(events[1]['type'], 'tool-use');
        expect(events[2]['type'], 'done');
      });

      test('returns independent lists per session', () {
        store.storeEvent('session-1', 1, {'type': 'a'});
        store.storeEvent('session-2', 1, {'type': 'b'});

        expect(store.getEvents('session-1').length, 1);
        expect(store.getEvents('session-2').length, 1);
        expect(store.getEvents('session-1')[0]['type'], 'a');
        expect(store.getEvents('session-2')[0]['type'], 'b');
      });
    });

    group('getLastSeq', () {
      test('returns 0 for new session', () {
        expect(store.getLastSeq('test-session'), 0);
      });

      test('returns last stored sequence number', () {
        store.storeEvent('test-session', 5, {'type': 'message', 'seq': 5});
        store.storeEvent('test-session', 10, {'type': 'done', 'seq': 10});

        expect(store.getLastSeq('test-session'), 10);
      });
    });

    group('hasEvents', () {
      test('returns false for new session', () {
        expect(store.hasEvents('test-session'), false);
      });

      test('returns true after storing event', () {
        store.storeEvent('test-session', 1, {'type': 'message'});
        expect(store.hasEvents('test-session'), true);
      });
    });

    group('clearSession', () {
      test('removes all events for session', () {
        store.storeEvent('test-session', 1, {'type': 'message'});
        store.storeEvent('test-session', 2, {'type': 'done'});
        expect(store.eventCount('test-session'), 2);

        store.clearSession('test-session');

        expect(store.eventCount('test-session'), 0);
        expect(store.getEvents('test-session'), isEmpty);
        expect(store.getLastSeq('test-session'), 0);
        expect(store.getCurrentSeq('test-session'), 0);
      });

      test('does not affect other sessions', () {
        store.storeEvent('session-1', 1, {'type': 'a'});
        store.storeEvent('session-2', 1, {'type': 'b'});

        store.clearSession('session-1');

        expect(store.eventCount('session-1'), 0);
        expect(store.eventCount('session-2'), 1);
      });
    });

    group('sessionCount', () {
      test('returns 0 when no sessions have events', () {
        expect(store.sessionCount, 0);
      });

      test('counts sessions with stored events', () {
        store.storeEvent('session-1', 1, {'type': 'a'});
        store.storeEvent('session-2', 1, {'type': 'b'});

        expect(store.sessionCount, 2);
      });
    });
  });
}
