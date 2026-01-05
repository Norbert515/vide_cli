import '../models/response.dart';
import '../models/conversation.dart';

/// Result of processing a response.
class ProcessResult {
  /// The updated conversation after processing the response.
  final Conversation updatedConversation;

  /// Whether the turn is complete (assistant finished responding).
  final bool turnComplete;

  ProcessResult({
    required this.updatedConversation,
    required this.turnComplete,
  });
}

/// Processes Claude responses and updates conversation state.
///
/// This class uses a visitor pattern to handle different response types,
/// making it easy to add new response types without modifying the core logic.
class ResponseProcessor {
  /// Process a ClaudeResponse and update conversation state.
  ///
  /// Returns a [ProcessResult] containing the updated conversation
  /// and whether the turn is complete.
  ProcessResult processResponse(
    ClaudeResponse response,
    Conversation currentConversation,
  ) {
    // Use exhaustive pattern matching for type-safe handling
    return switch (response) {
      TextResponse r => _processTextResponse(r, currentConversation),
      ToolUseResponse r => _processToolResponse(r, currentConversation),
      ToolResultResponse r => _processToolResponse(r, currentConversation),
      CompletionResponse r => _processCompletionResponse(
        r,
        currentConversation,
      ),
      ErrorResponse r => _processErrorResponse(r, currentConversation),
      CompactBoundaryResponse r => _processCompactBoundaryResponse(
        r,
        currentConversation,
      ),
      CompactSummaryResponse r => _processCompactSummaryResponse(
        r,
        currentConversation,
      ),
      UserMessageResponse r => _processUserMessageResponse(
        r,
        currentConversation,
      ),
      // Non-message responses - pass through unchanged
      StatusResponse() => _passThrough(currentConversation),
      MetaResponse() => _passThrough(currentConversation),
      UnknownResponse() => _passThrough(currentConversation),
    };
  }

  ProcessResult _passThrough(Conversation conversation) {
    return ProcessResult(
      updatedConversation: conversation,
      turnComplete: false,
    );
  }

  ProcessResult _processTextResponse(
    TextResponse response,
    Conversation currentConversation,
  ) {
    final context = _getAssistantMessageContext(currentConversation);
    final responses = _appendResponse(context, response);

    // Extract usage if available
    final usage = _extractUsageFromRawData(response.rawData);

    // Check if this is truly a complete turn
    final stopReason = response.rawData?['message']?['stop_reason'] as String?;
    final isTurnComplete = stopReason == 'end_turn';

    final message = ConversationMessage.assistant(
      id: context.messageId,
      responses: responses,
      isStreaming: !isTurnComplete,
      isComplete: isTurnComplete,
    );

    var updatedConversation = _updateOrAddMessage(
      currentConversation,
      message,
      context.isExistingMessage,
      ConversationState.receivingResponse,
    );

    // Update tokens whenever usage is available
    if (usage != null) {
      updatedConversation = _updateUsage(updatedConversation, usage);
    }

    // Set state to idle only if turn is complete
    if (isTurnComplete) {
      updatedConversation = updatedConversation.withState(
        ConversationState.idle,
      );
    }

    return ProcessResult(
      updatedConversation: updatedConversation,
      turnComplete: isTurnComplete,
    );
  }

  ProcessResult _processToolResponse(
    ClaudeResponse response,
    Conversation currentConversation,
  ) {
    final context = _getAssistantMessageContext(currentConversation);
    final responses = _appendResponse(context, response);

    // Extract usage if available
    final usage = _extractUsageFromRawData(response.rawData);

    final message = ConversationMessage.assistant(
      id: context.messageId,
      responses: responses,
      isStreaming: true, // Tool operations always continue
    );

    var updatedConversation = _updateOrAddMessage(
      currentConversation,
      message,
      context.isExistingMessage,
      ConversationState.processing,
    );

    // Ensure state is processing for tool operations
    if (updatedConversation.state != ConversationState.processing) {
      updatedConversation = updatedConversation.withState(
        ConversationState.processing,
      );
    }

    // Update usage if available
    if (usage != null) {
      updatedConversation = _updateUsage(updatedConversation, usage);
    }

    return ProcessResult(
      updatedConversation: updatedConversation,
      turnComplete: false,
    );
  }

  ProcessResult _processCompletionResponse(
    CompletionResponse response,
    Conversation currentConversation,
  ) {
    final context = _getAssistantMessageContext(currentConversation);
    final responses = _appendResponse(context, response);

    final message = ConversationMessage.assistant(
      id: context.messageId,
      responses: responses,
      isStreaming: false,
      isComplete: true,
    );

    Conversation updatedConversation;
    if (context.isExistingMessage) {
      updatedConversation = currentConversation.updateLastMessage(message);
    } else {
      updatedConversation = currentConversation.addMessage(message);
    }

    // Always set to idle for completion and update token counts
    updatedConversation = updatedConversation
        .withState(ConversationState.idle)
        .copyWith(
          totalInputTokens:
              currentConversation.totalInputTokens +
              (response.inputTokens ?? 0),
          totalOutputTokens:
              currentConversation.totalOutputTokens +
              (response.outputTokens ?? 0),
          totalCacheReadInputTokens:
              currentConversation.totalCacheReadInputTokens +
              (response.cacheReadInputTokens ?? 0),
          totalCacheCreationInputTokens:
              currentConversation.totalCacheCreationInputTokens +
              (response.cacheCreationInputTokens ?? 0),
          totalCostUsd:
              currentConversation.totalCostUsd + (response.totalCostUsd ?? 0.0),
        );

    return ProcessResult(
      updatedConversation: updatedConversation,
      turnComplete: true,
    );
  }

