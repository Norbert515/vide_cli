import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'events/events.dart';

/// Session lifecycle status.
enum SessionStatus {
  /// Session is active and connected.
  open,

  /// Session terminated normally (by client or server).
  closed,

  /// Session ended due to an error.
  error,
}

/// An active session with the vide_server.
///
/// Provides a stream of typed [VideEvent]s and methods to send messages.
class Session {
  final String id;
  final WebSocketChannel _channel;
  final StreamController<VideEvent> _eventController;
  SessionStatus _status = SessionStatus.open;
  Object? _error;

  Session({required this.id, required WebSocketChannel channel})
    : _channel = channel,
      _eventController = StreamController<VideEvent>.broadcast() {
    _channel.stream.listen(
      (message) {
        final json = jsonDecode(message as String) as Map<String, dynamic>;
        final event = VideEvent.fromJson(json);
        _eventController.add(event);
      },
      onError: (e) {
        _error = e;
        _status = SessionStatus.error;
        _eventController.addError(e);
      },
      onDone: () {
        if (_status == SessionStatus.open) {
          _status = SessionStatus.closed;
        }
        _eventController.close();
      },
    );
  }

  /// Stream of typed events from the server.
  Stream<VideEvent> get events => _eventController.stream;

  /// Current session status.
  SessionStatus get status => _status;

  /// The error that caused the session to end, if [status] is [SessionStatus.error].
  Object? get error => _error;

  /// Send a user message to the agent.
  void sendMessage(String content) {
    _send({'type': 'user-message', 'content': content});
  }

  /// Respond to a permission request.
  void respondToPermission({
    required String requestId,
    required bool allow,
    String? message,
  }) {
    _send({
      'type': 'permission-response',
      'request-id': requestId,
      'allow': allow,
      if (message != null) 'message': message,
    });
  }

  /// Abort all active agents in the session.
  void abort() {
    _send({'type': 'abort'});
  }

  void _send(Map<String, dynamic> message) {
    if (_status != SessionStatus.open) {
      throw StateError('Cannot send message on closed session');
    }
    _channel.sink.add(jsonEncode(message));
  }

  /// Close the session.
  Future<void> close() async {
    if (_status != SessionStatus.open) return;
    _status = SessionStatus.closed;
    await _channel.sink.close();
  }
}
