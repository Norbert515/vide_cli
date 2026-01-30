// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ConnectedEventImpl _$$ConnectedEventImplFromJson(Map<String, dynamic> json) =>
    _$ConnectedEventImpl(
      seq: (json['seq'] as num).toInt(),
      eventId: json['event-id'] as String,
      sessionId: json['session-id'] as String,
      mainAgentId: json['main-agent-id'] as String,
      lastSeq: (json['last-seq'] as num).toInt(),
      agents: (json['agents'] as List<dynamic>)
          .map((e) => SessionEventAgent.fromJson(e as Map<String, dynamic>))
          .toList(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$$ConnectedEventImplToJson(
        _$ConnectedEventImpl instance) =>
    <String, dynamic>{
      'seq': instance.seq,
      'event-id': instance.eventId,
      'session-id': instance.sessionId,
      'main-agent-id': instance.mainAgentId,
      'last-seq': instance.lastSeq,
      'agents': instance.agents,
      'timestamp': instance.timestamp.toIso8601String(),
      'type': instance.$type,
    };

_$HistoryEventImpl _$$HistoryEventImplFromJson(Map<String, dynamic> json) =>
    _$HistoryEventImpl(
      seq: (json['seq'] as num).toInt(),
      eventId: json['event-id'] as String,
      events: (json['events'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$$HistoryEventImplToJson(_$HistoryEventImpl instance) =>
    <String, dynamic>{
      'seq': instance.seq,
      'event-id': instance.eventId,
      'events': instance.events,
      'timestamp': instance.timestamp.toIso8601String(),
      'type': instance.$type,
    };

_$MessageEventImpl _$$MessageEventImplFromJson(Map<String, dynamic> json) =>
    _$MessageEventImpl(
      seq: (json['seq'] as num).toInt(),
      eventId: json['event-id'] as String,
      agentId: json['agent-id'] as String,
      agentType: json['agent-type'] as String,
      agentName: json['agent-name'] as String?,
      taskName: json['task-name'] as String?,
      data: SessionEventMessageData.fromJson(
          json['data'] as Map<String, dynamic>),
      isPartial: json['is-partial'] as bool? ?? false,
      timestamp: DateTime.parse(json['timestamp'] as String),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$$MessageEventImplToJson(_$MessageEventImpl instance) =>
    <String, dynamic>{
      'seq': instance.seq,
      'event-id': instance.eventId,
      'agent-id': instance.agentId,
      'agent-type': instance.agentType,
      'agent-name': instance.agentName,
      'task-name': instance.taskName,
      'data': instance.data,
      'is-partial': instance.isPartial,
      'timestamp': instance.timestamp.toIso8601String(),
      'type': instance.$type,
    };

_$StatusEventImpl _$$StatusEventImplFromJson(Map<String, dynamic> json) =>
    _$StatusEventImpl(
      seq: (json['seq'] as num).toInt(),
      eventId: json['event-id'] as String,
      agentId: json['agent-id'] as String,
      agentType: json['agent-type'] as String,
      agentName: json['agent-name'] as String?,
      taskName: json['task-name'] as String?,
      status: $enumDecode(_$AgentStatusEnumMap, json['status']),
      timestamp: DateTime.parse(json['timestamp'] as String),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$$StatusEventImplToJson(_$StatusEventImpl instance) =>
    <String, dynamic>{
      'seq': instance.seq,
      'event-id': instance.eventId,
      'agent-id': instance.agentId,
      'agent-type': instance.agentType,
      'agent-name': instance.agentName,
      'task-name': instance.taskName,
      'status': _$AgentStatusEnumMap[instance.status]!,
      'timestamp': instance.timestamp.toIso8601String(),
      'type': instance.$type,
    };

const _$AgentStatusEnumMap = {
  AgentStatus.working: 'working',
  AgentStatus.waitingForAgent: 'waiting-for-agent',
  AgentStatus.waitingForUser: 'waiting-for-user',
  AgentStatus.idle: 'idle',
};

_$ToolUseEventImpl _$$ToolUseEventImplFromJson(Map<String, dynamic> json) =>
    _$ToolUseEventImpl(
      seq: (json['seq'] as num).toInt(),
      eventId: json['event-id'] as String,
      agentId: json['agent-id'] as String,
      agentType: json['agent-type'] as String,
      agentName: json['agent-name'] as String?,
      taskName: json['task-name'] as String?,
      toolUseId: json['tool-use-id'] as String,
      toolName: json['tool-name'] as String,
      input: json['input'] as Map<String, dynamic>,
      timestamp: DateTime.parse(json['timestamp'] as String),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$$ToolUseEventImplToJson(_$ToolUseEventImpl instance) =>
    <String, dynamic>{
      'seq': instance.seq,
      'event-id': instance.eventId,
      'agent-id': instance.agentId,
      'agent-type': instance.agentType,
      'agent-name': instance.agentName,
      'task-name': instance.taskName,
      'tool-use-id': instance.toolUseId,
      'tool-name': instance.toolName,
      'input': instance.input,
      'timestamp': instance.timestamp.toIso8601String(),
      'type': instance.$type,
    };

_$ToolResultEventImpl _$$ToolResultEventImplFromJson(
        Map<String, dynamic> json) =>
    _$ToolResultEventImpl(
      seq: (json['seq'] as num).toInt(),
      eventId: json['event-id'] as String,
      agentId: json['agent-id'] as String,
      agentType: json['agent-type'] as String,
      agentName: json['agent-name'] as String?,
      taskName: json['task-name'] as String?,
      toolUseId: json['tool-use-id'] as String,
      toolName: json['tool-name'] as String,
      result: json['result'],
      isError: json['is-error'] as bool? ?? false,
      timestamp: DateTime.parse(json['timestamp'] as String),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$$ToolResultEventImplToJson(
        _$ToolResultEventImpl instance) =>
    <String, dynamic>{
      'seq': instance.seq,
      'event-id': instance.eventId,
      'agent-id': instance.agentId,
      'agent-type': instance.agentType,
      'agent-name': instance.agentName,
      'task-name': instance.taskName,
      'tool-use-id': instance.toolUseId,
      'tool-name': instance.toolName,
      'result': instance.result,
      'is-error': instance.isError,
      'timestamp': instance.timestamp.toIso8601String(),
      'type': instance.$type,
    };

_$PermissionRequestEventImpl _$$PermissionRequestEventImplFromJson(
        Map<String, dynamic> json) =>
    _$PermissionRequestEventImpl(
      seq: (json['seq'] as num).toInt(),
      eventId: json['event-id'] as String,
      agentId: json['agent-id'] as String,
      agentType: json['agent-type'] as String,
      agentName: json['agent-name'] as String?,
      taskName: json['task-name'] as String?,
      requestId: json['request-id'] as String,
      toolName: json['tool-name'] as String,
      toolInput: json['tool-input'] as Map<String, dynamic>,
      permissionSuggestions: (json['permission-suggestions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$$PermissionRequestEventImplToJson(
        _$PermissionRequestEventImpl instance) =>
    <String, dynamic>{
      'seq': instance.seq,
      'event-id': instance.eventId,
      'agent-id': instance.agentId,
      'agent-type': instance.agentType,
      'agent-name': instance.agentName,
      'task-name': instance.taskName,
      'request-id': instance.requestId,
      'tool-name': instance.toolName,
      'tool-input': instance.toolInput,
      'permission-suggestions': instance.permissionSuggestions,
      'timestamp': instance.timestamp.toIso8601String(),
      'type': instance.$type,
    };

_$PermissionTimeoutEventImpl _$$PermissionTimeoutEventImplFromJson(
        Map<String, dynamic> json) =>
    _$PermissionTimeoutEventImpl(
      seq: (json['seq'] as num).toInt(),
      eventId: json['event-id'] as String,
      agentId: json['agent-id'] as String,
      agentType: json['agent-type'] as String,
      agentName: json['agent-name'] as String?,
      taskName: json['task-name'] as String?,
      requestId: json['request-id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$$PermissionTimeoutEventImplToJson(
        _$PermissionTimeoutEventImpl instance) =>
    <String, dynamic>{
      'seq': instance.seq,
      'event-id': instance.eventId,
      'agent-id': instance.agentId,
      'agent-type': instance.agentType,
      'agent-name': instance.agentName,
      'task-name': instance.taskName,
      'request-id': instance.requestId,
      'timestamp': instance.timestamp.toIso8601String(),
      'type': instance.$type,
    };

_$DoneEventImpl _$$DoneEventImplFromJson(Map<String, dynamic> json) =>
    _$DoneEventImpl(
      seq: (json['seq'] as num).toInt(),
      eventId: json['event-id'] as String,
      agentId: json['agent-id'] as String,
      agentType: json['agent-type'] as String,
      agentName: json['agent-name'] as String?,
      taskName: json['task-name'] as String?,
      reason: json['reason'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$$DoneEventImplToJson(_$DoneEventImpl instance) =>
    <String, dynamic>{
      'seq': instance.seq,
      'event-id': instance.eventId,
      'agent-id': instance.agentId,
      'agent-type': instance.agentType,
      'agent-name': instance.agentName,
      'task-name': instance.taskName,
      'reason': instance.reason,
      'timestamp': instance.timestamp.toIso8601String(),
      'type': instance.$type,
    };

_$AbortedEventImpl _$$AbortedEventImplFromJson(Map<String, dynamic> json) =>
    _$AbortedEventImpl(
      seq: (json['seq'] as num).toInt(),
      eventId: json['event-id'] as String,
      agentId: json['agent-id'] as String,
      agentType: json['agent-type'] as String,
      agentName: json['agent-name'] as String?,
      taskName: json['task-name'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$$AbortedEventImplToJson(_$AbortedEventImpl instance) =>
    <String, dynamic>{
      'seq': instance.seq,
      'event-id': instance.eventId,
      'agent-id': instance.agentId,
      'agent-type': instance.agentType,
      'agent-name': instance.agentName,
      'task-name': instance.taskName,
      'timestamp': instance.timestamp.toIso8601String(),
      'type': instance.$type,
    };

_$AgentSpawnedEventImpl _$$AgentSpawnedEventImplFromJson(
        Map<String, dynamic> json) =>
    _$AgentSpawnedEventImpl(
      seq: (json['seq'] as num).toInt(),
      eventId: json['event-id'] as String,
      agentId: json['agent-id'] as String,
      agentType: json['agent-type'] as String,
      agentName: json['agent-name'] as String,
      parentAgentId: json['parent-agent-id'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$$AgentSpawnedEventImplToJson(
        _$AgentSpawnedEventImpl instance) =>
    <String, dynamic>{
      'seq': instance.seq,
      'event-id': instance.eventId,
      'agent-id': instance.agentId,
      'agent-type': instance.agentType,
      'agent-name': instance.agentName,
      'parent-agent-id': instance.parentAgentId,
      'timestamp': instance.timestamp.toIso8601String(),
      'type': instance.$type,
    };

_$AgentTerminatedEventImpl _$$AgentTerminatedEventImplFromJson(
        Map<String, dynamic> json) =>
    _$AgentTerminatedEventImpl(
      seq: (json['seq'] as num).toInt(),
      eventId: json['event-id'] as String,
      agentId: json['agent-id'] as String,
      agentType: json['agent-type'] as String,
      agentName: json['agent-name'] as String?,
      reason: json['reason'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$$AgentTerminatedEventImplToJson(
        _$AgentTerminatedEventImpl instance) =>
    <String, dynamic>{
      'seq': instance.seq,
      'event-id': instance.eventId,
      'agent-id': instance.agentId,
      'agent-type': instance.agentType,
      'agent-name': instance.agentName,
      'reason': instance.reason,
      'timestamp': instance.timestamp.toIso8601String(),
      'type': instance.$type,
    };

_$ErrorEventImpl _$$ErrorEventImplFromJson(Map<String, dynamic> json) =>
    _$ErrorEventImpl(
      seq: (json['seq'] as num).toInt(),
      eventId: json['event-id'] as String,
      agentId: json['agent-id'] as String?,
      agentType: json['agent-type'] as String?,
      agentName: json['agent-name'] as String?,
      taskName: json['task-name'] as String?,
      code: json['code'] as String,
      message: json['message'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$$ErrorEventImplToJson(_$ErrorEventImpl instance) =>
    <String, dynamic>{
      'seq': instance.seq,
      'event-id': instance.eventId,
      'agent-id': instance.agentId,
      'agent-type': instance.agentType,
      'agent-name': instance.agentName,
      'task-name': instance.taskName,
      'code': instance.code,
      'message': instance.message,
      'timestamp': instance.timestamp.toIso8601String(),
      'type': instance.$type,
    };

_$SessionEventAgentImpl _$$SessionEventAgentImplFromJson(
        Map<String, dynamic> json) =>
    _$SessionEventAgentImpl(
      id: json['id'] as String,
      type: json['type'] as String,
      name: json['name'] as String,
      status: $enumDecode(_$AgentStatusEnumMap, json['status']),
      taskName: json['task-name'] as String?,
    );

Map<String, dynamic> _$$SessionEventAgentImplToJson(
        _$SessionEventAgentImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'name': instance.name,
      'status': _$AgentStatusEnumMap[instance.status]!,
      'task-name': instance.taskName,
    };

_$SessionEventMessageDataImpl _$$SessionEventMessageDataImplFromJson(
        Map<String, dynamic> json) =>
    _$SessionEventMessageDataImpl(
      role: json['role'] as String,
      content: json['content'] as String,
    );

Map<String, dynamic> _$$SessionEventMessageDataImplToJson(
        _$SessionEventMessageDataImpl instance) =>
    <String, dynamic>{
      'role': instance.role,
      'content': instance.content,
    };
