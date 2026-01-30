import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import '../../domain/models/session.dart';

/// Exception thrown when API calls fail.
class VideApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? body;

  VideApiException(this.message, {this.statusCode, this.body});

  @override
  String toString() {
    if (statusCode != null) {
      return 'VideApiException: $message (status: $statusCode)';
    }
    return 'VideApiException: $message';
  }
}

/// Response from creating a session.
class CreateSessionResponse {
  final Session session;

  CreateSessionResponse({required this.session});
}

/// Directory entry from filesystem listing.
class DirectoryEntry {
  final String name;
  final String path;
  final bool isDirectory;

  DirectoryEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
  });

  factory DirectoryEntry.fromJson(Map<String, dynamic> json) {
    return DirectoryEntry(
      name: json['name'] as String,
      path: json['path'] as String,
      isDirectory: json['is-directory'] as bool? ?? json['isDirectory'] as bool? ?? false,
    );
  }
}

/// Summary of a session from the daemon.
class SessionSummary {
  final String sessionId;
  final String workingDirectory;
  final String? goal;
  final DateTime createdAt;
  final DateTime? lastActiveAt;
  final int agentCount;
  final String state;
  final int connectedClients;
  final int port;

  SessionSummary({
    required this.sessionId,
    required this.workingDirectory,
    this.goal,
    required this.createdAt,
    this.lastActiveAt,
    required this.agentCount,
    required this.state,
    required this.connectedClients,
    required this.port,
  });

  factory SessionSummary.fromJson(Map<String, dynamic> json) {
    return SessionSummary(
      sessionId: json['session-id'] as String,
      workingDirectory: json['working-directory'] as String,
      goal: json['goal'] as String?,
      createdAt: DateTime.parse(json['created-at'] as String),
      lastActiveAt: json['last-active-at'] != null
          ? DateTime.parse(json['last-active-at'] as String)
          : null,
      agentCount: json['agent-count'] as int,
      state: json['state'] as String,
      connectedClients: json['connected-clients'] as int,
      port: json['port'] as int,
    );
  }
}

/// HTTP client for the Vide daemon REST API.
class VideApiClient {
  final String baseUrl;
  final http.Client _client;

  VideApiClient._({
    required this.baseUrl,
    required http.Client client,
  }) : _client = client;

  /// Creates a new API client.
  factory VideApiClient({
    required String host,
    required int port,
    bool isSecure = false,
    http.Client? client,
  }) {
    // Strip protocol prefix if user accidentally included it
    var cleanHost = host;
    if (cleanHost.startsWith('http://')) {
      cleanHost = cleanHost.substring(7);
    } else if (cleanHost.startsWith('https://')) {
      cleanHost = cleanHost.substring(8);
    }
    // Strip trailing slashes
    cleanHost = cleanHost.replaceAll(RegExp(r'/+$'), '');

    final protocol = isSecure ? 'https' : 'http';
    return VideApiClient._(
      baseUrl: '$protocol://$cleanHost:$port',
      client: client ?? http.Client(),
    );
  }

  void _log(String message) {
    developer.log(message, name: 'VideApiClient');
  }

  /// Performs a health check on the daemon.
  /// Returns true if the daemon is healthy.
  Future<bool> healthCheck() async {
    try {
      _log('Performing health check on $baseUrl');
      final response = await _client
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));

      _log('Health check response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      _log('Health check error: $e');
      rethrow;
    }
  }

  /// Lists all sessions from the daemon.
  Future<List<SessionSummary>> listSessions() async {
    _log('Listing sessions');

    final response = await _client.get(
      Uri.parse('$baseUrl/sessions'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw VideApiException(
        'Failed to list sessions',
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final sessions = json['sessions'] as List<dynamic>;
    _log('Found ${sessions.length} sessions');

    return sessions
        .map((s) => SessionSummary.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  /// Get details for a specific session.
  Future<Map<String, dynamic>> getSession(String sessionId) async {
    _log('Getting session: $sessionId');

    final response = await _client.get(
      Uri.parse('$baseUrl/sessions/$sessionId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 404) {
      throw VideApiException(
        'Session not found',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode != 200) {
      throw VideApiException(
        'Failed to get session',
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Creates a new session.
  Future<CreateSessionResponse> createSession({
    required String initialMessage,
    required String workingDirectory,
    String? model,
    String? permissionMode,
  }) async {
    _log('Creating session with message: $initialMessage');

    final body = <String, dynamic>{
      'initial-message': initialMessage,
      'working-directory': workingDirectory,
    };

    if (model != null) {
      body['model'] = model;
    }
    if (permissionMode != null) {
      body['permission-mode'] = permissionMode;
    }

    final response = await _client.post(
      Uri.parse('$baseUrl/sessions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw VideApiException(
        'Failed to create session',
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    _log('Session created: ${json['session-id']}');

    // Parse the response and create a Session object
    final session = Session(
      sessionId: json['session-id'] as String,
      mainAgentId: json['main-agent-id'] as String,
      createdAt: DateTime.parse(json['created-at'] as String),
      workingDirectory: workingDirectory,
      model: model,
      wsUrl: json['ws-url'] as String?,
    );

    return CreateSessionResponse(session: session);
  }

  /// Stop a session.
  Future<void> stopSession(String sessionId, {bool force = false}) async {
    _log('Stopping session: $sessionId');

    final url = force
        ? '$baseUrl/sessions/$sessionId?force=true'
        : '$baseUrl/sessions/$sessionId';

    final response = await _client.delete(Uri.parse(url));

    if (response.statusCode == 404) {
      throw VideApiException('Session not found', statusCode: 404);
    }

    if (response.statusCode != 200) {
      throw VideApiException(
        'Failed to stop session',
        statusCode: response.statusCode,
        body: response.body,
      );
    }
  }

  /// Disposes of the HTTP client.
  void dispose() {
    _client.close();
  }
}
