import 'dart:async';

import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_cli/components/enhanced_loading_indicator.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/main.dart';
import 'package:vide_cli/modules/agent_network/components/attachment_text_field.dart';
import 'package:vide_cli/modules/agent_network/components/chat_input_area.dart';
import 'package:vide_cli/modules/agent_network/components/message_bubble.dart';
import 'package:vide_cli/modules/agent_network/components/tool_invocations/todo_list_component.dart';
import 'package:vide_cli/modules/commands/command.dart';
import 'package:vide_cli/modules/commands/command_provider.dart';
import 'package:vide_cli/modules/git/git_popup.dart';
import 'package:vide_cli/modules/permissions/components/plan_approval_dialog.dart';
import 'package:vide_cli/modules/permissions/permission_scope.dart';
import 'package:vide_cli/modules/permissions/permission_service.dart';
import 'package:vide_cli/modules/settings/settings_dialog.dart';
import 'package:vide_core/vide_core.dart';
import 'package:vide_cli/modules/agent_network/state/vide_session_providers.dart';
import 'package:vide_cli/modules/remote/daemon_connection_service.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_cli/components/vide_scaffold.dart';

class NetworkExecutionPage extends StatefulComponent {
  const NetworkExecutionPage({super.key});

  static Future<void> push(
    BuildContext context, {
    required VideSession session,
  }) async {
    context.read(sessionSelectionProvider.notifier).selectSession(session);

    // Mark session as seen on the daemon (best-effort).
    final daemonState = context.read(daemonConnectionProvider);
    if (daemonState.isConnected) {
      context
          .read(daemonConnectionProvider.notifier)
          .markSessionSeen(session.id);
    }

    return Navigator.of(context).push<void>(
      PageRoute(
        builder: (context) => const NetworkExecutionPage(),
        settings: RouteSettings(),
      ),
    );
  }

  @override
  State<NetworkExecutionPage> createState() => _NetworkExecutionPageState();
}

class _NetworkExecutionPageState extends State<NetworkExecutionPage> {
  DateTime? _lastCtrlCPress;
  bool _showQuitWarning = false;
  static const _quitTimeWindow = Duration(seconds: 2);

  /// Tracks whether conversation data has loaded for the main agent.
  /// For local sessions this is true immediately; for remote sessions
  /// the WebSocket must deliver history events first.
  bool _conversationReady = false;
  StreamSubscription<AgentConversationState>? _conversationReadySub;
  String? _trackedAgentId;

  @override
  void initState() {
    super.initState();
    // We're not on the home page anymore - set this early so sidebar shows
    context.read(isOnHomePageProvider.notifier).state = false;
  }

  void _trackConversationReady(VideSession session, String agentId) {
    if (_trackedAgentId == agentId) return;
    _conversationReadySub?.cancel();
    _trackedAgentId = agentId;

    // Check synchronously first
    final existing = session.getConversation(agentId);
    if (existing != null) {
      _conversationReady = true;
      return;
    }

    // Subscribe and wait for the first event
    _conversationReadySub = session.conversationStream(agentId).listen((_) {
      if (!_conversationReady && mounted) {
        setState(() => _conversationReady = true);
      }
      _conversationReadySub?.cancel();
      _conversationReadySub = null;
    });
  }

  @override
  void dispose() {
    _conversationReadySub?.cancel();
    // Back to home page
    context.read(isOnHomePageProvider.notifier).state = true;
    context.read(sessionSelectionProvider.notifier).clear();
    super.dispose();
  }

  Component _buildAgentChat(BuildContext context, List<String> agentIds) {
    // Get selected agent ID from provider, or use the first agent
    final selectedAgentIdNotifier = context.read(
      selectedAgentIdProvider.notifier,
    );
    final selectedAgentId = context.watch(selectedAgentIdProvider);

    // Find the selected agent, or default to the first agent
    String agentId =
        selectedAgentId ?? (agentIds.isNotEmpty ? agentIds[0] : '');

    // Ensure selected agent is still valid
    if (!agentIds.contains(agentId) && agentIds.isNotEmpty) {
      agentId = agentIds[0];
      selectedAgentIdNotifier.state = agentId;
    }

    final session = context.read(currentVideSessionProvider)!;
    return Expanded(
      child: _AgentChat(
        key: ValueKey(agentId),
        agentId: agentId,
        networkId: session.id,
        showQuitWarning: _showQuitWarning,
        onExit: _exitWithDaemonCleanup,
      ),
    );
  }

