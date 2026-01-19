import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';

void main() {
  group('AgentStatusManager', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial status is working', () {
      final status = container.read(agentStatusProvider('agent-1'));

      expect(status, AgentStatus.working);
    });

    test('setStatus updates status', () {
      final notifier = container.read(agentStatusProvider('agent-1').notifier);

      notifier.setStatus(AgentStatus.waitingForAgent);

      expect(
        container.read(agentStatusProvider('agent-1')),
        AgentStatus.waitingForAgent,
      );
    });

    test('family provider creates separate instances per agent', () {
      final notifier1 = container.read(agentStatusProvider('agent-1').notifier);
      final notifier2 = container.read(agentStatusProvider('agent-2').notifier);

      notifier1.setStatus(AgentStatus.idle);
      notifier2.setStatus(AgentStatus.waitingForUser);

      expect(container.read(agentStatusProvider('agent-1')), AgentStatus.idle);
      expect(
        container.read(agentStatusProvider('agent-2')),
        AgentStatus.waitingForUser,
      );
    });

    test('notifies listeners on status change', () {
      var notificationCount = 0;

      container.listen(agentStatusProvider('agent-1'), (previous, next) {
        notificationCount++;
      });

      final notifier = container.read(agentStatusProvider('agent-1').notifier);
      notifier.setStatus(AgentStatus.waitingForAgent);
      notifier.setStatus(AgentStatus.idle);

      expect(notificationCount, 2);
    });

    test('setting same status does not notify listeners', () {
      var notificationCount = 0;

      container.listen(agentStatusProvider('agent-1'), (previous, next) {
        notificationCount++;
      });

      final notifier = container.read(agentStatusProvider('agent-1').notifier);
      // Initial status is 'working', setting to 'working' again is a no-op
      notifier.setStatus(AgentStatus.working);
      notifier.setStatus(AgentStatus.working);

      // StateNotifier does NOT notify when value is unchanged (standard behavior)
      expect(notificationCount, 0);
    });
  });
}
