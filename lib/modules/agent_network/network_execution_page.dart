import 'dart:async';
import 'dart:io';

import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_cli/components/enhanced_loading_indicator.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/main.dart';
import 'package:vide_cli/modules/agent_network/components/attachment_text_field.dart';
import 'package:vide_cli/modules/agent_network/components/connecting_indicator.dart';
import 'package:vide_cli/modules/agent_network/components/chat_input_area.dart';
import 'package:vide_cli/modules/agent_network/components/assistant_entry_renderer.dart';
import 'package:vide_cli/modules/agent_network/components/user_message_renderer.dart';
import 'package:vide_cli/modules/agent_network/components/tool_invocations/todo_list_component.dart';
import 'package:vide_cli/modules/commands/command.dart';
import 'package:vide_cli/modules/commands/command_provider.dart';
import 'package:vide_cli/modules/git/git_popup.dart';
import 'package:vide_cli/modules/permissions/components/plan_approval_dialog.dart';
import 'package:vide_cli/modules/permissions/permission_scope.dart';
import 'package:vide_cli/modules/permissions/permission_service.dart';
import 'package:vide_cli/modules/settings/settings_dialog.dart';
import 'package:vide_client/src/remote_vide_session.dart';
import 'package:vide_core/vide_core.dart';
import 'package:vide_cli/modules/agent_network/state/vide_session_providers.dart';
import 'package:vide_cli/modules/remote/daemon_connection_service.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_cli/components/vide_scaffold.dart';

class NetworkExecutionPage extends StatefulComponent {
  final VideSession session;

  const NetworkExecutionPage({required this.session, super.key});

