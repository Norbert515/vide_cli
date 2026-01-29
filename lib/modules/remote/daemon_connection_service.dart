import 'dart:async';

import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_core/vide_core.dart' show videConfigManagerProvider;
import 'package:vide_daemon/vide_daemon.dart';

import 'package:vide_cli/main.dart' show daemonModeEnabledProvider;
import 'package:vide_cli/modules/remote/remote_vide_session.dart';

/// State for daemon connection.
class DaemonConnectionState {
  final DaemonClient? client;
  final bool isConnecting;
  final String? error;
  final String? host;
  final int? port;

  const DaemonConnectionState({
    this.client,
    this.isConnecting = false,
    this.error,
    this.host,
    this.port,
  });

  /// Whether connected and healthy.
  bool get isConnected => client != null && error == null && !isConnecting;

  /// Whether daemon mode is configured (has host/port).
  bool get isConfigured => host != null && port != null;

  DaemonConnectionState copyWith({
    DaemonClient? client,
    bool? isConnecting,
    String? error,
    String? host,
    int? port,
    bool clearClient = false,
    bool clearError = false,
  }) {
    return DaemonConnectionState(
      client: clearClient ? null : (client ?? this.client),
      isConnecting: isConnecting ?? this.isConnecting,
      error: clearError ? null : (error ?? this.error),
      host: host ?? this.host,
      port: port ?? this.port,
    );
  }
}

/// Manages daemon client lifecycle.
///
/// Handles connection, reconnection on settings change, and session creation.
class DaemonConnectionNotifier extends StateNotifier<DaemonConnectionState> {
  final Ref _ref;
  StreamSubscription<DaemonEvent>? _eventSubscription;

  DaemonConnectionNotifier(this._ref) : super(const DaemonConnectionState()) {
    _initialize();
  }

  /// Initialize connection based on current settings.
  Future<void> _initialize() async {
    final daemonEnabled = _ref.read(daemonModeEnabledProvider);
    if (!daemonEnabled) {
      _disconnect();
      return;
    }

    final configManager = _ref.read(videConfigManagerProvider);
    final settings = configManager.readGlobalSettings();

    // Check if settings changed
    if (state.host == settings.daemonHost &&
        state.port == settings.daemonPort &&
        state.client != null &&
        state.error == null) {
      return; // Already connected with same settings
    }

    await _connect(settings.daemonHost, settings.daemonPort);
  }

  /// Connect to daemon at the given host/port.
  Future<void> _connect(String host, int port) async {
    // Clean up existing connection
    _disconnect();

    state = DaemonConnectionState(
      isConnecting: true,
      host: host,
      port: port,
    );

    final client = DaemonClient(host: host, port: port);

    try {
      final healthy = await client.isHealthy();
      if (!healthy) {
        state = state.copyWith(
          isConnecting: false,
          error: 'Daemon not responding at $host:$port',
        );
        return;
      }

      state = state.copyWith(
        client: client,
        isConnecting: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isConnecting: false,
        error: 'Failed to connect to daemon: $e',
      );
    }
  }

  /// Disconnect and clean up.
  void _disconnect() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
    state.client?.close();
    state = const DaemonConnectionState();
  }

  /// Reconnect to daemon (e.g., after settings change or error).
  Future<void> reconnect() async {
    await _initialize();
  }

  /// Create a session on the daemon and return a connected RemoteVideSession.
  ///
  /// Throws if not connected or if session creation fails.
  Future<RemoteVideSession> createSession({
    required String initialMessage,
    required String workingDirectory,
    String permissionMode = 'ask',
  }) async {
    final client = state.client;
    if (client == null || !state.isConnected) {
      throw StateError('Not connected to daemon');
    }

    // Create session on daemon
    final response = await client.createSession(
      initialMessage: initialMessage,
      workingDirectory: workingDirectory,
      permissionMode: permissionMode,
    );

    // Get session details for WebSocket URL
    final details = await client.getSession(response.sessionId);

    // Create and connect the remote session
    final remoteSession = RemoteVideSession(
      sessionId: response.sessionId,
      wsUrl: details.wsUrl,
    );

    await remoteSession.connect();

    return remoteSession;
  }

  /// List sessions from the daemon.
  ///
  /// Returns empty list if not connected.
  Future<List<SessionSummary>> listSessions() async {
    final client = state.client;
    if (client == null || !state.isConnected) {
      return [];
    }

    return await client.listSessions();
  }

  /// Get details for a specific session.
  ///
  /// Throws if not connected.
  Future<SessionDetailsResponse> getSession(String sessionId) async {
    final client = state.client;
    if (client == null || !state.isConnected) {
      throw StateError('Not connected to daemon');
    }

    return await client.getSession(sessionId);
  }

  /// Subscribe to daemon events.
  ///
  /// Returns null if not connected.
  Stream<DaemonEvent>? connectEvents() {
    final client = state.client;
    if (client == null || !state.isConnected) {
      return null;
    }

    return client.connectEvents();
  }

  @override
  void dispose() {
    _disconnect();
    super.dispose();
  }
}

/// Provider for daemon connection management.
///
/// Automatically reinitializes when daemon mode or settings change.
final daemonConnectionProvider =
    StateNotifierProvider<DaemonConnectionNotifier, DaemonConnectionState>(
  (ref) {
    final notifier = DaemonConnectionNotifier(ref);

    // Watch for daemon mode changes and reinitialize
    ref.listen(daemonModeEnabledProvider, (_, __) {
      notifier.reconnect();
    });

    // Watch for settings changes
    ref.listen(videConfigManagerProvider, (_, __) {
      notifier.reconnect();
    });

    return notifier;
  },
);
