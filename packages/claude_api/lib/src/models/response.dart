import 'package:json_annotation/json_annotation.dart';

import '../utils/html_entity_decoder.dart';

part 'response.g.dart';

sealed class ClaudeResponse {
  final String id;
  final DateTime timestamp;
  final Map<String, dynamic>? rawData;

  const ClaudeResponse({
    required this.id,
    required this.timestamp,
    this.rawData,
  });

  factory ClaudeResponse.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    final subtype = json['subtype'] as String?;

    // Check for tool results in user messages
    if (type == 'user' && json['message'] != null) {
      final message = json['message'] as Map<String, dynamic>;
      final content = message['content'] as List<dynamic>?;
      if (content != null && content.isNotEmpty) {
        final firstContent = content.first as Map<String, dynamic>;
        if (firstContent['type'] == 'tool_result') {
          return ToolResultResponse.fromJson(json);
        }
      }
    }

    switch (type) {
      case 'text':
      case 'message':
        return TextResponse.fromJson(json);
      case 'assistant':
        // Claude CLI response format
        if (json['message'] != null) {
          final message = json['message'] as Map<String, dynamic>;
          final content = message['content'] as List<dynamic>?;

          // Check if it's a tool use in assistant message
          if (content != null && content.isNotEmpty) {
            final firstContent = content.first as Map<String, dynamic>;
            if (firstContent['type'] == 'tool_use') {
              return ToolUseResponse.fromAssistantMessage(json);
            }
          }

          return TextResponse.fromAssistantMessage(json);
        }
        return TextResponse.fromJson(json);
      case 'tool_use':
        return ToolUseResponse.fromJson(json);
      case 'error':
        return ErrorResponse.fromJson(json);
      case 'status':
        return StatusResponse.fromJson(json);
      case 'system':
        if (subtype == 'init') {
          return MetaResponse.fromJson(json);
        }
        return StatusResponse.fromJson(json);
      case 'result':
        return CompletionResponse.fromResultJson(json);
      case 'meta':
        return MetaResponse.fromJson(json);
      case 'completion':
        return CompletionResponse.fromJson(json);
      default:
        return UnknownResponse.fromJson(json);
    }
  }
}

@JsonSerializable()
class TextResponse extends ClaudeResponse {
  final String content;
  final bool isPartial;
  final String? role;

  const TextResponse({
    required super.id,
    required super.timestamp,
    required this.content,
    this.isPartial = false,
    this.role,
    super.rawData,
  });

  factory TextResponse.fromJson(Map<String, dynamic> json) {
    final content = json['content'] ?? json['text'] ?? '';
    final role = json['role'] as String?;

    // Decode HTML entities that may come from Claude CLI
    final decodedContent = HtmlEntityDecoder.decode(
      content is String ? content : content.toString(),
    );

    return TextResponse(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      content: decodedContent,
      isPartial: json['partial'] ?? false,
      role: role,
      rawData: json,
    );
  }

  factory TextResponse.fromAssistantMessage(Map<String, dynamic> json) {
    final message = json['message'] as Map<String, dynamic>;
    final content = message['content'] as List<dynamic>?;

    String text = '';
    if (content != null && content.isNotEmpty) {
      for (final item in content) {
        if (item is Map<String, dynamic> && item['type'] == 'text') {
          text += item['text'] ?? '';
        }
      }
    }

    // Decode HTML entities that may come from Claude CLI
    final decodedText = HtmlEntityDecoder.decode(text);

    return TextResponse(
      id:
          message['id'] ??
          json['uuid'] ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      content: decodedText,
      isPartial: message['stop_reason'] == null,
      role: message['role'],
      rawData: json,
    );
  }

  Map<String, dynamic> toJson() => _$TextResponseToJson(this);
}

@JsonSerializable()
class ToolUseResponse extends ClaudeResponse {
  final String toolName;
  final Map<String, dynamic> parameters;
  final String? toolUseId;

  const ToolUseResponse({
    required super.id,
    required super.timestamp,
    required this.toolName,
    required this.parameters,
    this.toolUseId,
    super.rawData,
  });

  factory ToolUseResponse.fromJson(Map<String, dynamic> json) {
    final toolName = json['name'] ?? json['tool_name'] ?? '';
    final parameters = json['input'] ?? json['parameters'] ?? {};

    return ToolUseResponse(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      toolName: HtmlEntityDecoder.decode(toolName),
      parameters: HtmlEntityDecoder.decodeMap(parameters),
      toolUseId: json['tool_use_id'],
      rawData: json,
    );
  }

