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
    final message = ConversationMessage.assistant(
      id: isAssistantMessage ? existingMessage!.id : assistantId,
      responses: responses,
      isStreaming: true,
    );

    Conversation updatedConversation;
    if (isAssistantMessage) {
      updatedConversation = currentConversation.updateLastMessage(message);
    } else {
      updatedConversation = currentConversation
          .addMessage(message)
          .withState(ConversationState.receivingResponse);
    }

    return ProcessResult(
      updatedConversation: updatedConversation,
      turnComplete: false,
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
    final message = ConversationMessage.assistant(
      id: isAssistantMessage ? existingMessage!.id : assistantId,
      responses: responses,
      isStreaming: true,
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

    return ProcessResult(
      updatedConversation: updatedConversation,
      turnComplete: false,
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
}
