import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:test/test.dart';
import 'package:vide_cli/modules/agent_network/state/vide_session_providers.dart';
import 'package:vide_core/vide_core.dart';

void main() {
  group('SessionSelectionNotifier', () {
    test('starts empty', () {
      final notifier = SessionSelectionNotifier();
      expect(notifier.state.sessionId, isNull);
      expect(notifier.state.session, isNull);
    });

    test('setSession selects the session id and object', () {
      final notifier = SessionSelectionNotifier();
      final session = createPendingRemoteVideSession().session;

      notifier.setSession(session);

      expect(notifier.state.sessionId, equals(session.id));
      expect(notifier.state.session, same(session));
    });

    test('selectSession retains session for same id', () {
      final notifier = SessionSelectionNotifier();
      final session = createPendingRemoteVideSession().session;

      notifier.setSession(session);
      notifier.selectSession(session.id);

      expect(notifier.state.sessionId, equals(session.id));
      expect(notifier.state.session, same(session));
    });

    test('selectSession drops session for different id', () {
      final notifier = SessionSelectionNotifier();
      final session = createPendingRemoteVideSession().session;

      notifier.setSession(session);
      notifier.selectSession('different-session-id');

      expect(notifier.state.sessionId, equals('different-session-id'));
      expect(notifier.state.session, isNull);
    });

    test('clear resets session selection', () {
      final notifier = SessionSelectionNotifier();
      final session = createPendingRemoteVideSession().session;

      notifier.setSession(session);
      notifier.clear();

      expect(notifier.state.sessionId, isNull);
      expect(notifier.state.session, isNull);
    });
  });

  group('currentVideSessionProvider', () {
    test('returns selected in-memory session when ids match', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final session = createPendingRemoteVideSession().session;
      container.read(sessionSelectionProvider.notifier).setSession(session);

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

      notifier.selectSession(session.id, session: session);

      final state = container.read(sessionSelectionProvider);
      expect(state.sessionId, equals(session.id));
      expect(state.session, same(session));
    });

    test('clear resets unified session selection state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(sessionSelectionProvider.notifier);
      final session = createPendingRemoteVideSession().session;

      notifier.setSession(session);
      notifier.clear();

      final state = container.read(sessionSelectionProvider);
      expect(state.sessionId, isNull);
      expect(state.session, isNull);
    });
  });
}
