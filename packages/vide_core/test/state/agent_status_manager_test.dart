import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';

void main() {
  group('AgentStatusRegistry', () {
    late AgentStatusRegistry registry;

    setUp(() {
      registry = AgentStatusRegistry();
    });

    tearDown(() {
      registry.dispose();
    });

    test('initial status is working', () {
      final status = registry.getStatus('agent-1');

      expect(status, AgentStatus.working);
    });

    test('setStatus updates status', () {
      registry.setStatus('agent-1', AgentStatus.waitingForAgent);

      expect(registry.getStatus('agent-1'), AgentStatus.waitingForAgent);
    });

    test('registry creates separate statuses per agent', () {
      registry.setStatus('agent-1', AgentStatus.idle);
      registry.setStatus('agent-2', AgentStatus.waitingForUser);

      expect(registry.getStatus('agent-1'), AgentStatus.idle);
      expect(registry.getStatus('agent-2'), AgentStatus.waitingForUser);
    });

    test('notifies listeners on status change', () {
      var notificationCount = 0;

      registry.changes.listen((_) {
        notificationCount++;
      });

      registry.setStatus('agent-1', AgentStatus.waitingForAgent);
      registry.setStatus('agent-1', AgentStatus.idle);

      expect(notificationCount, 2);
    });

    test('setting same status does not notify listeners', () {
      var notificationCount = 0;

      // Set initial status to working explicitly
      registry.setStatus('agent-1', AgentStatus.working);

      registry.changes.listen((_) {
        notificationCount++;
      });

      // Setting to 'working' again should be a no-op since it's already working
      registry.setStatus('agent-1', AgentStatus.working);

      expect(notificationCount, 0);
    });

    test('remove cleans up agent status', () {
      registry.setStatus('agent-1', AgentStatus.idle);
      registry.remove('agent-1');

      // After removal, should get default status again
      expect(registry.getStatus('agent-1'), AgentStatus.working);
    });
  });
}
