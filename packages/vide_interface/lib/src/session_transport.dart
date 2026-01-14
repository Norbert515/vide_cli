/// Abstract transport interface for vide session communication.

import 'client_message.dart';
import 'session_event.dart';

/// Connection state of a session transport.
enum ConnectionState {
  /// Attempting to establish connection.
  connecting,

  /// Connection established and active.
  connected,

  /// Connection lost or closed.
  disconnected,

  /// Attempting to re-establish connection.
  reconnecting,
}

/// Abstract interface for session communication transport.
///
/// Implementations handle the underlying protocol (WebSocket, HTTP, etc.)
/// and provide a consistent interface for sending and receiving messages.
abstract class SessionTransport {
  /// The session ID this transport is connected to.
  String get sessionId;

  /// Stream of events received from the server.
  Stream<SessionEvent> get events;

  /// Stream of connection state changes.
  Stream<ConnectionState> get connectionState;

  /// The current connection state.
  ConnectionState get currentState;

  /// Send a message to the server.
  ///
  /// Throws if the transport is not connected.
  void send(ClientMessage message);

  /// Close the transport connection.
  ///
  /// Returns a future that completes when the connection is fully closed.
  Future<void> close();
}
