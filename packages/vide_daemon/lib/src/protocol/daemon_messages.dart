import 'package:json_annotation/json_annotation.dart';

part 'daemon_messages.g.dart';

/// State of a session process.
enum SessionProcessState {
  /// Process spawned, waiting for ready.
  @JsonValue('starting')
  starting,

  /// Health check passed, accepting connections.
  @JsonValue('ready')
  ready,

  /// Process crashed or health check failed.
  @JsonValue('error')
  error,

  /// Graceful shutdown in progress.
  @JsonValue('stopping')
  stopping,
}

/// Request to create a new session.
@JsonSerializable()
class CreateSessionRequest {
  @JsonKey(name: 'initial-message')
  final String initialMessage;

  @JsonKey(name: 'working-directory')
  final String workingDirectory;

  final String? model;

  @JsonKey(name: 'permission-mode')
  final String? permissionMode;

  final String? team;

  CreateSessionRequest({
    required this.initialMessage,
    required this.workingDirectory,
    this.model,
    this.permissionMode,
    this.team,
  });

  factory CreateSessionRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateSessionRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CreateSessionRequestToJson(this);
}

/// Response after creating a session.
@JsonSerializable()
class CreateSessionResponse {
  @JsonKey(name: 'session-id')
  final String sessionId;

  @JsonKey(name: 'main-agent-id')
  final String mainAgentId;

  @JsonKey(name: 'ws-url')
  final String wsUrl;

  @JsonKey(name: 'http-url')
  final String httpUrl;

  final int port;

  @JsonKey(name: 'created-at')
  final DateTime createdAt;

  CreateSessionResponse({
    required this.sessionId,
    required this.mainAgentId,
    required this.wsUrl,
    required this.httpUrl,
    required this.port,
    required this.createdAt,
  });

  factory CreateSessionResponse.fromJson(Map<String, dynamic> json) =>
      _$CreateSessionResponseFromJson(json);

  Map<String, dynamic> toJson() => _$CreateSessionResponseToJson(this);
}

/// Summary of a session for listing.
@JsonSerializable()
class SessionSummary {
  @JsonKey(name: 'session-id')
  final String sessionId;

  @JsonKey(name: 'working-directory')
  final String workingDirectory;

  @JsonKey(name: 'created-at')
  final DateTime createdAt;

  final SessionProcessState state;

  @JsonKey(name: 'connected-clients')
  final int connectedClients;

  final int port;

  /// Overall goal/task name for the session.
  final String? goal;

  /// When the session was last active.
  @JsonKey(name: 'last-active-at')
  final DateTime? lastActiveAt;

  /// Number of agents in the session.
  @JsonKey(name: 'agent-count')
  final int agentCount;

  SessionSummary({
    required this.sessionId,
    required this.workingDirectory,
    required this.createdAt,
    required this.state,
    required this.connectedClients,
    required this.port,
    this.goal,
    this.lastActiveAt,
    this.agentCount = 0,
  });

  factory SessionSummary.fromJson(Map<String, dynamic> json) =>
      _$SessionSummaryFromJson(json);

  Map<String, dynamic> toJson() => _$SessionSummaryToJson(this);
}

/// Response containing list of sessions.
@JsonSerializable()
class ListSessionsResponse {
  final List<SessionSummary> sessions;

  ListSessionsResponse({required this.sessions});

  factory ListSessionsResponse.fromJson(Map<String, dynamic> json) =>
      _$ListSessionsResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ListSessionsResponseToJson(this);
}

/// Detailed information about a session.
@JsonSerializable()
class SessionDetailsResponse {
  @JsonKey(name: 'session-id')
  final String sessionId;

  @JsonKey(name: 'working-directory')
  final String workingDirectory;

  @JsonKey(name: 'ws-url')
  final String wsUrl;

  @JsonKey(name: 'http-url')
  final String httpUrl;

  final int port;

  @JsonKey(name: 'created-at')
  final DateTime createdAt;

  final SessionProcessState state;

  @JsonKey(name: 'connected-clients')
  final int connectedClients;

  final int pid;

  SessionDetailsResponse({
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

  factory SessionDetailsResponse.fromJson(Map<String, dynamic> json) =>
      _$SessionDetailsResponseFromJson(json);

  Map<String, dynamic> toJson() => _$SessionDetailsResponseToJson(this);
}

/// Persisted state of a session for daemon restart recovery.
@JsonSerializable()
class PersistedSessionState {
  @JsonKey(name: 'session-id')
  final String sessionId;

  final int port;

  @JsonKey(name: 'working-directory')
  final String workingDirectory;

  @JsonKey(name: 'created-at')
  final DateTime createdAt;

  final int pid;

  @JsonKey(name: 'initial-message')
  final String initialMessage;

  final String? model;

  @JsonKey(name: 'permission-mode')
  final String? permissionMode;

  final String? team;

  PersistedSessionState({
    required this.sessionId,
    required this.port,
    required this.workingDirectory,
    required this.createdAt,
    required this.pid,
    required this.initialMessage,
    this.model,
    this.permissionMode,
    this.team,
  });

  factory PersistedSessionState.fromJson(Map<String, dynamic> json) =>
      _$PersistedSessionStateFromJson(json);

  Map<String, dynamic> toJson() => _$PersistedSessionStateToJson(this);
}

/// Daemon state file format.
@JsonSerializable()
class DaemonState {
  final List<PersistedSessionState> sessions;

  @JsonKey(name: 'last-updated')
  final DateTime lastUpdated;

  DaemonState({required this.sessions, required this.lastUpdated});

  factory DaemonState.fromJson(Map<String, dynamic> json) =>
      _$DaemonStateFromJson(json);

  Map<String, dynamic> toJson() => _$DaemonStateToJson(this);

  factory DaemonState.empty() =>
      DaemonState(sessions: [], lastUpdated: DateTime.now());
}
