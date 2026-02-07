import 'dart:async';
import 'dart:developer' as developer;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vide_client/vide_client.dart';

import '../../core/providers/connection_state_provider.dart';
import '../../domain/services/network_monitor_service.dart';
import '../../domain/services/reconnection_service.dart';
import '../local/settings_storage.dart';
import 'connection_repository.dart';

part 'session_repository.g.dart';

/// Exception thrown when session operations fail.
class SessionException implements Exception {
  final String message;
  final Object? cause;

  SessionException(this.message, {this.cause});

  @override
  String toString() => 'SessionException: $message';
}

/// State for the session repository.
class SessionState {
  final RemoteVideSession? session;
  final bool isActive;
  final int lastSeq;

  const SessionState({
    this.session,
    this.isActive = false,
    this.lastSeq = 0,
  });

  SessionState copyWith({
    RemoteVideSession? session,
    bool? isActive,
    int? lastSeq,
  }) {
    return SessionState(
      session: session ?? this.session,
      isActive: isActive ?? this.isActive,
      lastSeq: lastSeq ?? this.lastSeq,
    );
  }
}

/// Repository for managing Vide sessions with reconnection support.
@Riverpod(keepAlive: true)
class SessionRepository extends _$SessionRepository {
  final _reconnectionService = ReconnectionService();
  StreamSubscription<VideEvent>? _eventSubscription;
  StreamSubscription<bool>? _connectionStateSubscription;
  NetworkStatus? _lastNetworkStatus;

  void _log(String message) {
    developer.log(message, name: 'SessionRepository');
  }

  @override
  SessionState build() {
    ref.onDispose(() {
      _eventSubscription?.cancel();
      _connectionStateSubscription?.cancel();
      _reconnectionService.dispose();
      state.session?.dispose();
    });

    // Listen for network changes
    ref.listen(networkMonitorProvider, (previous, next) {
      // Check if network came back online
      if (_lastNetworkStatus == NetworkStatus.offline &&
          next == NetworkStatus.online &&
          state.session != null &&
          !state.isActive) {
        _log('Network came back online, attempting reconnect');
        _attemptReconnect();
      }
      _lastNetworkStatus = next;
    });

    return const SessionState();
  }

  /// Creates a new session.
  Future<RemoteVideSession> createSession({
    required String initialMessage,
    required String workingDirectory,
    String? model,
    String? team,
  }) async {
    _log('Creating session with message: $initialMessage');

    final connectionState = ref.read(connectionRepositoryProvider);
    if (!connectionState.isConnected || connectionState.connection == null) {
      throw SessionException('Not connected to server');
    }

    final connection = connectionState.connection!;

    // Close existing session
    close();

    // Update connection state to connecting
    ref.read(webSocketConnectionProvider.notifier).setConnecting();

    // Create vide_client instance
    final videClient = VideClient(
      host: connection.host,
      port: connection.port,
    );

    // Create session via vide_client (handles both REST and WebSocket)
    final clientSession = await videClient.createSession(
      initialMessage: initialMessage,
      workingDirectory: workingDirectory,
      model: model,
      team: team,
    );

    _log('Session created: ${clientSession.id}');

    // Save working directory
    final settingsStorage = ref.read(settingsStorageProvider.notifier);
    await settingsStorage.saveWorkingDirectory(workingDirectory);

    // Create RemoteVideSession — the single owner of all session state
    final remoteSession = RemoteVideSession.fromClientSession(clientSession);

    // Set up event listening with disconnect handling
    _setupEventListening(remoteSession);

    state = SessionState(
      session: remoteSession,
      isActive: true,
    );

    return remoteSession;
  }

  /// Connects to an existing session by ID.
  ///
  /// Always creates a fresh WebSocket connection, even if already connected
  /// to the same session. This ensures the caller receives ConnectedEvent +
  /// HistoryEvent through the streams (important when the chat screen
  /// subscribes after session creation).
  Future<RemoteVideSession> connectToExistingSession(
      String sessionId) async {
    _log('Connecting to existing session: $sessionId');

    final connectionState = ref.read(connectionRepositoryProvider);
    if (!connectionState.isConnected || connectionState.connection == null) {
      throw SessionException('Not connected to server');
    }

    final connection = connectionState.connection!;

    // Close existing session (same or different)
    close();

    // Update connection state to connecting
    ref.read(webSocketConnectionProvider.notifier).setConnecting();

    // Create vide_client instance
    final videClient = VideClient(
      host: connection.host,
      port: connection.port,
    );

    // Connect to existing session via WebSocket
    final clientSession = await videClient.connectToSession(sessionId);

    _log('Connected to session: $sessionId');

    // Create RemoteVideSession — the single owner of all session state
    final remoteSession = RemoteVideSession.fromClientSession(clientSession);

    // Set up event listening with disconnect handling
    _setupEventListening(remoteSession);

    state = SessionState(
      session: remoteSession,
      isActive: true,
    );

    return remoteSession;
  }

