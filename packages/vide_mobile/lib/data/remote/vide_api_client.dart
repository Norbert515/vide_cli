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

/// HTTP client for the Vide REST API.
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
    final protocol = isSecure ? 'https' : 'http';
    return VideApiClient._(
      baseUrl: '$protocol://$host:$port',
      client: client ?? http.Client(),
    );
  }

  void _log(String message) {
    developer.log(message, name: 'VideApiClient');
  }

  /// Performs a health check on the server.
  /// Returns true if the server is healthy.
  Future<bool> healthCheck() async {
    try {
      _log('Performing health check on $baseUrl');
      final response = await _client
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final status = json['status'] as String?;
        _log('Health check result: $status');
        return status == 'ok';
      }
      _log('Health check failed with status: ${response.statusCode}');
      return false;
    } catch (e) {
      _log('Health check error: $e');
      return false;
    }
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
      Uri.parse('$baseUrl/api/v1/sessions'),
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
    );

    return CreateSessionResponse(session: session);
  }

  /// Lists contents of a directory on the server.
  Future<List<DirectoryEntry>> listDirectory(String path) async {
    _log('Listing directory: $path');

    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/filesystem').replace(
        queryParameters: {'path': path},
      ),
    );

    if (response.statusCode != 200) {
      throw VideApiException(
        'Failed to list directory',
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final entries = json['entries'] as List<dynamic>? ?? [];

    return entries
        .map((e) => DirectoryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Validates a path on the server.
  Future<bool> validatePath(String path) async {
    _log('Validating path: $path');

    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/api/v1/filesystem'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'path': path}),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return json['valid'] as bool? ?? false;
      }
      return false;
    } catch (e) {
      _log('Path validation error: $e');
      return false;
    }
  }

  /// Disposes of the HTTP client.
  void dispose() {
    _client.close();
  }
}
