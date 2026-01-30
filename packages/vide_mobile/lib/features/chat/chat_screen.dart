import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/connection_state_provider.dart';
import '../../data/models/session_event.dart' as session_events;
import '../../data/repositories/session_repository.dart';
import '../../domain/models/models.dart';
import '../agents/agent_panel.dart';
import '../permissions/permission_sheet.dart';
import 'chat_state.dart';
import 'widgets/connection_status_banner.dart';
import 'widgets/input_bar.dart';
import 'widgets/message_bubble.dart';
import 'widgets/tool_card.dart';

/// Main chat screen for a session.
class ChatScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const ChatScreen({
    super.key,
    required this.sessionId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  StreamSubscription<session_events.SessionEvent>? _eventSubscription;

  /// Tracks accumulated content for streaming messages by eventId.
  final Map<String, String> _streamingMessages = {};

  /// Tracks whether permission sheet is currently showing.
  bool _isPermissionSheetShowing = false;

  /// Track previous connection status for showing snackbar on reconnection.
  WebSocketConnectionStatus? _previousConnectionStatus;

  @override
  void initState() {
    super.initState();
    _subscribeToEvents();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _subscribeToEvents() {
    final sessionRepo = ref.read(sessionRepositoryProvider.notifier);
    _eventSubscription = sessionRepo.events.listen(_handleEvent);
  }

  void _handleEvent(session_events.SessionEvent event) {
    final notifier = ref.read(chatNotifierProvider(widget.sessionId).notifier);

    switch (event) {
      case session_events.ConnectedEvent(:final agents):
        // Set initial agents from connected event
        notifier.setAgents(agents);

      case session_events.HistoryEvent(:final events):
        // Process history events for reconnection
        for (final historyEvent in events) {
          _handleEvent(historyEvent);
        }

      case session_events.MessageEvent(
          :final eventId,
          :final agentId,
          :final agentType,
          :final agentName,
          :final content,
          :final role,
          :final isPartial,
          :final timestamp,
        ):
        _handleMessageEvent(
          eventId: eventId,
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          content: content,
          role: role,
          isPartial: isPartial,
          timestamp: timestamp,
        );

      case session_events.StatusEvent(:final agentId, :final status, :final taskName):
        notifier.updateAgentStatus(agentId, status, taskName);
        // Update isAgentWorking based on any agent working
        final agents = ref.read(chatNotifierProvider(widget.sessionId)).agents;
        final anyWorking = agents.any((a) => a.status == AgentStatus.working);
        notifier.setIsAgentWorking(anyWorking);

      case session_events.ToolUseEvent(:final toolUse):
        notifier.addToolUse(toolUse);
        _scrollToBottom();

      case session_events.ToolResultEvent(:final toolResult):
        notifier.addToolResult(toolResult);
        _scrollToBottom();

      case session_events.PermissionRequestEvent(:final request):
        notifier.setPendingPermission(request);

      case session_events.PermissionTimeoutEvent(:final requestId):
        final pending = ref.read(chatNotifierProvider(widget.sessionId)).pendingPermission;
        if (pending?.requestId == requestId) {
          notifier.setPendingPermission(null);
          if (_isPermissionSheetShowing && mounted) {
            Navigator.of(context).pop();
            _isPermissionSheetShowing = false;
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Permission request timed out')),
            );
          }
        }

      case session_events.AgentSpawnedEvent(:final agent):
        notifier.addAgent(agent);

      case session_events.AgentTerminatedEvent(:final terminatedAgentId):
        notifier.removeAgent(terminatedAgentId);

      case session_events.DoneEvent():
        notifier.setIsAgentWorking(false);

      case session_events.AbortedEvent():
        notifier.setIsAgentWorking(false);

      case session_events.ErrorEvent(:final message):
        notifier.setError(message);
        notifier.setIsAgentWorking(false);

      case session_events.UnknownEvent():
        // Ignore unknown events
        break;
    }
  }

  void _handleMessageEvent({
    required String eventId,
    required String agentId,
    required String agentType,
    required String? agentName,
    required String content,
    required MessageRole role,
    required bool isPartial,
    required DateTime timestamp,
  }) {
    final notifier = ref.read(chatNotifierProvider(widget.sessionId).notifier);
    final state = ref.read(chatNotifierProvider(widget.sessionId));

    if (isPartial) {
      // Accumulate streaming content
      _streamingMessages[eventId] = (_streamingMessages[eventId] ?? '') + content;

      // Check if we already have a message with this eventId
      final existingIndex = state.messages.indexWhere((m) => m.eventId == eventId);

      if (existingIndex >= 0) {
        // Update existing message with accumulated content
        notifier.updateMessage(
          eventId,
          state.messages[existingIndex].copyWith(
            content: _streamingMessages[eventId]!,
            isStreaming: true,
          ),
        );
      } else {
        // Create new streaming message
        notifier.addMessage(ChatMessage(
          eventId: eventId,
          role: role,
          content: _streamingMessages[eventId]!,
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          timestamp: timestamp,
          isStreaming: true,
        ));
      }
    } else {
      // Final message (isPartial: false)
      final accumulatedContent = _streamingMessages[eventId] ?? '';
      final finalContent = accumulatedContent + content;
      _streamingMessages.remove(eventId);

      final existingIndex = state.messages.indexWhere((m) => m.eventId == eventId);

      if (existingIndex >= 0) {
        // Mark message as complete
        notifier.updateMessage(
          eventId,
          state.messages[existingIndex].copyWith(
            content: finalContent,
            isStreaming: false,
          ),
        );
      } else if (finalContent.isNotEmpty) {
        // Add complete message (this can happen if we missed partial events)
        notifier.addMessage(ChatMessage(
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

    _scrollToBottom();
  }

  void _sendMessage() {
    final message = _inputController.text.trim();
    if (message.isEmpty) return;

    final notifier = ref.read(chatNotifierProvider(widget.sessionId).notifier);
    final sessionRepo = ref.read(sessionRepositoryProvider.notifier);

    // Add user message to state
    final userMessage = ChatMessage(
      eventId: DateTime.now().millisecondsSinceEpoch.toString(),
      role: MessageRole.user,
      content: message,
      agentId: 'user',
      agentType: 'user',
      timestamp: DateTime.now(),
    );

    notifier.addMessage(userMessage);
    notifier.setIsAgentWorking(true);

    // Send to WebSocket via vide_client
    sessionRepo.sendMessage(message);

    _inputController.clear();
    _scrollToBottom();
  }

  void _abort() {
    final sessionRepo = ref.read(sessionRepositoryProvider.notifier);
    sessionRepo.abort();
    ref.read(chatNotifierProvider(widget.sessionId).notifier).setIsAgentWorking(false);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showAgentPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => AgentPanel(sessionId: widget.sessionId),
    );
  }

  void _handlePermission(bool allow) {
    final state = ref.read(chatNotifierProvider(widget.sessionId));
    final pendingPermission = state.pendingPermission;
    if (pendingPermission == null) return;

    final sessionRepo = ref.read(sessionRepositoryProvider.notifier);
    sessionRepo.respondToPermission(
      pendingPermission.requestId,
      allow,
    );

    ref.read(chatNotifierProvider(widget.sessionId).notifier).setPendingPermission(null);
    _isPermissionSheetShowing = false;
    Navigator.of(context).pop(); // Close the permission sheet
  }

  void _showPermissionSheet(PermissionRequest request) {
    if (_isPermissionSheetShowing) return;
    _isPermissionSheetShowing = true;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => PermissionSheet(
        request: request,
        onAllow: () => _handlePermission(true),
        onDeny: () => _handlePermission(false),
      ),
    ).whenComplete(() {
      _isPermissionSheetShowing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatNotifierProvider(widget.sessionId));
    final connectionState = ref.watch(webSocketConnectionProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // Show snackbar when connection is restored
    _handleConnectionStatusChange(connectionState.status);

    // Show permission sheet if there's a pending permission
    if (state.pendingPermission != null && !_isPermissionSheetShowing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && state.pendingPermission != null) {
          _showPermissionSheet(state.pendingPermission!);
        }
      });
    }

    // Determine if input should be disabled
    final isDisconnected = connectionState.status != WebSocketConnectionStatus.connected;
    final inputEnabled = !state.isAgentWorking && !isDisconnected;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Session'),
        actions: [
          // Connection status chip
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Center(child: ConnectionStatusChip()),
          ),
          // Agent count badge
          if (state.agents.isNotEmpty)
            Badge(
              label: Text('${state.agents.length}'),
              child: IconButton(
                icon: const Icon(Icons.group_outlined),
                onPressed: _showAgentPanel,
                tooltip: 'Agents',
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.group_outlined),
              onPressed: _showAgentPanel,
              tooltip: 'Agents',
            ),
        ],
      ),
      body: Column(
        children: [
          // Connection status banner
          const ConnectionStatusBanner(),
          // Working indicator
          if (state.isAgentWorking && connectionState.status == WebSocketConnectionStatus.connected)
            LinearProgressIndicator(
              backgroundColor: colorScheme.primaryContainer,
              valueColor: AlwaysStoppedAnimation(colorScheme.primary),
            ),
          // Error banner
          if (state.error != null)
            MaterialBanner(
              content: Text(state.error!),
              backgroundColor: colorScheme.errorContainer,
              actions: [
                TextButton(
                  onPressed: () {
                    ref.read(chatNotifierProvider(widget.sessionId).notifier).setError(null);
                  },
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          // Messages list
          Expanded(
            child: state.messages.isEmpty
                ? _EmptyState()
                : _MessageList(
                    messages: state.messages,
                    toolUses: state.toolUses,
                    toolResults: state.toolResults,
                    scrollController: _scrollController,
                  ),
          ),
          // Input bar
          InputBar(
            controller: _inputController,
            enabled: inputEnabled,
            isLoading: state.isAgentWorking,
            onSend: _sendMessage,
            onAbort: _abort,
          ),
        ],
      ),
    );
  }

  void _handleConnectionStatusChange(WebSocketConnectionStatus currentStatus) {
    // Show snackbar when reconnected
    if (_previousConnectionStatus != null &&
        _previousConnectionStatus != WebSocketConnectionStatus.connected &&
        currentStatus == WebSocketConnectionStatus.connected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connection restored'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      });
    }
    _previousConnectionStatus = currentStatus;
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Start a conversation',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Send a message to begin',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  final List<ChatMessage> messages;
  final List<ToolUse> toolUses;
  final Map<String, ToolResult> toolResults;
  final ScrollController scrollController;

  const _MessageList({
    required this.messages,
    required this.toolUses,
    required this.toolResults,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    // Build interleaved list of messages and tools
    final items = <_ChatItem>[];

    for (final message in messages) {
      items.add(_ChatItem.message(message));
    }

    for (final toolUse in toolUses) {
      items.add(_ChatItem.tool(toolUse, toolResults[toolUse.toolUseId]));
    }

    // Sort by timestamp
    items.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return item.when(
          message: (message) => MessageBubble(message: message),
          tool: (toolUse, result) => ToolCard(
            toolUse: toolUse,
            result: result,
          ),
        );
      },
    );
  }
}

/// Represents an item in the chat list.
sealed class _ChatItem {
  DateTime get timestamp;

  factory _ChatItem.message(ChatMessage message) = _MessageItem;
  factory _ChatItem.tool(ToolUse toolUse, ToolResult? result) = _ToolItem;

  T when<T>({
    required T Function(ChatMessage message) message,
    required T Function(ToolUse toolUse, ToolResult? result) tool,
  });
}

class _MessageItem implements _ChatItem {
  final ChatMessage message;

  _MessageItem(this.message);

  @override
  DateTime get timestamp => message.timestamp;

  @override
  T when<T>({
    required T Function(ChatMessage message) message,
    required T Function(ToolUse toolUse, ToolResult? result) tool,
  }) {
    return message(this.message);
  }
}

class _ToolItem implements _ChatItem {
  final ToolUse toolUse;
  final ToolResult? result;

  _ToolItem(this.toolUse, this.result);

  @override
  DateTime get timestamp => toolUse.timestamp;

  @override
  T when<T>({
    required T Function(ChatMessage message) message,
    required T Function(ToolUse toolUse, ToolResult? result) tool,
  }) {
    return tool(toolUse, result);
  }
}
