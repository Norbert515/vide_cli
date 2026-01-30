import 'dart:async';
import 'dart:developer' as developer;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/models/session.dart';
import '../local/settings_storage.dart';
import '../models/session_event.dart';
import '../remote/vide_websocket_client.dart';
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
  final Session? session;
  final VideWebSocketClient? wsClient;
  final bool isActive;

  const SessionState({
    this.session,
    this.wsClient,
    this.isActive = false,
  });

  SessionState copyWith({
    Session? session,
    VideWebSocketClient? wsClient,
    bool? isActive,
  }) {
    return SessionState(
      session: session ?? this.session,
      wsClient: wsClient ?? this.wsClient,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// Repository for managing Vide sessions.
@Riverpod(keepAlive: true)
class SessionRepository extends _$SessionRepository {
  void _log(String message) {
    developer.log(message, name: 'SessionRepository');
  }

  @override
  SessionState build() {
    ref.onDispose(() {
      state.wsClient?.dispose();
    });
    return const SessionState();
  }

  /// Creates a new session.
  Future<Session> createSession({
    required String initialMessage,
    required String workingDirectory,
    String? model,
  }) async {
    _log('Creating session with message: $initialMessage');

    final connectionState = ref.read(connectionRepositoryProvider);
    if (!connectionState.isConnected || connectionState.client == null) {
      throw SessionException('Not connected to server');
    }

    final connection = connectionState.connection!;
    final client = connectionState.client!;

    // Close existing session
    close();

    // Create session via REST API
    final response = await client.createSession(
      initialMessage: initialMessage,
      workingDirectory: workingDirectory,
      model: model,
    );

    final session = response.session;
    _log('Session created: ${session.sessionId}');

    // Save working directory
    final settingsStorage = ref.read(settingsStorageProvider.notifier);
    await settingsStorage.saveWorkingDirectory(workingDirectory);

    // Create WebSocket client
    final wsClient = VideWebSocketClient(
      sessionId: session.sessionId,
      host: connection.host,
      port: connection.port,
      isSecure: connection.isSecure,
    );

    // Connect WebSocket
    await wsClient.connect();
    _log('WebSocket connected');

    state = SessionState(
      session: session,
      wsClient: wsClient,
      isActive: true,
    );

    return session;
  }

  /// Stream of session events.
  Stream<SessionEvent> get events {
    return state.wsClient?.events ?? const Stream.empty();
  }

  /// Whether a session is active.
  bool get isActive => state.isActive;

  /// Gets the current session.
  Session? get session => state.session;

  /// Sends a user message.
  void sendMessage(String content, {String? model}) {
    if (state.wsClient == null) {
      throw SessionException('No active session');
    }
    state.wsClient!.sendMessage(content, model: model);
  }

  /// Responds to a permission request.
  void respondToPermission(String requestId, bool allow, {String? message}) {
    if (state.wsClient == null) {
      throw SessionException('No active session');
    }
    state.wsClient!.sendPermissionResponse(requestId, allow, message: message);
  }

  /// Aborts all active agents.
  void abort() {
    if (state.wsClient == null) {
      throw SessionException('No active session');
    }
    state.wsClient!.abort();
  }

  /// Closes the current session.
  void close() {
    _log('Closing session');
    state.wsClient?.dispose();
    state = const SessionState();
  }
}
