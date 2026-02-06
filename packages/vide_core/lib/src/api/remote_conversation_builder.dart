/// Conversation state builder for remote sessions.
///
/// Extracts the conversation building logic from [RemoteVideSession] into a
/// composable component. This manages per-agent [Conversation] objects,
/// handling message streaming, tool use/result grouping, and history replay.
library;

import 'dart:async';

import 'package:claude_sdk/claude_sdk.dart';
import 'package:uuid/uuid.dart';

/// Builds and maintains [Conversation] state from remote session events.
///
/// Remote sessions receive streaming message chunks, tool use events, and tool
/// result events over the wire. This class accumulates those into coherent
/// [Conversation] objects per agent, handling:
///
/// - Streaming message chunk accumulation
/// - History replay (non-accumulating)
/// - Tool use/result grouping into assistant messages
/// - Optimistic user message deduplication
/// - Per-agent conversation stream notifications
class RemoteConversationBuilder {
  /// Conversation state per agent.
  final Map<String, Conversation> _conversations = {};

  /// Stream controllers for conversation updates per agent.
  final Map<String, StreamController<Conversation>> _controllers = {};

  /// Current message event IDs per agent (for streaming).
  final Map<String, String> _currentMessageEventIds = {};

  /// Current assistant message ID per agent (for grouping text + tool use + tool result).
  final Map<String, String> _currentAssistantMessageId = {};

  /// Get the current conversation for an agent.
  Conversation? getConversation(String agentId) => _conversations[agentId];

  /// Stream of conversation updates for an agent.
  Stream<Conversation> conversationStream(String agentId) {
    return _getOrCreateController(agentId).stream;
  }

  /// Handle a message event (user or assistant).
  ///
  /// For live streaming, assistant message chunks are accumulated into the
  /// current message. For [isHistoryReplay], messages are added directly
  /// (they are already consolidated).
  void handleMessage({
    required String agentId,
    required String eventId,
    required String role,
    required String content,
    required bool isPartial,
    bool isHistoryReplay = false,
  }) {
    // Track streaming state (skip for history replay - messages are already complete)
    if (!isHistoryReplay) {
      if (isPartial) {
        _currentMessageEventIds[agentId] = eventId;
      } else {
        _currentMessageEventIds.remove(agentId);
      }
    }

    var conversation = _conversations[agentId] ?? Conversation.empty();
    final messages = List<ConversationMessage>.from(conversation.messages);

    if (role == 'user') {
      _handleUserMessage(messages, agentId, eventId, content);
    } else if (isHistoryReplay) {
      _handleHistoryAssistantMessage(messages, eventId, content);
    } else {
      _handleStreamingAssistantMessage(
        messages,
        agentId,
        eventId,
        content,
        isPartial,
      );
    }

    final state = isPartial
        ? ConversationState.receivingResponse
        : ConversationState.idle;

    conversation = conversation.copyWith(messages: messages, state: state);
    _conversations[agentId] = conversation;
    _getOrCreateController(agentId).add(conversation);
  }

  /// Handle a tool use event.
  void handleToolUse({
    required String agentId,
    required String toolUseId,
    required String toolName,
    required Map<String, dynamic> toolInput,
  }) {
    var conversation = _conversations[agentId] ?? Conversation.empty();
    final messages = List<ConversationMessage>.from(conversation.messages);

    // Find or create the current assistant message
    var currentMsgId = _currentAssistantMessageId[agentId];
    var existingIndex = currentMsgId != null
        ? messages.indexWhere((m) => m.id == currentMsgId)
        : -1;

    if (existingIndex < 0) {
      // No current assistant message - create one
      currentMsgId = const Uuid().v4();
      _currentAssistantMessageId[agentId] = currentMsgId;
      messages.add(
        ConversationMessage(
          id: currentMsgId,
          role: MessageRole.assistant,
          content: '',
          timestamp: DateTime.now(),
          responses: [],
          isStreaming: true,
          isComplete: false,
          messageType: MessageType.assistantText,
        ),
      );
      existingIndex = messages.length - 1;
    }

    // Add ToolUseResponse to the current assistant message
    final existing = messages[existingIndex];
    final responses = List<ClaudeResponse>.from(existing.responses);
    responses.add(
      ToolUseResponse(
        id: toolUseId,
        timestamp: DateTime.now(),
        toolName: toolName,
        parameters: toolInput,
        toolUseId: toolUseId,
      ),
    );

    messages[existingIndex] = ConversationMessage(
      id: existing.id,
      role: MessageRole.assistant,
      content: existing.content,
      timestamp: existing.timestamp,
      responses: responses,
      isStreaming: true,
      isComplete: false,
      messageType: MessageType.assistantText,
    );

    conversation = conversation.copyWith(
      messages: messages,
      state: ConversationState.processing,
    );
    _conversations[agentId] = conversation;
    _getOrCreateController(agentId).add(conversation);
  }

