import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/models.dart';
import '../agents/agent_panel.dart';
import '../permissions/permission_sheet.dart';
import 'chat_state.dart';
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

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final message = _inputController.text.trim();
    if (message.isEmpty) return;

    // Add user message to state
    final userMessage = ChatMessage(
      eventId: DateTime.now().millisecondsSinceEpoch.toString(),
      role: MessageRole.user,
      content: message,
      agentId: 'user',
      agentType: 'user',
      timestamp: DateTime.now(),
    );

    ref.read(chatNotifierProvider(widget.sessionId).notifier).addMessage(userMessage);
    ref.read(chatNotifierProvider(widget.sessionId).notifier).setIsAgentWorking(true);

    // TODO: Send to WebSocket
    _inputController.clear();
    _scrollToBottom();

    // Simulate agent response for demo
    _simulateAgentResponse();
  }

  void _simulateAgentResponse() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;

      final assistantMessage = ChatMessage(
        eventId: DateTime.now().millisecondsSinceEpoch.toString(),
        role: MessageRole.assistant,
        content: 'I received your message. This is a simulated response. The actual implementation will stream responses from the Vide server via WebSocket.',
        agentId: 'main-agent',
        agentType: 'main',
        agentName: 'Main Agent',
        timestamp: DateTime.now(),
      );

      ref.read(chatNotifierProvider(widget.sessionId).notifier).addMessage(assistantMessage);
      ref.read(chatNotifierProvider(widget.sessionId).notifier).setIsAgentWorking(false);
      _scrollToBottom();
    });
  }

  void _abort() {
    // TODO: Send abort to WebSocket
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
    // TODO: Send permission response to WebSocket
    ref.read(chatNotifierProvider(widget.sessionId).notifier).setPendingPermission(null);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatNotifierProvider(widget.sessionId));
    final colorScheme = Theme.of(context).colorScheme;

    // Show permission sheet if there's a pending permission
    if (state.pendingPermission != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showModalBottomSheet(
          context: context,
          isDismissible: false,
          enableDrag: false,
          builder: (context) => PermissionSheet(
            request: state.pendingPermission!,
            onAllow: () => _handlePermission(true),
            onDeny: () => _handlePermission(false),
          ),
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Session'),
        actions: [
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
          // Working indicator
          if (state.isAgentWorking)
            LinearProgressIndicator(
              backgroundColor: colorScheme.primaryContainer,
              valueColor: AlwaysStoppedAnimation(colorScheme.primary),
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
            enabled: !state.isAgentWorking,
            isLoading: state.isAgentWorking,
            onSend: _sendMessage,
            onAbort: _abort,
          ),
        ],
      ),
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
