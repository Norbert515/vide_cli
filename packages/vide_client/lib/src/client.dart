import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'session.dart';

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
  Future<void> checkHealth({
    Duration timeout = const Duration(seconds: 2),
  }) async {
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
    String? model,
  }) async {
    final response = await http.post(
      Uri.parse('$_httpUrl/api/v1/sessions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'initial-message': initialMessage,
        'working-directory': workingDirectory,
        if (model != null) 'model': model,
      }),
    );

    if (response.statusCode != 200) {
      throw VideClientException('Failed to create session: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final sessionId = data['session-id'] as String;

    final wsUrl = '$_wsUrl/api/v1/sessions/$sessionId/stream';
    final channel = WebSocketChannel.connect(Uri.parse(wsUrl));

    return Session(id: sessionId, channel: channel);
  }
}

/// Exception thrown by [VideClient] operations.
class VideClientException implements Exception {
  final String message;

  VideClientException(this.message);

  @override
  String toString() => 'VideClientException: $message';
}