  Future<void> _exitWithDaemonCleanup() async {
    final session = context.read(currentVideSessionProvider);
    final sessionId = session?.id;
    if (sessionId != null) {
      final daemonState = context.read(daemonConnectionProvider);
      if (daemonState.isConnected) {
        try {
          await context
              .read(daemonConnectionProvider.notifier)
              .stopSession(sessionId)
              .timeout(const Duration(seconds: 3));
        } catch (_) {
          // Best-effort — don't block exit if stop fails or times out.
        }
      }
    }
    shutdownApp();
  }

  void _handleCtrlC() {
    final now = DateTime.now();

    if (_lastCtrlCPress != null &&
        now.difference(_lastCtrlCPress!) < _quitTimeWindow) {
      // Second press within time window - stop daemon session and quit
      _exitWithDaemonCleanup();
    } else {
      // First press - show warning
      setState(() {
        _showQuitWarning = true;
        _lastCtrlCPress = now;
      });

      // Hide warning after time window
      Future.delayed(_quitTimeWindow, () {
        if (mounted) {
          setState(() {
            _showQuitWarning = false;
            _lastCtrlCPress = null;
          });
        }
      });
    }
  }

  @override
  Component build(BuildContext context) {
    // Check connection state before building the full scaffold.
    // Remote sessions start disconnected while the WebSocket connects.
    final connectionAsync = context.watch(sessionConnectionProvider);
    final isConnected = connectionAsync.valueOrNull ?? true;
    final session = context.watch(currentVideSessionProvider);

    if (session == null || !isConnected) {
      return _buildConnectingScreen(context, label: 'Connecting to session...');
    }

    final sessionState = session.state;

    // Watch for agent changes - this is crucial for remote sessions where
    // agents are populated asynchronously from history/connected events
    final agentsAsync = context.watch(videSessionAgentsProvider);
    final agents = agentsAsync.valueOrNull ?? sessionState.agents;
    final agentIds = agents.map((a) => a.id).toList();

    // For remote sessions, conversation data loads asynchronously after
    // the WebSocket connects. Show loading screen until it arrives to
    // avoid a jarring empty scaffold.
    if (agentIds.isNotEmpty) {
      _trackConversationReady(session, agentIds.first);
      if (!_conversationReady) {
        return _buildConnectingScreen(context, label: 'Loading conversation...');
      }
    }

    // Build the main content column
    final content = Container(
      padding: EdgeInsets.symmetric(horizontal: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (agentIds.isEmpty)
            Center(child: Text('No agents'))
          else
            _buildAgentChat(context, agentIds),
        ],
      ),
    );

    final innerContent = PermissionScope(
      child: Focusable(
        focused: true,
        onKeyEvent: (event) {
          // Ctrl+C: Show quit warning (double press to quit)
          if (event.logicalKey == LogicalKey.keyC && event.isControlPressed) {
            _handleCtrlC();
            return true;
          }

          return false;
        },
        child: MouseRegion(child: content),
      ),
    );

    return VideScaffold(child: innerContent);
  }

  /// Full-screen loading state shown while connecting to a remote session
  /// or waiting for conversation history to load.
  Component _buildConnectingScreen(BuildContext context, {required String label}) {
    final theme = VideTheme.of(context);

    return Container(
      decoration: BoxDecoration(color: theme.base.surface),
      child: Center(
        child: _LoadingIndicator(label: label),
      ),
    );
  }
}

class _AgentChat extends StatefulComponent {
  final String agentId;
  final String networkId;
  final bool showQuitWarning;
  final Future<void> Function() onExit;

