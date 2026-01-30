// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tool_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ToolUseImpl _$$ToolUseImplFromJson(Map<String, dynamic> json) =>
    _$ToolUseImpl(
      toolUseId: json['tool-use-id'] as String,
      toolName: json['tool-name'] as String,
      input: json['input'] as Map<String, dynamic>,
      agentId: json['agent-id'] as String,
      agentName: json['agent-name'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );

Map<String, dynamic> _$$ToolUseImplToJson(_$ToolUseImpl instance) =>
    <String, dynamic>{
      'tool-use-id': instance.toolUseId,
      'tool-name': instance.toolName,
      'input': instance.input,
      'agent-id': instance.agentId,
      'agent-name': instance.agentName,
      'timestamp': instance.timestamp.toIso8601String(),
    };

_$ToolResultImpl _$$ToolResultImplFromJson(Map<String, dynamic> json) =>
    _$ToolResultImpl(
      toolUseId: json['tool-use-id'] as String,
      toolName: json['tool-name'] as String,
      result: json['result'],
      isError: json['is-error'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );

Map<String, dynamic> _$$ToolResultImplToJson(_$ToolResultImpl instance) =>
    <String, dynamic>{
      'tool-use-id': instance.toolUseId,
      'tool-name': instance.toolName,
      'result': instance.result,
      'is-error': instance.isError,
      'timestamp': instance.timestamp.toIso8601String(),
    };