  factory ToolUseResponse.fromAssistantMessage(Map<String, dynamic> json) {
    final message = json['message'] as Map<String, dynamic>;
    final content = message['content'] as List<dynamic>?;

    if (content != null && content.isNotEmpty) {
      final toolUse = content.first as Map<String, dynamic>;
      final toolName = toolUse['name'] ?? '';
      final parameters = toolUse['input'] ?? {};

      return ToolUseResponse(
        id: json['uuid'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        toolName: HtmlEntityDecoder.decode(toolName),
        parameters: HtmlEntityDecoder.decodeMap(parameters),
        toolUseId: toolUse['id'],
        rawData: json,
      );
    }

    return ToolUseResponse(
      id: json['uuid'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      toolName: '',
      parameters: {},
      rawData: json,
    );
  }

  Map<String, dynamic> toJson() => _$ToolUseResponseToJson(this);
}

@JsonSerializable()
class ToolResultResponse extends ClaudeResponse {
  final String toolUseId;
  final String content;
  final bool isError;

  const ToolResultResponse({
    required super.id,
    required super.timestamp,
    required this.toolUseId,
    required this.content,
    this.isError = false,
    super.rawData,
  });

  factory ToolResultResponse.fromJson(Map<String, dynamic> json) {
    final message = json['message'] as Map<String, dynamic>;
    final contentList = message['content'] as List<dynamic>?;

    String toolUseId = '';
    String content = '';
    bool isError = false;

    if (contentList != null && contentList.isNotEmpty) {
      final toolResult = contentList.first as Map<String, dynamic>;
      toolUseId = toolResult['tool_use_id'] ?? toolResult['id'] ?? '';

      // CRITICAL FIX: MCP tool results have content as an array of content blocks
      // Extract text from the content array: [{"type": "text", "text": "..."}]
      final rawContent = toolResult['content'];
      if (rawContent is String) {
        content = rawContent;
      } else if (rawContent is List) {
        // Extract text from array of content blocks
        for (final item in rawContent) {
          if (item is Map<String, dynamic> && item['type'] == 'text') {
            content += item['text'] as String? ?? '';
          }
        }
      }

      // is_error is inside the tool_result object, not at the top level!
      isError = toolResult['is_error'] ?? false;
    }

    // Decode HTML entities that may come from Claude CLI
    final decodedContent = HtmlEntityDecoder.decode(content);

    return ToolResultResponse(
      id: json['uuid'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      toolUseId: toolUseId,
      content: decodedContent,
      isError: isError,
      rawData: json,
    );
  }

  Map<String, dynamic> toJson() => _$ToolResultResponseToJson(this);
}

@JsonSerializable()
class ErrorResponse extends ClaudeResponse {
  final String error;
  final String? details;
  final String? code;

  const ErrorResponse({
    required super.id,
    required super.timestamp,
    required this.error,
    this.details,
    this.code,
    super.rawData,
  });

  factory ErrorResponse.fromJson(Map<String, dynamic> json) {
    return ErrorResponse(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      error: json['error'] ?? json['message'] ?? 'Unknown error',
      details: json['details'] ?? json['description'],
      code: json['code'],
      rawData: json,
    );
  }

  Map<String, dynamic> toJson() => _$ErrorResponseToJson(this);
}

@JsonSerializable()
class StatusResponse extends ClaudeResponse {
  final ClaudeStatus status;
  final String? message;

  const StatusResponse({
    required super.id,
    required super.timestamp,
    required this.status,
    this.message,
    super.rawData,
  });

  factory StatusResponse.fromJson(Map<String, dynamic> json) {
    return StatusResponse(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      status: ClaudeStatus.fromString(json['status'] ?? 'unknown'),
      message: json['message'],
      rawData: json,
    );
  }

  Map<String, dynamic> toJson() => _$StatusResponseToJson(this);
}

@JsonSerializable()
class MetaResponse extends ClaudeResponse {
  final String? conversationId;
  final Map<String, dynamic> metadata;

  const MetaResponse({
    required super.id,
    required super.timestamp,
    this.conversationId,
    required this.metadata,
    super.rawData,
  });

  factory MetaResponse.fromJson(Map<String, dynamic> json) {
    return MetaResponse(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      conversationId: json['conversation_id'],
      metadata: json['metadata'] ?? json,
      rawData: json,
    );
  }

  Map<String, dynamic> toJson() => _$MetaResponseToJson(this);
}

@JsonSerializable()
class CompletionResponse extends ClaudeResponse {
  final String? stopReason;
  final int? inputTokens;
  final int? outputTokens;

  const CompletionResponse({
    required super.id,
    required super.timestamp,
    this.stopReason,
    this.inputTokens,
    this.outputTokens,
    super.rawData,
  });

  factory CompletionResponse.fromJson(Map<String, dynamic> json) {
    return CompletionResponse(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      stopReason: json['stop_reason'],
      inputTokens: json['usage']?['input_tokens'],
      outputTokens: json['usage']?['output_tokens'],
      rawData: json,
    );
  }

  factory CompletionResponse.fromResultJson(Map<String, dynamic> json) {
    return CompletionResponse(
      id: json['uuid'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      stopReason: json['subtype'] == 'success' ? 'completed' : 'error',
      inputTokens: json['usage']?['input_tokens'],
      outputTokens: json['usage']?['output_tokens'],
      rawData: json,
    );
  }

  Map<String, dynamic> toJson() => _$CompletionResponseToJson(this);
}

@JsonSerializable()
class UnknownResponse extends ClaudeResponse {
  const UnknownResponse({
    required super.id,
    required super.timestamp,
    super.rawData,
  });

  factory UnknownResponse.fromJson(Map<String, dynamic> json) {
    return UnknownResponse(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      rawData: json,
    );
  }

  Map<String, dynamic> toJson() => _$UnknownResponseToJson(this);
}

enum ClaudeStatus {
  ready,
  processing,
  thinking,
  responding,
  completed,
  error,
  unknown;

  static ClaudeStatus fromString(String status) {
    return ClaudeStatus.values.firstWhere(
      (e) => e.name == status.toLowerCase(),
      orElse: () => ClaudeStatus.unknown,
    );
  }
}
