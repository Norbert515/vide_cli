import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connection_state_provider.freezed.dart';
part 'connection_state_provider.g.dart';

/// Status of the WebSocket connection to the server.
enum WebSocketConnectionStatus {
  /// WebSocket is open and ready.
  connected,

  /// Attempting initial connection.
  connecting,

  /// Lost connection, attempting to reconnect.
  reconnecting,

  /// No connection, not retrying.
  disconnected,

  /// Max retries exceeded, user must manually retry.
  failed,
}

/// State for the WebSocket connection.
@freezed
class WebSocketConnectionState with _$WebSocketConnectionState {
  const factory WebSocketConnectionState({
    @Default(WebSocketConnectionStatus.disconnected)
    WebSocketConnectionStatus status,
    @Default(0) int retryCount,
    @Default(5) int maxRetries,
    @Default(0) int lastSeq,
    String? errorMessage,
    DateTime? lastConnectedAt,
    DateTime? lastDisconnectedAt,
  }) = _WebSocketConnectionState;
}

/// Provider for managing WebSocket connection state.
@Riverpod(keepAlive: true)
class WebSocketConnection extends _$WebSocketConnection {
  @override
  WebSocketConnectionState build() {
    return const WebSocketConnectionState();
  }

  /// Sets the connection status to connecting (initial connection).
  void setConnecting() {
    state = state.copyWith(
      status: WebSocketConnectionStatus.connecting,
      errorMessage: null,
    );
  }

  /// Sets the connection status to connected.
  void setConnected({int? lastSeq}) {
    state = state.copyWith(
      status: WebSocketConnectionStatus.connected,
      retryCount: 0,
      lastSeq: lastSeq ?? state.lastSeq,
      lastConnectedAt: DateTime.now(),
      errorMessage: null,
    );
  }

  /// Sets the connection status to reconnecting.
  void setReconnecting({required int retryCount, required int maxRetries}) {
    state = state.copyWith(
      status: WebSocketConnectionStatus.reconnecting,
      retryCount: retryCount,
      maxRetries: maxRetries,
      lastDisconnectedAt: DateTime.now(),
    );
  }

  /// Sets the connection status to disconnected.
  void setDisconnected({String? errorMessage}) {
    state = state.copyWith(
      status: WebSocketConnectionStatus.disconnected,
      lastDisconnectedAt: DateTime.now(),
      errorMessage: errorMessage,
    );
  }

  /// Sets the connection status to failed (max retries exceeded).
  void setFailed({String? errorMessage}) {
    state = state.copyWith(
      status: WebSocketConnectionStatus.failed,
      errorMessage: errorMessage ?? 'Max retries exceeded',
    );
  }

  /// Updates the last sequence number received.
  void updateLastSeq(int seq) {
    state = state.copyWith(lastSeq: seq);
  }

  /// Resets the connection state.
  void reset() {
    state = const WebSocketConnectionState();
  }
}
