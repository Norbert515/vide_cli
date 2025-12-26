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
/// This class extracts the response processing logic from ClaudeClientImpl
/// to provide a testable, single-responsibility component for handling
/// different response types and updating conversation state accordingly.
class ResponseProcessor {
  /// Process a ClaudeResponse and update conversation state.
  ///
  /// Returns a [ProcessResult] containing the updated conversation
  /// and whether the turn is complete.
  ProcessResult processResponse(
    ClaudeResponse response,
    Conversation currentConversation,
  ) {
    // Generate a new assistant ID for new messages
    final assistantId = DateTime.now().millisecondsSinceEpoch.toString();

    // Check if we should append to existing assistant message
    final existingMessage = currentConversation.messages.lastOrNull;
    final isAssistantMessage =
        existingMessage?.role == MessageRole.assistant &&
            existingMessage?.isStreaming == true;

    // Build responses list
    List<ClaudeResponse> responses;
    if (isAssistantMessage) {
      responses = [...existingMessage!.responses, response];
    } else {
      responses = [response];
    }

    if (response is TextResponse) {
      return _processTextResponse(
        response,
        currentConversation,
        assistantId,
        existingMessage,
        isAssistantMessage,
        responses,
      );
    } else if (response is ToolUseResponse || response is ToolResultResponse) {
      return _processToolResponse(
        response,
        currentConversation,
        assistantId,
        existingMessage,
        isAssistantMessage,
        responses,
      );
    } else if (response is CompletionResponse) {
      return _processCompletionResponse(
        response,
        currentConversation,
        assistantId,
        existingMessage,
        isAssistantMessage,
        responses,
      );
    } else if (response is ErrorResponse) {
      return _processErrorResponse(
        response,
        currentConversation,
        assistantId,
        existingMessage,
        isAssistantMessage,
        responses,
      );
    } else {
      // StatusResponse, MetaResponse, UnknownResponse - ignore
      return ProcessResult(
        updatedConversation: currentConversation,
        turnComplete: false,
      );
    }
  }

  ProcessResult _processTextResponse(
    TextResponse response,
    Conversation currentConversation,
    String assistantId,
    ConversationMessage? existingMessage,
    bool isAssistantMessage,
    List<ClaudeResponse> responses,
  ) {
    // Extract usage if available
    final usage = _extractUsageFromRawData(response.rawData);

    // Check if this is truly a complete turn (end_turn stop_reason)
    // stop_reason="tool_use" means Claude wants to use a tool - turn is NOT complete
    // stop_reason="end_turn" means Claude is done - turn IS complete
    final stopReason = response.rawData?['message']?['stop_reason'] as String?;
    final isTurnComplete = stopReason == 'end_turn';

    final message = ConversationMessage.assistant(
      id: isAssistantMessage ? existingMessage!.id : assistantId,
      responses: responses,
      isStreaming: !isTurnComplete,
      isComplete: isTurnComplete,
    );

    Conversation updatedConversation;
    if (isAssistantMessage) {
      updatedConversation = currentConversation.updateLastMessage(message);
    } else {
      updatedConversation = currentConversation
          .addMessage(message)
          .withState(ConversationState.receivingResponse);
    }

    // Update tokens whenever usage is available
    if (usage != null) {
      updatedConversation = updatedConversation.copyWith(
        // Accumulate totals (for billing/stats)
        totalInputTokens:
            updatedConversation.totalInputTokens + usage.inputTokens,
        totalOutputTokens:
            updatedConversation.totalOutputTokens + usage.outputTokens,
        totalCacheReadInputTokens:
            updatedConversation.totalCacheReadInputTokens +
                usage.cacheReadInputTokens,
        totalCacheCreationInputTokens:
            updatedConversation.totalCacheCreationInputTokens +
                usage.cacheCreationInputTokens,
        // Replace current context values (for context window %)
        currentContextInputTokens: usage.inputTokens,
        currentContextCacheReadTokens: usage.cacheReadInputTokens,
        currentContextCacheCreationTokens: usage.cacheCreationInputTokens,
      );
    }

    // Set state to idle only if turn is complete
    if (isTurnComplete) {
      updatedConversation = updatedConversation.withState(ConversationState.idle);
    }

    return ProcessResult(
      updatedConversation: updatedConversation,
      turnComplete: isTurnComplete,
    );
  }

