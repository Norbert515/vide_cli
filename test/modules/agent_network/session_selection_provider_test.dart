import 'dart:async';

import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:test/test.dart';
import 'package:vide_cli/modules/agent_network/state/vide_session_providers.dart';
import 'package:vide_client/vide_client.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  group('SessionSelectionNotifier', () {
    test('starts empty', () {
      final notifier = SessionSelectionNotifier();
      expect(notifier.state.sessionId, isNull);
      expect(notifier.state.session, isNull);
    });

    test('selectSession stores session and derives id', () {
      final notifier = SessionSelectionNotifier();
      final session = createPendingRemoteVideSession().session;

      notifier.selectSession(session);

      expect(notifier.state.sessionId, equals(session.id));
      expect(notifier.state.session, same(session));
    });

    test('clear resets session selection', () {
      final notifier = SessionSelectionNotifier();
      final session = createPendingRemoteVideSession().session;

      notifier.selectSession(session);
      notifier.clear();

      expect(notifier.state.sessionId, isNull);
      expect(notifier.state.session, isNull);
    });

    test('sessionId tracks live session.id after completePending', () {
      final pending = createPendingRemoteVideSession();
      final notifier = SessionSelectionNotifier();

      notifier.selectSession(pending.session);

      final idBefore = notifier.state.sessionId;
      expect(idBefore, isNotNull);

      // Simulate daemon response with a real session ID
      pending.completeWithConnection(
        sessionId: 'daemon-assigned-id',
        channel: _FakeWebSocketChannel(),
      );

      // The derived sessionId should now reflect the updated session.id
      expect(notifier.state.sessionId, equals('daemon-assigned-id'));
      expect(notifier.state.sessionId, isNot(equals(idBefore)));
    });
  });

  group('currentVideSessionProvider', () {
    test('returns selected session', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final session = createPendingRemoteVideSession().session;
      container.read(sessionSelectionProvider.notifier).selectSession(session);

      final current = container.read(currentVideSessionProvider);
      expect(current, same(session));
    });
  });

  group('sessionSelectionProvider notifier', () {
    test('selectSession updates unified session selection state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(sessionSelectionProvider.notifier);
      final session = createPendingRemoteVideSession().session;

      notifier.selectSession(session);

      final state = container.read(sessionSelectionProvider);
      expect(state.sessionId, equals(session.id));
      expect(state.session, same(session));
    });

    test('clear resets unified session selection state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(sessionSelectionProvider.notifier);
      final session = createPendingRemoteVideSession().session;

      notifier.selectSession(session);
      notifier.clear();

      final state = container.read(sessionSelectionProvider);
      expect(state.sessionId, isNull);
      expect(state.session, isNull);
    });
  });
}

/// Minimal fake for [WebSocketChannel] to satisfy completeWithConnection.
class _FakeWebSocketChannel implements WebSocketChannel {
  final _controller = StreamController<dynamic>();

  @override
  Stream<dynamic> get stream => _controller.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
