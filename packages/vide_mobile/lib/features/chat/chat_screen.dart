import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vide_client/vide_client.dart' as vc;

import '../../core/providers/connection_state_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/vide_colors.dart';
import '../../data/repositories/session_repository.dart';
import '../../domain/models/models.dart';
import '../permissions/permission_sheet.dart';
import 'chat_state.dart';
import 'widgets/agent_tab_bar.dart';
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

  /// Currently selected tab index (0 = main agent, 1+ = other agents).
  int _selectedTabIndex = 0;

  /// Per-tab scroll controllers keyed by agent ID.
  final Map<String, ScrollController> _scrollControllers = {};

  /// Cached list of agent IDs in tab order, to track index shifts.
  List<String> _agentTabIds = [];

  /// True while processing history events — suppresses scroll animations and shows loading.
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _subscribeToEvents();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _connectToSessionIfNeeded();
    });
  }

  void _connectToSessionIfNeeded() {
    final sessionRepo = ref.read(sessionRepositoryProvider.notifier);
    final currentState = ref.read(sessionRepositoryProvider);

    if (currentState.session?.sessionId == widget.sessionId &&
        currentState.isActive) {
      return;
    }

    sessionRepo
        .connectToExistingSession(widget.sessionId)
        .then((_) {})
        .catchError((e) {
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
    for (final controller in _scrollControllers.values) {
      controller.dispose();
    }
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
        _syncAgentTabs(domainAgents);

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
        _handleMessageEvent(
          eventId: eventId,
          agentId: event.agentId,
          agentType: event.agentType,
          agentName: event.agentName,
          content: content,
          role: role == 'user' ? MessageRole.user : MessageRole.assistant,
          isPartial: isPartial,
          timestamp: timestamp,
        );

      case vc.StatusEvent(:final status):
        notifier.updateAgentStatus(
            event.agentId, _convertAgentStatus(status), event.taskName);
        final agents = ref.read(chatNotifierProvider(widget.sessionId)).agents;
        final anyWorking = agents.any((a) => a.status == AgentStatus.working);
        notifier.setIsAgentWorking(anyWorking);

      case vc.ToolUseEvent(:final toolUseId, :final toolName, :final toolInput):
        notifier.addToolUse(ToolUse(
          toolUseId: toolUseId,
          toolName: toolName,
          input: toolInput,
          agentId: event.agentId,
          agentName: event.agentName,
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

      case vc.PermissionRequestEvent(
          :final requestId,
          :final toolName,
          :final toolInput
        ):
        notifier.setPendingPermission(PermissionRequest(
          requestId: requestId,
          toolName: toolName,
          toolInput: toolInput,
          agentId: event.agentId,
          agentName: event.agentName,
          timestamp: event.timestamp,
        ));

      case vc.PermissionResolvedEvent(:final requestId):
        final pending =
            ref.read(chatNotifierProvider(widget.sessionId)).pendingPermission;
        if (pending?.requestId == requestId) {
          notifier.setPendingPermission(null);
          if (_isPermissionSheetShowing && mounted) {
            Navigator.of(context).pop();
            _isPermissionSheetShowing = false;
          }
        }

      case vc.AgentSpawnedEvent():
        final agent = Agent(
          id: event.agentId,
          type: event.agentType,
          name: event.agentName ?? 'Agent',
          taskName: event.taskName,
        );
        notifier.addAgent(agent);
        _onAgentAdded(agent);

      case vc.AgentTerminatedEvent():
        notifier.removeAgent(event.agentId);
        _onAgentRemoved(event.agentId);

      case vc.TurnCompleteEvent():
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

  AgentStatus _convertAgentStatus(vc.VideAgentStatus status) {
    return switch (status) {
      vc.VideAgentStatus.working => AgentStatus.working,
      vc.VideAgentStatus.waitingForAgent => AgentStatus.waitingForAgent,
      vc.VideAgentStatus.waitingForUser => AgentStatus.waitingForUser,
      vc.VideAgentStatus.idle => AgentStatus.idle,
    };
  }

  void _syncAgentTabs(List<Agent> agents) {
    setState(() {
      _agentTabIds = agents.map((a) => a.id).toList();
      for (final agent in agents) {
        _scrollControllers.putIfAbsent(agent.id, () => ScrollController());
      }
    });
  }

  void _onAgentAdded(Agent agent) {
    setState(() {
      _agentTabIds.add(agent.id);
      _scrollControllers.putIfAbsent(agent.id, () => ScrollController());
    });
  }

  void _onAgentRemoved(String agentId) {
    final removedIndex = _agentTabIds.indexOf(agentId);
    if (removedIndex < 0) return;

    setState(() {
      _agentTabIds.remove(agentId);
      _scrollControllers[agentId]?.dispose();
      _scrollControllers.remove(agentId);

      if (_selectedTabIndex == removedIndex) {
        _selectedTabIndex = 0;
      } else if (_selectedTabIndex > removedIndex) {
        _selectedTabIndex--;
      }
    });
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

    if (role == MessageRole.user) {
      final isDuplicate = state.messages.any(
        (m) => m.role == MessageRole.user && m.content == content,
      );
      if (isDuplicate) return;
    }

    if (isPartial) {
      _streamingMessages[eventId] =
          (_streamingMessages[eventId] ?? '') + content;

      final existingIndex =
          state.messages.indexWhere((m) => m.eventId == eventId);

      if (existingIndex >= 0) {
        notifier.updateMessage(
          eventId,
          state.messages[existingIndex].copyWith(
            content: _streamingMessages[eventId]!,
            isStreaming: true,
          ),
        );
      } else {
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
      final accumulatedContent = _streamingMessages[eventId] ?? '';
      final finalContent = accumulatedContent + content;
      _streamingMessages.remove(eventId);

      final existingIndex =
          state.messages.indexWhere((m) => m.eventId == eventId);

      if (existingIndex >= 0) {
        notifier.updateMessage(
          eventId,
          state.messages[existingIndex].copyWith(
            content: finalContent,
            isStreaming: false,
          ),
        );
      } else if (finalContent.isNotEmpty) {
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

  ScrollController get _activeScrollController {
    if (_selectedTabIndex < _agentTabIds.length) {
      final agentId = _agentTabIds[_selectedTabIndex];
      final controller = _scrollControllers[agentId];
      if (controller != null) return controller;
    }
    return _scrollControllers.values.firstOrNull ?? ScrollController();
  }

  void _scrollToBottom() {
    if (_isLoadingHistory) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = _activeScrollController;
      if (controller.hasClients) {
        controller.animateTo(
          controller.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final controller in _scrollControllers.values) {
        if (controller.hasClients) {
          controller.jumpTo(controller.position.maxScrollExtent);
        }
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
    Navigator.of(context).pop();
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

  void _switchToAgentTab(String agentId) {
    final index = _agentTabIds.indexOf(agentId);
    if (index >= 0) {
      setState(() => _selectedTabIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatNotifierProvider(widget.sessionId));
    final connectionState = ref.watch(webSocketConnectionProvider);
    final colorScheme = Theme.of(context).colorScheme;

    if (state.pendingPermission != null && !_isPermissionSheetShowing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && state.pendingPermission != null) {
          _showPermissionSheet(state.pendingPermission!);
        }
      });
    }

    final isDisconnected =
        connectionState.status != WebSocketConnectionStatus.connected;
    final inputEnabled = !state.isAgentWorking && !isDisconnected;
    final hasAgents = state.agents.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.sessions),
        ),
        title: const Text('Session'),
        actions: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Center(child: ConnectionStatusChip()),
          ),
        ],
      ),
      body: Column(
        children: [
          const ConnectionStatusBanner(),
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
          if (hasAgents)
            AgentTabBar(
              agents: state.agents,
              selectedIndex: _selectedTabIndex,
              onTabSelected: (index) {
                setState(() => _selectedTabIndex = index);
              },
            ),
          Expanded(
            child: _isLoadingHistory
                ? const Center(child: CircularProgressIndicator())
                : _buildTabContent(state),
          ),
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

  Widget _buildTabContent(ChatState state) {
    if (state.messages.isEmpty && state.toolUses.isEmpty) {
      return _EmptyState();
    }

    final tabViews = <Widget>[
      for (final agentId in _agentTabIds)
        _MessageList(
          messages: state.messages.where((m) => m.agentId == agentId).toList(),
          toolUses: state.toolUses.where((t) => t.agentId == agentId).toList(),
          toolResults: state.toolResults,
          agents: state.agents,
          scrollController: _scrollControllers[agentId] ?? ScrollController(),
          onAgentTap: _switchToAgentTab,
        ),
    ];

    if (tabViews.isEmpty) {
      return _EmptyState();
    }

    return IndexedStack(
      index: _selectedTabIndex.clamp(0, tabViews.length - 1),
      children: tabViews,
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
  final List<Agent> agents;
  final ScrollController scrollController;
  final ValueChanged<String>? onAgentTap;

  const _MessageList({
    required this.messages,
    required this.toolUses,
    required this.toolResults,
    required this.agents,
    required this.scrollController,
    this.onAgentTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = <_ChatItem>[];

    for (final message in messages) {
      items.add(_ChatItem.message(message));
    }

    for (final toolUse in toolUses) {
      items.add(_ChatItem.tool(toolUse, toolResults[toolUse.toolUseId]));
    }

    items.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (items.isEmpty) {
      return const Center(
        child: Text(
          'No messages from this agent yet',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return item.when(
          message: (message) => MessageBubble(message: message),
          tool: (toolUse, result) {
            if (_isSpawnAgentTool(toolUse)) {
              return _SpawnAgentCard(
                toolUse: toolUse,
                agents: agents,
                onTap: onAgentTap,
              );
            }
            return ToolCard(
              toolUse: toolUse,
              result: result,
            );
          },
        );
      },
    );
  }

  bool _isSpawnAgentTool(ToolUse toolUse) {
    return toolUse.toolName == 'mcp__vide-agent__spawnAgent';
  }
}

class _SpawnAgentCard extends StatelessWidget {
  final ToolUse toolUse;
  final List<Agent> agents;
  final ValueChanged<String>? onTap;

  const _SpawnAgentCard({
    required this.toolUse,
    required this.agents,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;
    final colorScheme = Theme.of(context).colorScheme;

    final agentName = toolUse.input['name'] as String? ?? 'Agent';
    final agentType = toolUse.input['agentType'] as String? ?? '';

    final matchingAgent = agents.cast<Agent?>().firstWhere(
          (a) => a!.name == agentName,
          orElse: () => null,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: VideSpacing.sm,
        vertical: VideSpacing.xs,
      ),
      child: GestureDetector(
        onTap:
            matchingAgent != null ? () => onTap?.call(matchingAgent.id) : null,
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: VideRadius.smAll,
            border: Border.all(
              color: videColors.glassBorder,
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: VideSpacing.md,
            vertical: 12,
          ),
          child: Row(
            children: [
              Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: videColors.accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agentName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: videColors.accent,
                      ),
                    ),
                    if (agentType.isNotEmpty)
                      Text(
                        agentType,
                        style: TextStyle(
                          fontSize: 12,
                          color: videColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (matchingAgent != null)
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: videColors.textTertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

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
