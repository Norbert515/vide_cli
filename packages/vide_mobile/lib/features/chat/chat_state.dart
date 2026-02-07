import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/models/models.dart';

part 'chat_state.freezed.dart';
part 'chat_state.g.dart';

/// State for the chat screen.
@freezed
class ChatState with _$ChatState {
  const factory ChatState({
    @Default([]) List<ChatMessage> messages,
    @Default([]) List<ToolUse> toolUses,
    @Default({}) Map<String, ToolResult> toolResults,
    @Default([]) List<Agent> agents,
    PermissionRequest? pendingPermission,
    @Default(false) bool isLoading,
    @Default(false) bool isAgentWorking,
    String? error,
  }) = _ChatState;
}

/// Provider for chat state management.
///
/// Kept alive so that optimistic user messages added before navigating
/// to the chat screen survive the route transition (auto-dispose would
/// reset the state between the creation screen disposing and the chat
/// screen subscribing).
@Riverpod(keepAlive: true)
class ChatNotifier extends _$ChatNotifier {
  /// Tracks accumulated content for streaming messages by eventId.
  /// This is the source of truth for whether a message already exists,
  /// avoiding stale-state issues during synchronous history replay.
  final Map<String, String> _streamingMessages = {};

  @override
  ChatState build(String sessionId) {
    return const ChatState();
  }

  /// Handles an incoming message event, accumulating partial streaming chunks.
  ///
  /// This is the single entry point for message events from the server.
  /// Partial chunks with the same [eventId] are accumulated into one message.
  void handleMessageEvent({
    required String eventId,
    required String agentId,
    required String agentType,
    required String? agentName,
    required String content,
    required MessageRole role,
    required bool isPartial,
    required DateTime timestamp,
  }) {
    // Deduplicate user messages by content
    if (role == MessageRole.user) {
      final isDuplicate = state.messages.any(
        (m) => m.role == MessageRole.user && m.content == content,
      );
      if (isDuplicate) return;
    }

    final alreadyTracked = _streamingMessages.containsKey(eventId);

    if (isPartial) {
      _streamingMessages[eventId] =
          (_streamingMessages[eventId] ?? '') + content;

      final msg = ChatMessage(
        eventId: eventId,
        role: role,
        content: _streamingMessages[eventId]!,
        agentId: agentId,
        agentType: agentType,
        agentName: agentName,
        timestamp: timestamp,
        isStreaming: true,
      );

      if (alreadyTracked) {
        _updateMessage(eventId, msg);
      } else {
        _addMessage(msg);
      }
    } else {
      final accumulatedContent = _streamingMessages[eventId] ?? '';
      final finalContent = accumulatedContent + content;
      _streamingMessages.remove(eventId);

      if (alreadyTracked) {
        _updateMessage(
          eventId,
          ChatMessage(
            eventId: eventId,
            role: role,
            content: finalContent,
            agentId: agentId,
            agentType: agentType,
            agentName: agentName,
            timestamp: timestamp,
            isStreaming: false,
          ),
        );
      } else if (finalContent.isNotEmpty) {
        _addMessage(ChatMessage(
          eventId: eventId,
          role: role,
          content: finalContent,
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          timestamp: timestamp,
          isStreaming: false,
        ));
      }
    }
  }

  void addMessage(ChatMessage message) {
    _addMessage(message);
  }

  void _addMessage(ChatMessage message) {
    state = state.copyWith(
      messages: [...state.messages, message],
    );
  }

  void _updateMessage(String eventId, ChatMessage updatedMessage) {
    state = state.copyWith(
      messages: state.messages.map((m) {
        return m.eventId == eventId ? updatedMessage : m;
      }).toList(),
    );
  }

  void addToolUse(ToolUse toolUse) {
    state = state.copyWith(
      toolUses: [...state.toolUses, toolUse],
    );
  }

  void addToolResult(ToolResult toolResult) {
    state = state.copyWith(
      toolResults: {
        ...state.toolResults,
        toolResult.toolUseId: toolResult,
      },
    );
  }

  void setAgents(List<Agent> agents) {
    state = state.copyWith(agents: agents);
  }

  void addAgent(Agent agent) {
    state = state.copyWith(
      agents: [...state.agents, agent],
    );
  }

  void removeAgent(String agentId) {
    state = state.copyWith(
      agents: state.agents.where((a) => a.id != agentId).toList(),
    );
  }

  void updateAgentStatus(String agentId, AgentStatus status, String? taskName) {
    state = state.copyWith(
      agents: state.agents.map((a) {
        if (a.id == agentId) {
          return a.copyWith(status: status, taskName: taskName ?? a.taskName);
        }
        return a;
      }).toList(),
    );
  }

  void setPendingPermission(PermissionRequest? request) {
    state = state.copyWith(pendingPermission: request);
  }

  void setIsLoading(bool isLoading) {
    state = state.copyWith(isLoading: isLoading);
  }

  void setIsAgentWorking(bool isWorking) {
    state = state.copyWith(isAgentWorking: isWorking);
  }

  void setError(String? error) {
    state = state.copyWith(error: error);
  }

  void reset() {
    state = const ChatState();
  }
}

/// Provider for the message input text.
@riverpod
class MessageInput extends _$MessageInput {
  @override
  String build() => '';

  void setText(String text) {
    state = text;
  }

  void clear() {
    state = '';
  }
}
