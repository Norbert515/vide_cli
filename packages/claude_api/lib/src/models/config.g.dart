// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ClaudeConfig _$ClaudeConfigFromJson(Map<String, dynamic> json) => ClaudeConfig(
  model: json['model'] as String?,
  timeout: json['timeout'] == null
      ? const Duration(seconds: 120)
      : Duration(microseconds: (json['timeout'] as num).toInt()),
  retryAttempts: (json['retryAttempts'] as num?)?.toInt() ?? 3,
  retryDelay: json['retryDelay'] == null
      ? const Duration(seconds: 1)
      : Duration(microseconds: (json['retryDelay'] as num).toInt()),
  verbose: json['verbose'] as bool? ?? false,
  appendSystemPrompt: json['appendSystemPrompt'] as String?,
  temperature: (json['temperature'] as num?)?.toDouble(),
  maxTokens: (json['maxTokens'] as num?)?.toInt(),
  additionalFlags: (json['additionalFlags'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  sessionId: json['sessionId'] as String?,
  permissionMode: json['permissionMode'] as String?,
  workingDirectory: json['workingDirectory'] as String?,
  allowedTools: (json['allowedTools'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  disallowedTools: (json['disallowedTools'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  maxTurns: (json['maxTurns'] as num?)?.toInt(),
);

Map<String, dynamic> _$ClaudeConfigToJson(ClaudeConfig instance) =>
    <String, dynamic>{
      'model': instance.model,
      'timeout': instance.timeout.inMicroseconds,
      'retryAttempts': instance.retryAttempts,
      'retryDelay': instance.retryDelay.inMicroseconds,
      'verbose': instance.verbose,
      'appendSystemPrompt': instance.appendSystemPrompt,
      'temperature': instance.temperature,
      'maxTokens': instance.maxTokens,
      'additionalFlags': instance.additionalFlags,
      'sessionId': instance.sessionId,
      'permissionMode': instance.permissionMode,
      'workingDirectory': instance.workingDirectory,
      'allowedTools': instance.allowedTools,
      'disallowedTools': instance.disallowedTools,
      'maxTurns': instance.maxTurns,
    };
