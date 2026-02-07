import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';
import 'package:claude_sdk/claude_sdk.dart';

/// A minimal mock ClaudeClient for testing
class MockClaudeClient implements ClaudeClient {
  final String testId;

  MockClaudeClient(this.testId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('ClaudeClientRegistry', () {
    late ClaudeClientRegistry registry;

    setUp(() {
      registry = ClaudeClientRegistry();
    });

    tearDown(() {
      registry.dispose();
    });

    test('initial state is empty', () {
      expect(registry.all, isEmpty);
    });

    test('addAgent adds client', () {
      final client = MockClaudeClient('test-1');

      registry.addAgent('agent-1', client);

      expect(registry['agent-1'], client);
    });

    test('addAgent can add multiple clients', () {
      final client1 = MockClaudeClient('test-1');
      final client2 = MockClaudeClient('test-2');

      registry.addAgent('agent-1', client1);
      registry.addAgent('agent-2', client2);

      expect(registry.all.length, 2);
      expect(registry['agent-1'], client1);
      expect(registry['agent-2'], client2);
    });

    test('addAgent replaces existing client for same agent', () {
      final client1 = MockClaudeClient('original');
      final client2 = MockClaudeClient('replacement');

      registry.addAgent('agent-1', client1);
      registry.addAgent('agent-1', client2);

      expect(registry['agent-1'], client2);
      expect(registry.all.length, 1);
    });

    test('removeAgent removes client', () {
      final client = MockClaudeClient('test-1');

      registry.addAgent('agent-1', client);
      registry.removeAgent('agent-1');

      expect(registry['agent-1'], isNull);
      expect(registry.all, isEmpty);
    });

    test('removeAgent is safe for non-existent agent', () {
      // Should not throw
      registry.removeAgent('non-existent');

      expect(registry.all, isEmpty);
    });

    test('notifies listeners on add', () {
      var notificationCount = 0;

      registry.changes.listen((_) {
        notificationCount++;
      });

      registry.addAgent('agent-1', MockClaudeClient('test'));

      expect(notificationCount, 1);
    });

    test('notifies listeners on remove', () {
      registry.addAgent('agent-1', MockClaudeClient('test'));

      var notificationCount = 0;
      registry.changes.listen((_) {
        notificationCount++;
      });

      registry.removeAgent('agent-1');

      expect(notificationCount, 1);
    });
  });

  group('ClaudeClientRegistry operator[]', () {
    late ClaudeClientRegistry registry;

    setUp(() {
      registry = ClaudeClientRegistry();
    });

    tearDown(() {
      registry.dispose();
    });

    test('returns client for agent', () {
      final client = MockClaudeClient('test');
      registry.addAgent('agent-1', client);

      final retrieved = registry['agent-1'];

      expect(retrieved, client);
    });

    test('returns null for non-existent agent', () {
      final retrieved = registry['non-existent'];

      expect(retrieved, isNull);
    });

    test('reflects client when added', () {
      // Initially null
      expect(registry['agent-1'], isNull);

      final client = MockClaudeClient('test');
      registry.addAgent('agent-1', client);

      // Now should return the client
      expect(registry['agent-1'], same(client));
    });

    test('reflects removal when client is removed', () {
      final client = MockClaudeClient('test');
      registry.addAgent('agent-1', client);

      // Verify client is present
      expect(registry['agent-1'], same(client));

      registry.removeAgent('agent-1');

      // Now should be null
      expect(registry['agent-1'], isNull);
    });
  });
}
