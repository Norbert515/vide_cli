import 'package:codex_sdk/codex_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('CodexTransport', () {
    late CodexTransport transport;

    setUp(() {
      transport = CodexTransport();
    });

    tearDown(() async {
      await transport.close();
    });

    group('before start', () {
      test('isRunning returns false', () {
        expect(transport.isRunning, isFalse);
      });

      test('sendRequest throws StateError', () {
        expect(
          () => transport.sendRequest('test'),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'Transport not started',
            ),
          ),
        );
      });

      test('sendNotification throws StateError', () {
        expect(
          () => transport.sendNotification('test'),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'Transport not started',
            ),
          ),
        );
      });

      test('respondToRequest throws StateError', () {
        expect(
          () => transport.respondToRequest(1, {'decision': 'accept'}),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'Transport not started',
            ),
          ),
        );
      });
    });

    group('close', () {
      test('on non-started transport does not throw', () async {
        await transport.close();
      });

      test('is idempotent', () async {
        await transport.close();
        await transport.close();
      });

      test('sets isRunning to false', () async {
        await transport.close();
        expect(transport.isRunning, isFalse);
      });
    });

    group('after close', () {
      setUp(() async {
        await transport.close();
      });

      test('start throws StateError', () {
        expect(
          () => transport.start(),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'Transport has been closed',
            ),
          ),
        );
      });

      test('sendRequest throws StateError', () {
        expect(
          () => transport.sendRequest('test'),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'Transport has been closed',
            ),
          ),
        );
      });

      test('sendNotification throws StateError', () {
        expect(
          () => transport.sendNotification('test'),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'Transport has been closed',
            ),
          ),
        );
      });

      test('respondToRequest throws StateError', () {
        expect(
          () => transport.respondToRequest(1, {}),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'Transport has been closed',
            ),
          ),
        );
      });
    });

    group('logging', () {
      test('accepts log callback', () {
        final logs = <String>[];
        final t = CodexTransport(
          log: (level, component, message) {
            logs.add('[$level] $component: $message');
          },
        );
        expect(t, isNotNull);
      });
    });
  });
}
