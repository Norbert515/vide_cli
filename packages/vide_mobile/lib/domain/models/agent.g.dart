// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AgentImpl _$$AgentImplFromJson(Map<String, dynamic> json) => _$AgentImpl(
      id: json['id'] as String,
      type: json['type'] as String,
      name: json['name'] as String,
      status: $enumDecodeNullable(_$AgentStatusEnumMap, json['status']) ??
          AgentStatus.idle,
      taskName: json['task-name'] as String?,
    );

Map<String, dynamic> _$$AgentImplToJson(_$AgentImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'name': instance.name,
      'status': _$AgentStatusEnumMap[instance.status]!,
      'task-name': instance.taskName,
    };

const _$AgentStatusEnumMap = {
  AgentStatus.working: 'working',
  AgentStatus.waitingForAgent: 'waiting-for-agent',
  AgentStatus.waitingForUser: 'waiting-for-user',
  AgentStatus.idle: 'idle',
};
