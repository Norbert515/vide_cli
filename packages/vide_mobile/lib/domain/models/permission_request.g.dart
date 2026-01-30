// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'permission_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PermissionRequestImpl _$$PermissionRequestImplFromJson(
        Map<String, dynamic> json) =>
    _$PermissionRequestImpl(
      requestId: json['request-id'] as String,
      toolName: json['tool-name'] as String,
      toolInput: json['tool-input'] as Map<String, dynamic>,
      agentId: json['agent-id'] as String,
      agentName: json['agent-name'] as String?,
      permissionSuggestions: (json['permission-suggestions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );

Map<String, dynamic> _$$PermissionRequestImplToJson(
        _$PermissionRequestImpl instance) =>
    <String, dynamic>{
      'request-id': instance.requestId,
      'tool-name': instance.toolName,
      'tool-input': instance.toolInput,
      'agent-id': instance.agentId,
      'agent-name': instance.agentName,
      'permission-suggestions': instance.permissionSuggestions,
      'timestamp': instance.timestamp.toIso8601String(),
    };
