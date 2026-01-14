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
  isCumulative: json['isCumulative'] as bool? ?? false,
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
      'isCumulative': instance.isCumulative,
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
      stdout: json['stdout'] as String?,
      stderr: json['stderr'] as String?,
      interrupted: json['interrupted'] as bool?,
      isImage: json['isImage'] as bool?,
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
      'stdout': instance.stdout,
      'stderr': instance.stderr,
      'interrupted': instance.interrupted,
      'isImage': instance.isImage,
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

ApiErrorResponse _$ApiErrorResponseFromJson(Map<String, dynamic> json) =>
    ApiErrorResponse(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      level: json['level'] as String,
      cause: json['cause'] as Map<String, dynamic>?,
      error: json['error'] as Map<String, dynamic>?,
      retryInMs: (json['retryInMs'] as num?)?.toDouble(),
      retryAttempt: (json['retryAttempt'] as num?)?.toInt(),
      maxRetries: (json['maxRetries'] as num?)?.toInt(),
      rawData: json['rawData'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$ApiErrorResponseToJson(ApiErrorResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'timestamp': instance.timestamp.toIso8601String(),
      'rawData': instance.rawData,
      'level': instance.level,
      'cause': instance.cause,
      'error': instance.error,
      'retryInMs': instance.retryInMs,
      'retryAttempt': instance.retryAttempt,
      'maxRetries': instance.maxRetries,
    };

TurnDurationResponse _$TurnDurationResponseFromJson(
  Map<String, dynamic> json,
) => TurnDurationResponse(
  id: json['id'] as String,
  timestamp: DateTime.parse(json['timestamp'] as String),
  durationMs: (json['durationMs'] as num).toInt(),
  rawData: json['rawData'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$TurnDurationResponseToJson(
  TurnDurationResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'timestamp': instance.timestamp.toIso8601String(),
  'rawData': instance.rawData,
  'durationMs': instance.durationMs,
};

LocalCommandResponse _$LocalCommandResponseFromJson(
  Map<String, dynamic> json,
) => LocalCommandResponse(
  id: json['id'] as String,
  timestamp: DateTime.parse(json['timestamp'] as String),
  content: json['content'] as String,
  level: json['level'] as String,
  rawData: json['rawData'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$LocalCommandResponseToJson(
  LocalCommandResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'timestamp': instance.timestamp.toIso8601String(),
  'rawData': instance.rawData,
  'content': instance.content,
  'level': instance.level,
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
      modelUsage: json['modelUsage'] as Map<String, dynamic>?,
      permissionDenials: (json['permissionDenials'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList(),
      durationApiMs: (json['durationApiMs'] as num?)?.toInt(),
      serverToolUse: json['serverToolUse'] as Map<String, dynamic>?,
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
      'modelUsage': instance.modelUsage,
      'permissionDenials': instance.permissionDenials,
      'durationApiMs': instance.durationApiMs,
      'serverToolUse': instance.serverToolUse,
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

UserMessageResponse _$UserMessageResponseFromJson(Map<String, dynamic> json) =>
    UserMessageResponse(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      content: json['content'] as String,
      isReplay: json['isReplay'] as bool? ?? false,
      rawData: json['rawData'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$UserMessageResponseToJson(
  UserMessageResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'timestamp': instance.timestamp.toIso8601String(),
  'rawData': instance.rawData,
  'content': instance.content,
  'isReplay': instance.isReplay,
};

CompactBoundaryResponse _$CompactBoundaryResponseFromJson(
  Map<String, dynamic> json,
) => CompactBoundaryResponse(
  id: json['id'] as String,
  timestamp: DateTime.parse(json['timestamp'] as String),
  trigger: json['trigger'] as String,
  preTokens: (json['preTokens'] as num).toInt(),
  content: json['content'] as String? ?? 'Conversation compacted',
  rawData: json['rawData'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$CompactBoundaryResponseToJson(
  CompactBoundaryResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'timestamp': instance.timestamp.toIso8601String(),
  'rawData': instance.rawData,
  'trigger': instance.trigger,
  'preTokens': instance.preTokens,
  'content': instance.content,
};

CompactSummaryResponse _$CompactSummaryResponseFromJson(
  Map<String, dynamic> json,
) => CompactSummaryResponse(
  id: json['id'] as String,
  timestamp: DateTime.parse(json['timestamp'] as String),
  content: json['content'] as String,
  isVisibleInTranscriptOnly: json['isVisibleInTranscriptOnly'] as bool? ?? true,
  rawData: json['rawData'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$CompactSummaryResponseToJson(
  CompactSummaryResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'timestamp': instance.timestamp.toIso8601String(),
  'rawData': instance.rawData,
  'content': instance.content,
  'isVisibleInTranscriptOnly': instance.isVisibleInTranscriptOnly,
};