  /// Handle a tool result event.
  void handleToolResult({
    required String agentId,
    required String toolUseId,
    required String result,
    required bool isError,
  }) {
    var conversation = _conversations[agentId] ?? Conversation.empty();
    final messages = List<ConversationMessage>.from(conversation.messages);

    // Find the current assistant message
    final currentMsgId = _currentAssistantMessageId[agentId];
    final existingIndex = currentMsgId != null
        ? messages.indexWhere((m) => m.id == currentMsgId)
        : -1;

    if (existingIndex >= 0) {
      // Add ToolResultResponse to the current assistant message
      final existing = messages[existingIndex];
      final responses = List<ClaudeResponse>.from(existing.responses);
      responses.add(
        ToolResultResponse(
          id: '${toolUseId}_result',
          timestamp: DateTime.now(),
          toolUseId: toolUseId,
          content: result,
          isError: isError,
        ),
      );

      messages[existingIndex] = ConversationMessage(
        id: existing.id,
        role: MessageRole.assistant,
        content: existing.content,
        timestamp: existing.timestamp,
        responses: responses,
        isStreaming: true,
        isComplete: false,
        messageType: MessageType.assistantText,
      );
    }

    conversation = conversation.copyWith(
      messages: messages,
      state: ConversationState.processing,
    );
    _conversations[agentId] = conversation;
    _getOrCreateController(agentId).add(conversation);
  }

  /// Mark the current assistant turn as complete for an agent.
  void markAssistantTurnComplete(String agentId) {
    final currentMsgId = _currentAssistantMessageId.remove(agentId);
    if (currentMsgId == null) return;

    var conversation = _conversations[agentId];
    if (conversation == null) return;

    final messages = List<ConversationMessage>.from(conversation.messages);
    final existingIndex = messages.indexWhere((m) => m.id == currentMsgId);

    if (existingIndex >= 0) {
      final existing = messages[existingIndex];
      messages[existingIndex] = ConversationMessage(
        id: existing.id,
        role: existing.role,
        content: existing.content,
        timestamp: existing.timestamp,
        responses: existing.responses,
        isStreaming: false,
        isComplete: true,
        messageType: existing.messageType,
      );

      conversation = conversation.copyWith(
        messages: messages,
        state: ConversationState.idle,
      );
      _conversations[agentId] = conversation;
      _getOrCreateController(agentId).add(conversation);
    }
  }

  /// Add a user message directly (for optimistic display).
  ///
  /// Returns the updated conversation.
  Conversation addUserMessage(String agentId, String content) {
    var conversation = _conversations[agentId] ?? Conversation.empty();
    final messages = List<ConversationMessage>.from(conversation.messages);

    messages.add(
      ConversationMessage(
        id: const Uuid().v4(),
        role: MessageRole.user,
        content: content,
        timestamp: DateTime.now(),
        responses: [],
        isStreaming: false,
        isComplete: true,
        messageType: MessageType.userMessage,
      ),
    );

    conversation = conversation.copyWith(
      messages: messages,
      state: ConversationState.sendingMessage,
    );
    _conversations[agentId] = conversation;
    _getOrCreateController(agentId).add(conversation);
    return conversation;
  }

  /// Clear conversation state for an agent.
  void clearConversation(String agentId) {
    _conversations[agentId] = Conversation.empty();
    _getOrCreateController(agentId).add(Conversation.empty());
  }

  /// Migrate a conversation from one agent ID to another.
  ///
  /// Used when a pending session's placeholder agent is replaced with
  /// the real agent from the server's connected event.
  void migrateConversation({
    required String fromAgentId,
    required String toAgentId,
  }) {
    final conversation = _conversations.remove(fromAgentId);
    final oldController = _controllers.remove(fromAgentId);

    if (conversation != null) {
      _conversations[toAgentId] = conversation;
      _getOrCreateController(toAgentId).add(conversation);
    }

    oldController?.close();
  }

  /// Remove all conversation state for an agent.
  void removeAgent(String agentId) {
    _conversations.remove(agentId);
    _currentMessageEventIds.remove(agentId);
    _currentAssistantMessageId.remove(agentId);
    unawaited(_controllers.remove(agentId)?.close());
  }

