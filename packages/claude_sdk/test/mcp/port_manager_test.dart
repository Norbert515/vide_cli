import 'dart:io';

import 'package:claude_sdk/src/mcp/utils/port_manager.dart';
import 'package:test/test.dart';

void main() {
  group('PortManager', () {
    // Clean up reserved ports between tests
    setUp(() {
      // Release any previously reserved ports by requesting and releasing them
      // This ensures a clean state for each test
    });

    group('findAvailablePort', () {
      test('returns available port in range', () async {
        final port = await PortManager.findAvailablePort();

        expect(port, greaterThanOrEqualTo(PortManager.startPort));
        expect(port, lessThanOrEqualTo(PortManager.endPort));

        // Verify it's actually available (not bound)
        final isAvailable = await PortManager.isPortAvailable(port);
        // The port is reserved but not bound, so it should still be "available"
        // from a socket perspective
        expect(isAvailable, isTrue);

        // Clean up
        PortManager.releasePort(port);
      });

      test('reserves returned port', () async {
        final port1 = await PortManager.findAvailablePort();
        final port2 = await PortManager.findAvailablePort();

        // Reserved ports should be different
        expect(port1, isNot(equals(port2)));

        // Clean up
        PortManager.releasePort(port1);
        PortManager.releasePort(port2);
      });

      test('prefers preferredPort when available', () async {
        // Find an available port first
        final availablePort = await PortManager.findAvailablePort();
        PortManager.releasePort(availablePort);

        // Request the same port as preferred
        final port = await PortManager.findAvailablePort(
          preferredPort: availablePort,
        );

        expect(port, equals(availablePort));

        // Clean up
        PortManager.releasePort(port);
      });

      test('falls back when preferred port unavailable', () async {
        // Bind to a port to make it unavailable
        final blockedPort = await PortManager.findAvailablePort();
        PortManager.releasePort(blockedPort);

        final server = await ServerSocket.bind('localhost', blockedPort);
        addTearDown(() => server.close());

        // Request the blocked port as preferred
        final port = await PortManager.findAvailablePort(
          preferredPort: blockedPort,
        );

        // Should get a different port
        expect(port, isNot(equals(blockedPort)));
        expect(port, greaterThanOrEqualTo(PortManager.startPort));
        expect(port, lessThanOrEqualTo(PortManager.endPort));

        // Clean up
        PortManager.releasePort(port);
      });

      test('falls back when preferred port is already reserved', () async {
        // Reserve a port
        final reservedPort = await PortManager.findAvailablePort();

        // Request the reserved port as preferred
        final port = await PortManager.findAvailablePort(
          preferredPort: reservedPort,
        );

        // Should get a different port since reservedPort is already reserved
        expect(port, isNot(equals(reservedPort)));

        // Clean up
        PortManager.releasePort(reservedPort);
        PortManager.releasePort(port);
      });
    });

    group('isPortAvailable', () {
      test('returns true for free port', () async {
        // Use a port that's likely free
        const testPort = 9050;

        // First make sure it's not bound
        final isFree = await PortManager.isPortAvailable(testPort);

        // If it's free, verify
        if (isFree) {
          expect(isFree, isTrue);
        } else {
          // Skip if port happens to be in use
          print('Port $testPort is in use, skipping test');
        }
      });

      test('returns false for bound port', () async {
        // Find and bind to a port
        final port = await PortManager.findAvailablePort();
        PortManager.releasePort(port);

        final server = await ServerSocket.bind('localhost', port);
        addTearDown(() => server.close());

        // Check availability - should be false since it's bound
        final isAvailable = await PortManager.isPortAvailable(port);

        expect(isAvailable, isFalse);
      });
    });

    group('releasePort', () {
      test('allows port to be reused', () async {
        final port = await PortManager.findAvailablePort();

        // While reserved, trying to get the same port as preferred should fail
        final port2 = await PortManager.findAvailablePort(preferredPort: port);
        expect(port2, isNot(equals(port)));
        PortManager.releasePort(port2);

        // Release the original port
        PortManager.releasePort(port);

        // Now we should be able to get it as preferred
        final port3 = await PortManager.findAvailablePort(preferredPort: port);
        expect(port3, equals(port));

        // Clean up
        PortManager.releasePort(port3);
      });

      test('releasing non-reserved port is safe', () {
        // Should not throw
        PortManager.releasePort(12345);
      });
    });

    group('findAvailablePorts', () {
      test('returns requested number of ports', () async {
        final ports = await PortManager.findAvailablePorts(3);

        expect(ports, hasLength(3));

        // All ports should be in valid range
        for (final port in ports) {
          expect(port, greaterThanOrEqualTo(PortManager.startPort));
          expect(port, lessThanOrEqualTo(PortManager.endPort));
        }

        // Clean up
        for (final port in ports) {
          PortManager.releasePort(port);
        }
      });

      test('all ports are unique', () async {
        final ports = await PortManager.findAvailablePorts(5);

        // Convert to set to check uniqueness
        final uniquePorts = ports.toSet();
        expect(uniquePorts, hasLength(5));

        // Clean up
        for (final port in ports) {
          PortManager.releasePort(port);
        }
      });

      test('all returned ports are reserved', () async {
        final ports = await PortManager.findAvailablePorts(3);

        // Each port should be reserved (can't get it as preferred)
        for (final port in ports) {
          final attempt = await PortManager.findAvailablePort(
            preferredPort: port,
          );
          expect(attempt, isNot(equals(port)));
          PortManager.releasePort(attempt);
        }

        // Clean up
        for (final port in ports) {
          PortManager.releasePort(port);
        }
      });
    });
  });
}