  void _setupEventListening(RemoteVideSession remoteSession) {
    _eventSubscription?.cancel();
    _connectionStateSubscription?.cancel();

    // Listen to connection state changes from RemoteVideSession.
    // ConnectedEvent is consumed internally by RemoteVideSession and not
    // forwarded to the public events stream, so we use connectionStateStream.
    _connectionStateSubscription = remoteSession.connectionStateStream.listen(
      (connected) {
        if (connected) {
          _reconnectionService.reset();
          ref.read(webSocketConnectionProvider.notifier).setConnected();
        } else {
          _handleDisconnect('Connection lost');
        }
      },
    );

    _eventSubscription = remoteSession.events.listen(
      (event) {
        // Update lastSeq for deduplication
        final seq = event.seq ?? 0;
        if (seq > state.lastSeq) {
          state = state.copyWith(lastSeq: seq);
          ref.read(webSocketConnectionProvider.notifier).updateLastSeq(seq);
        }
      },
      onError: (e) {
        _log('WebSocket error: $e');
        _handleDisconnect(e.toString());
      },
      onDone: () {
        _log('WebSocket closed');
        if (state.isActive) {
          _handleDisconnect('Connection closed');
        }
      },
    );
  }

  void _handleDisconnect(String reason) {
    _log('Handling disconnect: $reason');

    state = state.copyWith(isActive: false);

    // Check network status
    final networkStatus = ref.read(networkMonitorProvider);
    if (networkStatus == NetworkStatus.offline) {
      _log('Network is offline, waiting for network');
      ref.read(webSocketConnectionProvider.notifier).setDisconnected(
            errorMessage: 'No internet connection',
          );
      return;
    }

    // Attempt reconnect
    _attemptReconnect();
  }

  void _attemptReconnect() {
    if (_reconnectionService.hasExceededMaxRetries) {
      _log('Max retries exceeded');
      ref.read(webSocketConnectionProvider.notifier).setFailed(
            errorMessage:
                'Unable to reconnect after ${_reconnectionService.maxRetries} attempts',
          );
      return;
    }

    ref.read(webSocketConnectionProvider.notifier).setReconnecting(
          retryCount: _reconnectionService.retryCount + 1,
          maxRetries: _reconnectionService.maxRetries,
        );

    _log('Scheduling reconnect attempt ${_reconnectionService.retryCount + 1}');

    _reconnectionService.scheduleReconnect(
      onReconnect: () async {
        await _reconnect();
      },
    )?.catchError((e) {
      _log('Reconnect attempt failed: $e');
      _attemptReconnect();
    });
  }

  Future<void> _reconnect() async {
    final currentSession = state.session;
    if (currentSession == null) {
      _log('No session to reconnect to');
      return;
    }

    _log('Attempting to reconnect to session ${currentSession.id}');

    final connectionState = ref.read(connectionRepositoryProvider);
    if (!connectionState.isConnected || connectionState.connection == null) {
      throw SessionException('Not connected to server');
    }

    final connection = connectionState.connection!;

    // Create vide_client instance
    final videClient = VideClient(
      host: connection.host,
      port: connection.port,
    );

    // Connect to existing session
    final clientSession =
        await videClient.connectToSession(currentSession.id);

    // Create fresh RemoteVideSession
    final remoteSession =
        RemoteVideSession.fromClientSession(clientSession);

    // Set up event listening
    _setupEventListening(remoteSession);

    state = state.copyWith(
      session: remoteSession,
      isActive: true,
    );

    _log('Reconnected to session ${currentSession.id}');
  }

  /// Manually trigger a reconnection attempt (e.g., after max retries exceeded).
  Future<void> manualReconnect() async {
    _reconnectionService.reset();
    ref.read(webSocketConnectionProvider.notifier).setConnecting();
    await _reconnect();
  }

  /// Whether a session is active.
  bool get isActive => state.isActive;

  /// Gets the current RemoteVideSession.
  RemoteVideSession? get session => state.session;

  /// Sends a user message.
  void sendMessage(String content, {String? model}) {
    final session = state.session;
    if (session == null || !state.isActive) {
      throw SessionException('No active session');
    }
    session.sendMessage(VideMessage(text: content));
  }

  /// Responds to a permission request.
  void respondToPermission(
    String requestId,
    bool allow, {
    String? message,
    bool remember = false,
  }) {
    final session = state.session;
    if (session == null || !state.isActive) {
      throw SessionException('No active session');
    }
    session.respondToPermission(
      requestId,
      allow: allow,
      message: message,
      remember: remember,
    );
  }

  /// Aborts all active agents.
  void abort() {
    final session = state.session;
    if (session == null || !state.isActive) {
      throw SessionException('No active session');
    }
    session.abort();
  }

  /// Closes the current session.
  void close() {
    _log('Closing session');
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;
    _reconnectionService.cancel();
    state.session?.dispose();
    ref.read(webSocketConnectionProvider.notifier).reset();
    state = const SessionState();
  }
}
