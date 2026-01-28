import 'dart:async';

import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:claude_sdk/claude_sdk.dart';
import 'package:vide_cli/components/enhanced_loading_indicator.dart';
import 'package:vide_cli/components/queue_indicator.dart';
import 'package:vide_cli/components/typing_text.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/main.dart';
import 'package:vide_cli/modules/agent_network/components/attachment_text_field.dart';
import 'package:vide_cli/modules/agent_network/components/context_usage_bar.dart';
import 'package:vide_cli/modules/settings/settings_dialog.dart';
import 'package:vide_cli/modules/agent_network/components/tool_invocations/tool_invocation_router.dart';
import 'package:vide_cli/modules/agent_network/components/tool_invocations/todo_list_component.dart';
import 'package:vide_cli/modules/commands/command.dart';
import 'package:vide_cli/modules/commands/command_provider.dart';
import 'package:vide_cli/modules/git/git_branch_indicator.dart';
import 'package:vide_cli/modules/git/git_popup.dart';
import 'package:vide_cli/modules/permissions/components/ask_user_question_dialog.dart';
import 'package:vide_cli/modules/permissions/components/permission_dialog.dart';
import 'package:vide_cli/modules/permissions/permission_scope.dart';
import 'package:vide_cli/modules/permissions/permission_service.dart';
import 'package:vide_core/vide_core.dart';
import 'package:vide_cli/modules/agent_network/state/vide_session_providers.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_cli/modules/agent_network/state/prompt_history_provider.dart';
import 'package:vide_cli/components/vide_scaffold.dart';

class NetworkExecutionPage extends StatefulComponent {
  final AgentNetworkId networkId;

  const NetworkExecutionPage({required this.networkId, super.key});

