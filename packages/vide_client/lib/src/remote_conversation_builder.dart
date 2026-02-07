/// Conversation state builder for remote sessions.
///
/// Manages per-agent [VideConversation] objects, handling message streaming,
/// tool use/result grouping, and history replay.
library;

import 'dart:async';

import 'package:uuid/uuid.dart';
import 'package:vide_interface/vide_interface.dart';

/// Builds and maintains [VideConversation] state from remote session events.
///
/// Remote sessions receive streaming message chunks, tool use events, and tool
/// result events over the wire. This class accumulates those into coherent
/// [VideConversation] objects per agent, handling:
///
/// - Streaming message chunk accumulation
/// - History replay (non-accumulating)
/// - Tool use/result grouping into assistant messages
/// - Optimistic user message deduplication
/// - Per-agent conversation stream notifications
class RemoteConversationBuilder {
  /// Conversation state per agent.
  final Map<String, VideConversation> _conversations = {};

  /// Stream controllers for conversation updates per agent.
  final Map<String, StreamController<VideConversation>> _controllers = {};

  /// Current message event IDs per agent (for streaming).
  final Map<String, String> _currentMessageEventIds = {};

  /// Current assistant message ID per agent (for grouping text + tool use + tool result).
  final Map<String, String> _currentAssistantMessageId = {};

  /// Get the current conversation for an agent.
  VideConversation? getConversation(String agentId) => _conversations[agentId];

