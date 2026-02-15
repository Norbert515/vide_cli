import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:vide_interface/vide_interface.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'remote_vide_session.dart';

/// Summary of a session from the daemon.
class SessionSummary {
  final String sessionId;
  final String workingDirectory;
  final DateTime createdAt;
  final String state;
  final int connectedClients;
  final int port;

  SessionSummary({
    required this.sessionId,
    required this.workingDirectory,
    required this.createdAt,
    required this.state,
    required this.connectedClients,
    required this.port,
  });

  factory SessionSummary.fromJson(Map<String, dynamic> json) {
    return SessionSummary(
      sessionId: json['session-id'] as String,
      workingDirectory: json['working-directory'] as String,
      createdAt: DateTime.parse(json['created-at'] as String),
      state: json['state'] as String,
      connectedClients: json['connected-clients'] as int,
      port: json['port'] as int,
    );
  }
}

/// Detailed session information from the daemon.
class SessionDetails {
  final String sessionId;
  final String workingDirectory;
  final String wsUrl;
  final String httpUrl;
  final int port;
  final DateTime createdAt;
  final String state;
  final int connectedClients;
  final int pid;

  SessionDetails({
    required this.sessionId,
    required this.workingDirectory,
    required this.wsUrl,
    required this.httpUrl,
    required this.port,
    required this.createdAt,
    required this.state,
    required this.connectedClients,
    required this.pid,
  });

  factory SessionDetails.fromJson(Map<String, dynamic> json) {
    return SessionDetails(
      sessionId: json['session-id'] as String,
      workingDirectory: json['working-directory'] as String,
      wsUrl: json['ws-url'] as String,
      httpUrl: json['http-url'] as String,
      port: json['port'] as int,
      createdAt: DateTime.parse(json['created-at'] as String),
      state: json['state'] as String,
      connectedClients: json['connected-clients'] as int,
      pid: json['pid'] as int,
    );
  }
}

/// Client for connecting to vide daemon.
///
/// ```dart
/// final client = VideClient(port: 8080);
/// await client.checkHealth();
///
/// // List existing sessions
/// final sessions = await client.listSessions();
///
/// // Create a new session
/// final session = await client.createSession(
///   initialMessage: 'Hello',
///   workingDirectory: '/path/to/project',
/// );
///
/// // Listen to accumulated conversation state
/// final agentId = session.state.agents.first.id;
/// session.conversationStream(agentId).listen((agentState) {
///   for (final entry in agentState.messages) {
///     print(entry.text); // Full accumulated text
///   }
/// });
/// ```
class VideClient {
  final String host;
  final int port;

  VideClient({String host = '127.0.0.1', required this.port})
    : host = _cleanHost(host);

  /// Strip protocol prefix and trailing slashes from host.
  static String _cleanHost(String host) {
    var clean = host;
    if (clean.startsWith('http://')) {
      clean = clean.substring(7);
    } else if (clean.startsWith('https://')) {
      clean = clean.substring(8);
    }
    // Strip trailing slashes
    return clean.replaceAll(RegExp(r'/+$'), '');
  }

  String get _httpUrl => 'http://$host:$port';

