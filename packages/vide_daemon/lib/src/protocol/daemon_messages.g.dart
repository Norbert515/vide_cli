// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daemon_messages.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateSessionRequest _$CreateSessionRequestFromJson(
  Map<String, dynamic> json,
) => CreateSessionRequest(
  initialMessage: json['initial-message'] as String,
  workingDirectory: json['working-directory'] as String,
  permissionMode: json['permission-mode'] as String?,
  team: json['team'] as String?,
  attachments: (json['attachments'] as List<dynamic>?)
      ?.map((e) => e as Map<String, dynamic>)
      .toList(),
);

Map<String, dynamic> _$CreateSessionRequestToJson(
  CreateSessionRequest instance,
) => <String, dynamic>{
  'initial-message': instance.initialMessage,
  'working-directory': instance.workingDirectory,
  'permission-mode': instance.permissionMode,
  'team': instance.team,
  'attachments': instance.attachments,
};

ResumeSessionRequest _$ResumeSessionRequestFromJson(
  Map<String, dynamic> json,
) =>
    ResumeSessionRequest(workingDirectory: json['working-directory'] as String);

Map<String, dynamic> _$ResumeSessionRequestToJson(
  ResumeSessionRequest instance,
) => <String, dynamic>{'working-directory': instance.workingDirectory};

CreateSessionResponse _$CreateSessionResponseFromJson(
  Map<String, dynamic> json,
) => CreateSessionResponse(
  sessionId: json['session-id'] as String,
  mainAgentId: json['main-agent-id'] as String,
  wsUrl: json['ws-url'] as String,
  httpUrl: json['http-url'] as String,
  port: (json['port'] as num).toInt(),
  createdAt: DateTime.parse(json['created-at'] as String),
);

Map<String, dynamic> _$CreateSessionResponseToJson(
  CreateSessionResponse instance,
) => <String, dynamic>{
  'session-id': instance.sessionId,
  'main-agent-id': instance.mainAgentId,
  'ws-url': instance.wsUrl,
  'http-url': instance.httpUrl,
  'port': instance.port,
  'created-at': instance.createdAt.toIso8601String(),
};

SessionSummary _$SessionSummaryFromJson(Map<String, dynamic> json) =>
    SessionSummary(
      sessionId: json['session-id'] as String,
      workingDirectory: json['working-directory'] as String,
      createdAt: DateTime.parse(json['created-at'] as String),
      state: $enumDecode(_$SessionProcessStateEnumMap, json['state']),
      connectedClients: (json['connected-clients'] as num).toInt(),
      port: (json['port'] as num).toInt(),
      goal: json['goal'] as String?,
      lastActiveAt: json['last-active-at'] == null
          ? null
          : DateTime.parse(json['last-active-at'] as String),
      agentCount: (json['agent-count'] as num?)?.toInt() ?? 0,
      lastSeenAt: json['last-seen-at'] == null
          ? null
          : DateTime.parse(json['last-seen-at'] as String),
    );

Map<String, dynamic> _$SessionSummaryToJson(SessionSummary instance) =>
    <String, dynamic>{
      'session-id': instance.sessionId,
      'working-directory': instance.workingDirectory,
      'created-at': instance.createdAt.toIso8601String(),
      'state': _$SessionProcessStateEnumMap[instance.state]!,
      'connected-clients': instance.connectedClients,
      'port': instance.port,
      'goal': instance.goal,
      'last-active-at': instance.lastActiveAt?.toIso8601String(),
      'agent-count': instance.agentCount,
      'last-seen-at': instance.lastSeenAt?.toIso8601String(),
    };

const _$SessionProcessStateEnumMap = {
  SessionProcessState.starting: 'starting',
  SessionProcessState.ready: 'ready',
  SessionProcessState.error: 'error',
  SessionProcessState.stopping: 'stopping',
};

ListSessionsResponse _$ListSessionsResponseFromJson(
  Map<String, dynamic> json,
) => ListSessionsResponse(
  sessions: (json['sessions'] as List<dynamic>)
      .map((e) => SessionSummary.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$ListSessionsResponseToJson(
  ListSessionsResponse instance,
) => <String, dynamic>{'sessions': instance.sessions};

SessionDetailsResponse _$SessionDetailsResponseFromJson(
  Map<String, dynamic> json,
) => SessionDetailsResponse(
  sessionId: json['session-id'] as String,
  workingDirectory: json['working-directory'] as String,
  wsUrl: json['ws-url'] as String,
  httpUrl: json['http-url'] as String,
  port: (json['port'] as num).toInt(),
  createdAt: DateTime.parse(json['created-at'] as String),
  state: $enumDecode(_$SessionProcessStateEnumMap, json['state']),
  connectedClients: (json['connected-clients'] as num).toInt(),
  pid: (json['pid'] as num).toInt(),
);

Map<String, dynamic> _$SessionDetailsResponseToJson(
  SessionDetailsResponse instance,
) => <String, dynamic>{
  'session-id': instance.sessionId,
  'working-directory': instance.workingDirectory,
  'ws-url': instance.wsUrl,
  'http-url': instance.httpUrl,
  'port': instance.port,
  'created-at': instance.createdAt.toIso8601String(),
  'state': _$SessionProcessStateEnumMap[instance.state]!,
  'connected-clients': instance.connectedClients,
  'pid': instance.pid,
};

PersistedSessionState _$PersistedSessionStateFromJson(
  Map<String, dynamic> json,
) => PersistedSessionState(
  sessionId: json['session-id'] as String,
  port: (json['port'] as num).toInt(),
  workingDirectory: json['working-directory'] as String,
  createdAt: DateTime.parse(json['created-at'] as String),
  pid: (json['pid'] as num).toInt(),
  initialMessage: json['initial-message'] as String,
  permissionMode: json['permission-mode'] as String?,
  team: json['team'] as String?,
  lastSeenAt: json['last-seen-at'] == null
      ? null
      : DateTime.parse(json['last-seen-at'] as String),
);

Map<String, dynamic> _$PersistedSessionStateToJson(
  PersistedSessionState instance,
) => <String, dynamic>{
  'session-id': instance.sessionId,
  'port': instance.port,
  'working-directory': instance.workingDirectory,
  'created-at': instance.createdAt.toIso8601String(),
  'pid': instance.pid,
  'initial-message': instance.initialMessage,
  'permission-mode': instance.permissionMode,
  'team': instance.team,
  'last-seen-at': instance.lastSeenAt?.toIso8601String(),
};

DaemonState _$DaemonStateFromJson(Map<String, dynamic> json) => DaemonState(
  sessions: (json['sessions'] as List<dynamic>)
      .map((e) => PersistedSessionState.fromJson(e as Map<String, dynamic>))
      .toList(),
  lastUpdated: DateTime.parse(json['last-updated'] as String),
);

Map<String, dynamic> _$DaemonStateToJson(DaemonState instance) =>
    <String, dynamic>{
      'sessions': instance.sessions,
      'last-updated': instance.lastUpdated.toIso8601String(),
    };
