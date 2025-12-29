/// Streaming delta handler for computing and emitting conversation updates.
///
/// This class encapsulates the delta computation logic, making it testable
/// independently from WebSocket transport concerns.
import 'package:claude_sdk/claude_sdk.dart'
    show
        Conversation,
        ConversationMessage,
        MessageRole,
        ToolUseResponse,
        ToolResultResponse;
import 'package:meta/meta.dart';

/// Represents a streaming event to be sent to clients.
sealed class StreamingEvent {}

/// Full message content (sent when a new message starts).
class MessageEvent extends StreamingEvent {
  final String role;
  final String content;
  MessageEvent({required this.role, required this.content});
}

/// Delta content (sent when an existing message grows).
class MessageDeltaEvent extends StreamingEvent {
  final String role;
  final String delta;
  MessageDeltaEvent({required this.role, required this.delta});
}

/// Tool use event.
class ToolUseEvent extends StreamingEvent {
  final String toolName;
  final String? toolUseId;
  final Map<String, dynamic> parameters;
  ToolUseEvent({
    required this.toolName,
    this.toolUseId,
    required this.parameters,
  });
}

/// Tool result event.
class ToolResultEvent extends StreamingEvent {
  final String toolName;
  final String? toolUseId;
  final dynamic content;
  final bool isError;
  ToolResultEvent({
    required this.toolName,
    this.toolUseId,
    required this.content,
    this.isError = false,
  });
}

/// Error event.
class ErrorEvent extends StreamingEvent {
  final String message;
  ErrorEvent({required this.message});
}

/// Mutable state for tracking streaming progress.
///
/// Using a class ensures state updates are immediately visible to all readers,
/// preventing race conditions when multiple conversation updates arrive rapidly.
class StreamingState {
  int lastMessageCount = 0;
  int lastContentLength = 0;

  @visibleForTesting
  void reset() {
    lastMessageCount = 0;
    lastContentLength = 0;
  }
}

/// Handles streaming delta computation for conversation updates.
///
/// This class is stateless - it takes a [StreamingState] parameter to allow
/// the caller to manage state lifetime.
class StreamingDeltaHandler {
  /// Maps toolUseId to toolName for correlating tool results with their invocations.
  final Map<String, String> _toolNamesByUseId = {};

  /// Process a conversation update and emit events for changes.
  ///
  /// Returns a list of [StreamingEvent]s representing the changes since the
  /// last update as tracked by [state].
  List<StreamingEvent> handleUpdate(
    Conversation conversation,
    StreamingState state,
  ) {
    final events = <StreamingEvent>[];

    if (conversation.messages.isEmpty) {
      return events;
    }

    final currentMessageCount = conversation.messages.length;
    final latestMessage = conversation.messages.last;
    final currentContentLength = latestMessage.content.length;

    var isNewMessage = false;

    // New message started - send full content
    if (currentMessageCount > state.lastMessageCount) {
      isNewMessage = true;
      if (latestMessage.content.isNotEmpty) {
        events.add(
          MessageEvent(
            role: _roleToString(latestMessage.role),
            content: latestMessage.content,
          ),
        );
      }
      state.lastMessageCount = currentMessageCount;
      state.lastContentLength = currentContentLength;
    }
    // Same message, but content grew - send only the delta
    else if (currentContentLength > state.lastContentLength) {
      final delta = latestMessage.content.substring(state.lastContentLength);
      if (delta.isNotEmpty) {
        events.add(
          MessageDeltaEvent(
            role: _roleToString(latestMessage.role),
            delta: delta,
          ),
        );
      }
      state.lastMessageCount = currentMessageCount;
      state.lastContentLength = currentContentLength;
    }

    // Send tool events only for new messages
    if (isNewMessage) {
      events.addAll(_extractToolEvents(latestMessage));
    }

    // Send error event if conversation has an error
    if (conversation.currentError != null) {
      events.add(ErrorEvent(message: conversation.currentError!));
    }

    return events;
  }

  /// Send all messages in a conversation (used for initial state sync).
  ///
  /// Returns a list of [StreamingEvent]s for all messages in the conversation.
  List<StreamingEvent> sendFullState(Conversation conversation) {
    final events = <StreamingEvent>[];

    if (conversation.messages.isEmpty) {
      return events;
    }

    for (final message in conversation.messages) {
      if (message.content.isNotEmpty) {
        events.add(
          MessageEvent(
            role: _roleToString(message.role),
            content: message.content,
          ),
        );
      }
      events.addAll(_extractToolEvents(message));
    }

    if (conversation.currentError != null) {
      events.add(ErrorEvent(message: conversation.currentError!));
    }

    return events;
  }

  /// Look up a tool name by its use ID.
  ///
  /// Returns 'unknown' if the tool use ID was not tracked.
  String getToolName(String? toolUseId) {
    if (toolUseId == null) return 'unknown';
    return _toolNamesByUseId[toolUseId] ?? 'unknown';
  }

  List<StreamingEvent> _extractToolEvents(ConversationMessage message) {
    final events = <StreamingEvent>[];
    for (final response in message.responses) {
      if (response is ToolUseResponse) {
        // Track tool name by use ID for later result correlation
        if (response.toolUseId != null) {
          _toolNamesByUseId[response.toolUseId!] = response.toolName;
        }
        events.add(
          ToolUseEvent(
            toolName: response.toolName,
            toolUseId: response.toolUseId,
            parameters: response.parameters,
          ),
        );
      } else if (response is ToolResultResponse) {
        final toolName = getToolName(response.toolUseId);
        events.add(
          ToolResultEvent(
            toolName: toolName,
            toolUseId: response.toolUseId,
            content: response.content,
            isError: response.isError,
          ),
        );
      }
    }
    return events;
  }

  String _roleToString(MessageRole role) {
    return role == MessageRole.user ? 'user' : 'assistant';
  }
}