  static Future<void> push(BuildContext context, {required VideSession session}) async {
    context.read(sessionSelectionProvider.notifier).selectSession(session);

    // Mark session as seen on the daemon (best-effort).
    final daemonState = context.read(daemonConnectionProvider);
    if (daemonState.isConnected) {
      context.read(daemonConnectionProvider.notifier).markSessionSeen(session.id);
    }

    return Navigator.of(
      context,
    ).push<void>(PageRoute(builder: (context) => NetworkExecutionPage(session: session), settings: RouteSettings()));
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

  /// Agents list, updated via direct session stream subscription.
  List<VideAgent> _agents = const [];
  StreamSubscription<List<VideAgent>>? _agentsSub;

  /// Connection state for remote sessions.
  bool _isConnected = true;
  StreamSubscription<bool>? _connectionSub;

  @override
  void initState() {
    super.initState();
    // We're not on the home page anymore - set this early so sidebar shows
    context.read(isOnHomePageProvider.notifier).state = false;

    final session = component.session;

    // Subscribe to agents stream
    _agents = session.state.agents;
    _agentsSub = session.stateStream.map((s) => s.agents).listen((agents) {
      if (mounted) setState(() => _agents = agents);
    });

    // Subscribe to connection stream (remote sessions only)
    if (session is RemoteVideSession) {
      _isConnected = session.isConnected;
      _connectionSub = session.connectionStateStream.listen((connected) {
        if (mounted) setState(() => _isConnected = connected);
      });
    }
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
    _agentsSub?.cancel();
    _connectionSub?.cancel();
    // Back to home page
    context.read(isOnHomePageProvider.notifier).state = true;
    context.read(sessionSelectionProvider.notifier).clear();
    super.dispose();
  }

  Component _buildAgentChat(
    BuildContext context,
    List<String> agentIds, {
    required bool contentFocused,
    required VoidCallback focusLeftSidebar,
    required VoidCallback focusRightSidebar,
  }) {
    // Get selected agent ID from provider, or use the first agent
    final sessionId = component.session.id;
    final selectedAgentIdNotifier = context.read(selectedAgentIdProvider(sessionId).notifier);
    final selectedAgentId = context.watch(selectedAgentIdProvider(sessionId));

    // Find the selected agent, or default to the first agent
    String agentId = selectedAgentId ?? (agentIds.isNotEmpty ? agentIds[0] : '');

    // Ensure selected agent is still valid
    if (!agentIds.contains(agentId) && agentIds.isNotEmpty) {
      agentId = agentIds[0];
      selectedAgentIdNotifier.state = agentId;
    }

    final session = component.session;
    return Expanded(
      child: _AgentChat(
        key: ValueKey(agentId),
        session: session,
        agentId: agentId,
        networkId: session.id,
        agents: _agents,
        showQuitWarning: _showQuitWarning,
        onExit: _exitWithDaemonCleanup,
        contentFocused: contentFocused,
        focusLeftSidebar: focusLeftSidebar,
        focusRightSidebar: focusRightSidebar,
      ),
    );
  }

  Future<void> _exitWithDaemonCleanup() async {
    final sessionId = component.session.id;
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
    shutdownApp();
  }

  void _handleCtrlC() {
    final now = DateTime.now();

    if (_lastCtrlCPress != null && now.difference(_lastCtrlCPress!) < _quitTimeWindow) {
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
    final session = component.session;

    if (!_isConnected) {
      return _buildConnectingScreen(context, label: 'Connecting to session...');
    }

    final agentIds = _agents.map((a) => a.id).toList();

    // For remote sessions, conversation data loads asynchronously after
    // the WebSocket connects. Show loading screen until it arrives to
    // avoid a jarring empty scaffold.
    if (agentIds.isNotEmpty) {
      _trackConversationReady(session, agentIds.first);
      if (!_conversationReady) {
        return _buildConnectingScreen(context, label: 'Loading conversation...');
      }
    }

    return VideScaffold(
      session: session,
      agents: _agents,
      childBuilder: ({
        required contentFocused,
        required focusLeftSidebar,
        required focusRightSidebar,
      }) {
        final content = Container(
          padding: EdgeInsets.symmetric(horizontal: 1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (agentIds.isEmpty)
                Center(child: Text('No agents'))
              else
                _buildAgentChat(
                  context,
                  agentIds,
                  contentFocused: contentFocused,
                  focusLeftSidebar: focusLeftSidebar,
                  focusRightSidebar: focusRightSidebar,
                ),
            ],
          ),
        );

        return PermissionScope(
          session: session,
          child: Focusable(
            focused: true,
            onKeyEvent: (event) {
              if (event.logicalKey == LogicalKey.keyC && event.isControlPressed) {
                _handleCtrlC();
                return true;
              }
              return false;
            },
            child: MouseRegion(child: content),
          ),
        );
      },
    );
  }

  /// Full-screen loading state shown while connecting to a remote session
  /// or waiting for conversation history to load.
  Component _buildConnectingScreen(BuildContext context, {required String label}) {
    final theme = VideTheme.of(context);

    return Container(
      decoration: BoxDecoration(color: theme.base.surface),
      child: Center(child: ConnectingIndicator(label: label)),
    );
  }
}

class _AgentChat extends StatefulComponent {
  final VideSession session;
  final String agentId;
  final String networkId;
  final List<VideAgent> agents;
  final bool showQuitWarning;
  final Future<void> Function() onExit;
  final bool contentFocused;
  final VoidCallback focusLeftSidebar;
  final VoidCallback focusRightSidebar;

