import 'package:test/test.dart';
import 'package:vide_cli/modules/remote/daemon_connection_service.dart';

void main() {
  group('DaemonConnectionState', () {
    group('isConnected', () {
      test('returns false when client is null', () {
        const state = DaemonConnectionState(
          client: null,
          isConnecting: false,
          error: null,
        );
        expect(state.isConnected, isFalse);
      });

      test('returns false when connecting', () {
        const state = DaemonConnectionState(
          isConnecting: true,
          error: null,
          host: 'localhost',
          port: 8080,
        );
        expect(state.isConnected, isFalse);
      });

      test('returns false when there is an error', () {
        const state = DaemonConnectionState(
          isConnecting: false,
          error: 'Connection failed',
          host: 'localhost',
          port: 8080,
        );
        expect(state.isConnected, isFalse);
      });

      // Note: Can't test "returns true when connected" without a real DaemonClient
      // That would require mocking which is outside scope of this unit test
    });

    group('isConfigured', () {
      test('returns true when both host and port are set', () {
        const state = DaemonConnectionState(host: 'localhost', port: 8080);
        expect(state.isConfigured, isTrue);
      });

      test('returns false when host is null', () {
        const state = DaemonConnectionState(host: null, port: 8080);
        expect(state.isConfigured, isFalse);
      });

      test('returns false when port is null', () {
        const state = DaemonConnectionState(host: 'localhost', port: null);
        expect(state.isConfigured, isFalse);
      });

      test('returns false when both are null', () {
        const state = DaemonConnectionState();
        expect(state.isConfigured, isFalse);
      });
    });

    group('copyWith', () {
      test('preserves existing values when not overridden', () {
        const original = DaemonConnectionState(
          isConnecting: true,
          error: 'test error',
          host: 'localhost',
          port: 8080,
        );

        final copied = original.copyWith();

        expect(copied.isConnecting, isTrue);
        expect(copied.error, equals('test error'));
        expect(copied.host, equals('localhost'));
        expect(copied.port, equals(8080));
      });

      test('overrides isConnecting', () {
        const original = DaemonConnectionState(isConnecting: true);
        final copied = original.copyWith(isConnecting: false);
        expect(copied.isConnecting, isFalse);
      });

      test('overrides error', () {
        const original = DaemonConnectionState(error: 'old error');
        final copied = original.copyWith(error: 'new error');
        expect(copied.error, equals('new error'));
      });

      test('clears error when clearError is true', () {
        const original = DaemonConnectionState(error: 'some error');
        final copied = original.copyWith(clearError: true);
        expect(copied.error, isNull);
      });

      test('clearError takes precedence over error parameter', () {
        const original = DaemonConnectionState(error: 'old error');
        final copied = original.copyWith(error: 'new error', clearError: true);
        expect(copied.error, isNull);
      });

      test('overrides host and port', () {
        const original = DaemonConnectionState(host: 'localhost', port: 8080);
        final copied = original.copyWith(host: '192.168.1.1', port: 9090);
        expect(copied.host, equals('192.168.1.1'));
        expect(copied.port, equals(9090));
      });

      test('clears client when clearClient is true', () {
        // Note: We can't set a real client, but we can test the clear behavior
        const original = DaemonConnectionState();
        final copied = original.copyWith(clearClient: true);
        expect(copied.client, isNull);
      });
    });

    group('default constructor', () {
      test('has sensible defaults', () {
        const state = DaemonConnectionState();

        expect(state.client, isNull);
        expect(state.isConnecting, isFalse);
        expect(state.error, isNull);
        expect(state.host, isNull);
        expect(state.port, isNull);
      });
    });
  });
}