  ProcessResult _processErrorResponse(
    ErrorResponse response,
    Conversation currentConversation,
  ) {
    final context = _getAssistantMessageContext(currentConversation);
    final responses = _appendResponse(context, response);

    final message = ConversationMessage.assistant(
      id: context.messageId,
      responses: responses,
      isStreaming: false,
      isComplete: true,
    ).copyWith(error: response.error);

    final updatedConversation = _updateOrAddMessage(
      currentConversation,
      message,
      context.isExistingMessage,
      ConversationState.idle,
    ).withError(response.error);

    return ProcessResult(
      updatedConversation: updatedConversation,
      turnComplete: true,
    );
  }

  ProcessResult _processCompactBoundaryResponse(
    CompactBoundaryResponse response,
    Conversation currentConversation,
  ) {
    final message = ConversationMessage.compactBoundary(
      id: response.id,
      timestamp: response.timestamp,
      trigger: response.trigger,
      preTokens: response.preTokens,
    );

    return ProcessResult(
      updatedConversation: currentConversation.addMessage(message),
      turnComplete: false,
    );
  }

  ProcessResult _processCompactSummaryResponse(
    CompactSummaryResponse response,
    Conversation currentConversation,
  ) {
    final message = ConversationMessage.user(
      content: response.content,
      isCompactSummary: true,
      isVisibleInTranscriptOnly: response.isVisibleInTranscriptOnly,
    );

    return ProcessResult(
      updatedConversation: currentConversation.addMessage(message),
      turnComplete: false,
    );
  }

  ProcessResult _processUserMessageResponse(
    UserMessageResponse response,
    Conversation currentConversation,
  ) {
    final message = ConversationMessage.user(content: response.content);

    return ProcessResult(
      updatedConversation: currentConversation.addMessage(message),
      turnComplete: false,
    );
  }

  // Helper methods

  /// Get context about the current assistant message (for appending responses).
  _AssistantMessageContext _getAssistantMessageContext(
    Conversation conversation,
  ) {
    final existingMessage = conversation.messages.lastOrNull;
    final isExistingMessage =
        existingMessage?.role == MessageRole.assistant &&
        existingMessage?.isStreaming == true;

    return _AssistantMessageContext(
      messageId: isExistingMessage
          ? existingMessage!.id
          : DateTime.now().millisecondsSinceEpoch.toString(),
      existingResponses: isExistingMessage ? existingMessage!.responses : [],
      isExistingMessage: isExistingMessage,
    );
  }

  /// Append a response to existing responses.
  List<ClaudeResponse> _appendResponse(
    _AssistantMessageContext context,
    ClaudeResponse response,
  ) {
    return [...context.existingResponses, response];
  }

  /// Update or add a message to the conversation.
  Conversation _updateOrAddMessage(
    Conversation conversation,
    ConversationMessage message,
    bool isExistingMessage,
    ConversationState newState,
  ) {
    if (isExistingMessage) {
      return conversation.updateLastMessage(message);
    } else {
      return conversation.addMessage(message).withState(newState);
    }
  }

  /// Update conversation with usage data.
  Conversation _updateUsage(Conversation conversation, _UsageData usage) {
    return conversation.copyWith(
      // Accumulate totals
      totalInputTokens: conversation.totalInputTokens + usage.inputTokens,
      totalOutputTokens: conversation.totalOutputTokens + usage.outputTokens,
      totalCacheReadInputTokens:
          conversation.totalCacheReadInputTokens + usage.cacheReadInputTokens,
      totalCacheCreationInputTokens:
          conversation.totalCacheCreationInputTokens +
          usage.cacheCreationInputTokens,
      // Replace current context values
      currentContextInputTokens: usage.inputTokens,
      currentContextCacheReadTokens: usage.cacheReadInputTokens,
      currentContextCacheCreationTokens: usage.cacheCreationInputTokens,
    );
  }

  /// Extracts usage data from the raw JSON data of an assistant message.
  _UsageData? _extractUsageFromRawData(Map<String, dynamic>? rawData) {
    if (rawData == null) return null;

    // Try message.usage first (Claude CLI format)
    final messageUsage = rawData['message']?['usage'] as Map<String, dynamic>?;
    if (messageUsage != null) {
      return _UsageData(
        inputTokens: messageUsage['input_tokens'] as int? ?? 0,
        outputTokens: messageUsage['output_tokens'] as int? ?? 0,
        cacheReadInputTokens:
            messageUsage['cache_read_input_tokens'] as int? ?? 0,
        cacheCreationInputTokens:
            messageUsage['cache_creation_input_tokens'] as int? ?? 0,
      );
    }

    // Fallback: try top-level usage (direct API format)
    final usage = rawData['usage'] as Map<String, dynamic>?;
    if (usage != null) {
      return _UsageData(
        inputTokens: usage['input_tokens'] as int? ?? 0,
        outputTokens: usage['output_tokens'] as int? ?? 0,
        cacheReadInputTokens: usage['cache_read_input_tokens'] as int? ?? 0,
        cacheCreationInputTokens:
            usage['cache_creation_input_tokens'] as int? ?? 0,
      );
    }

    return null;
  }
}

/// Context about an assistant message being built.
class _AssistantMessageContext {
  final String messageId;
  final List<ClaudeResponse> existingResponses;
  final bool isExistingMessage;

  _AssistantMessageContext({
    required this.messageId,
    required this.existingResponses,
    required this.isExistingMessage,
  });
}

/// Internal class to hold extracted usage data.
class _UsageData {
  final int inputTokens;
  final int outputTokens;
  final int cacheReadInputTokens;
  final int cacheCreationInputTokens;

  const _UsageData({
    required this.inputTokens,
    required this.outputTokens,
    required this.cacheReadInputTokens,
    required this.cacheCreationInputTokens,
  });
}
