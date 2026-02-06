import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vide_client/vide_client.dart' as vc;

import '../../core/providers/connection_state_provider.dart';
import '../../core/router/app_router.dart';
import '../../data/repositories/session_repository.dart';
import '../../domain/models/models.dart';
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
  StreamSubscription<vc.VideEvent>? _eventSubscription;

  /// Tracks accumulated content for streaming messages by eventId.
  final Map<String, String> _streamingMessages = {};

  /// Tracks whether permission sheet is currently showing.
  bool _isPermissionSheetShowing = false;

  final ScrollController _scrollController = ScrollController();

  /// True while processing history events — suppresses scroll animations and shows loading.
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _subscribeToEvents();
    // Defer connection to post-frame to avoid modifying providers during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _connectToSessionIfNeeded();
    });
  }

  /// Connects to the session if not already connected.
  ///
  /// This handles the case when navigating to a session from the sessions list.
  void _connectToSessionIfNeeded() {
    final sessionRepo = ref.read(sessionRepositoryProvider.notifier);
    final currentState = ref.read(sessionRepositoryProvider);

    // If already connected to this session, nothing to do
    if (currentState.session?.sessionId == widget.sessionId &&
        currentState.isActive) {
      return;
    }

    // Connect to the session
    sessionRepo.connectToExistingSession(widget.sessionId).then((_) {
      // Successfully connected
    }).catchError((e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect: $e'),
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }
    });
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

  void _handleEvent(vc.VideEvent event) {
    final notifier = ref.read(chatNotifierProvider(widget.sessionId).notifier);

    switch (event) {
      case vc.ConnectedEvent(:final agents):
        final domainAgents = agents
            .map((a) => Agent(
                  id: a.id,
                  type: a.type,
                  name: a.name,
                  taskName: a.taskName,
                ))
            .toList();
        notifier.setAgents(domainAgents);

      case vc.HistoryEvent(:final events):
        setState(() => _isLoadingHistory = true);
        for (final rawEvent in events) {
          _handleEvent(vc.VideEvent.fromJson(rawEvent as Map<String, dynamic>));
        }
        setState(() => _isLoadingHistory = false);
        _jumpToBottom();

      case vc.MessageEvent(
          :final eventId,
          :final content,
          :final role,
          :final isPartial,
          :final timestamp,
        ):
        final agentId = event.agent?.id ?? '';
        final agentType = event.agent?.type ?? '';
        final agentName = event.agent?.name;
        _handleMessageEvent(
          eventId: eventId ?? '',
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          content: content,
          role: role == vc.MessageRole.user
              ? MessageRole.user
              : MessageRole.assistant,
          isPartial: isPartial,
          timestamp: timestamp,
        );

      case vc.StatusEvent(:final status):
        final agentId = event.agent?.id ?? '';
        final taskName = event.agent?.taskName;
        notifier.updateAgentStatus(
            agentId, _convertAgentStatus(status), taskName);
        final agents = ref.read(chatNotifierProvider(widget.sessionId)).agents;
        final anyWorking = agents.any((a) => a.status == AgentStatus.working);
        notifier.setIsAgentWorking(anyWorking);

      case vc.ToolUseEvent(:final toolUseId, :final toolName, :final toolInput):
        final agentId = event.agent?.id ?? '';
        final agentName = event.agent?.name;
        notifier.addToolUse(ToolUse(
          toolUseId: toolUseId,
          toolName: toolName,
          input: toolInput,
          agentId: agentId,
          agentName: agentName,
          timestamp: event.timestamp,
        ));
        _scrollToBottom();

      case vc.ToolResultEvent(
          :final toolUseId,
          :final toolName,
          :final result,
          :final isError
        ):
        notifier.addToolResult(ToolResult(
          toolUseId: toolUseId,
          toolName: toolName,
          result: result,
          isError: isError,
          timestamp: event.timestamp,
        ));
        _scrollToBottom();

      case vc.PermissionRequestEvent(:final requestId, :final tool):
        final agentId = event.agent?.id ?? '';
        final agentName = event.agent?.name;
        notifier.setPendingPermission(PermissionRequest(
          requestId: requestId,
          toolName: tool['name'] as String? ?? '',
          toolInput: tool['input'] as Map<String, dynamic>? ?? {},
          agentId: agentId,
          agentName: agentName,
          timestamp: event.timestamp,
        ));

      case vc.PermissionTimeoutEvent(:final requestId):
        final pending =
            ref.read(chatNotifierProvider(widget.sessionId)).pendingPermission;
        if (pending?.requestId == requestId) {
          notifier.setPendingPermission(null);
          if (_isPermissionSheetShowing && mounted) {
            Navigator.of(context).pop();
            _isPermissionSheetShowing = false;
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Permission request timed out'),
                behavior: SnackBarBehavior.fixed,
              ),
            );
          }
        }

      case vc.AgentSpawnedEvent():
        final agentId = event.agent?.id ?? '';
        final agentType = event.agent?.type ?? '';
        final agentName = event.agent?.name ?? 'Agent';
        final taskName = event.agent?.taskName;
        final agent = Agent(
          id: agentId,
          type: agentType,
          name: agentName,
          taskName: taskName,
        );
        notifier.addAgent(agent);

      case vc.AgentTerminatedEvent():
        final terminatedAgentId = event.agent?.id ?? '';
        notifier.removeAgent(terminatedAgentId);

      case vc.DoneEvent():
        notifier.setIsAgentWorking(false);

      case vc.AbortedEvent():
        notifier.setIsAgentWorking(false);

      case vc.ErrorEvent(:final message):
        notifier.setError(message);
        notifier.setIsAgentWorking(false);

      case vc.TaskNameChangedEvent():
        break;

      case vc.CommandResultEvent():
        break;

      case vc.AskUserQuestionEvent():
        break;

      case vc.UnknownEvent():
        break;
    }
  }

  AgentStatus _convertAgentStatus(vc.AgentStatus status) {
    return switch (status) {
      vc.AgentStatus.working => AgentStatus.working,
      vc.AgentStatus.waitingForAgent => AgentStatus.waitingForAgent,
      vc.AgentStatus.waitingForUser => AgentStatus.waitingForUser,
      vc.AgentStatus.idle => AgentStatus.idle,
    };
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

    // Deduplicate user messages by content
    // We add user messages optimistically in _sendMessage(), then receive them
    // back from the server with a different eventId. Skip if we already have it.
    if (role == MessageRole.user) {
      final isDuplicate = state.messages.any(
        (m) => m.role == MessageRole.user && m.content == content,
      );
      if (isDuplicate) {
        return; // Skip duplicate user message
      }
    }

    if (isPartial) {
      // Accumulate streaming content
      _streamingMessages[eventId] =
          (_streamingMessages[eventId] ?? '') + content;

      // Check if we already have a message with this eventId
      final existingIndex =
          state.messages.indexWhere((m) => m.eventId == eventId);

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

      final existingIndex =
          state.messages.indexWhere((m) => m.eventId == eventId);

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
    ref
        .read(chatNotifierProvider(widget.sessionId).notifier)
        .setIsAgentWorking(false);
  }

  void _scrollToBottom() {
    if (_isLoadingHistory) return;
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

  /// Instantly jumps to bottom without animation (used after history load).
  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
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

    ref
        .read(chatNotifierProvider(widget.sessionId).notifier)
        .setPendingPermission(null);
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

    // Show permission sheet if there's a pending permission
    if (state.pendingPermission != null && !_isPermissionSheetShowing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && state.pendingPermission != null) {
          _showPermissionSheet(state.pendingPermission!);
        }
      });
    }

    // Determine if input should be disabled
    final isDisconnected =
        connectionState.status != WebSocketConnectionStatus.connected;
    final inputEnabled = !state.isAgentWorking && !isDisconnected;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.sessions),
        ),
        title: const Text('Session'),
        actions: [
          // Connection status chip
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Center(child: ConnectionStatusChip()),
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection status banner
          const ConnectionStatusBanner(),
          // Error banner
          if (state.error != null)
            MaterialBanner(
              content: Text(state.error!),
              backgroundColor: colorScheme.errorContainer,
              actions: [
                TextButton(
                  onPressed: () {
                    ref
                        .read(chatNotifierProvider(widget.sessionId).notifier)
                        .setError(null);
                  },
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          // Messages area with floating input bar overlay
          Expanded(
            child: Stack(
              children: [
                // Messages
                _isLoadingHistory
                    ? const Center(child: CircularProgressIndicator())
                    : _buildMessageList(state),
                // Floating input bar
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: InputBar(
                    controller: _inputController,
                    enabled: inputEnabled,
                    isLoading: state.isAgentWorking,
                    onSend: _sendMessage,
                    onAbort: _abort,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(ChatState state) {
    if (state.messages.isEmpty && state.toolUses.isEmpty) {
      return _EmptyState();
    }

    return _MessageList(
      messages: state.messages,
      toolUses: state.toolUses,
      toolResults: state.toolResults,
      scrollController: _scrollController,
    );
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

    if (items.isEmpty) {
      return const Center(
        child: Text(
          'No messages yet',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.only(top: 16, bottom: 80),
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
