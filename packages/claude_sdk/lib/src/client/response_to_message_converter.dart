import '../models/response.dart';
import '../models/conversation.dart';

/// Converts ClaudeResponse objects to ConversationMessage objects.
///
/// This provides a unified conversion layer used by both:
/// - ResponseProcessor (streaming responses)
/// - ConversationLoader (loading from JSONL storage)
///
/// This ensures consistent behavior regardless of how responses are received.
class ResponseToMessageConverter {
  /// Convert a ClaudeResponse to a ConversationMessage.
  ///
  /// All response types are converted to messages, allowing the UI layer
  /// to decide what to display or filter. The `messageType` field on the
  /// returned message indicates the semantic type.
  ///
  /// For responses that should be merged with previous messages (like tool results),
  /// returns the message that should be merged.
  static ConversationMessage convert(
    ClaudeResponse response, {
    DateTime? timestamp,
  }) {
    final ts = timestamp ?? response.timestamp;

    return switch (response) {
      TextResponse r => _convertTextResponse(r, ts),
      ToolUseResponse r => _convertToolUseResponse(r, ts),
      ToolResultResponse r => _convertToolResultResponse(r, ts),
      CompactBoundaryResponse r => _convertCompactBoundaryResponse(r, ts),
      CompactSummaryResponse r => _convertCompactSummaryResponse(r, ts),
      UserMessageResponse r => _convertUserMessageResponse(r, ts),
      ErrorResponse r => _convertErrorResponse(r, ts),
      StatusResponse r => _convertStatusResponse(r, ts),
      MetaResponse r => _convertMetaResponse(r, ts),
      CompletionResponse r => _convertCompletionResponse(r, ts),
      UnknownResponse r => _convertUnknownResponse(r, ts),
    };
  }

  /// Check if a response is a tool result that should be merged with assistant messages.
  static bool isToolResult(ClaudeResponse response) =>
      response is ToolResultResponse;

  /// Check if a response produces an assistant message.
  static bool isAssistantResponse(ClaudeResponse response) =>
      response is TextResponse ||
      response is ToolUseResponse ||
      response is CompactBoundaryResponse ||
      response is ErrorResponse;

  /// Check if a response produces a user message.
  static bool isUserResponse(ClaudeResponse response) =>
      response is CompactSummaryResponse || response is UserMessageResponse;

  static ConversationMessage _convertTextResponse(
    TextResponse response,
    DateTime timestamp,
  ) {
    return ConversationMessage.assistant(
      id: response.id,
      responses: [response],
      isComplete: false,
      isStreaming: true,
    );
  }

  static ConversationMessage _convertToolUseResponse(
    ToolUseResponse response,
    DateTime timestamp,
  ) {
    return ConversationMessage.assistant(
      id: response.id,
      responses: [response],
      isComplete: false,
      isStreaming: true,
    );
  }

  static ConversationMessage _convertToolResultResponse(
    ToolResultResponse response,
    DateTime timestamp,
  ) {
    // Tool results are returned as assistant messages to be merged
    return ConversationMessage.assistant(
      id: response.id,
      responses: [response],
      isComplete: false,
      isStreaming: true,
    );
  }

  static ConversationMessage _convertCompactBoundaryResponse(
    CompactBoundaryResponse response,
    DateTime timestamp,
  ) {
    return ConversationMessage.compactBoundary(
      id: response.id,
      timestamp: timestamp,
      trigger: response.trigger,
      preTokens: response.preTokens,
    );
  }

  static ConversationMessage _convertCompactSummaryResponse(
    CompactSummaryResponse response,
    DateTime timestamp,
  ) {
    return ConversationMessage.user(
      content: response.content,
      isCompactSummary: true,
      isVisibleInTranscriptOnly: response.isVisibleInTranscriptOnly,
    );
  }

  static ConversationMessage _convertUserMessageResponse(
    UserMessageResponse response,
    DateTime timestamp,
  ) {
    return ConversationMessage.user(
      content: response.content,
      isCompactSummary: false,
    );
  }

