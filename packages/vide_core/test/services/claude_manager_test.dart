import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';
import 'package:claude_api/claude_api.dart';

/// A minimal mock ClaudeClient for testing
class MockClaudeClient implements ClaudeClient {
  final String testId;

  MockClaudeClient(this.testId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('ClaudeManagerStateNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is empty map', () {
      final clients = container.read(claudeManagerProvider);

      expect(clients, isEmpty);
    });

    test('addAgent adds client to map', () {
      final notifier = container.read(claudeManagerProvider.notifier);
      final client = MockClaudeClient('test-1');

      notifier.addAgent('agent-1', client);

      final clients = container.read(claudeManagerProvider);
      expect(clients['agent-1'], client);
    });

    test('addAgent can add multiple clients', () {
      final notifier = container.read(claudeManagerProvider.notifier);
      final client1 = MockClaudeClient('test-1');
      final client2 = MockClaudeClient('test-2');

      notifier.addAgent('agent-1', client1);
      notifier.addAgent('agent-2', client2);

      final clients = container.read(claudeManagerProvider);
      expect(clients.length, 2);
      expect(clients['agent-1'], client1);
      expect(clients['agent-2'], client2);
    });

    test('addAgent replaces existing client for same agent', () {
      final notifier = container.read(claudeManagerProvider.notifier);
      final client1 = MockClaudeClient('original');
      final client2 = MockClaudeClient('replacement');

      notifier.addAgent('agent-1', client1);
      notifier.addAgent('agent-1', client2);

      final clients = container.read(claudeManagerProvider);
      expect(clients['agent-1'], client2);
      expect(clients.length, 1);
    });

    test('removeAgent removes client from map', () {
      final notifier = container.read(claudeManagerProvider.notifier);
      final client = MockClaudeClient('test-1');

      notifier.addAgent('agent-1', client);
      notifier.removeAgent('agent-1');

      final clients = container.read(claudeManagerProvider);
      expect(clients['agent-1'], isNull);
      expect(clients, isEmpty);
    });

    test('removeAgent is safe for non-existent agent', () {
      final notifier = container.read(claudeManagerProvider.notifier);

      // Should not throw
      notifier.removeAgent('non-existent');

      final clients = container.read(claudeManagerProvider);
      expect(clients, isEmpty);
    });

    test('notifies listeners on add', () {
      var notificationCount = 0;

      container.listen(
        claudeManagerProvider,
        (previous, next) {
          notificationCount++;
        },
      );

      final notifier = container.read(claudeManagerProvider.notifier);
      notifier.addAgent('agent-1', MockClaudeClient('test'));

      expect(notificationCount, 1);
    });

    test('notifies listeners on remove', () {
      final notifier = container.read(claudeManagerProvider.notifier);
      notifier.addAgent('agent-1', MockClaudeClient('test'));

      var notificationCount = 0;
      container.listen(
        claudeManagerProvider,
        (previous, next) {
          notificationCount++;
        },
      );

      notifier.removeAgent('agent-1');

      expect(notificationCount, 1);
    });
  });

  group('claudeProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('returns client for agent', () {
      final notifier = container.read(claudeManagerProvider.notifier);
      final client = MockClaudeClient('test');
      notifier.addAgent('agent-1', client);

      final retrieved = container.read(claudeProvider('agent-1'));

      expect(retrieved, client);
    });

    test('returns null for non-existent agent', () {
      final retrieved = container.read(claudeProvider('non-existent'));

      expect(retrieved, isNull);
    });

    test('updates when client is added', () {
      var updateCount = 0;

      container.listen(
        claudeProvider('agent-1'),
        (previous, next) {
          updateCount++;
        },
      );

      final notifier = container.read(claudeManagerProvider.notifier);
      notifier.addAgent('agent-1', MockClaudeClient('test'));

      expect(updateCount, 1);
      expect(container.read(claudeProvider('agent-1')), isNotNull);
    });

    test('updates when client is removed', () {
      final notifier = container.read(claudeManagerProvider.notifier);
      notifier.addAgent('agent-1', MockClaudeClient('test'));

      var updateCount = 0;
      container.listen(
        claudeProvider('agent-1'),
        (previous, next) {
          updateCount++;
        },
      );

      notifier.removeAgent('agent-1');

      expect(updateCount, 1);
      expect(container.read(claudeProvider('agent-1')), isNull);
    });
  });
}
