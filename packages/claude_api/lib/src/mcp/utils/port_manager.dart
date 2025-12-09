import 'dart:io';
import 'dart:math';

/// Manages automatic port allocation for MCP servers
class PortManager {
  static const int startPort = 8080;
  static const int endPort = 9100;

  /// Tracks ports that have been allocated but not yet bound by a server.
  /// This prevents race conditions when multiple agents start simultaneously.
  static final Set<int> _reservedPorts = {};

  /// Release a reserved port after the server has successfully bound to it,
  /// or if the server failed to start.
  static void releasePort(int port) {
    _reservedPorts.remove(port);
  }

  /// Find an available port, preferring the given port if specified.
  /// The returned port is reserved until [releasePort] is called.
  static Future<int> findAvailablePort({int? preferredPort}) async {
    // Try preferred port first
    if (preferredPort != null) {
      if (!_reservedPorts.contains(preferredPort) && await isPortAvailable(preferredPort)) {
        _reservedPorts.add(preferredPort);
        return preferredPort;
      }
    }

    // Find random available port
    final random = Random();
    for (int attempts = 0; attempts < 50; attempts++) {
      final port = startPort + random.nextInt(endPort - startPort);
      if (!_reservedPorts.contains(port) && await isPortAvailable(port)) {
        _reservedPorts.add(port);
        return port;
      }
    }

    // Fallback: sequential search
    for (int port = startPort; port <= endPort; port++) {
      if (!_reservedPorts.contains(port) && await isPortAvailable(port)) {
        _reservedPorts.add(port);
        return port;
      }
    }

    throw StateError('No available ports found in range $startPort-$endPort');
  }

  /// Check if a specific port is available
  static Future<bool> isPortAvailable(int port) async {
    try {
      final server = await ServerSocket.bind('localhost', port);
      await server.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Find multiple available ports
  static Future<List<int>> findAvailablePorts(int count) async {
    final ports = <int>[];
    final usedPorts = <int>{};

    for (int i = 0; i < count; i++) {
      int attempts = 0;
      while (attempts < 100) {
        final port = await findAvailablePort();
        if (!usedPorts.contains(port)) {
          ports.add(port);
          usedPorts.add(port);
          break;
        }
        attempts++;
      }
    }

    if (ports.length < count) {
      throw StateError('Could not find $count available ports');
    }

    return ports;
  }
}
