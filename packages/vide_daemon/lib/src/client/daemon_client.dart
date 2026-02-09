import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../protocol/daemon_events.dart';
import '../protocol/daemon_messages.dart';

/// Client for communicating with the vide daemon.
class DaemonClient {
  final String host;
  final int port;
  final String? authToken;

  final http.Client _httpClient;
  WebSocketChannel? _wsChannel;
  StreamController<DaemonEvent>? _eventController;

  DaemonClient({
    this.host = '127.0.0.1',
    required this.port,
    this.authToken,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  String get _baseUrl => 'http://$host:$port';
  String get _wsUrl => 'ws://$host:$port';

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (authToken != null) 'Authorization': 'Bearer $authToken',
  };

  /// Check if the daemon is running and healthy.
  Future<bool> isHealthy() async {
    try {
      final response = await _httpClient
          .get(Uri.parse('$_baseUrl/health'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Get daemon health information.
  Future<Map<String, dynamic>> getHealth() async {
    final response = await _httpClient.get(
      Uri.parse('$_baseUrl/health'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw DaemonClientException(
        'Health check failed: ${response.statusCode}',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Create a new session.
  Future<CreateSessionResponse> createSession({
    required String initialMessage,
    required String workingDirectory,
    String? model,
    String? permissionMode,
    String? team,
    List<Map<String, dynamic>>? attachments,
  }) async {
    final request = CreateSessionRequest(
      initialMessage: initialMessage,
      workingDirectory: workingDirectory,
      model: model,
      permissionMode: permissionMode,
      team: team,
      attachments: attachments,
    );

    final response = await _httpClient.post(
      Uri.parse('$_baseUrl/sessions'),
      headers: _headers,
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw DaemonClientException(
        'Failed to create session: ${response.statusCode} ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return CreateSessionResponse.fromJson(json);
  }

  /// Resume an existing session from persistence.
  ///
  /// Spawns a new vide_server process and loads the session from disk.
  /// Returns the same [CreateSessionResponse] as [createSession].
  Future<CreateSessionResponse> resumeSession({
    required String sessionId,
    required String workingDirectory,
  }) async {
    final request = ResumeSessionRequest(
      workingDirectory: workingDirectory,
    );

    final response = await _httpClient.post(
      Uri.parse('$_baseUrl/sessions/$sessionId/resume'),
      headers: _headers,
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw DaemonClientException(
        'Failed to resume session: ${response.statusCode} ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return CreateSessionResponse.fromJson(json);
  }

  /// List all sessions.
  Future<List<SessionSummary>> listSessions() async {
    final response = await _httpClient.get(
      Uri.parse('$_baseUrl/sessions'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw DaemonClientException(
        'Failed to list sessions: ${response.statusCode}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final listResponse = ListSessionsResponse.fromJson(json);
    return listResponse.sessions;
  }

  /// Get session details.
  Future<SessionDetailsResponse> getSession(String sessionId) async {
    final response = await _httpClient.get(
      Uri.parse('$_baseUrl/sessions/$sessionId'),
      headers: _headers,
    );

    if (response.statusCode == 404) {
      throw SessionNotFoundException(sessionId);
    }

    if (response.statusCode != 200) {
      throw DaemonClientException(
        'Failed to get session: ${response.statusCode}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return SessionDetailsResponse.fromJson(json);
  }

  /// Stop a session.
  Future<void> stopSession(String sessionId, {bool force = false}) async {
    final url = force
        ? '$_baseUrl/sessions/$sessionId?force=true'
        : '$_baseUrl/sessions/$sessionId';

    final response = await _httpClient.delete(
      Uri.parse(url),
      headers: _headers,
    );

    if (response.statusCode == 404) {
      throw SessionNotFoundException(sessionId);
    }

    if (response.statusCode != 200) {
      throw DaemonClientException(
        'Failed to stop session: ${response.statusCode}',
      );
    }
  }

  /// Connect to daemon WebSocket for real-time events.
  ///
  /// Returns a stream of daemon events.
  Stream<DaemonEvent> connectEvents() {
    if (_eventController != null) {
      return _eventController!.stream;
    }

    _eventController = StreamController<DaemonEvent>.broadcast(
      onCancel: () {
        _wsChannel?.sink.close();
        _wsChannel = null;
        _eventController = null;
      },
    );

    final wsUrl = authToken != null
        ? '$_wsUrl/daemon?token=$authToken'
        : '$_wsUrl/daemon';

    _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));

    _wsChannel!.stream.listen(
      (message) {
        try {
          final json = jsonDecode(message as String) as Map<String, dynamic>;
          final event = DaemonEvent.fromJson(json);
          _eventController?.add(event);
        } catch (e) {
          // Ignore malformed events
        }
      },
      onError: (error) {
        _eventController?.addError(error);
      },
      onDone: () {
        _eventController?.close();
        _eventController = null;
        _wsChannel = null;
      },
    );

    return _eventController!.stream;
  }

  /// Disconnect from daemon WebSocket.
  void disconnectEvents() {
    _wsChannel?.sink.close();
    _wsChannel = null;
    _eventController?.close();
    _eventController = null;
  }

  /// Close the client and release resources.
  void close() {
    disconnectEvents();
    _httpClient.close();
  }
}

/// Exception thrown by the daemon client.
class DaemonClientException implements Exception {
  final String message;

  DaemonClientException(this.message);

  @override
  String toString() => 'DaemonClientException: $message';
}

/// Exception thrown when a session is not found.
class SessionNotFoundException implements Exception {
  final String sessionId;

  SessionNotFoundException(this.sessionId);

  @override
  String toString() => 'Session not found: $sessionId';
}