  /// Check if the daemon is running and healthy.
  ///
  /// Returns true if healthy, false otherwise.
  Future<bool> checkHealth({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      final response = await http
          .get(Uri.parse('$_httpUrl/health'))
          .timeout(timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// List all sessions from the daemon.
  Future<List<SessionSummary>> listSessions() async {
    final response = await http.get(
      Uri.parse('$_httpUrl/sessions'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw VideClientException('Failed to list sessions: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final sessions = data['sessions'] as List<dynamic>;
    return sessions
        .map((s) => SessionSummary.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  /// Get details for a specific session.
  Future<SessionDetails> getSession(String sessionId) async {
    final response = await http.get(
      Uri.parse('$_httpUrl/sessions/$sessionId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 404) {
      throw VideClientException('Session not found: $sessionId');
    }

    if (response.statusCode != 200) {
      throw VideClientException('Failed to get session: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return SessionDetails.fromJson(data);
  }

  /// List available teams from the server.
  ///
  /// Returns a list of team definitions with name, description, and agents.
  Future<List<TeamInfo>> listTeams() async {
    final response = await http.get(
      Uri.parse('$_httpUrl/api/v1/teams'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw VideClientException('Failed to list teams: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final teams = data['teams'] as List<dynamic>;
    return teams
        .map((t) => TeamInfo.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  /// Create a new session with an initial message.
  ///
  /// Returns a [RemoteVideSession] that provides conversation state management,
  /// agent tracking, and a stream of typed events.
  Future<RemoteVideSession> createSession({
    required String initialMessage,
    required String workingDirectory,
    String? permissionMode,
    String? team,
  }) async {
    final info = await createSessionRaw(
      initialMessage: initialMessage,
      workingDirectory: workingDirectory,
      permissionMode: permissionMode,
      team: team,
    );

    final channel = WebSocketChannel.connect(Uri.parse(info.wsUrl));
    return RemoteVideSession.fromConnection(
      sessionId: info.sessionId,
      channel: channel,
    );
  }

  /// Create a new session and return raw connection info.
  ///
  /// Use this with [PendingRemoteVideSession] for optimistic navigation
  /// flows where you need to control the WebSocket connection yourself.
  Future<SessionConnectionInfo> createSessionRaw({
    required String initialMessage,
    required String workingDirectory,
    String? permissionMode,
    String? team,
  }) async {
    final response = await http.post(
      Uri.parse('$_httpUrl/sessions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'initial-message': initialMessage,
        'working-directory': workingDirectory,
        if (permissionMode != null) 'permission-mode': permissionMode,
        if (team != null) 'team': team,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw VideClientException('Failed to create session: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return SessionConnectionInfo(
      sessionId: data['session-id'] as String,
      wsUrl: data['ws-url'] as String,
    );
  }

  /// Connect to an existing session by ID.
  ///
  /// Fetches session details and connects via WebSocket.
  Future<RemoteVideSession> connectToSession(String sessionId) async {
    final details = await getSession(sessionId);
    final channel = WebSocketChannel.connect(Uri.parse(details.wsUrl));
    return RemoteVideSession.fromConnection(
      sessionId: sessionId,
      channel: channel,
    );
  }

  /// Open a WebSocket channel to an existing session.
  ///
  /// Use this with [RemoteVideSession.reconnect] to swap the transport
  /// on an existing session without losing UI state.
  Future<WebSocketChannel> openChannel(String sessionId) async {
    final details = await getSession(sessionId);
    return WebSocketChannel.connect(Uri.parse(details.wsUrl));
  }

  /// Stop a session.
  Future<void> stopSession(String sessionId, {bool force = false}) async {
    final url = force
        ? '$_httpUrl/sessions/$sessionId?force=true'
        : '$_httpUrl/sessions/$sessionId';

    final response = await http.delete(Uri.parse(url));

    if (response.statusCode == 404) {
      throw VideClientException('Session not found: $sessionId');
    }

    if (response.statusCode != 200) {
      throw VideClientException('Failed to stop session: ${response.body}');
    }
  }

  // ==========================================================================
  // Filesystem API
  // ==========================================================================

  /// List directory contents.
  ///
  /// If [parent] is null, lists the server's configured filesystem root.
  Future<List<FileEntry>> listDirectory({String? parent}) async {
    final uri = Uri.parse('$_httpUrl/api/v1/filesystem').replace(
      queryParameters: {
        if (parent != null) 'parent': parent,
      },
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw VideClientException(
        'Failed to list directory: ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final entries = data['entries'] as List<dynamic>;
    return entries
        .map((e) => FileEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ==========================================================================
  // Git API
  // ==========================================================================

  /// Get git status for a repository.
  Future<GitStatusInfo> gitStatus(
    String path, {
    bool detailed = false,
  }) async {
    final uri = Uri.parse('$_httpUrl/api/v1/git/status').replace(
      queryParameters: {
        'path': path,
        if (detailed) 'detailed': 'true',
      },
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw VideClientException('Failed to get git status: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return GitStatusInfo.fromJson(data);
  }

  /// Get git diff output.
  Future<String> gitDiff(
    String path, {
    bool staged = false,
  }) async {
    final uri = Uri.parse('$_httpUrl/api/v1/git/diff').replace(
      queryParameters: {
        'path': path,
        if (staged) 'staged': 'true',
      },
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw VideClientException('Failed to get git diff: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['diff'] as String;
  }
}

/// Information about an available team.
class TeamInfo {
  final String name;
  final String description;
  final String? icon;
  final String mainAgent;
  final List<String> agents;

  TeamInfo({
    required this.name,
    required this.description,
    this.icon,
    required this.mainAgent,
    required this.agents,
  });

  factory TeamInfo.fromJson(Map<String, dynamic> json) {
    return TeamInfo(
      name: json['name'] as String,
      description: json['description'] as String,
      icon: json['icon'] as String?,
      mainAgent: json['main-agent'] as String,
      agents: (json['agents'] as List<dynamic>).cast<String>(),
    );
  }
}

/// Raw connection info returned by [VideClient.createSessionRaw].
class SessionConnectionInfo {
  final String sessionId;
  final String wsUrl;

  SessionConnectionInfo({required this.sessionId, required this.wsUrl});
}

/// Exception thrown by [VideClient] operations.
class VideClientException implements Exception {
  final String message;

  VideClientException(this.message);

  @override
  String toString() => 'VideClientException: $message';
}
