import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'events.dart';

/// Client for connecting to vide_server.
///
/// ```dart
/// final client = VideClient(port: 8080);
/// await client.checkHealth();
///
/// final session = await client.createSession(
///   initialMessage: 'Hello',
///   workingDirectory: '/path/to/project',
/// );
///
/// session.events.listen((event) {
///   switch (event) {
///     case MessageEvent(:final content): print(content);
///     case DoneEvent(): print('Done');
///   }
/// });
/// ```
class VideClient {
  final String host;
  final int port;

  VideClient({this.host = '127.0.0.1', required this.port});

  String get _httpUrl => 'http://$host:$port';
  String get _wsUrl => 'ws://$host:$port';

  /// Check if the server is running and healthy.
  ///
  /// Throws if the server is not reachable or not responding correctly.
  Future<void> checkHealth({Duration timeout = const Duration(seconds: 2)}) async {
    final response = await http
        .get(Uri.parse('$_httpUrl/health'))
        .timeout(timeout);

    if (response.statusCode != 200 || response.body != 'OK') {
      throw VideClientException('Server is not responding correctly');
    }
  }

  /// Create a new session with an initial message.
  ///
  /// Returns a [Session] that provides a stream of typed events and
  /// methods to send messages and close the session.
  Future<Session> createSession({
    required String initialMessage,
    required String workingDirectory,
  }) async {
    final response = await http.post(
      Uri.parse('$_httpUrl/api/v1/sessions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'initial-message': initialMessage,
        'working-directory': workingDirectory,
      }),
    );

    if (response.statusCode != 200) {
      throw VideClientException('Failed to create session: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final sessionId = data['session-id'] as String;

    final wsUrl = '$_wsUrl/api/v1/sessions/$sessionId/stream';
    final channel = WebSocketChannel.connect(Uri.parse(wsUrl));

    return Session._(
      id: sessionId,
      channel: channel,
    );
  }
}

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

  Session._({
    required this.id,
    required WebSocketChannel channel,
  })  : _channel = channel,
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

  /// Send a message to the agent.
  void send(String message) {
    if (_status != SessionStatus.open) {
      throw StateError('Cannot send message on closed session');
    }
    _channel.sink.add(jsonEncode({
      'type': 'user-message',
      'content': message,
    }));
  }

  /// Close the session.
  Future<void> close() async {
    if (_status != SessionStatus.open) return;
    _status = SessionStatus.closed;
    await _channel.sink.close();
  }
}

/// Exception thrown by [VideClient] operations.
class VideClientException implements Exception {
  final String message;

  VideClientException(this.message);

  @override
  String toString() => 'VideClientException: $message';
}