  /// Dispose all resources.
  void dispose() {
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
    _conversations.clear();
    _currentMessageEventIds.clear();
    _currentAssistantMessageId.clear();
  }

  // ============================================================
  // Private helpers
  // ============================================================

  void _handleUserMessage(
    List<ConversationMessage> messages,
    String agentId,
    String eventId,
    String content,
  ) {
    // Check if this user message already exists (from optimistic add)
    // We compare by content since IDs may differ between optimistic and server events
    // Check ALL recent user messages, not just the last one, because an assistant
    // message might have started before the server echoes back the user message
    final isDuplicate = messages.any(
      (m) => m.role == MessageRole.user && m.content == content,
    );

    if (!isDuplicate) {
      messages.add(
        ConversationMessage(
          id: eventId,
          role: MessageRole.user,
          content: content,
          timestamp: DateTime.now(),
          responses: [],
          isStreaming: false,
          isComplete: true,
          messageType: MessageType.userMessage,
        ),
      );
    }
    // Clear any current assistant message tracking since user started new turn
    _currentAssistantMessageId.remove(agentId);
  }

  void _handleHistoryAssistantMessage(
    List<ConversationMessage> messages,
    String eventId,
    String content,
  ) {
    // History replay - add message directly without accumulation
    // Check for duplicate by eventId first
    final existingIndex = messages.indexWhere((m) => m.id == eventId);
    if (existingIndex >= 0) {
      // Update existing message (shouldn't happen with proper consolidation)
      final existing = messages[existingIndex];
      messages[existingIndex] = ConversationMessage(
        id: existing.id,
        role: MessageRole.assistant,
        content: content,
        timestamp: existing.timestamp,
        responses: [
          if (content.isNotEmpty)
            TextResponse(
              id: const Uuid().v4(),
              timestamp: DateTime.now(),
              content: content,
              isPartial: false,
            ),
        ],
        isStreaming: false,
        isComplete: true,
        messageType: MessageType.assistantText,
      );
    } else {
      // Add new message
      messages.add(
        ConversationMessage(
          id: eventId,
          role: MessageRole.assistant,
          content: content,
          timestamp: DateTime.now(),
          responses: [
            if (content.isNotEmpty)
              TextResponse(
                id: const Uuid().v4(),
                timestamp: DateTime.now(),
                content: content,
                isPartial: false,
              ),
          ],
          isStreaming: false,
          isComplete: true,
          messageType: MessageType.assistantText,
        ),
      );
    }
  }

  void _handleStreamingAssistantMessage(
    List<ConversationMessage> messages,
    String agentId,
    String eventId,
    String content,
    bool isPartial,
  ) {
    // Live streaming - accumulate chunks into current message
    final currentMsgId = _currentAssistantMessageId[agentId];
    final existingIndex = currentMsgId != null
        ? messages.indexWhere((m) => m.id == currentMsgId)
        : -1;

    if (existingIndex >= 0) {
      // Add text to existing assistant message
      final existing = messages[existingIndex];
      final newContent = existing.content + content;
      final responses = List<ClaudeResponse>.from(existing.responses);

      if (content.isNotEmpty) {
        responses.add(
          TextResponse(
            id: const Uuid().v4(),
            timestamp: DateTime.now(),
            content: content,
            isPartial: true,
          ),
        );
      }

      messages[existingIndex] = ConversationMessage(
        id: existing.id,
        role: MessageRole.assistant,
        content: newContent,
        timestamp: existing.timestamp,
        responses: responses,
        isStreaming: isPartial,
        isComplete: !isPartial,
        messageType: MessageType.assistantText,
      );
    } else {
      // Create new assistant message
      final newMsgId = eventId;
      _currentAssistantMessageId[agentId] = newMsgId;

      final responses = <ClaudeResponse>[];
      if (content.isNotEmpty) {
        responses.add(
          TextResponse(
            id: const Uuid().v4(),
            timestamp: DateTime.now(),
            content: content,
            isPartial: true,
          ),
        );
      }

      messages.add(
        ConversationMessage(
          id: newMsgId,
          role: MessageRole.assistant,
          content: content,
          timestamp: DateTime.now(),
          responses: responses,
          isStreaming: isPartial,
          isComplete: !isPartial,
          messageType: MessageType.assistantText,
        ),
      );
    }

    // Clear tracking when turn completes
    if (!isPartial) {
      _currentAssistantMessageId.remove(agentId);
    }
  }

  StreamController<Conversation> _getOrCreateController(String agentId) {
    return _controllers.putIfAbsent(
      agentId,
      () => StreamController<Conversation>.broadcast(),
    );
  }
}
