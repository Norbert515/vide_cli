import 'dart:async';

import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_client/vide_client.dart'
    show
        createPendingRemoteVideSession,
        createRemoteVideSession,
        AgentAttachment;
import 'package:vide_core/vide_core.dart'
    show videConfigManagerProvider, VideSession;
import 'package:vide_daemon/vide_daemon.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:vide_cli/main.dart' show remoteConfigProvider;

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
  }) {
    return DaemonConnectionState(
      client: client ?? this.client,
      isConnecting: isConnecting ?? this.isConnecting,
      error: error ?? this.error,
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
  String? _authToken;

  DaemonConnectionNotifier(this._ref) : super(const DaemonConnectionState()) {
    _initialize();
  }

  /// Initialize connection based on current settings.
  Future<void> _initialize() async {
    final remoteConfig = _ref.read(remoteConfigProvider);

    final String targetHost;
    final int targetPort;
    String? authToken;

    if (remoteConfig != null) {
      targetHost = remoteConfig.host;
      targetPort = remoteConfig.port;
      authToken = remoteConfig.authToken;
    } else {
      final configManager = _ref.read(videConfigManagerProvider);
      final settings = configManager.readGlobalSettings();
      targetHost = settings.daemonHost;
      targetPort = settings.daemonPort;
    }

    // Check if target changed
    if (state.host == targetHost &&
        state.port == targetPort &&
        state.client != null &&
        state.error == null) {
      return; // Already connected with same target
    }

    await _connect(targetHost, targetPort, authToken: authToken);
  }

  /// Connect to daemon at the given host/port.
  ///
  /// If the daemon is not running and this is a local connection (not via
  /// `vide connect`), attempts to auto-start it.
  ///
  /// [authToken] is used for remote connections (from RemoteConfig).
  /// For local daemons, the token is read from the DaemonInfo file.
  Future<void> _connect(
    String host,
    int port, {
    String? authToken,
  }) async {
    // Clean up existing connection
    _disconnect();

    state = DaemonConnectionState(isConnecting: true, host: host, port: port);

    // Health check doesn't need auth (exempt endpoint)
    final healthClient = DaemonClient(host: host, port: port);

    try {
      var healthy = await healthClient.isHealthy();
      healthClient.close();

      // If not healthy and this is a local daemon (not remote config),
      // attempt to auto-start.
      if (!healthy && _shouldAutoStart()) {
        healthy = await _tryAutoStart(host, port);
      }

      if (!healthy) {
        state = state.copyWith(
          isConnecting: false,
          error: 'Daemon not responding at $host:$port',
        );
        return;
      }

      // For local daemons, read the auth token from the DaemonInfo file.
      final resolvedToken = authToken ?? DaemonInfo.read()?.authToken;
      _authToken = resolvedToken;

      final client = DaemonClient(
        host: host,
        port: port,
        authToken: resolvedToken,
      );

      state = DaemonConnectionState(
        client: client,
        host: state.host,
        port: state.port,
      );
    } catch (e) {
      state = state.copyWith(
        isConnecting: false,
        error: 'Failed to connect to daemon: $e',
      );
    }
  }

  /// Whether auto-start should be attempted.
  ///
  /// Only auto-start for local daemon connections, not when connected to a
  /// remote daemon via `vide connect`.
  bool _shouldAutoStart() {
    final remoteConfig = _ref.read(remoteConfigProvider);
    return remoteConfig == null;
  }

  /// Attempt to auto-start the daemon as a detached background process.
  ///
  /// Returns true if the daemon is now healthy after starting.
  Future<bool> _tryAutoStart(String host, int port) async {
    final lifecycle = DaemonLifecycle();
    try {
      await lifecycle.startDetached(host: host, port: port);
      // startDetached polls health for 15s, so if we get here it's healthy.
      return true;
    } on DaemonAlreadyRunningException {
      // Race condition: daemon started between our check and now.
      // Re-check health.
      final client = DaemonClient(host: host, port: port);
      try {
        return await client.isHealthy();
      } finally {
        client.close();
      }
    } on DaemonStartFailedException {
      return false;
    } catch (_) {
      return false;
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

  /// Create a session on the daemon and return a [VideSession] immediately.
  ///
  /// This returns a "pending" session that can be used right away for navigation.
  /// The actual HTTP call to create the session happens in the background.
  /// Once complete, the session will connect via WebSocket automatically.
  ///
  /// [onReady] is called when the session is ready (HTTP call completed and
  /// WebSocket connection started). Use this to trigger a UI rebuild.
  ///
  /// Throws synchronously if not connected to daemon.
  VideSession createSessionOptimistic({
    required String initialMessage,
    required String workingDirectory,
    String? permissionMode,
    String? team,
    List<AgentAttachment>? attachments,
    void Function()? onReady,
  }) {
    final daemonClient = state.client;
    if (daemonClient == null || !state.isConnected) {
      throw StateError('Not connected to daemon');
    }

    // Create a pending session immediately for instant navigation
    final pendingSession = createPendingRemoteVideSession(
      initialMessage: initialMessage,
      attachments: attachments,
      onReady: onReady,
    );

    // Serialize attachments to raw JSON maps for the daemon protocol.
    final rawAttachments = attachments
        ?.map(
          (a) => <String, dynamic>{
            'type': a.type,
            if (a.path != null) 'file-path': a.path,
            if (a.content != null) 'content': a.content,
            if (a.mimeType != null) 'mime-type': a.mimeType,
          },
        )
        .toList();

    // Do the HTTP call in background
    () async {
      try {
        // Use auth-aware daemon client to create the session.
        final response = await daemonClient.createSession(
          initialMessage: initialMessage,
          workingDirectory: workingDirectory,
          permissionMode: permissionMode,
          team: team,
          attachments: rawAttachments,
        );
        // Complete the pending session with the transport connection
        pendingSession.completeWithConnection(
          sessionId: response.sessionId,
          channel: _createChannel(response.wsUrl),
        );
      } catch (e) {
        pendingSession.fail('Failed to create session: $e');
      }
    }();

    return pendingSession.session;
  }

  /// Create a session on the daemon and return a [VideSession].
  ///
  /// This waits for the HTTP call to complete before returning.
  /// Use [createSessionOptimistic] for instant navigation.
  ///
  /// Throws if not connected to daemon or if session creation fails.
  Future<VideSession> createSession({
    required String initialMessage,
    required String workingDirectory,
    String? permissionMode,
  }) async {
    final daemonClient = state.client;
    if (daemonClient == null || !state.isConnected) {
      throw StateError('Not connected to daemon');
    }

    // Use auth-aware daemon client for creation.
    final response = await daemonClient.createSession(
      initialMessage: initialMessage,
      workingDirectory: workingDirectory,
      permissionMode: permissionMode,
    );
    return createRemoteVideSession(
      sessionId: response.sessionId,
      channel: _createChannel(response.wsUrl),
    );
  }

  /// Connect to an existing daemon session and return a [VideSession]
  /// immediately for optimistic navigation.
  ///
  /// Returns a pending session that can be used right away. The actual
  /// connection (or resume) happens in the background.
  ///
  /// [workingDirectory] is required for resuming historical sessions.
  /// [onReady] is called when the background work completes.
  VideSession connectToSessionOptimistic(
    String sessionId, {
    String? workingDirectory,
    void Function()? onReady,
  }) {
    final daemonClient = state.client;
    if (daemonClient == null || !state.isConnected) {
      throw StateError('Not connected to daemon');
    }

    // Create a pending session immediately for instant navigation.
    // No initial message for resume (unlike create).
    final pendingSession = createPendingRemoteVideSession(onReady: onReady);

    // Do the connect/resume work in background
    () async {
      try {
        String wsUrl;
        try {
          final details = await daemonClient.getSession(sessionId);
          wsUrl = details.wsUrl;
        } on SessionNotFoundException {
          // Session not running on daemon — resume from persistence.
          if (workingDirectory == null) {
            throw StateError(
              'Session $sessionId not found on daemon and no working directory '
              'provided for resume',
            );
          }
          final response = await daemonClient.resumeSession(
            sessionId: sessionId,
            workingDirectory: workingDirectory,
          );
          wsUrl = response.wsUrl;
        }

        pendingSession.completeWithConnection(
          sessionId: sessionId,
          channel: _createChannel(wsUrl),
        );
      } catch (e) {
        pendingSession.fail('Failed to connect to session: $e');
      }
    }();

    return pendingSession.session;
  }

  /// Build an authorized WebSocket channel for the given session URL.
  WebSocketChannel _createChannel(String wsUrl) {
    final rewrittenUri = Uri.parse(_rewriteWsUrlForDaemonHost(wsUrl));
    final authorizedUri = _applySessionStreamAuth(rewrittenUri);
    return WebSocketChannel.connect(authorizedUri);
  }

  String _rewriteWsUrlForDaemonHost(String wsUrl) {
    final configuredHost = state.host;
    if (configuredHost == null || configuredHost.isEmpty) return wsUrl;

    final uri = Uri.parse(wsUrl);
    if (!_isLoopbackHost(uri.host) || _isLoopbackHost(configuredHost)) {
      return wsUrl;
    }

    return uri.replace(host: configuredHost, port: uri.port).toString();
  }

  bool _isLoopbackHost(String host) {
    return host == '127.0.0.1' || host == 'localhost' || host == '::1';
  }

  Uri _applySessionStreamAuth(Uri wsUri) {
    if (_authToken == null) return wsUri;
    // Add auth token as query parameter for WebSocket upgrade requests
    // (browsers can't set Authorization headers on WS upgrades).
    return wsUri.replace(
      queryParameters: {...wsUri.queryParameters, 'token': _authToken!},
    );
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

  /// Stop (delete) a session on the daemon.
  ///
  /// Throws if not connected.
  Future<void> stopSession(String sessionId) async {
    final client = state.client;
    if (client == null || !state.isConnected) {
      throw StateError('Not connected to daemon');
    }

    await client.stopSession(sessionId);
  }

  /// Mark a session as seen by the user.
  ///
  /// Best-effort — does not throw on failure.
  Future<void> markSessionSeen(String sessionId) async {
    final client = state.client;
    if (client == null || !state.isConnected) return;

    try {
      await client.markSessionSeen(sessionId);
    } catch (_) {
      // Best-effort — don't disrupt the user if this fails.
    }
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
    StateNotifierProvider<DaemonConnectionNotifier, DaemonConnectionState>((
      ref,
    ) {
      final notifier = DaemonConnectionNotifier(ref);

      // Watch for remote config changes and reinitialize.
      ref.listen(remoteConfigProvider, (_, __) {
        notifier.reconnect();
      });

      // Watch for settings changes (host/port).
      ref.listen(videConfigManagerProvider, (_, __) {
        notifier.reconnect();
      });

      return notifier;
    });
