/// Configuration for connecting to a remote vide daemon.
class RemoteConfig {
  /// Host address of the daemon.
  final String host;

  /// Port number of the daemon.
  final int port;

  /// Specific session ID to connect to (optional).
  /// If null, will show session picker or create new session.
  final String? sessionId;

  /// Authentication token for the daemon (optional).
  final String? authToken;

  RemoteConfig({
    required this.host,
    required this.port,
    this.sessionId,
    this.authToken,
  });

  /// Get the daemon base URL.
  String get daemonUrl => 'http://$host:$port';

  /// Get the daemon WebSocket URL.
  String get daemonWsUrl => 'ws://$host:$port/daemon';

  @override
  String toString() => 'RemoteConfig($host:$port, session: $sessionId)';
}
