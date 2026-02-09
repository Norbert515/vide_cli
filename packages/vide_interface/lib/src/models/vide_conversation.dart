/// Conversation types for the Vide interface boundary.
///
/// Replaces claude_sdk's Conversation at the public API surface.
library;

import 'enums.dart';
import 'vide_message.dart';

/// State of a conversation.
enum VideConversationState {
  idle,
  sendingMessage,
  receivingResponse,
  processing,
  error,
}

/// Type of a conversation message.
enum VideMessageType { userMessage, assistantText }

/// A response within a conversation message (text, tool use, or tool result).
sealed class VideResponse {
  final String id;
  final DateTime timestamp;

  const VideResponse({required this.id, required this.timestamp});
}

/// A text response chunk.
final class VideTextResponse extends VideResponse {
  final String content;
  final bool isPartial;

  /// Whether this response contains cumulative content (full text up to this point)
  /// rather than sequential/delta content.
  /// When true, only the last cumulative response should be used to avoid duplicates.
  final bool isCumulative;

  const VideTextResponse({
    required super.id,
    required super.timestamp,
    required this.content,
    this.isPartial = false,
    this.isCumulative = false,
  });
}

/// A tool use response.
final class VideToolUseResponse extends VideResponse {
  final String toolName;
  final Map<String, dynamic> parameters;
  final String? toolUseId;

  const VideToolUseResponse({
    required super.id,
    required super.timestamp,
    required this.toolName,
    required this.parameters,
    this.toolUseId,
  });
}

/// A tool result response.
final class VideToolResultResponse extends VideResponse {
  final String toolUseId;
  final String content;
  final bool isError;

  const VideToolResultResponse({
    required super.id,
    required super.timestamp,
    required this.toolUseId,
    required this.content,
    this.isError = false,
  });
}

/// A single message in a conversation.
class VideConversationMessage {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final List<VideResponse> responses;
  final bool isStreaming;
  final bool isComplete;
  final VideMessageType messageType;

  /// Attachments included with this message (user messages only).
  final List<VideAttachment>? attachments;

  const VideConversationMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    required this.responses,
    this.isStreaming = false,
    this.isComplete = true,
    required this.messageType,
    this.attachments,
  });

  VideConversationMessage copyWith({
    String? id,
    MessageRole? role,
    String? content,
    DateTime? timestamp,
    List<VideResponse>? responses,
    bool? isStreaming,
    bool? isComplete,
    VideMessageType? messageType,
    List<VideAttachment>? attachments,
  }) {
    return VideConversationMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      responses: responses ?? this.responses,
      isStreaming: isStreaming ?? this.isStreaming,
      isComplete: isComplete ?? this.isComplete,
      messageType: messageType ?? this.messageType,
      attachments: attachments ?? this.attachments,
    );
  }
}

/// An active conversation with an agent.
class VideConversation {
  final List<VideConversationMessage> messages;
  final VideConversationState state;

  /// Whether the conversation is currently processing.
  bool get isProcessing =>
      state == VideConversationState.receivingResponse ||
      state == VideConversationState.processing ||
      state == VideConversationState.sendingMessage;

  /// Current error message, if any.
  final String? currentError;

  // Token usage (accumulated totals)
  final int totalInputTokens;
  final int totalOutputTokens;
  final int totalCacheReadInputTokens;
  final int totalCacheCreationInputTokens;
  final double totalCostUsd;

  // Current context window usage (from latest turn)
  final int currentContextInputTokens;
  final int currentContextCacheReadTokens;
  final int currentContextCacheCreationTokens;

  const VideConversation({
    this.messages = const [],
    this.state = VideConversationState.idle,
    this.currentError,
    this.totalInputTokens = 0,
    this.totalOutputTokens = 0,
    this.totalCacheReadInputTokens = 0,
    this.totalCacheCreationInputTokens = 0,
    this.totalCostUsd = 0.0,
    this.currentContextInputTokens = 0,
    this.currentContextCacheReadTokens = 0,
    this.currentContextCacheCreationTokens = 0,
  });

  /// Empty conversation.
  static const VideConversation empty = VideConversation();

  VideConversation copyWith({
    List<VideConversationMessage>? messages,
    VideConversationState? state,
    String? currentError,
    int? totalInputTokens,
    int? totalOutputTokens,
    int? totalCacheReadInputTokens,
    int? totalCacheCreationInputTokens,
    double? totalCostUsd,
    int? currentContextInputTokens,
    int? currentContextCacheReadTokens,
    int? currentContextCacheCreationTokens,
  }) {
    return VideConversation(
      messages: messages ?? this.messages,
      state: state ?? this.state,
      currentError: currentError ?? this.currentError,
      totalInputTokens: totalInputTokens ?? this.totalInputTokens,
      totalOutputTokens: totalOutputTokens ?? this.totalOutputTokens,
      totalCacheReadInputTokens:
          totalCacheReadInputTokens ?? this.totalCacheReadInputTokens,
      totalCacheCreationInputTokens:
          totalCacheCreationInputTokens ?? this.totalCacheCreationInputTokens,
      totalCostUsd: totalCostUsd ?? this.totalCostUsd,
      currentContextInputTokens:
          currentContextInputTokens ?? this.currentContextInputTokens,
      currentContextCacheReadTokens:
          currentContextCacheReadTokens ?? this.currentContextCacheReadTokens,
      currentContextCacheCreationTokens:
          currentContextCacheCreationTokens ??
          this.currentContextCacheCreationTokens,
    );
  }
}