  static ConversationMessage _convertErrorResponse(
    ErrorResponse response,
    DateTime timestamp,
  ) {
    return ConversationMessage.assistant(
      id: response.id,
      responses: [response],
      isComplete: true,
      isStreaming: false,
    ).copyWith(error: response.error, messageType: MessageType.error);
  }

  static ConversationMessage _convertStatusResponse(
    StatusResponse response,
    DateTime timestamp,
  ) {
    return ConversationMessage.status(
      id: response.id,
      timestamp: timestamp,
      status: response.status,
      message: response.message,
      response: response,
    );
  }

  static ConversationMessage _convertMetaResponse(
    MetaResponse response,
    DateTime timestamp,
  ) {
    return ConversationMessage.meta(
      id: response.id,
      timestamp: timestamp,
      conversationId: response.conversationId,
      metadata: response.metadata,
      response: response,
    );
  }

  static ConversationMessage _convertCompletionResponse(
    CompletionResponse response,
    DateTime timestamp,
  ) {
    return ConversationMessage.completion(
      id: response.id,
      timestamp: timestamp,
      response: response,
    );
  }

  static ConversationMessage _convertUnknownResponse(
    UnknownResponse response,
    DateTime timestamp,
  ) {
    return ConversationMessage.unknown(
      id: response.id,
      timestamp: timestamp,
      response: response,
    );
  }
}

/// Parses JSONL content and converts to ConversationMessages using unified parsing.
///
/// This replaces the manual parsing in ConversationLoader with the unified
/// ClaudeResponse parsing pipeline.
class JsonlMessageParser {
  /// Parse a single JSONL line and return the appropriate ClaudeResponse.
  ///
  /// Returns null if the line should be skipped.
  static ClaudeResponse? parseLine(Map<String, dynamic> json) {
    // Skip meta messages
    final isMeta = json['isMeta'] as bool? ?? false;
    if (isMeta) return null;

    // Use the unified ClaudeResponse parsing
    final response = ClaudeResponse.fromJson(json);

    // Filter out unknown responses
    if (response is UnknownResponse) return null;

    return response;
  }

  /// Parse multiple JSONL lines into ClaudeResponse objects.
  ///
  /// For assistant messages with multiple content blocks, this expands
  /// them into separate responses to preserve interleaving.
  static List<ClaudeResponse> parseLineMultiple(Map<String, dynamic> json) {
    // Skip meta messages
    final isMeta = json['isMeta'] as bool? ?? false;
    if (isMeta) return [];

    // Use the unified ClaudeResponse parsing (handles expansion)
    final responses = ClaudeResponse.fromJsonMultiple(json);

    // Filter out unknown responses
    return responses.where((r) => r is! UnknownResponse).toList();
  }

  /// Extract usage data from a JSONL line.
  static UsageData? extractUsage(Map<String, dynamic> json) {
    final messageData = json['message'] as Map<String, dynamic>?;
    if (messageData == null) return null;

    final usage = messageData['usage'] as Map<String, dynamic>?;
    if (usage == null) return null;

    final inputTokens = usage['input_tokens'] as int? ?? 0;
    final cacheRead = usage['cache_read_input_tokens'] as int? ?? 0;
    final cacheCreation = usage['cache_creation_input_tokens'] as int? ?? 0;

    // Only return if we have meaningful data
    if (inputTokens == 0 && cacheRead == 0 && cacheCreation == 0) {
      return null;
    }

    return UsageData(
      inputTokens: inputTokens,
      cacheReadTokens: cacheRead,
      cacheCreationTokens: cacheCreation,
    );
  }

  /// Extract the message ID from a JSONL line.
  static String? extractMessageId(Map<String, dynamic> json) {
    final messageData = json['message'] as Map<String, dynamic>?;
    return messageData?['id'] as String?;
  }
}

/// Usage data extracted from JSONL.
class UsageData {
  final int inputTokens;
  final int cacheReadTokens;
  final int cacheCreationTokens;

  const UsageData({
    required this.inputTokens,
    required this.cacheReadTokens,
    required this.cacheCreationTokens,
  });
}
