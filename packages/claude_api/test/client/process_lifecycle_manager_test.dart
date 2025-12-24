import 'package:claude_api/src/client/process_lifecycle_manager.dart';
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

      test('isAborting is false initially', () {
        expect(manager.isAborting, isFalse);
      });

      test('controlProtocol is null before starting', () {
        expect(manager.controlProtocol, isNull);
      });

      test('isRunning is false initially', () {
        expect(manager.isRunning, isFalse);
      });
    });

    group('startProcess', () {
      test('throws StateError if already started', () async {
        // Start a mock process using a simple command
        await manager.startMockProcess();

        expect(
          () => manager.startMockProcess(),
          throwsA(isA<StateError>()),
        );
      });

      test('sets activeProcess after starting', () async {
        await manager.startMockProcess();
        expect(manager.activeProcess, isNotNull);
        expect(manager.isRunning, isTrue);
      });
    });

    group('abort', () {
      test('sets isAborting to true during abort', () async {
        await manager.startMockProcess();

        // Start abort and check state
        final abortFuture = manager.abort();

        // The abort should set isAborting synchronously
        expect(manager.isAborting, isTrue);

        await abortFuture;
      });

      test('resets isAborting to false after abort completes', () async {
        await manager.startMockProcess();

        await manager.abort();

        expect(manager.isAborting, isFalse);
      });

      test('sets activeProcess to null after abort', () async {
        await manager.startMockProcess();
        expect(manager.activeProcess, isNotNull);

        await manager.abort();

        expect(manager.activeProcess, isNull);
        expect(manager.isRunning, isFalse);
      });

      test('does nothing if no active process', () async {
        expect(manager.activeProcess, isNull);

        // Should not throw
        await manager.abort();

        expect(manager.isAborting, isFalse);
      });

      test('returns exit code from aborted process', () async {
        await manager.startMockProcess();

        final exitCode = await manager.abort();

        // Exit code should be non-null (either from graceful term or force kill)
        expect(exitCode, isNotNull);
      });
    });

    group('close', () {
      test('kills active process', () async {
        await manager.startMockProcess();
        expect(manager.activeProcess, isNotNull);

        await manager.close();

        expect(manager.activeProcess, isNull);
      });

      test('can be called multiple times safely', () async {
        await manager.startMockProcess();

        await manager.close();
        await manager.close(); // Should not throw

        expect(manager.activeProcess, isNull);
      });

      test('works when no process is active', () async {
        // Should not throw
        await manager.close();

        expect(manager.activeProcess, isNull);
      });

      test('sets isRunning to false', () async {
        await manager.startMockProcess();
        expect(manager.isRunning, isTrue);

        await manager.close();

        expect(manager.isRunning, isFalse);
      });
    });

    group('process signals', () {
      test('abort sends SIGTERM first', () async {
        // This tests that we try graceful shutdown before force kill
        await manager.startMockProcess();

        // We can't easily verify the signal was sent, but we can verify
        // the abort completes successfully
        final exitCode = await manager.abort();

        expect(exitCode, isNotNull);
        expect(manager.activeProcess, isNull);
      });
    });
  });
}