  static Future<void> push(BuildContext context, String networkId) async {
    return Navigator.of(context).push<void>(
      PageRoute(
        builder: (context) => NetworkExecutionPage(networkId: networkId),
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

  @override
  void initState() {
    super.initState();
    // We're not on the home page anymore - set this early so sidebar shows
    context.read(isOnHomePageProvider.notifier).state = false;
  }

  @override
  void dispose() {
    // Back to home page
    context.read(isOnHomePageProvider.notifier).state = true;
    super.dispose();
  }

  Component _buildAgentChat(
    BuildContext context,
    List<String> agentIds,
  ) {
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

    final session = context.watch(currentVideSessionProvider);
    if (session == null) {
      // Session still being created - show optimistic loading state
      // This looks the same as when we're waiting for a response
      final theme = VideTheme.of(context);
      return Expanded(
        child: Container(
          decoration: BoxDecoration(title: BorderTitle(text: 'Main')),
          child: Column(
            children: [
              Expanded(child: SizedBox()),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  EnhancedLoadingIndicator(agentId: agentId),
                  SizedBox(width: 2),
                  Text(
                    '(Press ESC to stop)',
                    style: TextStyle(
                      color: theme.base.onSurface.withOpacity(
                        TextOpacity.tertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return Expanded(
      child: _AgentChat(
        key: ValueKey(agentId),
        agentId: agentId,
        networkId: component.networkId,
        showQuitWarning: _showQuitWarning,
      ),
    );
  }

  void _handleCtrlC() {
    final now = DateTime.now();

    if (_lastCtrlCPress != null &&
        now.difference(_lastCtrlCPress!) < _quitTimeWindow) {
      // Second press within time window - quit app
      shutdownApp();
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
    // Get session (works for both local and remote modes)
    final session = context.watch(currentVideSessionProvider);
    final agentIds = session?.agentIds ?? [];
    final workingDirectory = session?.workingDirectory ?? '';

    // Get goal text from network state (only available in local mode)
    final networkState = context.watch(agentNetworkManagerProvider);
    final currentNetwork = networkState.currentNetwork;
    final goalText = currentNetwork?.goal ?? 'Session';

    // Build the main content column
    final content = Container(
      padding: EdgeInsets.symmetric(horizontal: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Display the network goal with git branch indicator
          Row(
            children: [
              Expanded(
                child: TypingText(
                  text: goalText,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              GitBranchIndicator(repoPath: workingDirectory),
            ],
          ),
          Divider(),
          if (agentIds.isEmpty)
            Center(child: Text('No agents'))
          else
            _buildAgentChat(context, agentIds),
        ],
      ),
    );

    return VideScaffold(
      child: PermissionScope(
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
      ),
    );
  }
}

class _AgentChat extends StatefulComponent {
  final String agentId;
  final String networkId;
  final bool showQuitWarning;

  const _AgentChat({
    required this.agentId,
    required this.networkId,
    this.showQuitWarning = false,
    super.key,
  });

  @override
  State<_AgentChat> createState() => _AgentChatState();
}

class _AgentChatState extends State<_AgentChat> {
  StreamSubscription<Conversation>? _conversationSubscription;
  StreamSubscription<String?>? _queueSubscription;
  StreamSubscription<String?>? _modelSubscription;
  Conversation _conversation = Conversation.empty();
  final _scrollController = AutoScrollController();
  String? _commandResult;
  bool _commandResultIsError = false;
  String? _queuedMessage;
  String? _model;

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
    _conversation =
        session.getConversation(component.agentId) ?? Conversation.empty();

    // Listen to queued message updates
    _queueSubscription = session.queuedMessageStream(component.agentId).listen((
      text,
    ) {
      setState(() => _queuedMessage = text);
    });
    _queuedMessage = session.getQueuedMessage(component.agentId);

    // Listen to model updates
    _modelSubscription = session.modelStream(component.agentId).listen((model) {
      setState(() => _model = model);
    });
    _model = session.getModel(component.agentId);
  }

  void _syncTokenStats(Conversation conversation, VideSession session) {
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

  void _sendMessage(Message message) {
    final session = context.read(currentVideSessionProvider);
    session?.sendMessage(message, agentId: component.agentId);
  }

  bool _isLastAgent() {
    final network = context.read(agentNetworkManagerProvider).currentNetwork;
    if (network == null)
      return true; // If no network, treat as last agent (safe default)
    return network.agents.length <= 1;
  }

  Future<void> _handleCommand(String commandInput) async {
    final session = context.read(currentVideSessionProvider);
    final dispatcher = context.read(commandDispatcherProvider);
    final commandContext = CommandContext(
      agentId: component.agentId,
      workingDirectory: session?.workingDirectory ?? '',
      isLastAgent: _isLastAgent(),
      sendMessage: (message) {
        session?.sendMessage(Message.text(message), agentId: component.agentId);
      },
      clearConversation: () async {
        await session?.clearConversation(agentId: component.agentId);
        setState(() {
          _conversation = Conversation.empty();
        });
      },
      exitApp: shutdownApp,
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
              Message.text(message),
              agentId: component.agentId,
            );
          },
          onSwitchWorktree: (path) {
            final container = ProviderScope.containerOf(context);
            container.read(repoPathOverrideProvider.notifier).state = path;
            container
                .read(agentNetworkManagerProvider.notifier)
                .setWorktreePath(path);
          },
        );
      },
      showSettingsDialog: () async {
        await SettingsPopup.show(context);
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
    for (final message in _conversation.messages.reversed) {
      for (final response in message.responses.reversed) {
        if (response is ToolUseResponse && response.toolName == 'TodoWrite') {
          final todos = response.parameters['todos'];
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
  }) async {
    final session = context.read(currentVideSessionProvider);

    // If remember and granted, decide where to store based on tool type
    if (remember && granted) {
      final toolName = request.toolName;
      final toolInput = request.toolInput;

      // Convert to type-safe ToolInput for pattern inference
      final input = ToolInput.fromJson(toolName, toolInput);

      // Check if this is a write operation
      final isWriteOperation =
          toolName == 'Write' || toolName == 'Edit' || toolName == 'MultiEdit';

      if (isWriteOperation) {
        // Add to session cache (in-memory only) using inferred pattern
        final pattern =
            patternOverride ?? PatternInference.inferPattern(toolName, input);
        session?.addSessionPermissionPattern(pattern);
      } else {
        // Add to persistent whitelist with inferred pattern (or override)
        final settingsManager = ClaudeSettingsManager(projectRoot: request.cwd);

        final pattern =
            patternOverride ?? PatternInference.inferPattern(toolName, input);
        await settingsManager.addToAllowList(pattern);
      }
    }

    // Determine the reason for the response
    String reason;
    if (granted) {
      reason = 'User approved';
    } else if (denyReason != null && denyReason.isNotEmpty) {
      reason = denyReason;
    } else {
      reason = 'User denied';
    }

    // Send the response through the session (unified path for local and remote)
    session?.respondToPermission(
      request.requestId,
      allow: granted,
      message: reason,
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
    session?.respondToAskUserQuestion(
      request.requestId,
      answers: answers,
    );

    // Dequeue the current request to show the next one
    context.read(askUserQuestionStateProvider.notifier).dequeueRequest();
  }

  bool _handleKeyEvent(KeyboardEvent event) {
    if (event.logicalKey == LogicalKey.escape) {
      final session = context.read(currentVideSessionProvider);
      if (session == null) return false;

      // If there's a queued message, clear it first
      if (_queuedMessage != null) {
        session.clearQueuedMessage(component.agentId);
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

  /// Formats a full model ID to a short display name.
  /// e.g., "claude-sonnet-4-5-20250929" -> "sonnet"
  ///       "claude-opus-4-5-20251101" -> "opus"
  String _formatModelName(String model) {
    final lower = model.toLowerCase();
    if (lower.contains('opus')) return 'opus';
    if (lower.contains('sonnet')) return 'sonnet';
    if (lower.contains('haiku')) return 'haiku';
    // Fallback: return last part before date suffix, or full name if short
    if (model.length <= 10) return model;
    // Try to extract meaningful part
    final parts = model.split('-');
    if (parts.length >= 2) return parts[1];
    return model;
  }

  Component _buildContextUsageSection(VideThemeData theme) {
    // Use currentContextWindowTokens for context window percentage.
    // This is the CURRENT context size (from latest turn), which includes:
    // input_tokens + cache_read_input_tokens + cache_creation_input_tokens
    // Cache tokens DO count towards context window - they're just read from cache.
    final usedTokens = _conversation.currentContextWindowTokens;
    final percentage = kClaudeContextWindowSize > 0
        ? (usedTokens / kClaudeContextWindowSize).clamp(0.0, 1.0)
        : 0.0;
    final isWarningZone = percentage >= kContextWarningThreshold;
    final isCautionZone = percentage >= kContextCautionThreshold;

    // Only show context usage when it's getting full (>= 60%)
    final showContextUsage = isCautionZone;

    // If nothing to show (no model, no context warning, no cost), return empty
    if (_model == null &&
        !showContextUsage &&
        _conversation.totalCostUsd <= 0) {
      return SizedBox();
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1),
      child: Row(
        children: [
          // Show model name
          if (_model != null) ...[
            Text(
              _formatModelName(_model!),
              style: TextStyle(
                color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
              ),
            ),
          ],

          // Context usage indicator (only when >= caution threshold)
          if (showContextUsage) ...[
            if (_model != null) SizedBox(width: 1),
            ContextUsageIndicator(usedTokens: usedTokens),
            SizedBox(width: 1),
            Text(
              'context',
              style: TextStyle(
                color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
              ),
            ),
          ],

          // Show /compact hint when in warning zone
          if (isWarningZone) ...[
            SizedBox(width: 1),
            Text(
              '(/compact)',
              style: TextStyle(color: theme.base.error.withOpacity(0.7)),
            ),
          ],
        ],
      ),
    );
  }

  /// Builds the filtered list of messages (excluding slash commands)
  List<ConversationMessage> _getFilteredMessages() {
    return _conversation.messages.reversed
        .where(
          (message) =>
              !(message.role == MessageRole.user &&
                  message.content.startsWith('/')),
        )
        .toList();
  }

  /// Builds the message list using ListView.builder for better performance.
  /// This avoids rebuilding all messages when unrelated state changes (like spinner).
  Component _buildMessageList(BuildContext context) {
    final todos = _getLatestTodos();
    final hasTodos = todos != null && todos.isNotEmpty;
    final filteredMessages = _getFilteredMessages();

    // Total items = todos (if any) + filtered messages
    final itemCount = (hasTodos ? 1 : 0) + filteredMessages.length;

    return ListView.builder(
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

        // Adjust index for messages (subtract 1 if todos exist)
        final messageIndex = hasTodos ? index - 1 : index;
        final message = filteredMessages[messageIndex];
        return _buildMessage(context, message);
      },
    );
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    // Get the current permission queue state from the provider
    final permissionQueueState = context.watch(permissionStateProvider);
    final currentPermissionRequest = permissionQueueState.current;

    // Get the current AskUserQuestion queue state from the provider
    final askUserQuestionQueueState = context.watch(
      askUserQuestionStateProvider,
    );
    final currentAskUserQuestionRequest = askUserQuestionQueueState.current;

    return Focusable(
      onKeyEvent: _handleKeyEvent,
      focused: true,
      child: Container(
        child: Column(
          children: [
            // Messages area
            Expanded(child: _buildMessageList(context)),

            // Input area - conditionally show permission dialog or text field
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Show queued message indicator above the generating indicator
                if (_queuedMessage != null)
                  QueueIndicator(
                    queuedText: _queuedMessage!,
                    onClear: () {
                      final session = context.read(currentVideSessionProvider);
                      session?.clearQueuedMessage(component.agentId);
                    },
                  ),

                // Loading indicator row - always 1 cell height to prevent layout jumps
                if (_conversation.isProcessing &&
                    currentAskUserQuestionRequest == null &&
                    currentPermissionRequest == null)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      EnhancedLoadingIndicator(agentId: component.agentId),
                      SizedBox(width: 2),
                      Text(
                        '(Press ESC to stop)',
                        style: TextStyle(
                          color: theme.base.onSurface.withOpacity(
                            TextOpacity.tertiary,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Text(' '), // Reserve 1 line when loading indicator is hidden
                // Show quit warning if active
                if (component.showQuitWarning)
                  Text(
                    '(Press Ctrl+C again to quit)',
                    style: TextStyle(
                      color: theme.base.onSurface.withOpacity(
                        TextOpacity.tertiary,
                      ),
                    ),
                  ),

                // Show AskUserQuestion dialog above text field (if active)
                if (currentAskUserQuestionRequest != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Show queue length if there are more questions waiting
                      if (askUserQuestionQueueState.queueLength > 1)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 1,
                            vertical: 0,
                          ),
                          child: Text(
                            'Question 1 of ${askUserQuestionQueueState.queueLength} (${askUserQuestionQueueState.queueLength - 1} more in queue)',
                            style: TextStyle(
                              color: theme.base.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      AskUserQuestionDialog(
                        request: currentAskUserQuestionRequest,
                        onSubmit: (answers) => _handleAskUserQuestionResponse(
                          currentAskUserQuestionRequest,
                          answers,
                        ),
                        key: Key(
                          'ask_user_question_${currentAskUserQuestionRequest.requestId}',
                        ),
                      ),
                    ],
                  )
                // Show permission dialog above text field (if active)
                else if (currentPermissionRequest != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Show queue length if there are more requests waiting
                      if (permissionQueueState.queueLength > 1)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 1,
                            vertical: 0,
                          ),
                          child: Text(
                            'Permission 1 of ${permissionQueueState.queueLength} (${permissionQueueState.queueLength - 1} more in queue)',
                            style: TextStyle(
                              color: theme.base.warning,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      PermissionDialog.fromRequest(
                        request: currentPermissionRequest,
                        onResponse:
                            (
                              granted,
                              remember, {
                              String? patternOverride,
                              String? denyReason,
                            }) => _handlePermissionResponse(
                              currentPermissionRequest,
                              granted,
                              remember,
                              patternOverride: patternOverride,
                              denyReason: denyReason,
                            ),
                        key: Key(
                          'permission_${currentPermissionRequest.requestId}',
                        ),
                      ),
                    ],
                  ),

                // Text field - rendered when no dialogs are active
                // Text persists through pendingInputTextProvider when dialogs appear
                if (currentAskUserQuestionRequest == null &&
                    currentPermissionRequest == null)
                  Builder(
                    builder: (context) {
                      final promptHistory = context.watch(
                        promptHistoryProvider,
                      );
                      final pendingText = context.watch(
                        pendingInputTextProvider,
                      );
                      // Text field is focused when neither sidebar has focus
                      final leftSidebarFocused = context.watch(
                        sidebarFocusProvider,
                      );
                      final rightSidebarFocused = context.watch(
                        gitSidebarFocusProvider,
                      );
                      final textFieldFocused =
                          !leftSidebarFocused && !rightSidebarFocused;

                      return AttachmentTextField(
                        focused: textFieldFocused,
                        enabled:
                            true, // Always enabled - messages queue during processing
                        placeholder: 'Type a message...',
                        initialText: pendingText,
                        onTextChanged: (text) =>
                            context
                                    .read(pendingInputTextProvider.notifier)
                                    .state =
                                text,
                        onSubmit: (message) {
                          // Clear pending text on submit
                          context
                                  .read(pendingInputTextProvider.notifier)
                                  .state =
                              '';
                          _sendMessage(message);
                        },
                        onCommand: (cmd) {
                          // Clear pending text on command
                          context
                                  .read(pendingInputTextProvider.notifier)
                                  .state =
                              '';
                          _handleCommand(cmd);
                        },
                        commandSuggestions: _getCommandSuggestions,
                        promptHistory: promptHistory,
                        onPromptSubmitted: (prompt) => context
                            .read(promptHistoryProvider.notifier)
                            .addPrompt(prompt),
                        onLeftEdge: () =>
                            context.read(sidebarFocusProvider.notifier).state =
                                true,
                        onRightEdge: () =>
                            context
                                    .read(gitSidebarFocusProvider.notifier)
                                    .state =
                                true,
                        onEscape: () {
                          final session = context.read(
                            currentVideSessionProvider,
                          );
                          if (session == null) return;
                          // If there's a queued message, clear it first
                          if (_queuedMessage != null) {
                            session.clearQueuedMessage(component.agentId);
                          } else {
                            // Otherwise abort the current processing
                            session.abortAgent(component.agentId);
                          }
                        },
                      );
                    },
                  ),

                // Command result feedback
                if (_commandResult != null)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 1),
                    child: Text(
                      _commandResult!,
                      style: TextStyle(
                        color: _commandResultIsError
                            ? theme.base.error
                            : theme.base.onSurface.withOpacity(
                                TextOpacity.secondary,
                              ),
                      ),
                    ),
                  ),

                // Context usage bar with compact button
                _buildContextUsageSection(theme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Component _buildMessage(BuildContext context, ConversationMessage message) {
    final theme = VideTheme.of(context);

    // Check for compact boundary message using messageType
    if (message.messageType == MessageType.compactBoundary) {
      // Extract compact metadata for display
      final compactResponse =
          message.responses.firstWhere((r) => r is CompactBoundaryResponse)
              as CompactBoundaryResponse;
      final trigger = compactResponse.trigger;
      final preTokens = compactResponse.preTokens;

      return Container(
        padding: EdgeInsets.symmetric(vertical: 1),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '────────────── Conversation Compacted ($trigger) ──────────────',
                    style: TextStyle(
                      color: theme.base.onSurface.withOpacity(
                        TextOpacity.tertiary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (preTokens > 0)
              Text(
                'Previous context: ${(preTokens / 1000).toStringAsFixed(0)}k tokens',
                style: TextStyle(
                  color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
                ),
              ),
          ],
        ),
      );
    }

    // Check for compact summary user message
    if (message.messageType == MessageType.compactSummary) {
      // Show compact summary as collapsed/truncated
      final summaryPreview = message.content.length > 100
          ? '${message.content.substring(0, 100)}...'
          : message.content;
      return Container(
        padding: EdgeInsets.only(bottom: 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📋 Continuation Summary',
              style: TextStyle(
                color: theme.base.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              summaryPreview,
              style: TextStyle(
                color: theme.base.onSurface.withOpacity(TextOpacity.secondary),
              ),
            ),
          ],
        ),
      );
    }

    if (message.role == MessageRole.user) {
      return Container(
        padding: EdgeInsets.only(bottom: 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '> ${message.content}',
              style: TextStyle(color: theme.base.onSurface),
            ),
            if (message.attachments != null && message.attachments!.isNotEmpty)
              for (var attachment in message.attachments!)
                Text(
                  '  📎 ${attachment.path ?? "image"}',
                  style: TextStyle(
                    color: theme.base.onSurface.withOpacity(
                      TextOpacity.secondary,
                    ),
                  ),
                ),
          ],
        ),
      );
    } else {
      // Build tool results lookup for pairing with tool calls
      final toolResultsById = <String, ToolResultResponse>{};
      for (final response in message.responses) {
        if (response is ToolResultResponse) {
          toolResultsById[response.toolUseId] = response;
        }
      }

      // Process responses in order, preserving interleaving of text and tool calls.
      // Text segments are accumulated between tool calls to handle streaming deltas.
      final widgets = <Component>[];
      final renderedToolResults = <String>{};

      // Track text accumulation for the current segment
      final textBuffer = StringBuffer();
      bool hasPartialInSegment = false;

      // Helper to flush accumulated text as a widget
      void flushTextSegment() {
        final text = textBuffer.toString();
        if (text.isNotEmpty) {
          // Check for context-full errors and add helpful hint
          final isContextFullError =
              text.toLowerCase().contains('prompt is too long') ||
              text.toLowerCase().contains('context window') ||
              text.toLowerCase().contains('token limit');

          widgets.add(MarkdownText(text));

          if (isContextFullError) {
            widgets.add(
              Container(
                padding: EdgeInsets.only(top: 1),
                child: Text(
                  '💡 Tip: Type /compact to free up context space',
                  style: TextStyle(color: theme.base.primary),
                ),
              ),
            );
          }
        }
        textBuffer.clear();
        hasPartialInSegment = false;
      }

      for (final response in message.responses) {
        if (response is TextResponse) {
          // Accumulate text for the current segment, handling streaming deduplication.
          // When we have partial (delta) responses, only use those.
          // When we have cumulative responses, use only the last one (clear before writing).
          if (response.isPartial) {
            hasPartialInSegment = true;
            textBuffer.write(response.content);
          } else if (response.isCumulative) {
            // Cumulative contains full text up to this point - only use if no partials
            if (!hasPartialInSegment) {
              textBuffer.clear();
              textBuffer.write(response.content);
            }
            // If we have partials, ignore cumulative to avoid duplicates
          } else {
            // Sequential non-partial, non-cumulative - concatenate
            textBuffer.write(response.content);
          }
        } else if (response is ToolUseResponse) {
          // Flush any accumulated text before this tool call
          flushTextSegment();

          // Check if we have a result for this tool call
          final result = response.toolUseId != null
              ? toolResultsById[response.toolUseId]
              : null;

          // Use factory method to create typed invocation
          final invocation = ConversationMessage.createTypedInvocation(
            response,
            result,
          );

          final session = context.read(currentVideSessionProvider);
          widgets.add(
            ToolInvocationRouter(
              key: ValueKey(response.toolUseId ?? response.id),
              invocation: invocation,
              workingDirectory: session?.workingDirectory ?? '',
              executionId: component.networkId,
              agentId: component.agentId,
            ),
          );
          if (result != null && response.toolUseId != null) {
            renderedToolResults.add(response.toolUseId!);
          }
        } else if (response is ToolResultResponse) {
          // Tool results are paired with their calls above, so we skip them here
          // unless they're orphaned (which shouldn't normally happen)
          if (!renderedToolResults.contains(response.toolUseId)) {
            flushTextSegment();
            widgets.add(
              Container(
                padding: EdgeInsets.only(left: 2, top: 1),
                child: Text(
                  '[orphaned result: ${response.content}]',
                  style: TextStyle(color: theme.base.error),
                ),
              ),
            );
          }
        }
      }

      // Flush any remaining text after the last tool call
      flushTextSegment();

      // Show loading indicator if streaming with no content yet
      if (widgets.isEmpty && message.isStreaming) {
        widgets.add(EnhancedLoadingIndicator(agentId: component.agentId));
      }

      return Container(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...widgets,

            // If no responses yet but streaming, show loading
            if (message.responses.isEmpty && message.isStreaming)
              EnhancedLoadingIndicator(agentId: component.agentId),

            if (message.error != null)
              Container(
                padding: EdgeInsets.only(left: 2, top: 1),
                child: Text(
                  '[error: ${message.error}]',
                  style: TextStyle(
                    color: theme.base.onSurface.withOpacity(
                      TextOpacity.secondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }
  }
}
