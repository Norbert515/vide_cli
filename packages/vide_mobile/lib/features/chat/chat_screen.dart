import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vide_client/vide_client.dart';

import '../../core/providers/connection_state_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/vide_colors.dart';
import '../../data/repositories/session_repository.dart';
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

  /// The session we're connected to.
  RemoteVideSession? _session;

  /// Stream subscriptions.
  StreamSubscription<VideEvent>? _eventSubscription;
  StreamSubscription<List<VideAgent>>? _agentsSubscription;
  StreamSubscription<void>? _conversationSubscription;

  /// Tracks whether permission sheet is currently showing.
  bool _isPermissionSheetShowing = false;

  /// Currently selected tab index (0 = main agent, 1+ = other agents).
  int _selectedTabIndex = 0;

  /// Per-tab scroll controllers keyed by agent ID.
  final Map<String, ScrollController> _scrollControllers = {};

  /// Current agents list — owned by RemoteVideSession, cached here for rendering.
  List<VideAgent> _agents = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _connectToSession();
    });
  }

  Future<void> _connectToSession() async {
    final sessionRepo = ref.read(sessionRepositoryProvider.notifier);

    try {
      // Reuse the existing session if it matches (e.g., just created).
      // Only open a new connection when navigating to a different session.
      final existing = sessionRepo.session;
      final RemoteVideSession session;
      if (existing != null && existing.id == widget.sessionId && sessionRepo.isActive) {
        session = existing;
      } else {
        session = await sessionRepo.connectToExistingSession(widget.sessionId);
      }
      if (!mounted) return;
      setState(() => _session = session);
      _subscribeToSession(session);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect: $e'),
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }
    }
  }

  void _subscribeToSession(RemoteVideSession session) {
    // Seed agents from current session state (events may have already been
    // delivered before we subscribed, e.g., when reusing an existing session).
    final currentAgents = session.agents;
    if (currentAgents.isNotEmpty) {
      _agents = currentAgents;
      for (final agent in currentAgents) {
        _scrollControllers.putIfAbsent(agent.id, () => ScrollController());
      }
    }

    // 1. Events stream — only for UI-specific events (permissions, errors).
    //    Everything else (messages, tools, agents, status) is already
    //    accumulated by RemoteVideSession and exposed via its getters/streams.
    _eventSubscription = session.events.listen(_handleEvent);

    // 2. Agents stream — updates agent tabs
    _agentsSubscription = session.agentsStream.listen((agents) {
      if (!mounted) return;
      setState(() {
        _agents = agents;
        for (final agent in agents) {
          _scrollControllers.putIfAbsent(agent.id, () => ScrollController());
        }
        // Clean up controllers for removed agents
        final agentIds = agents.map((a) => a.id).toSet();
        final removedIds = _scrollControllers.keys
            .where((id) => !agentIds.contains(id))
            .toList();
        for (final id in removedIds) {
          _scrollControllers[id]?.dispose();
          _scrollControllers.remove(id);
        }
        // Adjust selected tab if needed
        if (_selectedTabIndex >= _agents.length && _agents.isNotEmpty) {
          _selectedTabIndex = 0;
        }
      });
    });

    // 3. Conversation state changes — triggers rebuild for new messages/tools
    _conversationSubscription =
        session.conversationState.onStateChanged.listen((_) {
      if (mounted) {
        setState(() {});
        _scrollToBottom();
      }
    });
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _agentsSubscription?.cancel();
    _conversationSubscription?.cancel();
    _inputController.dispose();
    for (final controller in _scrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _handleEvent(VideEvent event) {
    final notifier = ref.read(chatNotifierProvider(widget.sessionId).notifier);

    switch (event) {
      case PermissionRequestEvent():
        notifier.setPendingPermission(event);

      case PermissionResolvedEvent(:final requestId):
        final pending =
            ref.read(chatNotifierProvider(widget.sessionId)).pendingPermission;
        if (pending?.requestId == requestId) {
          notifier.setPendingPermission(null);
          if (_isPermissionSheetShowing && mounted) {
            Navigator.of(context).pop();
            _isPermissionSheetShowing = false;
          }
        }

      case ErrorEvent(:final message):
        notifier.setError(message);

      default:
        // All other events (messages, tools, agents, status, history, etc.)
        // are handled by RemoteVideSession internally and exposed via
        // session.agents, session.agentsStream, session.conversationState,
        // and session.isProcessing.
        break;
    }
  }

  void _sendMessage() {
    final message = _inputController.text.trim();
    if (message.isEmpty) return;

    final sessionRepo = ref.read(sessionRepositoryProvider.notifier);
    sessionRepo.sendMessage(message);

    _inputController.clear();
    _scrollToBottom();
  }

  void _abort() {
    final sessionRepo = ref.read(sessionRepositoryProvider.notifier);
    sessionRepo.abort();
  }

  ScrollController get _activeScrollController {
    if (_selectedTabIndex < _agents.length) {
      final agentId = _agents[_selectedTabIndex].id;
      final controller = _scrollControllers[agentId];
      if (controller != null) return controller;
    }
    return _scrollControllers.values.firstOrNull ?? ScrollController();
  }

  void _scrollToBottom() {
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

  void _handlePermission(bool allow, {bool remember = false}) {
    final state = ref.read(chatNotifierProvider(widget.sessionId));
    final pendingPermission = state.pendingPermission;
    if (pendingPermission == null) return;

    final sessionRepo = ref.read(sessionRepositoryProvider.notifier);
    sessionRepo.respondToPermission(
      pendingPermission.requestId,
      allow,
      remember: remember,
    );

    ref
        .read(chatNotifierProvider(widget.sessionId).notifier)
        .setPendingPermission(null);
    _isPermissionSheetShowing = false;
    Navigator.of(context).pop();
  }

  void _showPermissionSheet(PermissionRequestEvent request) {
    if (_isPermissionSheetShowing) return;
    _isPermissionSheetShowing = true;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => PermissionSheet(
        request: request,
        onAllow: ({required bool remember}) =>
            _handlePermission(true, remember: remember),
        onDeny: () => _handlePermission(false),
      ),
    ).whenComplete(() {
      _isPermissionSheetShowing = false;
    });
  }

  void _openToolDetail(ToolContent tool) {
    context.push(
      AppRoutes.toolDetailPath(widget.sessionId),
      extra: tool,
    );
  }

  void _switchToAgentTab(String agentId) {
    final index = _agents.indexWhere((a) => a.id == agentId);
    if (index >= 0) {
      setState(() => _selectedTabIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatNotifierProvider(widget.sessionId));
    final connectionState = ref.watch(webSocketConnectionProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final session = _session;

    if (state.pendingPermission != null && !_isPermissionSheetShowing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && state.pendingPermission != null) {
          _showPermissionSheet(state.pendingPermission!);
        }
      });
    }

    final isDisconnected =
        connectionState.status != WebSocketConnectionStatus.connected;
    final isProcessing = session?.isProcessing ?? false;
    final inputEnabled = !isProcessing && !isDisconnected;
    final hasAgents = _agents.isNotEmpty;

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
              agents: _agents,
              selectedIndex: _selectedTabIndex,
              onTabSelected: (index) {
                setState(() => _selectedTabIndex = index);
              },
            ),
          Expanded(child: _buildTabContent()),
          InputBar(
            controller: _inputController,
            enabled: inputEnabled,
            isLoading: isProcessing,
            onSend: _sendMessage,
            onAbort: _abort,
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    final session = _session;
    if (session == null || _agents.isEmpty) {
      return _EmptyState();
    }

    final tabViews = <Widget>[
      for (final (index, agent) in _agents.indexed)
        _MessageList(
          agentState: session.conversationState.getAgentState(agent.id),
          isMainAgent: index == 0,
          agents: _agents,
          scrollController: _scrollControllers[agent.id] ?? ScrollController(),
          onAgentTap: _switchToAgentTab,
          onToolTap: _openToolDetail,
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

/// Renders conversation entries for a single agent.
///
/// Content comes from [AgentConversationState.messages] which contains
/// [ConversationEntry]s with interleaved [TextContent] and [ToolContent].
class _MessageList extends StatelessWidget {
  final AgentConversationState? agentState;
  final bool isMainAgent;
  final List<VideAgent> agents;
  final ScrollController scrollController;
  final ValueChanged<String>? onAgentTap;
  final void Function(ToolContent tool)? onToolTap;

  const _MessageList({
    required this.agentState,
    required this.isMainAgent,
    required this.agents,
    required this.scrollController,
    this.onAgentTap,
    this.onToolTap,
  });

  @override
  Widget build(BuildContext context) {
    final messages = agentState?.messages ?? [];

    if (messages.isEmpty) {
      return const Center(
        child: Text(
          'No messages from this agent yet',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // Flatten ConversationEntry content blocks into render items
    final items = <_RenderItem>[];
    for (final entry in messages) {
      for (final content in entry.content) {
        switch (content) {
          case TextContent():
            if (content.text.isNotEmpty) {
              items.add(_RenderItem.text(entry, content));
            }
          case ToolContent():
            items.add(_RenderItem.tool(entry, content));
        }
      }
    }

    if (items.isEmpty) {
      return const Center(
        child: Text(
          'No messages from this agent yet',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          switch (item) {
            case _TextRenderItem(:final entry):
              return MessageBubble(entry: entry);
            case _ToolRenderItem(:final tool):
              if (_isSpawnAgentTool(tool)) {
                return _SpawnAgentCard(
                  tool: tool,
                  agents: agents,
                  onTap: onAgentTap,
                );
              }
              return ToolCard(
                tool: tool,
                onTap: () => onToolTap?.call(tool),
              );
          }
        },
      ),
    );
  }

  bool _isSpawnAgentTool(ToolContent tool) {
    return tool.toolName == 'mcp__vide-agent__spawnAgent';
  }
}

class _SpawnAgentCard extends StatelessWidget {
  final ToolContent tool;
  final List<VideAgent> agents;
  final ValueChanged<String>? onTap;

  const _SpawnAgentCard({
    required this.tool,
    required this.agents,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;
    final colorScheme = Theme.of(context).colorScheme;

    final agentName = tool.toolInput['name'] as String? ?? 'Agent';
    final agentType = tool.toolInput['agentType'] as String? ?? '';

    final matchingAgent = agents.cast<VideAgent?>().firstWhere(
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

/// A flattened render item from ConversationEntry content blocks.
sealed class _RenderItem {
  factory _RenderItem.text(ConversationEntry entry, TextContent content) =
      _TextRenderItem;
  factory _RenderItem.tool(ConversationEntry entry, ToolContent tool) =
      _ToolRenderItem;
}

class _TextRenderItem implements _RenderItem {
  final ConversationEntry entry;
  final TextContent content;

  _TextRenderItem(this.entry, this.content);
}

class _ToolRenderItem implements _RenderItem {
  final ConversationEntry entry;
  final ToolContent tool;

  _ToolRenderItem(this.entry, this.tool);
}
