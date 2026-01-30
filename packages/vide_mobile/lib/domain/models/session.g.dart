// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SessionImpl _$$SessionImplFromJson(Map<String, dynamic> json) =>
    _$SessionImpl(
      sessionId: json['session-id'] as String,
      mainAgentId: json['main-agent-id'] as String,
      createdAt: DateTime.parse(json['created-at'] as String),
      workingDirectory: json['working-directory'] as String,
      model: json['model'] as String?,
    );

Map<String, dynamic> _$$SessionImplToJson(_$SessionImpl instance) =>
    <String, dynamic>{
      'session-id': instance.sessionId,
      'main-agent-id': instance.mainAgentId,
      'created-at': instance.createdAt.toIso8601String(),
      'working-directory': instance.workingDirectory,
      'model': instance.model,
    };
