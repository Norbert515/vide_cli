import 'package:claude_sdk/src/client/process_lifecycle_manager.dart';
import 'package:test/test.dart';

void main() {
  group('ProcessLifecycleManager', () {
    late ProcessLifecycleManager manager;

    setUp(() {
      manager = ProcessLifecycleManager();
    });

    tearDown(() async {
      await manager.close();
    });

    group('initial state', () {
      test('activeProcess is null before starting', () {
        expect(manager.activeProcess, isNull);
      });

      test('controlProtocol is null before starting', () {
        expect(manager.controlProtocol, isNull);
      });

      test('isRunning is false initially', () {
        expect(manager.isRunning, isFalse);
      });
    });

    group('close', () {
      test('can be called multiple times safely', () async {
        await manager.close();
        await manager.close(); // Should not throw

        expect(manager.activeProcess, isNull);
      });

      test('works when no process is active', () async {
        // Should not throw
        await manager.close();

        expect(manager.activeProcess, isNull);
      });
    });
  });
}