  const _AgentChat({
    required this.session,
    required this.agentId,
    required this.networkId,
    required this.agents,
    required this.onExit,
    required this.contentFocused,
    required this.focusLeftSidebar,
    required this.focusRightSidebar,
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

  /// Cached file list from git ls-files for @mention suggestions.
  List<String>? _cachedFileList;
  DateTime? _cachedFileListTimestamp;

  /// Tracks attachments sent with user messages (keyed by message content).
  final Map<String, List<AgentAttachment>> _sentAttachments = {};

  Future<void> _loadInitialAgentRuntimeMetadata(VideSession session) async {
    final queuedMessage = await session.getQueuedMessage(component.agentId);
    final model = await session.getModel(component.agentId);
    if (!mounted) return;
    setState(() {
      _queuedMessage = queuedMessage;
      _model = model;
    });
    context.read(currentModelProvider(component.session.id).notifier).state = model;
  }

  @override
  void initState() {
    super.initState();

    final session = component.session;

    // Listen to conversation updates
    _conversationSubscription = session.conversationStream(component.agentId).listen((conversation) {
      setState(() {
        _conversation = conversation;
      });

      // Sync token stats to AgentMetadata for persistence and network-wide tracking
      _syncTokenStats(conversation, session);
    });
    _conversation = session.getConversation(component.agentId);

    // Listen to queued message updates
    _queueSubscription = session.queuedMessageStream(component.agentId).listen((text) {
      setState(() => _queuedMessage = text);
    });

    // Listen to model updates
    _modelSubscription = session.modelStream(component.agentId).listen((model) {
      setState(() => _model = model);
      context.read(currentModelProvider(component.session.id).notifier).state = model;
    });

    unawaited(_loadInitialAgentRuntimeMetadata(session));
  }

  void _syncTokenStats(AgentConversationState conversation, VideSession session) {
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

  void _sendMessage(AgentMessage message) {
    if (message.attachments != null && message.attachments!.isNotEmpty) {
      _sentAttachments[message.text] = message.attachments!;
    }
    component.session.sendMessage(message, agentId: component.agentId);
  }

  bool _isLastAgent() {
    return component.session.state.agents.length <= 1;
  }

  Future<void> _handleCommand(String commandInput) async {
    final session = component.session;
    final dispatcher = context.read(commandDispatcherProvider);
    final commandContext = CommandContext(
      agentId: component.agentId,
      workingDirectory: session.state.workingDirectory,
      isLastAgent: _isLastAgent(),
      sendMessage: (message) {
        session.sendMessage(AgentMessage(text: message), agentId: component.agentId);
      },
      clearConversation: () async {
        await session.clearConversation(agentId: component.agentId);
        setState(() {
          _conversation = null;
        });
      },
      exitApp: component.onExit,
      detachApp: shutdownApp,
      forkAgent: (name) async {
        final newAgentId = await session.forkAgent(component.agentId, name: name);
        return newAgentId;
      },
      killAgent: () async {
        await session.terminateAgent(
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
            session.sendMessage(AgentMessage(text: message), agentId: component.agentId);
          },
          onSwitchWorktree: (path) async {
            final container = ProviderScope.containerOf(context);
            container.read(repoPathOverrideProvider.notifier).state = path;
            // Use VideSession.setWorktreePath() instead of direct provider access
            await session.setWorktreePath(path);
          },
        );
      },
      showSettingsDialog: () async {
        await SettingsPopup.show(context);
      },
      getClaudeSettings: () => session.getClaudeSettings(),
      applyClaudeSettings: (settings) =>
          session.applyClaudeSettings(settings),
      getMcpServers: () async {
        final servers = await session.getMcpServers();
        return servers
            .where((s) => !s.name.startsWith('vide-'))
            .map((s) => McpServerStatus(
                  name: s.name,
                  status: s.status.name,
                  error: s.error,
                ))
            .toList();
      },
      reconnectMcpServer: (name) => session.reconnectMcpServer(name),
      toggleMcpServer: (name, {required enabled}) =>
          session.toggleMcpServer(name, enabled: enabled),
      showSessionLogs: () {
        final sessionId = session.id;
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

  Future<List<CommandSuggestion>> _getFileSuggestions(String query) async {
    final workingDir = component.session.state.workingDirectory;
    if (workingDir.isEmpty) return [];

    final now = DateTime.now();
    if (_cachedFileList == null ||
        _cachedFileListTimestamp == null ||
        now.difference(_cachedFileListTimestamp!) >
            const Duration(seconds: 10)) {
      try {
        final result = await Process.run(
          'git',
          ['ls-files', '--cached', '--others', '--exclude-standard'],
          workingDirectory: workingDir,
        );
        if (result.exitCode == 0) {
          _cachedFileList = (result.stdout as String)
              .split('\n')
              .where((l) => l.isNotEmpty)
              .toList();
          _cachedFileListTimestamp = now;
        }
      } catch (_) {
        return [];
      }
    }

    if (_cachedFileList == null) return [];

    // Empty query: show first N files. Non-empty: filter by substring match.
    final results = query.isEmpty
        ? _cachedFileList!.take(10)
        : _cachedFileList!
            .where((f) => f.toLowerCase().contains(query.toLowerCase()))
            .take(10);

    return results
        .map((f) => CommandSuggestion(name: f, description: 'file'))
        .toList();
  }

  List<Map<String, dynamic>>? _getLatestTodos() => _conversation?.latestTodos;

  void _handlePermissionResponse(
    PermissionRequest request,
    bool granted,
    bool remember, {
    String? patternOverride,
    String? denyReason,
  }) {
    String reason;
    if (granted) {
      reason = 'User approved';
    } else if (denyReason != null && denyReason.isNotEmpty) {
      reason = denyReason;
    } else {
      reason = 'User denied';
    }

    component.session.respondToPermission(
      request.requestId,
      allow: granted,
      message: reason,
      remember: remember,
      patternOverride: patternOverride,
    );

    // Dequeue the current request to show the next one
    context.read(permissionStateProvider(component.session.id).notifier).dequeueRequest();
  }

  void _handleAskUserQuestionResponse(AskUserQuestionUIRequest request, Map<String, String> answers) {
    // Send the response through the session (unified path for local and remote)
    component.session.respondToAskUserQuestion(request.requestId, answers: answers);

    // Dequeue the current request to show the next one
    context.read(askUserQuestionStateProvider(component.session.id).notifier).dequeueRequest();
  }

  void _handlePlanApprovalResponse(PlanApprovalUIRequest request, String action, String? feedback) {
    component.session.respondToPlanApproval(request.requestId, action: action, feedback: feedback);

    // Dequeue the current request to show the next one
    context.read(planApprovalStateProvider(component.session.id).notifier).dequeueRequest();
  }

  void _handleEscape() {
    // If there's a queued message, clear it first
    if (_queuedMessage != null) {
      unawaited(component.session.clearQueuedMessage(component.agentId));
    } else {
      // Otherwise abort the current processing
      component.session.abortAgent(component.agentId);
    }
  }

  bool _handleKeyEvent(KeyboardEvent event) {
    // Don't intercept keys when plan approval dialog is active —
    // the dialog handles its own key events (Escape, Tab, etc.)
    final planState = context.read(planApprovalStateProvider(component.session.id));
    if (planState.current != null) return false;

    if (event.logicalKey == LogicalKey.escape) {
      _handleEscape();
      return true;
    }

    // Tab: Quick access to settings (when not consumed by text field autocomplete)
    if (event.logicalKey == LogicalKey.tab) {
      SettingsPopup.show(context);
      return true;
    }

    return false;
  }

  /// Builds the filtered list of messages (excluding slash commands and
  /// entries that consist entirely of hidden/invisible tools).
  List<ConversationEntry> _getFilteredMessages() {
    final conv = _conversation;
    if (conv == null) return [];
    return conv.messages.reversed.where((entry) => !entry.isSlashCommand && !entry.isAllHidden).toList();
  }

  /// Whether the current agent is working.
  ///
  /// Uses [AgentConversationState.isProcessing] which is updated synchronously
  /// via the sync broadcast event stream, so it's correct immediately after
  /// [sendMessage] — unlike [videSessionAgentsProvider] which is stream-based
  /// and can miss the initial status event on broadcast streams.
  bool get _isAgentWorking => _conversation?.isProcessing ?? false;

  /// Builds the message list using ListView.builder for better performance.
  /// This avoids rebuilding all messages when unrelated state changes (like spinner).
  Component _buildMessageList(BuildContext context) {
    final filteredMessages = _getFilteredMessages();
    final todos = _getLatestTodos();
    final hasTodos = todos != null && todos.isNotEmpty;
    final itemCount = filteredMessages.length + (hasTodos ? 1 : 0);

    return SelectionArea(
      onSelectionCompleted: ClipboardManager.copy,
      child: ListView.builder(
        controller: _scrollController,
        reverse: true,
        padding: EdgeInsets.all(1),
        lazy: true,
        itemCount: itemCount,
        itemBuilder: (context, index) {
          // Index 0 in reversed list = bottom of chat. Show todo list there.
          if (hasTodos && index == 0) {
            return Padding(
              padding: EdgeInsets.only(top: 1),
              child: TodoListComponent(todos: todos),
            );
          }

          final messageIndex = hasTodos ? index - 1 : index;
          final message = filteredMessages[messageIndex];
          final workingDir = component.session.state.workingDirectory;

          // Render system-like user messages (e.g. "[Request interrupted by user]")
          // as dimmed inline text instead of a full user message bubble.
          final isSystemLike = message.role == MessageRole.user &&
              message.text.startsWith('[') &&
              message.text.endsWith(']');

          return Padding(
            padding: EdgeInsets.only(top: 1),
            child: switch (message.role) {
              MessageRole.user when isSystemLike => _SystemMessageRenderer(
                key: ValueKey(message.hashCode),
                text: message.text,
              ),
              MessageRole.user => UserMessageRenderer(
                key: ValueKey(message.hashCode),
                entry: message,
                sentAttachments: _sentAttachments,
              ),
              MessageRole.system => _SystemMessageRenderer(
                key: ValueKey(message.hashCode),
                text: message.text,
              ),
              MessageRole.assistant => AssistantEntryRenderer(
                key: ValueKey(message.hashCode),
                entry: message,
                networkId: component.networkId,
                agentId: component.agentId,
                workingDirectory: workingDir,
              ),
            },
          );
        },
      ),
    );
  }

  @override
  Component build(BuildContext context) {
    // Get the current plan approval queue state from the provider
    final planApprovalQueueState = context.watch(planApprovalStateProvider(component.session.id));
    final currentPlanApproval = planApprovalQueueState.current;

    return Focusable(
      onKeyEvent: _handleKeyEvent,
      focused: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate the max height available for dialogs inside the input area.
          // Reserve space for the loading indicator line, text field, and
          // context bar (~4 lines) so the dialog doesn't push them off-screen.
          final maxDialogHeight = (constraints.maxHeight - 4).clamp(4.0, double.infinity);

          return Container(
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
                      onResponse: (action, feedback) =>
                          _handlePlanApprovalResponse(currentPlanApproval, action, feedback),
                      key: Key('plan_approval_${currentPlanApproval.requestId}'),
                    ),
                  ),

                // Input area
                ChatInputArea(
                  agentId: component.agentId,
                  sessionId: component.session.id,
                  agents: component.agents,
                  queuedMessage: _queuedMessage,
                  isAgentWorking: _isAgentWorking,
                  showQuitWarning: component.showQuitWarning,
                  hasPlanApproval: currentPlanApproval != null,
                  commandResult: _commandResult,
                  commandResultIsError: _commandResultIsError,
                  conversation: _conversation,
                  model: _model,
                  maxDialogHeight: maxDialogHeight,
                  onClearQueue: () {
                    unawaited(component.session.clearQueuedMessage(component.agentId));
                  },
                  onSendMessage: _sendMessage,
                  onCommand: _handleCommand,
                  onPermissionResponse: _handlePermissionResponse,
                  onAskUserQuestionResponse: _handleAskUserQuestionResponse,
                  onEscape: _handleEscape,
                  commandSuggestions: _getCommandSuggestions,
                  fileSuggestions: _getFileSuggestions,
                  contentFocused: component.contentFocused,
                  onFocusLeftSidebar: component.focusLeftSidebar,
                  onFocusRightSidebar: component.focusRightSidebar,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Renders a system message (e.g. context compaction boundary, request
/// interrupted) as a left-aligned, dimmed line.
class _SystemMessageRenderer extends StatelessComponent {
  final String text;

  const _SystemMessageRenderer({required this.text, super.key});

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    return Text(
      text,
      style: TextStyle(
        color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
      ),
    );
  }
}
