// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TextResponse _$TextResponseFromJson(Map<String, dynamic> json) => TextResponse(
  id: json['id'] as String,
  timestamp: DateTime.parse(json['timestamp'] as String),
  content: json['content'] as String,
  isPartial: json['isPartial'] as bool? ?? false,
  role: json['role'] as String?,
  rawData: json['rawData'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$TextResponseToJson(TextResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'timestamp': instance.timestamp.toIso8601String(),
      'rawData': instance.rawData,
      'content': instance.content,
      'isPartial': instance.isPartial,
      'role': instance.role,
    };

ToolUseResponse _$ToolUseResponseFromJson(Map<String, dynamic> json) =>
    ToolUseResponse(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      toolName: json['toolName'] as String,
      parameters: json['parameters'] as Map<String, dynamic>,
      toolUseId: json['toolUseId'] as String?,
      rawData: json['rawData'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$ToolUseResponseToJson(ToolUseResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'timestamp': instance.timestamp.toIso8601String(),
      'rawData': instance.rawData,
      'toolName': instance.toolName,
      'parameters': instance.parameters,
      'toolUseId': instance.toolUseId,
    };

ToolResultResponse _$ToolResultResponseFromJson(Map<String, dynamic> json) =>
    ToolResultResponse(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      toolUseId: json['toolUseId'] as String,
      content: json['content'] as String,
      isError: json['isError'] as bool? ?? false,
      rawData: json['rawData'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$ToolResultResponseToJson(ToolResultResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'timestamp': instance.timestamp.toIso8601String(),
      'rawData': instance.rawData,
      'toolUseId': instance.toolUseId,
      'content': instance.content,
      'isError': instance.isError,
    };

ErrorResponse _$ErrorResponseFromJson(Map<String, dynamic> json) =>
    ErrorResponse(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      error: json['error'] as String,
      details: json['details'] as String?,
      code: json['code'] as String?,
      rawData: json['rawData'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$ErrorResponseToJson(ErrorResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'timestamp': instance.timestamp.toIso8601String(),
      'rawData': instance.rawData,
      'error': instance.error,
      'details': instance.details,
      'code': instance.code,
    };

StatusResponse _$StatusResponseFromJson(Map<String, dynamic> json) =>
    StatusResponse(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      status: $enumDecode(_$ClaudeStatusEnumMap, json['status']),
      message: json['message'] as String?,
      rawData: json['rawData'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$StatusResponseToJson(StatusResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'timestamp': instance.timestamp.toIso8601String(),
      'rawData': instance.rawData,
      'status': _$ClaudeStatusEnumMap[instance.status]!,
      'message': instance.message,
    };

const _$ClaudeStatusEnumMap = {
  ClaudeStatus.ready: 'ready',
  ClaudeStatus.processing: 'processing',
  ClaudeStatus.thinking: 'thinking',
  ClaudeStatus.responding: 'responding',
  ClaudeStatus.completed: 'completed',
  ClaudeStatus.error: 'error',
  ClaudeStatus.unknown: 'unknown',
};

MetaResponse _$MetaResponseFromJson(Map<String, dynamic> json) => MetaResponse(
  id: json['id'] as String,
  timestamp: DateTime.parse(json['timestamp'] as String),
  conversationId: json['conversationId'] as String?,
  metadata: json['metadata'] as Map<String, dynamic>,
  rawData: json['rawData'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$MetaResponseToJson(MetaResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'timestamp': instance.timestamp.toIso8601String(),
      'rawData': instance.rawData,
      'conversationId': instance.conversationId,
      'metadata': instance.metadata,
    };

CompletionResponse _$CompletionResponseFromJson(Map<String, dynamic> json) =>
    CompletionResponse(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      stopReason: json['stopReason'] as String?,
      inputTokens: (json['inputTokens'] as num?)?.toInt(),
      outputTokens: (json['outputTokens'] as num?)?.toInt(),
      cacheReadInputTokens: (json['cacheReadInputTokens'] as num?)?.toInt(),
      cacheCreationInputTokens: (json['cacheCreationInputTokens'] as num?)
          ?.toInt(),
      totalCostUsd: (json['totalCostUsd'] as num?)?.toDouble(),
      rawData: json['rawData'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$CompletionResponseToJson(CompletionResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'timestamp': instance.timestamp.toIso8601String(),
      'rawData': instance.rawData,
      'stopReason': instance.stopReason,
      'inputTokens': instance.inputTokens,
      'outputTokens': instance.outputTokens,
      'cacheReadInputTokens': instance.cacheReadInputTokens,
      'cacheCreationInputTokens': instance.cacheCreationInputTokens,
      'totalCostUsd': instance.totalCostUsd,
    };

UnknownResponse _$UnknownResponseFromJson(Map<String, dynamic> json) =>
    UnknownResponse(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      rawData: json['rawData'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$UnknownResponseToJson(UnknownResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'timestamp': instance.timestamp.toIso8601String(),
      'rawData': instance.rawData,
    };
