// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ChatMessageImpl _$$ChatMessageImplFromJson(Map<String, dynamic> json) =>
    _$ChatMessageImpl(
      eventId: json['event-id'] as String,
      role: $enumDecode(_$MessageRoleEnumMap, json['role']),
      content: json['content'] as String,
      agentId: json['agent-id'] as String,
      agentType: json['agent-type'] as String,
      agentName: json['agent-name'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isStreaming: json['is-streaming'] as bool? ?? false,
    );

Map<String, dynamic> _$$ChatMessageImplToJson(_$ChatMessageImpl instance) =>
    <String, dynamic>{
      'event-id': instance.eventId,
      'role': _$MessageRoleEnumMap[instance.role]!,
      'content': instance.content,
      'agent-id': instance.agentId,
      'agent-type': instance.agentType,
      'agent-name': instance.agentName,
      'timestamp': instance.timestamp.toIso8601String(),
      'is-streaming': instance.isStreaming,
    };

const _$MessageRoleEnumMap = {
  MessageRole.user: 'user',
  MessageRole.assistant: 'assistant',
};