  const _AgentChat({
    required this.agentId,
    required this.networkId,
    required this.onExit,
    this.showQuitWarning = false,
    super.key,
  });

  @override
  State<_AgentChat> createState() => _AgentChatState();
}

class _AgentChatState extends State<_AgentChat> {
  StreamSubscription<AgentConversationState>? _conversationSubscription;
  StreamSubscription<String?>? _queueSubscription;
  StreamSubscription<String?>? _modelSubscription;
  AgentConversationState? _conversation;
  final _scrollController = AutoScrollController();
  String? _commandResult;
  bool _commandResultIsError = false;
  String? _queuedMessage;
  String? _model;

  /// Tracks attachments sent with user messages (keyed by message content).
  final Map<String, List<VideAttachment>> _sentAttachments = {};

  Future<void> _loadInitialAgentRuntimeMetadata(VideSession session) async {
    final queuedMessage = await session.getQueuedMessage(component.agentId);
    final model = await session.getModel(component.agentId);
    if (!mounted) return;
    setState(() {
      _queuedMessage = queuedMessage;
      _model = model;
    });
    context.read(currentModelProvider.notifier).state = model;
  }

  @override
  void initState() {
    super.initState();

    final session = context.read(currentVideSessionProvider);
    if (session == null) return;

    // Listen to conversation updates
    _conversationSubscription = session
        .conversationStream(component.agentId)
        .listen((conversation) {
          setState(() {
            _conversation = conversation;
          });

          // Sync token stats to AgentMetadata for persistence and network-wide tracking
          _syncTokenStats(conversation, session);
        });
    _conversation = session.getConversation(component.agentId);

    // Listen to queued message updates
    _queueSubscription = session.queuedMessageStream(component.agentId).listen((
      text,
    ) {
      setState(() => _queuedMessage = text);
    });

    // Listen to model updates
    _modelSubscription = session.modelStream(component.agentId).listen((model) {
      setState(() => _model = model);
      context.read(currentModelProvider.notifier).state = model;
    });

    unawaited(_loadInitialAgentRuntimeMetadata(session));
  }

  void _syncTokenStats(
    AgentConversationState conversation,
    VideSession session,
  ) {
    session.updateAgentTokenStats(
      component.agentId,
      totalInputTokens: conversation.totalInputTokens,
      totalOutputTokens: conversation.totalOutputTokens,
      totalCacheReadInputTokens: conversation.totalCacheReadInputTokens,
      totalCacheCreationInputTokens: conversation.totalCacheCreationInputTokens,
      totalCostUsd: conversation.totalCostUsd,
    );
  }

  @override
  void dispose() {
    _conversationSubscription?.cancel();
    _queueSubscription?.cancel();
    _modelSubscription?.cancel();
    super.dispose();
  }

  void _sendMessage(VideMessage message) {
    if (message.attachments != null && message.attachments!.isNotEmpty) {
      _sentAttachments[message.text] = message.attachments!;
    }
    final session = context.read(currentVideSessionProvider);
    session?.sendMessage(message, agentId: component.agentId);
  }

  bool _isLastAgent() {
    final session = context.read(currentVideSessionProvider);
    if (session == null)
      return true; // If no session, treat as last agent (safe default)
    return session.state.agents.length <= 1;
  }

