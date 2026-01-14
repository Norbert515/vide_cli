import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:vide_interface/vide_interface.dart';

import 'websocket_transport.dart';

/// High-level client for interacting with a vide server.
///
/// Provides methods to create sessions, list sessions, and connect to
/// existing sessions via WebSocket.
///
/// ## Usage
///
/// ```dart
/// final client = VideClient(Uri.parse('http://localhost:8080'));
///
/// // Create a new session
/// final sessionInfo = await client.createSession(
///   initialMessage: 'Hello!',
///   workingDirectory: '/path/to/project',
/// );
///
/// // Connect to the session
/// final transport = await client.connect(sessionInfo.sessionId);
///
/// // Use the transport to send/receive messages
/// transport.events.listen((event) => print(event));
/// transport.send(SendUserMessage(content: 'Do something'));
/// ```
class VideClient {
  /// Creates a new vide client.
  ///
  /// The [serverUri] should be the base HTTP URL of the server
  /// (e.g., `http://localhost:8080`).
  VideClient(this.serverUri, {http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// The base URI of the vide server.
  final Uri serverUri;

  final http.Client _httpClient;

  String get _httpUrl => serverUri.toString().replaceAll(RegExp(r'/$'), '');

  String get _wsUrl {
    final scheme = serverUri.scheme == 'https' ? 'wss' : 'ws';
    return '$scheme://${serverUri.host}:${serverUri.port}';
  }

  /// Check if the server is healthy.
  ///
  /// Returns `true` if the server responds correctly, `false` otherwise.
  Future<bool> checkHealth({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      final response = await _httpClient
          .get(Uri.parse('$_httpUrl/health'))
          .timeout(timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Create a new session on the server.
  ///
  /// Returns a [SessionInfo] with the session ID and other metadata.
  ///
  /// The [initialMessage] is the first user message to start the conversation.
  /// The [workingDirectory] is the directory the agent will work in.
  /// The optional [model] specifies which model to use (e.g., 'sonnet', 'opus').
  Future<SessionInfo> createSession({
    required String initialMessage,
    required String workingDirectory,
    String? model,
  }) async {
    final body = <String, dynamic>{
      'initial-message': initialMessage,
      'working-directory': workingDirectory,
    };
    if (model != null) {
      body['model'] = model;
    }

    final response = await _httpClient.post(
      Uri.parse('$_httpUrl/api/v1/sessions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw VideClientException(
        'Failed to create session: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return SessionInfo.fromJson(data);
  }

  /// Connect to an existing session via WebSocket.
  ///
  /// Returns a [WebSocketSessionTransport] that can be used to send/receive
  /// messages. The transport is connected and ready to use when returned.
  Future<WebSocketSessionTransport> connect(String sessionId) async {
    final wsUrl = '$_wsUrl/api/v1/sessions/$sessionId/stream';
    final transport = WebSocketSessionTransport(
      uri: Uri.parse(wsUrl),
      sessionId: sessionId,
    );

    await transport.connect();
    return transport;
  }

  /// List all available sessions on the server.
  ///
  /// Note: This endpoint may not be available on all server versions.
  Future<List<SessionInfo>> listSessions() async {
    final response = await _httpClient.get(
      Uri.parse('$_httpUrl/api/v1/sessions'),
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode == 404) {
      // Endpoint not implemented
      return [];
    }

    if (response.statusCode != 200) {
      throw VideClientException(
        'Failed to list sessions: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => SessionInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Close the client and release resources.
  void close() {
    _httpClient.close();
  }
}

/// Exception thrown by [VideClient] operations.
class VideClientException implements Exception {
  final String message;

  VideClientException(this.message);

  @override
  String toString() => 'VideClientException: $message';
}
