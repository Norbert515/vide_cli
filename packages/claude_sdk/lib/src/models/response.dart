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

  /// Parses a JSON response and returns one or more ClaudeResponse objects.
  ///
  /// For most response types, returns a single response.
  /// For `type: assistant` messages with interleaved content (text + tool_use + text),
  /// returns multiple responses in order to preserve interleaving.
  static List<ClaudeResponse> fromJsonMultiple(Map<String, dynamic> json) {
    final type = json['type'] as String?;

    // Handle assistant messages with potentially interleaved content
    if (type == 'assistant' && json['message'] != null) {
      final message = json['message'] as Map<String, dynamic>;
      final content = message['content'] as List<dynamic>?;

      if (content != null && content.length > 1) {
        // Multiple content blocks - expand into separate responses
        return _expandAssistantContentBlocks(json, content);
      }
    }

    // For all other cases, use the single-response parser
    return [ClaudeResponse.fromJson(json)];
  }

  /// Expands an assistant message with multiple content blocks into separate responses.
  /// This preserves the interleaving of text and tool_use blocks.
  static List<ClaudeResponse> _expandAssistantContentBlocks(
    Map<String, dynamic> json,
    List<dynamic> content,
  ) {
    final responses = <ClaudeResponse>[];
    final baseId =
        json['uuid'] ?? DateTime.now().millisecondsSinceEpoch.toString();

    for (int i = 0; i < content.length; i++) {
      final block = content[i] as Map<String, dynamic>;
      final blockType = block['type'] as String?;
      final blockId = block['id'] ?? '$baseId-$i';

      if (blockType == 'text') {
        final text = block['text'] as String? ?? '';
        if (text.isNotEmpty) {
          responses.add(
            TextResponse(
              id: blockId,
              timestamp: DateTime.now(),
              content: HtmlEntityDecoder.decode(text),
              // These are cumulative per-block, not streaming deltas
              isCumulative: true,
              rawData: json,
            ),
          );
        }
      } else if (blockType == 'tool_use') {
        final toolName = block['name'] as String? ?? '';
        final rawInput = block['input'];
        final parameters = rawInput is Map<String, dynamic>
            ? rawInput
            : (rawInput is Map
                  ? Map<String, dynamic>.from(rawInput)
                  : <String, dynamic>{});

        responses.add(
          ToolUseResponse(
            id: blockId,
            timestamp: DateTime.now(),
            toolName: HtmlEntityDecoder.decode(toolName),
            parameters: HtmlEntityDecoder.decodeMap(parameters),
            toolUseId: block['id'] as String?,
            rawData: json,
          ),
        );
      } else if (blockType == 'tool_result') {
        // Handle tool_result blocks in assistant messages (results from MCP tools)
        final toolUseId = block['tool_use_id'] as String?;
        final resultContent = block['content'];
        String content = '';
        if (resultContent is String) {
          content = resultContent;
        } else if (resultContent is List && resultContent.isNotEmpty) {
          final firstItem = resultContent.first;
          if (firstItem is Map && firstItem['text'] != null) {
            content = firstItem['text'] as String;
          }
        }

        if (toolUseId != null) {
          responses.add(
            ToolResultResponse(
              id: blockId,
              timestamp: DateTime.now(),
              toolUseId: toolUseId,
              content: content,
              isError: block['is_error'] as bool? ?? false,
              rawData: json,
            ),
          );
        }
      }
    }

    return responses;
  }

  factory ClaudeResponse.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    final subtype = json['subtype'] as String?;

    // Check for user message types
    if (type == 'user' && json['message'] != null) {
      // Check for compact summary (both camelCase and snake_case)
      final isCompactSummary =
          json['isCompactSummary'] as bool? ??
          json['is_compact_summary'] as bool? ??
          false;
      if (isCompactSummary) {
        return CompactSummaryResponse.fromJson(json);
      }

      // Check for tool results (content is a List with tool_result blocks)
      final message = json['message'] as Map<String, dynamic>;
      final content = message['content'];

      if (content is List && content.isNotEmpty) {
        final firstContent = content.first;
        if (firstContent is Map<String, dynamic> &&
            firstContent['type'] == 'tool_result') {
          return ToolResultResponse.fromJson(json);
        }
      }

      // All other user messages - return as UserMessageResponse
      // (content can be String for regular messages or List for structured content)
      return UserMessageResponse.fromJson(json);
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
        if (subtype == 'api_error') {
          return ApiErrorResponse.fromJson(json);
        }
        if (subtype == 'compact_boundary') {
          return CompactBoundaryResponse.fromJson(json);
        }
        if (subtype == 'turn_duration') {
          return TurnDurationResponse.fromJson(json);
        }
        if (subtype == 'local_command') {
          return LocalCommandResponse.fromJson(json);
        }
        // Unrecognized system subtype — return as a generic text response
        // rather than a StatusResponse, which would produce ClaudeStatus.unknown
        // and incorrectly affect agent status tracking.
        return TextResponse.fromJson(json);
      case 'result':
        return CompletionResponse.fromResultJson(json);
      case 'meta':
        return MetaResponse.fromJson(json);
      case 'completion':
        return CompletionResponse.fromJson(json);
      case 'stream_event':
        // Handle streaming events from --include-partial-messages
        final event = json['event'] as Map<String, dynamic>?;
        if (event != null) {
          final eventType = event['type'] as String?;
          if (eventType == 'content_block_delta') {
            // Extract streaming text delta
            final delta = event['delta'] as Map<String, dynamic>?;
            final text = delta?['text'] as String?;
            if (text != null && text.isNotEmpty) {
              return TextResponse(
                id:
                    json['uuid'] ??
                    DateTime.now().millisecondsSinceEpoch.toString(),
                timestamp: DateTime.now(),
                content: text,
                isPartial: true,
                rawData: json,
              );
            }
          }
        }
        // Other stream_event types (message_start, content_block_start, etc.) - ignore
        return UnknownResponse.fromJson(json);
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

  /// Whether this response contains cumulative content (full text up to this point)
  /// rather than sequential/delta content.
  /// When true, only the last cumulative response should be used to avoid duplicates.
  final bool isCumulative;

  const TextResponse({
    required super.id,
    required super.timestamp,
    required this.content,
    this.isPartial = false,
    this.role,
    this.isCumulative = false,
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
      // fromAssistantMessage always contains CUMULATIVE content, not a delta
      // So it should never be marked as partial. The stop_reason check was incorrect.
      isPartial: false,
      // Mark as cumulative so that only the last one is used (to avoid duplicates)
      isCumulative: true,
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

  /// stdout output from tool execution (if available)
  final String? stdout;

  /// stderr output from tool execution (if available)
  final String? stderr;

  /// Whether the tool execution was interrupted
  final bool? interrupted;

  /// Whether the result contains image data
  final bool? isImage;

  const ToolResultResponse({
    required super.id,
    required super.timestamp,
    required this.toolUseId,
    required this.content,
    this.isError = false,
    this.stdout,
    this.stderr,
    this.interrupted,
    this.isImage,
    super.rawData,
  });

  /// Whether the tool execution was interrupted
  bool get wasInterrupted => interrupted ?? false;

  /// Whether the result contains image data
  bool get hasImage => isImage ?? false;

  factory ToolResultResponse.fromJson(Map<String, dynamic> json) {
    final message = json['message'] as Map<String, dynamic>;
    final contentList = message['content'] as List<dynamic>?;

    String toolUseId = '';
    String content = '';
    bool isError = false;
    String? stdout;
    String? stderr;
    bool? interrupted;
    bool? isImage;

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

    // Extract execution metadata from tool_use_result if present
    // Note: tool_use_result can be either a Map (with metadata) or a List (content blocks)
    final rawToolUseResult = json['tool_use_result'];
    if (rawToolUseResult is Map<String, dynamic>) {
      stdout = rawToolUseResult['stdout'] as String?;
      stderr = rawToolUseResult['stderr'] as String?;
      interrupted = rawToolUseResult['interrupted'] as bool?;
      isImage = rawToolUseResult['isImage'] as bool?;
    }
    // If it's a List, it's just content blocks which we already extracted above

    // Decode HTML entities that may come from Claude CLI
    final decodedContent = HtmlEntityDecoder.decode(content);

    return ToolResultResponse(
      id: json['uuid'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      toolUseId: toolUseId,
      content: decodedContent,
      isError: isError,
      stdout: stdout,
      stderr: stderr,
      interrupted: interrupted,
      isImage: isImage,
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

/// API error response from Claude CLI (system subtype: api_error)
///
/// This represents transient API errors that Claude Code handles internally,
/// often with automatic retries. These include rate limits, server errors,
/// and other recoverable API failures.
@JsonSerializable()
class ApiErrorResponse extends ClaudeResponse {
  /// Error level (e.g., 'error', 'warning')
  final String level;

  /// The underlying cause of the error
  final Map<String, dynamic>? cause;

  /// Structured error information
  final Map<String, dynamic>? error;

  /// Milliseconds before retry (if retrying)
  final double? retryInMs;

  /// Current retry attempt number
  final int? retryAttempt;

  /// Maximum number of retries configured
  final int? maxRetries;

  const ApiErrorResponse({
    required super.id,
    required super.timestamp,
    required this.level,
    this.cause,
    this.error,
    this.retryInMs,
    this.retryAttempt,
    this.maxRetries,
    super.rawData,
  });

  /// Whether this error will be retried
  bool get willRetry => retryInMs != null && retryInMs! > 0;

  /// Human-readable error message extracted from cause or error
  String get message {
    // Try to extract message from cause
    if (cause != null) {
      final causeMessage = cause!['message'] as String?;
      if (causeMessage != null) return causeMessage;
    }
    // Try to extract message from error
    if (error != null) {
      final errorMessage = error!['message'] as String?;
      if (errorMessage != null) return errorMessage;
    }
    return 'API error occurred';
  }

  /// Error type extracted from cause (e.g., 'overloaded_error', 'rate_limit_error')
  String? get errorType {
    return cause?['type'] as String? ?? error?['type'] as String?;
  }

  factory ApiErrorResponse.fromJson(Map<String, dynamic> json) {
    return ApiErrorResponse(
      id:
          json['uuid'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      level: json['level'] as String? ?? 'error',
      cause: json['cause'] as Map<String, dynamic>?,
      error: json['error'] as Map<String, dynamic>?,
      retryInMs: (json['retryInMs'] as num?)?.toDouble(),
      retryAttempt: json['retryAttempt'] as int?,
      maxRetries: json['maxRetries'] as int?,
      rawData: json,
    );
  }

  Map<String, dynamic> toJson() => _$ApiErrorResponseToJson(this);
}

/// Turn duration response from Claude CLI (system subtype: turn_duration)
///
/// This reports the duration of a completed turn in milliseconds.
@JsonSerializable()
class TurnDurationResponse extends ClaudeResponse {
  /// Duration of the turn in milliseconds
  final int durationMs;

  const TurnDurationResponse({
    required super.id,
    required super.timestamp,
    required this.durationMs,
    super.rawData,
  });

  factory TurnDurationResponse.fromJson(Map<String, dynamic> json) {
    return TurnDurationResponse(
      id:
          json['uuid'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      durationMs: json['durationMs'] as int? ?? 0,
      rawData: json,
    );
  }

  Map<String, dynamic> toJson() => _$TurnDurationResponseToJson(this);
}

/// Local command (slash command) execution response (system subtype: local_command)
///
/// This tracks slash command execution status and output.
@JsonSerializable()
class LocalCommandResponse extends ClaudeResponse {
  /// The content/output of the command
  final String content;

  /// Log level (e.g., 'info', 'warning', 'error')
  final String level;

  const LocalCommandResponse({
    required super.id,
    required super.timestamp,
    required this.content,
    required this.level,
    super.rawData,
  });

  factory LocalCommandResponse.fromJson(Map<String, dynamic> json) {
    return LocalCommandResponse(
      id:
          json['uuid'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      content: json['content'] as String? ?? '',
      level: json['level'] as String? ?? 'info',
      rawData: json,
    );
  }

  Map<String, dynamic> toJson() => _$LocalCommandResponseToJson(this);
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

  /// MCP servers from init message
  List<Map<String, dynamic>>? get mcpServers {
    final servers = metadata['mcp_servers'];
    if (servers == null) return null;
    return (servers as List).cast<Map<String, dynamic>>();
  }

  /// Available tools from init message
  List<String>? get tools {
    final toolsList = metadata['tools'];
    if (toolsList == null) return null;
    return (toolsList as List).cast<String>();
  }

  /// Claude Code version from init message
  String? get claudeCodeVersion => metadata['claude_code_version'] as String?;

  /// Model name from init message
  String? get model => metadata['model'] as String?;

  /// Available skills from init message
  List<String>? get skills {
    final skillsList = metadata['skills'];
    if (skillsList == null) return null;
    return (skillsList as List).cast<String>();
  }

  /// Available agent types from init message
  List<String>? get agents {
    final agentsList = metadata['agents'];
    if (agentsList == null) return null;
    return (agentsList as List).cast<String>();
  }

  /// Available slash commands from init message
  List<String>? get slashCommands {
    final cmdList = metadata['slash_commands'];
    if (cmdList == null) return null;
    return (cmdList as List).cast<String>();
  }

  /// Loaded plugins from init message
  List<Map<String, dynamic>>? get plugins {
    final pluginList = metadata['plugins'];
    if (pluginList == null) return null;
    return (pluginList as List).cast<Map<String, dynamic>>();
  }

  /// Permission mode from init message (e.g., 'default', 'plan', 'bypassPermissions')
  String? get permissionMode => metadata['permissionMode'] as String?;

  /// API key source from init message (e.g., 'ANTHROPIC_API_KEY')
  String? get apiKeySource => metadata['apiKeySource'] as String?;

  /// Session ID from init message
  String? get sessionId => metadata['session_id'] as String?;

  /// Working directory from init message
  String? get cwd => metadata['cwd'] as String?;

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
  final int? cacheReadInputTokens;
  final int? cacheCreationInputTokens;
  final double? totalCostUsd;

  /// Per-model token usage breakdown (model ID -> usage stats)
  final Map<String, dynamic>? modelUsage;

  /// List of permission denials that occurred during the turn
  final List<Map<String, dynamic>>? permissionDenials;

  /// Duration of API calls in milliseconds
  final int? durationApiMs;

  /// Server-side tool usage statistics
  final Map<String, dynamic>? serverToolUse;

  const CompletionResponse({
    required super.id,
    required super.timestamp,
    this.stopReason,
    this.inputTokens,
    this.outputTokens,
    this.cacheReadInputTokens,
    this.cacheCreationInputTokens,
    this.totalCostUsd,
    this.modelUsage,
    this.permissionDenials,
    this.durationApiMs,
    this.serverToolUse,
    super.rawData,
  });

  /// Total context tokens (input + cache read + cache creation).
  /// This represents the actual context window usage.
  int get totalContextTokens =>
      (inputTokens ?? 0) +
      (cacheReadInputTokens ?? 0) +
      (cacheCreationInputTokens ?? 0);

  /// Get usage for a specific model
  Map<String, dynamic>? getModelUsage(String modelId) {
    return modelUsage?[modelId] as Map<String, dynamic>?;
  }

  /// Get all model IDs that were used
  List<String> get usedModels => modelUsage?.keys.toList() ?? [];

  /// Whether any permissions were denied during this turn
  bool get hadPermissionDenials =>
      permissionDenials != null && permissionDenials!.isNotEmpty;

  factory CompletionResponse.fromJson(Map<String, dynamic> json) {
    return CompletionResponse(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      stopReason: json['stop_reason'],
      inputTokens: json['usage']?['input_tokens'],
      outputTokens: json['usage']?['output_tokens'],
      cacheReadInputTokens: json['usage']?['cache_read_input_tokens'],
      cacheCreationInputTokens: json['usage']?['cache_creation_input_tokens'],
      totalCostUsd: (json['total_cost_usd'] as num?)?.toDouble(),
      modelUsage: json['modelUsage'] as Map<String, dynamic>?,
      permissionDenials: (json['permission_denials'] as List?)
          ?.cast<Map<String, dynamic>>(),
      durationApiMs: json['duration_api_ms'] as int?,
      serverToolUse: json['usage']?['server_tool_use'] as Map<String, dynamic>?,
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
      cacheReadInputTokens: json['usage']?['cache_read_input_tokens'],
      cacheCreationInputTokens: json['usage']?['cache_creation_input_tokens'],
      totalCostUsd: (json['total_cost_usd'] as num?)?.toDouble(),
      modelUsage: json['modelUsage'] as Map<String, dynamic>?,
      permissionDenials: (json['permission_denials'] as List?)
          ?.cast<Map<String, dynamic>>(),
      durationApiMs: json['duration_api_ms'] as int?,
      serverToolUse: json['usage']?['server_tool_use'] as Map<String, dynamic>?,
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

/// Response representing a user message from the streaming protocol.
///
/// This handles user messages that come through streaming, including
/// the continuation summary after compaction (which may or may not have
/// the isCompactSummary flag depending on the protocol version).
@JsonSerializable()
class UserMessageResponse extends ClaudeResponse {
  /// The message content
  final String content;

  /// Whether this is a replay of a previous message
  final bool isReplay;

  const UserMessageResponse({
    required super.id,
    required super.timestamp,
    required this.content,
    this.isReplay = false,
    super.rawData,
  });

  factory UserMessageResponse.fromJson(Map<String, dynamic> json) {
    final message = json['message'] as Map<String, dynamic>?;
    String content = '';

    if (message != null) {
      final messageContent = message['content'];
      if (messageContent is String) {
        content = messageContent;
      } else if (messageContent is List) {
        // Extract text from content blocks
        for (final block in messageContent) {
          if (block is Map<String, dynamic> && block['type'] == 'text') {
            content += block['text'] as String? ?? '';
          }
        }
      }
    }

    final isReplay =
        json['isReplay'] as bool? ?? json['is_replay'] as bool? ?? false;

    return UserMessageResponse(
      id: json['uuid'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
          : DateTime.now(),
      content: content,
      isReplay: isReplay,
      rawData: json,
    );
  }

  Map<String, dynamic> toJson() => _$UserMessageResponseToJson(this);
}

/// Response representing a compact boundary event.
///
/// This is emitted when Claude Code compacts the conversation context.
/// The session ID remains the same, but messages before this point
/// have been summarized to free up context space.
@JsonSerializable()
class CompactBoundaryResponse extends ClaudeResponse {
  /// What triggered the compaction: 'manual' (user ran /compact) or 'auto'
  final String trigger;

  /// Token count before compaction
  final int preTokens;

  /// The content message (typically "Conversation compacted")
  final String content;

  const CompactBoundaryResponse({
    required super.id,
    required super.timestamp,
    required this.trigger,
    required this.preTokens,
    this.content = 'Conversation compacted',
    super.rawData,
  });

  factory CompactBoundaryResponse.fromJson(Map<String, dynamic> json) {
    // Handle both camelCase (from JSONL storage) and snake_case (from streaming)
    final compactMetadata =
        json['compactMetadata'] as Map<String, dynamic>? ??
        json['compact_metadata'] as Map<String, dynamic>? ??
        {};

    // Try to get trigger from compactMetadata first, then fall back to top-level
    final trigger =
        compactMetadata['trigger'] as String? ??
        json['trigger'] as String? ??
        'auto';

    // Try to get preTokens (camelCase) or pre_tokens (snake_case)
    final preTokens =
        compactMetadata['preTokens'] as int? ??
        compactMetadata['pre_tokens'] as int? ??
        json['preTokens'] as int? ??
        json['pre_tokens'] as int? ??
        0;

    return CompactBoundaryResponse(
      id: json['uuid'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
          : DateTime.now(),
      trigger: trigger,
      preTokens: preTokens,
      content: json['content'] as String? ?? 'Conversation compacted',
      rawData: json,
    );
  }

  Map<String, dynamic> toJson() => _$CompactBoundaryResponseToJson(this);
}

/// Response representing a compact summary user message.
///
/// This is the continuation summary injected by Claude Code after compaction.
/// It contains a summarized version of the conversation history.
@JsonSerializable()
class CompactSummaryResponse extends ClaudeResponse {
  /// The summary content
  final String content;

  /// Whether this message is only visible in the transcript
  final bool isVisibleInTranscriptOnly;

  const CompactSummaryResponse({
    required super.id,
    required super.timestamp,
    required this.content,
    this.isVisibleInTranscriptOnly = true,
    super.rawData,
  });

  factory CompactSummaryResponse.fromJson(Map<String, dynamic> json) {
    final message = json['message'] as Map<String, dynamic>?;
    String content = '';

    if (message != null) {
      final messageContent = message['content'];
      if (messageContent is String) {
        content = messageContent;
      } else if (messageContent is List) {
        // Extract text from content blocks
        for (final block in messageContent) {
          if (block is Map<String, dynamic> && block['type'] == 'text') {
            content += block['text'] as String? ?? '';
          }
        }
      }
    }

    // Handle both camelCase and snake_case
    final isVisibleInTranscriptOnly =
        json['isVisibleInTranscriptOnly'] as bool? ??
        json['is_visible_in_transcript_only'] as bool? ??
        true;

    return CompactSummaryResponse(
      id: json['uuid'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
          : DateTime.now(),
      content: content,
      isVisibleInTranscriptOnly: isVisibleInTranscriptOnly,
      rawData: json,
    );
  }

  Map<String, dynamic> toJson() => _$CompactSummaryResponseToJson(this);
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
