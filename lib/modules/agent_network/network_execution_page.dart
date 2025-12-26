import 'dart:async';
import 'dart:io';

import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:claude_api/claude_api.dart';
import 'package:vide_cli/components/attachment_text_field.dart';
import 'package:vide_cli/components/enhanced_loading_indicator.dart';
import 'package:vide_cli/components/permission_dialog.dart';
import 'package:vide_cli/components/tool_invocations/tool_invocation_router.dart';
import 'package:vide_cli/components/tool_invocations/todo_list_component.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/modules/agent_network/components/running_agents_bar.dart';
import 'package:vide_cli/modules/agent_network/components/context_usage_bar.dart';
import 'package:vide_cli/modules/commands/command.dart';
import 'package:vide_cli/modules/commands/command_provider.dart';
import 'package:vide_core/vide_core.dart';
import 'package:vide_cli/modules/permissions/permission_service.dart';
import 'package:vide_cli/theme/theme.dart';
import '../permissions/permission_scope.dart';
import '../../components/typing_text.dart';

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

  int selectedAgentIndex = 0;

  Component _buildAgentChat(BuildContext context, AgentNetworkState networkState) {
    // Clamp selectedAgentIndex to valid bounds after agents may have been removed
    final safeIndex = selectedAgentIndex.clamp(0, networkState.agentIds.length - 1);
    if (safeIndex != selectedAgentIndex) {
      // Schedule index update for next frame to avoid setState during build
      Future.microtask(() {
        if (mounted) setState(() => selectedAgentIndex = safeIndex);
      });
    }
    final agentId = networkState.agentIds[safeIndex];
    final client = context.watch(claudeProvider(agentId));
    if (client == null) {
      // Client still being created - show optimistic loading state
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
                  EnhancedLoadingIndicator(),
                  SizedBox(width: 2),
                  Text(
                    '(Press ESC to stop)',
                    style: TextStyle(color: theme.base.onSurface.withOpacity(TextOpacity.tertiary)),
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
        client: client,
        networkId: component.networkId,
        showQuitWarning: _showQuitWarning,
      ),
    );
  }

  void _handleCtrlC() {
    final now = DateTime.now();

    if (_lastCtrlCPress != null && now.difference(_lastCtrlCPress!) < _quitTimeWindow) {
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
    final networkState = context.watch(agentNetworkManagerProvider);
    final currentNetwork = networkState.currentNetwork;

    // Display the network goal
    final goalText = currentNetwork?.goal ?? 'Loading...';

    return PermissionScope(
      child: Focusable(
        focused: true,
        onKeyEvent: (event) {
          // Tab: Cycle through agents
          if (event.logicalKey == LogicalKey.tab && networkState.agentIds.isNotEmpty) {
            setState(() {
              selectedAgentIndex = (selectedAgentIndex + 1) % networkState.agentIds.length;
            });
            return true;
          }

          // Ctrl+C: Show quit warning (double press to quit)
          if (event.logicalKey == LogicalKey.keyC && event.isControlPressed) {
            _handleCtrlC();
            return true;
          }

          return false;
        },
        child: MouseRegion(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Display the network goal with typing animation
                TypingText(
                  text: goalText,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Divider(),
                RunningAgentsBar(agents: networkState.agents, selectedIndex: selectedAgentIndex),
                if (networkState.agentIds.isEmpty)
                  Center(child: Text('No agents'))
                else
                  _buildAgentChat(context, networkState),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AgentChat extends StatefulComponent {
  final ClaudeClient client;
  final String networkId;
  final bool showQuitWarning;

  const _AgentChat({required this.client, required this.networkId, this.showQuitWarning = false, super.key});

  @override
  State<_AgentChat> createState() => _AgentChatState();
}

class _AgentChatState extends State<_AgentChat> {
  StreamSubscription<Conversation>? _conversationSubscription;
  Conversation _conversation = Conversation.empty();
  final _scrollController = AutoScrollController();
  String? _commandResult;
  bool _commandResultIsError = false;

  @override
  void initState() {
    super.initState();

    // Listen to conversation updates
    _conversationSubscription = component.client.conversation.listen((conversation) {
      setState(() {
        _conversation = conversation;
      });

      // Sync token stats to AgentMetadata for persistence and network-wide tracking
      _syncTokenStats(conversation);
    });
    _conversation = component.client.currentConversation;
  }

  void _syncTokenStats(Conversation conversation) {
    context.read(agentNetworkManagerProvider.notifier).updateAgentTokenStats(
      component.client.sessionId,
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
    super.dispose();
  }

  void _sendMessage(Message message) {
    component.client.sendMessage(message);
  }

  Future<void> _handleCommand(String commandInput) async {
    final dispatcher = context.read(commandDispatcherProvider);
    final commandContext = CommandContext(
      agentId: component.client.sessionId,
      workingDirectory: component.client.workingDirectory,
      sendMessage: (message) {
        component.client.sendMessage(Message(text: message));
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
      return CommandSuggestion(
        name: cmd.name,
        description: cmd.description,
      );
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

  void _handlePermissionResponse(PermissionRequest request, bool granted, bool remember, {String? patternOverride}) async {
    final permissionService = context.read(permissionServiceProvider);

    // If remember and granted, decide where to store based on tool type
    if (remember && granted) {
      final toolName = request.toolName;
      final toolInput = request.toolInput;

      // Check if this is a write operation
      final isWriteOperation = toolName == 'Write' || toolName == 'Edit' || toolName == 'MultiEdit';

      if (isWriteOperation) {
        // Add to session cache (in-memory only) using inferred pattern
        final pattern = patternOverride ?? PatternInference.inferPattern(toolName, toolInput);
        permissionService.addSessionPattern(pattern);
      } else {
        // Add to persistent whitelist with inferred pattern (or override)
        final settingsManager = LocalSettingsManager(
          projectRoot: request.cwd,
          parrottRoot: Platform.script.resolve('.').toFilePath(),
        );

        final pattern = patternOverride ?? PatternInference.inferPattern(toolName, toolInput);
        await settingsManager.addToAllowList(pattern);
      }
    }

    permissionService.respondToPermission(
      request.requestId,
      PermissionResponse(
        decision: granted ? 'allow' : 'deny',
        reason: granted ? 'User approved' : 'User denied',
        remember: remember,
      ),
    );

    // If denied, abort the process
    if (!granted) {
      print('[AgentChat] Tool denied by user, aborting process');
      // Abort the client - this will stop the Claude process
      await component.client.abort();
    }

    // Dequeue the current request to show the next one
    context.read(permissionStateProvider.notifier).dequeueRequest();
  }

  bool _handleKeyEvent(KeyboardEvent event) {
    if (event.logicalKey == LogicalKey.escape) {
      component.client.abort();
      return true;
    }
    return false;
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

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1),
      child: Row(
        children: [
          // Context usage indicator
          ContextUsageIndicator(usedTokens: usedTokens),
          SizedBox(width: 1),
          Text(
            'context',
            style: TextStyle(
              color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
            ),
          ),

          // Show /compact hint when in warning zone
          if (isWarningZone) ...[
            SizedBox(width: 1),
            Text(
              '(/compact)',
              style: TextStyle(
                color: theme.base.error.withOpacity(0.7),
              ),
            ),
          ],

          // Cost display
          if (_conversation.totalCostUsd > 0) ...[
            Expanded(child: SizedBox()),
            Text(
              '\$${_conversation.totalCostUsd.toStringAsFixed(4)}',
              style: TextStyle(
                color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    // Get the current permission queue state from the provider
    final permissionQueueState = context.watch(permissionStateProvider);
    final currentPermissionRequest = permissionQueueState.current;

    return Focusable(
      onKeyEvent: _handleKeyEvent,
      focused: true,
      child: Container(
        decoration: BoxDecoration(title: BorderTitle(text: component.key.toString())),
        child: Column(
          children: [
            // Messages area
            Expanded(
              child: ListView(
                controller: _scrollController,
                reverse: true,
                padding: EdgeInsets.all(1),
                lazy: true,
                children: [
                  // Todo list at the end (first in reversed list)
                  if (_getLatestTodos() case final todos? when todos.isNotEmpty) TodoListComponent(todos: todos),
                  for (final message in _conversation.messages.reversed)
                    // Skip slash commands - they're handled internally
                    if (!(message.role == MessageRole.user && message.content.startsWith('/')))
                      _buildMessage(context, message),
                ],
              ),
            ),

            // Input area - conditionally show permission dialog or text field
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Show typing indicator with hint when processing
                if (_conversation.isProcessing)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      EnhancedLoadingIndicator(),
                      SizedBox(width: 2),
                      Text(
                        '(Press ESC to stop)',
                        style: TextStyle(color: theme.base.onSurface.withOpacity(TextOpacity.tertiary)),
                      ),
                    ],
                  ),

                // Show quit warning if active
                if (component.showQuitWarning)
                  Text(
                    '(Press Ctrl+C again to quit)',
                    style: TextStyle(color: theme.base.onSurface.withOpacity(TextOpacity.tertiary)),
                  ),

                // Show permission dialog if there's an active request, otherwise show text field
                if (currentPermissionRequest != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Show queue length if there are more requests waiting
                      if (permissionQueueState.queueLength > 1)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 1, vertical: 0),
                          child: Text(
                            'Permission 1 of ${permissionQueueState.queueLength} (${permissionQueueState.queueLength - 1} more in queue)',
                            style: TextStyle(color: theme.base.warning, fontWeight: FontWeight.bold),
                          ),
                        ),
                      PermissionDialog.fromRequest(
                        request: currentPermissionRequest,
                        onResponse: (granted, remember, {String? patternOverride}) =>
                            _handlePermissionResponse(currentPermissionRequest, granted, remember, patternOverride: patternOverride),
                        key: Key('permission_${currentPermissionRequest.requestId}'),
                      ),
                    ],
                  )
                else
                  AttachmentTextField(
                    enabled: !_conversation.isProcessing,
                    placeholder: 'Type a message...',
                    onSubmit: _sendMessage,
                    onCommand: _handleCommand,
                    commandSuggestions: _getCommandSuggestions,
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
                            : theme.base.onSurface.withOpacity(TextOpacity.secondary),
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

    if (message.role == MessageRole.user) {
      return Container(
        padding: EdgeInsets.only(bottom: 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('> ${message.content}', style: TextStyle(color: theme.base.onSurface)),
            if (message.attachments != null && message.attachments!.isNotEmpty)
              for (var attachment in message.attachments!)
                Text(
                  '  📎 ${attachment.path ?? "image"}',
                  style: TextStyle(color: theme.base.onSurface.withOpacity(TextOpacity.secondary)),
                ),
          ],
        ),
      );
    } else {
      // Build tool invocations by pairing calls with their results
      final toolCallsById = <String, ToolUseResponse>{};
      final toolResultsById = <String, ToolResultResponse>{};

      // First pass: collect all tool calls and results by ID
      for (final response in message.responses) {
        if (response is ToolUseResponse && response.toolUseId != null) {
          toolCallsById[response.toolUseId!] = response;
        } else if (response is ToolResultResponse) {
          toolResultsById[response.toolUseId] = response;
        }
      }

      // Second pass: render responses in order, combining tool calls with their results
      final widgets = <Component>[];
      final renderedToolResults = <String>{};

      for (final response in message.responses) {
        if (response is TextResponse) {
          if (response.content.isEmpty && message.isStreaming) {
            widgets.add(EnhancedLoadingIndicator());
          } else {
            // Check for context-full errors and add helpful hint
            final isContextFullError = response.content.toLowerCase().contains('prompt is too long') ||
                response.content.toLowerCase().contains('context window') ||
                response.content.toLowerCase().contains('token limit');

            widgets.add(MarkdownText(response.content));

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
        } else if (response is ToolUseResponse) {
          // Check if we have a result for this tool call
          final result = response.toolUseId != null ? toolResultsById[response.toolUseId] : null;

          String? subagentSessionId;

          // Use factory method to create typed invocation
          final invocation = ConversationMessage.createTypedInvocation(response, result, sessionId: subagentSessionId);

          widgets.add(
            ToolInvocationRouter(
              key: ValueKey(response.toolUseId ?? response.id),
              invocation: invocation,
              workingDirectory: component.client.workingDirectory,
              executionId: component.networkId,
              agentId: component.client.sessionId,
            ),
          );
          if (result != null && response.toolUseId != null) {
            renderedToolResults.add(response.toolUseId!);
          }
        } else if (response is ToolResultResponse) {
          // Only show tool result if it wasn't already paired with its call
          if (!renderedToolResults.contains(response.toolUseId)) {
            // This is an orphaned tool result (shouldn't normally happen)
            widgets.add(
              Container(
                padding: EdgeInsets.only(left: 2, top: 1),
                child: Text('[orphaned result: ${response.content}]', style: TextStyle(color: theme.base.error)),
              ),
            );
          }
        }
      }

      return Container(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...widgets,

            // If no responses yet but streaming, show loading
            if (message.responses.isEmpty && message.isStreaming) EnhancedLoadingIndicator(),

            if (message.error != null)
              Container(
                padding: EdgeInsets.only(left: 2, top: 1),
                child: Text(
                  '[error: ${message.error}]',
                  style: TextStyle(color: theme.base.onSurface.withOpacity(TextOpacity.secondary)),
                ),
              ),
          ],
        ),
      );
    }
  }
}