  /// Stream of conversation updates for an agent.
  Stream<VideConversation> conversationStream(String agentId) {
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

    var conversation = _conversations[agentId] ?? const VideConversation();
    final messages = List<VideConversationMessage>.from(conversation.messages);

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
        ? VideConversationState.receivingResponse
        : VideConversationState.idle;

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
    var conversation = _conversations[agentId] ?? const VideConversation();
    final messages = List<VideConversationMessage>.from(conversation.messages);

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
        VideConversationMessage(
          id: currentMsgId,
          role: MessageRole.assistant,
          content: '',
          timestamp: DateTime.now(),
          responses: const [],
          isStreaming: true,
          isComplete: false,
          messageType: VideMessageType.assistantText,
        ),
      );
      existingIndex = messages.length - 1;
    }

    // Add ToolUseResponse to the current assistant message
    final existing = messages[existingIndex];
    final responses = List<VideResponse>.from(existing.responses);
    responses.add(
      VideToolUseResponse(
        id: toolUseId,
        timestamp: DateTime.now(),
        toolName: toolName,
        parameters: toolInput,
        toolUseId: toolUseId,
      ),
    );

    messages[existingIndex] = existing.copyWith(
      responses: responses,
      isStreaming: true,
      isComplete: false,
    );

    conversation = conversation.copyWith(
      messages: messages,
      state: VideConversationState.processing,
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
    var conversation = _conversations[agentId] ?? const VideConversation();
    final messages = List<VideConversationMessage>.from(conversation.messages);

    // Find the current assistant message
    final currentMsgId = _currentAssistantMessageId[agentId];
    final existingIndex = currentMsgId != null
        ? messages.indexWhere((m) => m.id == currentMsgId)
        : -1;

    if (existingIndex >= 0) {
      // Add ToolResultResponse to the current assistant message
      final existing = messages[existingIndex];
      final responses = List<VideResponse>.from(existing.responses);
      responses.add(
        VideToolResultResponse(
          id: '${toolUseId}_result',
          timestamp: DateTime.now(),
          toolUseId: toolUseId,
          content: result,
          isError: isError,
        ),
      );

      messages[existingIndex] = existing.copyWith(
        responses: responses,
        isStreaming: true,
        isComplete: false,
      );
    }

    conversation = conversation.copyWith(
      messages: messages,
      state: VideConversationState.processing,
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

    final messages = List<VideConversationMessage>.from(conversation.messages);
    final existingIndex = messages.indexWhere((m) => m.id == currentMsgId);

    if (existingIndex >= 0) {
      messages[existingIndex] = messages[existingIndex].copyWith(
        isStreaming: false,
        isComplete: true,
      );

      conversation = conversation.copyWith(
        messages: messages,
        state: VideConversationState.idle,
      );
      _conversations[agentId] = conversation;
      _getOrCreateController(agentId).add(conversation);
    }
  }

  /// Add a user message directly (for optimistic display).
  ///
  /// Returns the updated conversation.
  VideConversation addUserMessage(String agentId, String content) {
    var conversation = _conversations[agentId] ?? const VideConversation();
    final messages = List<VideConversationMessage>.from(conversation.messages);

    messages.add(
      VideConversationMessage(
        id: const Uuid().v4(),
        role: MessageRole.user,
        content: content,
        timestamp: DateTime.now(),
        responses: const [],
        isStreaming: false,
        isComplete: true,
        messageType: VideMessageType.userMessage,
      ),
    );

    conversation = conversation.copyWith(
      messages: messages,
      state: VideConversationState.sendingMessage,
    );
    _conversations[agentId] = conversation;
    _getOrCreateController(agentId).add(conversation);
    return conversation;
  }

  /// Clear conversation state for an agent.
  void clearConversation(String agentId) {
    _conversations[agentId] = const VideConversation();
    _getOrCreateController(agentId).add(const VideConversation());
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
    List<VideConversationMessage> messages,
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
        VideConversationMessage(
          id: eventId,
          role: MessageRole.user,
          content: content,
          timestamp: DateTime.now(),
          responses: const [],
          isStreaming: false,
          isComplete: true,
          messageType: VideMessageType.userMessage,
        ),
      );
    }
    // Clear any current assistant message tracking since user started new turn
    _currentAssistantMessageId.remove(agentId);
  }

  void _handleHistoryAssistantMessage(
    List<VideConversationMessage> messages,
    String eventId,
    String content,
  ) {
    // History replay - add message directly without accumulation
    // Check for duplicate by eventId first
    final existingIndex = messages.indexWhere((m) => m.id == eventId);
    if (existingIndex >= 0) {
      // Update existing message (shouldn't happen with proper consolidation)
      messages[existingIndex] = messages[existingIndex].copyWith(
        content: content,
        responses: [
          if (content.isNotEmpty)
            VideTextResponse(
              id: const Uuid().v4(),
              timestamp: DateTime.now(),
              content: content,
            ),
        ],
        isStreaming: false,
        isComplete: true,
      );
    } else {
      // Add new message
      messages.add(
        VideConversationMessage(
          id: eventId,
          role: MessageRole.assistant,
          content: content,
          timestamp: DateTime.now(),
          responses: [
            if (content.isNotEmpty)
              VideTextResponse(
                id: const Uuid().v4(),
                timestamp: DateTime.now(),
                content: content,
              ),
          ],
          isStreaming: false,
          isComplete: true,
          messageType: VideMessageType.assistantText,
        ),
      );
    }
  }

  void _handleStreamingAssistantMessage(
    List<VideConversationMessage> messages,
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
      final responses = List<VideResponse>.from(existing.responses);

      if (content.isNotEmpty) {
        responses.add(
          VideTextResponse(
            id: const Uuid().v4(),
            timestamp: DateTime.now(),
            content: content,
            isPartial: true,
          ),
        );
      }

      messages[existingIndex] = existing.copyWith(
        content: newContent,
        responses: responses,
        isStreaming: isPartial,
        isComplete: !isPartial,
      );
    } else {
      // Create new assistant message
      final newMsgId = eventId;
      _currentAssistantMessageId[agentId] = newMsgId;

      final responses = <VideResponse>[];
      if (content.isNotEmpty) {
        responses.add(
          VideTextResponse(
            id: const Uuid().v4(),
            timestamp: DateTime.now(),
            content: content,
            isPartial: true,
          ),
        );
      }

      messages.add(
        VideConversationMessage(
          id: newMsgId,
          role: MessageRole.assistant,
          content: content,
          timestamp: DateTime.now(),
          responses: responses,
          isStreaming: isPartial,
          isComplete: !isPartial,
          messageType: VideMessageType.assistantText,
        ),
      );
    }

    // Only clear assistant message tracking when a non-empty final message
    // arrives (true turn boundary). Empty finalization messages (content == '')
    // just signal that a text block ended before a tool use, not that the
    // entire assistant turn is complete. Turn completion is signaled by
    // markAssistantTurnComplete (from TurnCompleteEvent).
    if (!isPartial && content.isNotEmpty) {
      _currentAssistantMessageId.remove(agentId);
    }
  }

  StreamController<VideConversation> _getOrCreateController(String agentId) {
    return _controllers.putIfAbsent(
      agentId,
      () => StreamController<VideConversation>.broadcast(),
    );
  }
}
