/// Conversation state accumulator for the Vide API.
///
/// This provides a mutable state container that accumulates [VideEvent]s
/// into a renderable conversation structure, suitable for UI display.
library;

import 'dart:async';

import '../models/vide_agent.dart';
import '../models/vide_message.dart';
import '../events/vide_event.dart';

/// A piece of content within a conversation entry.
sealed class ConversationContent {
  const ConversationContent();
}

/// Text content from an assistant or user.
final class TextContent extends ConversationContent {
  /// The accumulated text content.
  final String text;

  /// Whether this text is still being streamed.
  final bool isStreaming;

  const TextContent({required this.text, this.isStreaming = false});

  TextContent copyWith({String? text, bool? isStreaming}) {
    return TextContent(
      text: text ?? this.text,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}

/// A tool invocation with its result.
final class ToolContent extends ConversationContent {
  /// Unique ID for this tool use.
  final String toolUseId;

  /// Name of the tool.
  final String toolName;

  /// Input parameters for the tool.
  final Map<String, dynamic> toolInput;

  /// Result from the tool (null if still executing).
  final String? result;

  /// True if the tool execution failed.
  final bool isError;

  /// True if the tool is still executing.
  bool get isExecuting => result == null;

  const ToolContent({
    required this.toolUseId,
    required this.toolName,
    required this.toolInput,
    this.result,
    this.isError = false,
  });

  ToolContent copyWith({
    String? toolUseId,
    String? toolName,
    Map<String, dynamic>? toolInput,
    String? result,
    bool? isError,
  }) {
    return ToolContent(
      toolUseId: toolUseId ?? this.toolUseId,
      toolName: toolName ?? this.toolName,
      toolInput: toolInput ?? this.toolInput,
      result: result ?? this.result,
      isError: isError ?? this.isError,
    );
  }
}

/// Thinking/reasoning content from the model.
///
/// Separate from [TextContent] so the UI can render it differently
/// (e.g., collapsed, dimmed, or in an expandable section).
final class ThinkingContent extends ConversationContent {
  /// The accumulated thinking/reasoning text.
  final String text;

  const ThinkingContent({required this.text});

  ThinkingContent copyWith({String? text}) {
    return ThinkingContent(text: text ?? this.text);
  }
}

/// An attachment included with a user message (image, file, etc.).
final class AttachmentContent extends ConversationContent {
  /// The attachments.
  final List<VideAttachment> attachments;

  const AttachmentContent({required this.attachments});
}

/// A message entry in the conversation (for UI rendering).
///
/// Named `ConversationEntry` to avoid collision with [VideMessage] (input message type).
final class ConversationEntry {
  /// Role of the message sender: 'user' or 'assistant'.
  final String role;

  /// Content blocks within this message.
  final List<ConversationContent> content;

  /// Whether this message is still being streamed.
  bool get isStreaming {
    for (final c in content) {
      if (c is TextContent && c.isStreaming) return true;
      if (c is ToolContent && c.isExecuting) return true;
    }
    return false;
  }

  /// Get the full text content of this message.
  String get text {
    final buffer = StringBuffer();
    for (final c in content) {
      if (c is TextContent) {
        buffer.write(c.text);
      }
    }
    return buffer.toString();
  }

  const ConversationEntry({required this.role, required this.content});

  ConversationEntry copyWith({
    String? role,
    List<ConversationContent>? content,
  }) {
    return ConversationEntry(
      role: role ?? this.role,
      content: content ?? this.content,
    );
  }
}

/// Accumulated conversation state for a single agent.
class AgentConversationState {
  /// The agent this state is for.
  final String agentId;

  /// Agent name (for display).
  final String? agentName;

  /// Agent type.
  final String agentType;

  /// Current status of the agent.
  VideAgentStatus status;

  /// Current task name.
  String? taskName;

  /// Messages in the conversation.
  final List<ConversationEntry> messages;

  // Token usage (accumulated totals across all turns)
  int totalInputTokens;
  int totalOutputTokens;
  int totalCacheReadInputTokens;
  int totalCacheCreationInputTokens;
  double totalCostUsd;

  // Current context window usage (from latest turn)
  int currentContextInputTokens;
  int currentContextCacheReadTokens;
  int currentContextCacheCreationTokens;

  /// Whether the agent is currently processing.
  bool get isProcessing => status == VideAgentStatus.working;

  /// Total context tokens used across all turns.
  int get totalContextTokens =>
      totalInputTokens +
      totalCacheReadInputTokens +
      totalCacheCreationInputTokens;

  /// Current context window usage (for percentage display).
  int get currentContextWindowTokens =>
      currentContextInputTokens +
      currentContextCacheReadTokens +
      currentContextCacheCreationTokens;

  AgentConversationState({
    required this.agentId,
    this.agentName,
    required this.agentType,
    this.status = VideAgentStatus.idle,
    this.taskName,
    List<ConversationEntry>? messages,
    this.totalInputTokens = 0,
    this.totalOutputTokens = 0,
    this.totalCacheReadInputTokens = 0,
    this.totalCacheCreationInputTokens = 0,
    this.totalCostUsd = 0.0,
    this.currentContextInputTokens = 0,
    this.currentContextCacheReadTokens = 0,
    this.currentContextCacheCreationTokens = 0,
  }) : messages = messages ?? [];

  /// Internal: current message event ID being streamed.
  String? currentMessageEventId;

  /// Internal: pending tool uses waiting for results.
  final Map<String, int> pendingToolMessageIndex = {};
  final Map<String, int> pendingToolContentIndex = {};
}

/// Manages conversation state accumulated from [VideEvent]s.
///
/// This is the bridge between the event stream and UI rendering.
/// It also serves as the authoritative store of event history for the session,
/// enabling features like history replay for late-joining clients.
class ConversationStateManager {
  /// Per-agent conversation state.
  final Map<String, AgentConversationState> _agentStates = {};

  /// Stream controller for state change notifications.
  final StreamController<void> _changeController =
      StreamController<void>.broadcast();

  /// Per-agent stream controllers for targeted subscriptions.
  final Map<String, StreamController<AgentConversationState>>
  _agentControllers = {};

  /// Authoritative event history for this session.
  final List<VideEvent> _eventHistory = [];

  /// Stream that emits whenever state changes.
  Stream<void> get onStateChanged => _changeController.stream;

  /// Get all agent IDs with state.
  Iterable<String> get agentIds => _agentStates.keys;

  /// The authoritative list of all events processed by this manager.
  List<VideEvent> get eventHistory => List.unmodifiable(_eventHistory);

  /// Get state for a specific agent.
  AgentConversationState? getAgentState(String agentId) =>
      _agentStates[agentId];

  /// Stream of state changes for a specific agent.
  ///
  /// Emits the current [AgentConversationState] whenever that agent's
  /// conversation state changes (new message, tool use, status update, etc.).
  Stream<AgentConversationState> agentStream(String agentId) {
    return _getOrCreateAgentController(agentId).stream;
  }

  StreamController<AgentConversationState> _getOrCreateAgentController(
    String agentId,
  ) {
    return _agentControllers.putIfAbsent(
      agentId,
      () => StreamController<AgentConversationState>.broadcast(),
    );
  }

  /// Get or create state for an agent.
  AgentConversationState _getOrCreateAgentState(VideEvent event) {
    return _agentStates.putIfAbsent(
      event.agentId,
      () => AgentConversationState(
        agentId: event.agentId,
        agentName: event.agentName,
        agentType: event.agentType,
        taskName: event.taskName,
      ),
    );
  }

  /// Handle an event and update state.
  ///
  /// Every event is appended to [eventHistory] before processing.
  void handleEvent(VideEvent event) {
    _eventHistory.add(event);

    switch (event) {
      case MessageEvent e:
        _handleMessage(e);
      case ThinkingEvent e:
        _handleThinking(e);
      case ToolUseEvent e:
        _handleToolUse(e);
      case ToolResultEvent e:
        _handleToolResult(e);
      case StatusEvent e:
        _handleStatus(e);
      case TurnCompleteEvent e:
        _handleTurnComplete(e);
      case AgentSpawnedEvent e:
        _handleAgentSpawned(e);
      case AgentTerminatedEvent e:
        _handleAgentTerminated(e);
      case PermissionRequestEvent _:
      case AskUserQuestionEvent _:
      case AskUserQuestionResolvedEvent _:
      case PlanApprovalRequestEvent _:
      case PlanApprovalResolvedEvent _:
      case ErrorEvent _:
      case TaskNameChangedEvent _:
      case ConnectedEvent _:
      case HistoryEvent _:
      case PermissionResolvedEvent _:
      case AbortedEvent _:
      case CommandResultEvent _:
      case UnknownEvent _:
        break;
    }
  }

  /// Notify both global and per-agent listeners of a state change.
  void _notifyChange(String agentId) {
    _changeController.add(null);
    final state = _agentStates[agentId];
    if (state != null) {
      _getOrCreateAgentController(agentId).add(state);
    }
  }

  void _handleMessage(MessageEvent event) {
    final state = _getOrCreateAgentState(event);
    state.taskName = event.taskName;

    // Deduplicate user messages against the last message only.
    // User messages are emitted twice: once optimistically (for instant UI) and
    // once from the conversation stream (when Claude SDK processes it). Only the
    // last message needs checking since these arrive back-to-back. Checking all
    // history would silently drop legitimate repeated messages (e.g. "yes").
    if (event.role == 'user' && state.messages.isNotEmpty) {
      final lastMessage = state.messages.last;
      if (lastMessage.role == 'user' && lastMessage.text == event.content) {
        return;
      }
    }

    if (state.currentMessageEventId != event.eventId) {
      state.currentMessageEventId = event.eventId;

      // Merge consecutive assistant messages into a single entry so that
      // interleaved text/tool sequences render with consistent spacing.
      // During live streaming, each text segment after a tool call gets a
      // new eventId, which would otherwise create a separate entry — leading
      // to extra blank lines from MarkdownText paragraph trailing newlines.
      if (event.role == 'assistant' && state.messages.isNotEmpty) {
        final prev = state.messages.last;
        if (prev.role == 'assistant') {
          final contentList =
              List<ConversationContent>.from(prev.content);
          if (event.content.isNotEmpty) {
            contentList.add(
              TextContent(
                text: event.content,
                isStreaming: event.isPartial,
              ),
            );
          }
          state.messages[state.messages.length - 1] =
              prev.copyWith(content: contentList);
          _notifyChange(event.agentId);
          return;
        }
      }

      final contentBlocks = <ConversationContent>[
        if (event.attachments != null && event.attachments!.isNotEmpty)
          AttachmentContent(attachments: event.attachments!),
        TextContent(text: event.content, isStreaming: event.isPartial),
      ];
      state.messages.add(
        ConversationEntry(role: event.role, content: contentBlocks),
      );
    } else {
      if (state.messages.isEmpty) return;

      final lastMessage = state.messages.last;
      final contentList = List<ConversationContent>.from(lastMessage.content);

      final lastTextIndex = contentList.lastIndexWhere((c) => c is TextContent);
      if (lastTextIndex >= 0 && contentList[lastTextIndex] is TextContent) {
        final textContent = contentList[lastTextIndex] as TextContent;
        contentList[lastTextIndex] = textContent.copyWith(
          text: textContent.text + event.content,
          isStreaming: event.isPartial,
        );
      } else {
        contentList.add(
          TextContent(text: event.content, isStreaming: event.isPartial),
        );
      }

      state.messages[state.messages.length - 1] = lastMessage.copyWith(
        content: contentList,
      );
    }

    _notifyChange(event.agentId);
  }

  void _handleThinking(ThinkingEvent event) {
    final state = _getOrCreateAgentState(event);
    state.taskName = event.taskName;

    // Ensure we have an assistant message to attach thinking to
    if (state.messages.isEmpty || state.messages.last.role != 'assistant') {
      state.messages.add(
        const ConversationEntry(role: 'assistant', content: []),
      );
    }

    final lastMessage = state.messages.last;
    final contentList = List<ConversationContent>.from(lastMessage.content);

    // Append or update ThinkingContent
    final lastThinkingIndex =
        contentList.lastIndexWhere((c) => c is ThinkingContent);
    if (lastThinkingIndex >= 0) {
      final existing = contentList[lastThinkingIndex] as ThinkingContent;
      contentList[lastThinkingIndex] = existing.copyWith(
        text: existing.text + event.content,
      );
    } else {
      contentList.add(ThinkingContent(text: event.content));
    }

    state.messages[state.messages.length - 1] = lastMessage.copyWith(
      content: contentList,
    );

    _notifyChange(event.agentId);
  }

  void _handleToolUse(ToolUseEvent event) {
    final state = _getOrCreateAgentState(event);
    state.taskName = event.taskName;

    if (state.messages.isEmpty || state.messages.last.role != 'assistant') {
      state.messages.add(
        const ConversationEntry(role: 'assistant', content: []),
      );
    }

    final lastMessage = state.messages.last;
    final contentList = List<ConversationContent>.from(lastMessage.content);

    for (int i = 0; i < contentList.length; i++) {
      if (contentList[i] is TextContent) {
        final textContent = contentList[i] as TextContent;
        if (textContent.isStreaming) {
          contentList[i] = textContent.copyWith(isStreaming: false);
        }
      }
    }

    contentList.add(
      ToolContent(
        toolUseId: event.toolUseId,
        toolName: event.toolName,
        toolInput: event.toolInput,
      ),
    );

    state.pendingToolMessageIndex[event.toolUseId] = state.messages.length - 1;
    state.pendingToolContentIndex[event.toolUseId] = contentList.length - 1;

    state.messages[state.messages.length - 1] = lastMessage.copyWith(
      content: contentList,
    );

    _notifyChange(event.agentId);
  }

  void _handleToolResult(ToolResultEvent event) {
    final state = _agentStates[event.agentId];
    if (state == null) return;

    final messageIndex = state.pendingToolMessageIndex.remove(event.toolUseId);
    final contentIndex = state.pendingToolContentIndex.remove(event.toolUseId);

    if (messageIndex == null ||
        contentIndex == null ||
        messageIndex >= state.messages.length) {
      return;
    }

    final message = state.messages[messageIndex];
    if (contentIndex >= message.content.length) return;

    final content = message.content[contentIndex];
    if (content is! ToolContent) return;

    final contentList = List<ConversationContent>.from(message.content);
    contentList[contentIndex] = content.copyWith(
      result: event.result,
      isError: event.isError,
    );

    state.messages[messageIndex] = message.copyWith(content: contentList);

    _notifyChange(event.agentId);
  }

  void _handleStatus(StatusEvent event) {
    final state = _getOrCreateAgentState(event);
    state.status = event.status;
    state.taskName = event.taskName;
    _notifyChange(event.agentId);
  }

  void _handleTurnComplete(TurnCompleteEvent event) {
    final state = _agentStates[event.agentId];
    if (state == null) return;

    state.currentMessageEventId = null;

    state.totalInputTokens = event.totalInputTokens;
    state.totalOutputTokens = event.totalOutputTokens;
    state.totalCacheReadInputTokens = event.totalCacheReadInputTokens;
    state.totalCacheCreationInputTokens = event.totalCacheCreationInputTokens;
    state.totalCostUsd = event.totalCostUsd;
    state.currentContextInputTokens = event.currentContextInputTokens;
    state.currentContextCacheReadTokens = event.currentContextCacheReadTokens;
    state.currentContextCacheCreationTokens =
        event.currentContextCacheCreationTokens;

    if (state.messages.isNotEmpty) {
      final lastMessage = state.messages.last;
      final contentList = List<ConversationContent>.from(lastMessage.content);
      bool changed = false;

      for (int i = 0; i < contentList.length; i++) {
        if (contentList[i] is TextContent) {
          final textContent = contentList[i] as TextContent;
          if (textContent.isStreaming) {
            contentList[i] = textContent.copyWith(isStreaming: false);
            changed = true;
          }
        }
      }

      if (changed) {
        state.messages[state.messages.length - 1] = lastMessage.copyWith(
          content: contentList,
        );
      }
    }

    _notifyChange(event.agentId);
  }

  void _handleAgentSpawned(AgentSpawnedEvent event) {
    _getOrCreateAgentState(event);
    _notifyChange(event.agentId);
  }

  void _handleAgentTerminated(AgentTerminatedEvent event) {
    _agentStates.remove(event.agentId);
    _agentControllers.remove(event.agentId)?.close();
    _changeController.add(null);
  }

  /// Clear all state.
  void clear() {
    _agentStates.clear();
    _eventHistory.clear();
    for (final controller in _agentControllers.values) {
      controller.close();
    }
    _agentControllers.clear();
    _changeController.add(null);
  }

  /// Dispose resources.
  void dispose() {
    for (final controller in _agentControllers.values) {
      controller.close();
    }
    _agentControllers.clear();
    _changeController.close();
  }
}