  Future<void> _handleCommand(String commandInput) async {
    final session = context.read(currentVideSessionProvider);
    final dispatcher = context.read(commandDispatcherProvider);
    final commandContext = CommandContext(
      agentId: component.agentId,
      workingDirectory: session?.state.workingDirectory ?? '',
      isLastAgent: _isLastAgent(),
      sendMessage: (message) {
        session?.sendMessage(
          VideMessage(text: message),
          agentId: component.agentId,
        );
      },
      clearConversation: () async {
        await session?.clearConversation(agentId: component.agentId);
        setState(() {
          _conversation = null;
        });
      },
      exitApp: component.onExit,
      detachApp: shutdownApp,
      toggleIdeMode: () {
        final container = ProviderScope.containerOf(context);
        final current = container.read(ideModeEnabledProvider);
        container.read(ideModeEnabledProvider.notifier).state = !current;

        // Also persist to settings
        final configManager = container.read(videConfigManagerProvider);
        final settings = configManager.readGlobalSettings();
        configManager.writeGlobalSettings(
          settings.copyWith(ideModeEnabled: !current),
        );
      },
      forkAgent: (name) async {
        final newAgentId = await session?.forkAgent(
          component.agentId,
          name: name,
        );
        return newAgentId ?? '';
      },
      killAgent: () async {
        await session?.terminateAgent(
          component.agentId,
          terminatedBy: component.agentId, // Self-termination
          reason: 'User invoked /kill command',
        );
        // Navigation will be handled by the network state update since the agent is removed
      },
      showGitPopup: () async {
        final repoPath = context.read(currentRepoPathProvider);
        await GitPopup.show(
          context,
          repoPath: repoPath,
          onSendMessage: (message) {
            session?.sendMessage(
              VideMessage(text: message),
              agentId: component.agentId,
            );
          },
          onSwitchWorktree: (path) async {
            final container = ProviderScope.containerOf(context);
            container.read(repoPathOverrideProvider.notifier).state = path;
            // Use VideSession.setWorktreePath() instead of direct provider access
            await session?.setWorktreePath(path);
          },
        );
      },
      showSettingsDialog: () async {
        await SettingsPopup.show(context);
      },
      showSessionLogs: () {
        final sessionId = session?.id;
        if (sessionId == null) return;
        final logPath = VideLogger.instance.sessionLogPath(sessionId);
        context.read(filePreviewPathProvider.notifier).state = logPath;
      },
    );

    final result = await dispatcher.dispatch(commandInput, commandContext);

    setState(() {
      _commandResult = result.success ? result.message : result.error;
      _commandResultIsError = !result.success;
    });

    // Auto-clear command result after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _commandResult = null;
        });
      }
    });
  }

  List<CommandSuggestion> _getCommandSuggestions(String prefix) {
    final registry = context.read(commandRegistryProvider);
    final allCommands = registry.allCommands;

    // Filter commands that match the prefix
    final matching = allCommands.where((cmd) {
      return cmd.name.toLowerCase().startsWith(prefix.toLowerCase());
    }).toList();

    // Convert to CommandSuggestion
    return matching.map((cmd) {
      return CommandSuggestion(name: cmd.name, description: cmd.description);
    }).toList();
  }

  List<Map<String, dynamic>>? _getLatestTodos() {
    final conv = _conversation;
    if (conv == null) return null;
    for (final entry in conv.messages.reversed) {
      for (final content in entry.content.reversed) {
        if (content is ToolContent && content.toolName == 'TodoWrite') {
          final todos = content.toolInput['todos'];
          if (todos is List) {
            return todos.cast<Map<String, dynamic>>();
          }
        }
      }
    }
    return null;
  }

  void _handlePermissionResponse(
    PermissionRequest request,
    bool granted,
    bool remember, {
    String? patternOverride,
    String? denyReason,
  }) {
    final session = context.read(currentVideSessionProvider);

    String reason;
    if (granted) {
      reason = 'User approved';
    } else if (denyReason != null && denyReason.isNotEmpty) {
      reason = denyReason;
    } else {
      reason = 'User denied';
    }

    session?.respondToPermission(
      request.requestId,
      allow: granted,
      message: reason,
      remember: remember,
      patternOverride: patternOverride,
    );

    // Dequeue the current request to show the next one
    context.read(permissionStateProvider.notifier).dequeueRequest();
  }

  void _handleAskUserQuestionResponse(
    AskUserQuestionUIRequest request,
    Map<String, String> answers,
  ) {
    final session = context.read(currentVideSessionProvider);

    // Send the response through the session (unified path for local and remote)
    session?.respondToAskUserQuestion(request.requestId, answers: answers);

    // Dequeue the current request to show the next one
    context.read(askUserQuestionStateProvider.notifier).dequeueRequest();
  }

  void _handlePlanApprovalResponse(
    PlanApprovalUIRequest request,
    String action,
    String? feedback,
  ) {
    final session = context.read(currentVideSessionProvider);

    session?.respondToPlanApproval(
      request.requestId,
      action: action,
      feedback: feedback,
    );

    // Dequeue the current request to show the next one
    context.read(planApprovalStateProvider.notifier).dequeueRequest();
  }

  bool _handleKeyEvent(KeyboardEvent event) {
    // Don't intercept keys when plan approval dialog is active —
    // the dialog handles its own key events (Escape, Tab, etc.)
    final planState = context.read(planApprovalStateProvider);
    if (planState.current != null) return false;

    if (event.logicalKey == LogicalKey.escape) {
      final session = context.read(currentVideSessionProvider);
      if (session == null) return false;

      // If there's a queued message, clear it first
      if (_queuedMessage != null) {
        unawaited(session.clearQueuedMessage(component.agentId));
        return true;
      }
      // Otherwise abort the current processing
      session.abortAgent(component.agentId);
      return true;
    }

    // Tab: Quick access to settings (when not consumed by text field autocomplete)
    if (event.logicalKey == LogicalKey.tab) {
      SettingsPopup.show(context);
      return true;
    }

    return false;
  }

  /// Builds the filtered list of messages (excluding slash commands)
  List<ConversationEntry> _getFilteredMessages() {
    final conv = _conversation;
    if (conv == null) return [];
    return conv.messages.reversed
        .where((entry) => !(entry.role == 'user' && entry.text.startsWith('/')))
        .toList();
  }

  /// Whether the current agent is working.
  ///
  /// Uses [AgentConversationState.isProcessing] which is updated synchronously
  /// via the sync broadcast event stream, so it's correct immediately after
  /// [sendMessage] — unlike [videSessionAgentsProvider] which is stream-based
  /// and can miss the initial status event on broadcast streams.
  bool get _isAgentWorking => _conversation?.isProcessing ?? false;

  /// Groups consecutive tool-only assistant entries into single display items.
  /// Returns a list where each element is either a single [ConversationEntry]
  /// or a list of consecutive tool-only entries to be rendered in one box.
  List<Object> _groupMessages(List<ConversationEntry> messages) {
    final items = <Object>[];
    List<ConversationEntry>? currentToolGroup;

    for (final message in messages) {
      if (MessageBubble.isToolOnlyEntry(message)) {
        currentToolGroup ??= [];
        currentToolGroup.add(message);
      } else {
        if (currentToolGroup != null) {
          items.add(currentToolGroup);
          currentToolGroup = null;
        }
        items.add(message);
      }
    }
    if (currentToolGroup != null) {
      items.add(currentToolGroup);
    }
    return items;
  }

  /// Builds the message list using ListView.builder for better performance.
  /// This avoids rebuilding all messages when unrelated state changes (like spinner).
  Component _buildMessageList(BuildContext context) {
    final todos = _getLatestTodos();
    final hasTodos = todos != null && todos.isNotEmpty;
    final filteredMessages = _getFilteredMessages();
    final groupedItems = _groupMessages(filteredMessages);

    // Total items = todos (if any) + grouped items
    final itemCount = (hasTodos ? 1 : 0) + groupedItems.length;

    return SelectionArea(
      onSelectionCompleted: ClipboardManager.copy,
      child: ListView.builder(
        controller: _scrollController,
        reverse: true,
        padding: EdgeInsets.all(1),
        lazy: true,
        itemCount: itemCount,
        itemBuilder: (context, index) {
          // First item (index 0) is the todo list if it exists
          if (hasTodos && index == 0) {
            return TodoListComponent(todos: todos);
          }

          final itemIndex = hasTodos ? index - 1 : index;
          final item = groupedItems[itemIndex];
          final session = context.read(currentVideSessionProvider);
          final workingDir = session?.state.workingDirectory ?? '';

          // Grouped tool-only entries: render all together without borders
          if (item is List<ConversationEntry>) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final entry in item)
                    MessageBubble(
                      key: ValueKey(entry.hashCode),
                      entry: entry,
                      networkId: component.networkId,
                      agentId: component.agentId,
                      workingDirectory: workingDir,
                      sentAttachments: _sentAttachments,
                    ),
                ],
              ),
            );
          }

          // Single entry (text + tools, user message, etc.)
          final message = item as ConversationEntry;
          return MessageBubble(
            key: ValueKey(message.hashCode),
            entry: message,
            networkId: component.networkId,
            agentId: component.agentId,
            workingDirectory: workingDir,
            sentAttachments: _sentAttachments,
          );
        },
      ),
    );
  }

  @override
  Component build(BuildContext context) {
    // Get the current plan approval queue state from the provider
    final planApprovalQueueState = context.watch(planApprovalStateProvider);
    final currentPlanApproval = planApprovalQueueState.current;

    return Focusable(
      onKeyEvent: _handleKeyEvent,
      focused: true,
      child: Container(
        child: Column(
          children: [
            // Messages area (hidden when plan approval is active to give it
            // the full Expanded space for scrolling)
            if (currentPlanApproval == null)
              Expanded(
                child: _conversation == null
                    ? Center(child: EnhancedLoadingIndicator())
                    : _buildMessageList(context),
              ),

            // Plan approval dialog takes the Expanded slot when active
            if (currentPlanApproval != null)
              Expanded(
                child: PlanApprovalDialog(
                  request: currentPlanApproval,
                  onResponse: (action, feedback) => _handlePlanApprovalResponse(
                    currentPlanApproval,
                    action,
                    feedback,
                  ),
                  key: Key('plan_approval_${currentPlanApproval.requestId}'),
                ),
              ),

            // Input area
            ChatInputArea(
              agentId: component.agentId,
              queuedMessage: _queuedMessage,
              isAgentWorking: _isAgentWorking,
              showQuitWarning: component.showQuitWarning,
              hasPlanApproval: currentPlanApproval != null,
              commandResult: _commandResult,
              commandResultIsError: _commandResultIsError,
              conversation: _conversation,
              model: _model,
              onClearQueue: () {
                final session = context.read(currentVideSessionProvider);
                if (session != null) {
                  unawaited(session.clearQueuedMessage(component.agentId));
                }
              },
              onSendMessage: _sendMessage,
              onCommand: _handleCommand,
              onPermissionResponse: _handlePermissionResponse,
              onAskUserQuestionResponse: _handleAskUserQuestionResponse,
              onEscape: () {
                final session = context.read(currentVideSessionProvider);
                if (session == null) return;
                if (_queuedMessage != null) {
                  unawaited(session.clearQueuedMessage(component.agentId));
                } else {
                  session.abortAgent(component.agentId);
                }
              },
              commandSuggestions: _getCommandSuggestions,
            ),
          ],
        ),
      ),
    );
  }
}

/// Minimal centered loading indicator with braille spinner and label.
class _LoadingIndicator extends StatefulComponent {
  final String label;

  const _LoadingIndicator({required this.label});

  @override
  State<_LoadingIndicator> createState() => _LoadingIndicatorState();
}

class _LoadingIndicatorState extends State<_LoadingIndicator>
    with TickerProviderStateMixin {
  static const _frames = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];

  late AnimationController _controller;

  int get _frameIndex =>
      (_controller.value * _frames.length).floor() % _frames.length;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )
      ..addListener(() => setState(() {}))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    final dim = theme.base.onSurface.withOpacity(TextOpacity.secondary);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'VIDE',
          style: TextStyle(
            color: theme.base.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 1),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_frames[_frameIndex], style: TextStyle(color: dim)),
            SizedBox(width: 1),
            Text(component.label, style: TextStyle(color: dim)),
          ],
        ),
      ],
    );
  }
}