  ProcessResult _processToolResponse(
    ClaudeResponse response,
    Conversation currentConversation,
    String assistantId,
    ConversationMessage? existingMessage,
    bool isAssistantMessage,
    List<ClaudeResponse> responses,
  ) {
    // Extract usage if available - this indicates the response has stop_reason set
    final usage = _extractUsageFromRawData(response.rawData);

    final message = ConversationMessage.assistant(
      id: isAssistantMessage ? existingMessage!.id : assistantId,
      responses: responses,
      isStreaming: true, // Tool operations always continue (waiting for result)
    );

    Conversation updatedConversation;
    if (isAssistantMessage) {
      updatedConversation = currentConversation.updateLastMessage(message);
    } else {
      updatedConversation = currentConversation
          .addMessage(message)
          .withState(ConversationState.processing);
    }

    // Ensure state is processing for tool operations
    if (updatedConversation.state != ConversationState.processing) {
      updatedConversation =
          updatedConversation.withState(ConversationState.processing);
    }

    // Update usage if available (even during tool use, Claude reports usage)
    if (usage != null) {
      updatedConversation = updatedConversation.copyWith(
        // Accumulate totals (for billing/stats)
        totalInputTokens:
            updatedConversation.totalInputTokens + usage.inputTokens,
        totalOutputTokens:
            updatedConversation.totalOutputTokens + usage.outputTokens,
        totalCacheReadInputTokens:
            updatedConversation.totalCacheReadInputTokens +
                usage.cacheReadInputTokens,
        totalCacheCreationInputTokens:
            updatedConversation.totalCacheCreationInputTokens +
                usage.cacheCreationInputTokens,
        // Replace current context values (for context window %)
        currentContextInputTokens: usage.inputTokens,
        currentContextCacheReadTokens: usage.cacheReadInputTokens,
        currentContextCacheCreationTokens: usage.cacheCreationInputTokens,
      );
    }

    return ProcessResult(
      updatedConversation: updatedConversation,
      turnComplete: false, // Tool responses are never turn-complete, we wait for result
    );
  }

  ProcessResult _processCompletionResponse(
    CompletionResponse response,
    Conversation currentConversation,
    String assistantId,
    ConversationMessage? existingMessage,
    bool isAssistantMessage,
    List<ClaudeResponse> responses,
  ) {
    final message = ConversationMessage.assistant(
      id: isAssistantMessage ? existingMessage!.id : assistantId,
      responses: responses,
      isStreaming: false,
      isComplete: true,
    );

    final updatedConversation = (isAssistantMessage
            ? currentConversation.updateLastMessage(message)
            : currentConversation.addMessage(message))
        .withState(ConversationState.idle)
        .copyWith(
          totalInputTokens:
              currentConversation.totalInputTokens + (response.inputTokens ?? 0),
          totalOutputTokens:
              currentConversation.totalOutputTokens + (response.outputTokens ?? 0),
          totalCacheReadInputTokens: currentConversation.totalCacheReadInputTokens +
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
    String assistantId,
    ConversationMessage? existingMessage,
    bool isAssistantMessage,
    List<ClaudeResponse> responses,
  ) {
    final message = ConversationMessage.assistant(
      id: isAssistantMessage ? existingMessage!.id : assistantId,
      responses: responses,
      isStreaming: false,
      isComplete: true,
    ).copyWith(error: response.error);

    Conversation updatedConversation;
    if (isAssistantMessage) {
      updatedConversation = currentConversation
          .updateLastMessage(message)
          .withError(response.error);
    } else {
      updatedConversation =
          currentConversation.addMessage(message).withError(response.error);
    }

    return ProcessResult(
      updatedConversation: updatedConversation,
      turnComplete: true,
    );
  }

  /// Extracts usage data from the raw JSON data of an assistant message.
  ///
  /// The usage is typically at `rawData['message']['usage']` for Claude CLI output.
  /// Returns null if no usage data is found.
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
