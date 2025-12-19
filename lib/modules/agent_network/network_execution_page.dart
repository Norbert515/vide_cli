import 'dart:async';
import 'dart:io';

import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:claude_api/claude_api.dart';
import 'package:vide_cli/components/attachment_text_field.dart';
import 'package:vide_cli/components/enhanced_loading_indicator.dart';
import 'package:vide_cli/components/permission_dialog.dart';
import 'package:vide_cli/components/tool_invocations/todo_list_component.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/modules/agent_network/components/message_renderer.dart';
import 'package:vide_cli/modules/agent_network/components/running_agents_bar.dart';
import 'package:vide_cli/modules/agent_network/models/agent_id.dart';
import 'package:vide_cli/modules/agent_network/service/agent_network_manager.dart';
import 'package:vide_cli/modules/agent_network/state/agent_response_times.dart';
import 'package:vide_cli/modules/haiku/haiku_providers.dart';
import 'package:vide_cli/modules/haiku/message_enhancement_service.dart';
import 'package:vide_cli/modules/agent_network/mixins/idle_detection_mixin.dart';
import 'package:vide_cli/modules/permissions/permission_service.dart';
import 'package:vide_cli/modules/settings/local_settings_manager.dart';
import 'package:vide_cli/modules/settings/pattern_inference.dart';
import 'service/claude_manager.dart';
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
      return Expanded(child: Center(child: Text('Agent disconnected')));
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

class _AgentChatState extends State<_AgentChat> with IdleDetectionMixin {
  StreamSubscription<Conversation>? _conversationSubscription;
  Conversation _conversation = Conversation.empty();
  final _scrollController = AutoScrollController();

  // Track conversation state changes for response timing
  ConversationState? _lastConversationState;

  // Implement IdleDetectionMixin required getter
  @override
  Conversation get idleDetectionConversation => _conversation;

  @override
  void initState() {
    super.initState();

    // Listen to conversation updates
    _conversationSubscription = component.client.conversation.listen((conversation) {
      // Track when response starts
      if (conversation.state == ConversationState.receivingResponse &&
          _lastConversationState != ConversationState.receivingResponse) {
        AgentResponseTimes.startIfNeeded(component.client.sessionId);
        // Stop idle timer when agent is responding
        stopIdleTimer();
        // Clear any idle message when agent starts responding
        context.read(idleMessageProvider.notifier).state = null;
      } else if (_lastConversationState == ConversationState.receivingResponse &&
          conversation.state != ConversationState.receivingResponse) {
        AgentResponseTimes.clear(component.client.sessionId);
      }

      // When response completes and becomes idle, start idle timer
      if (_lastConversationState == ConversationState.receivingResponse &&
          conversation.state == ConversationState.idle) {
        startIdleTimer();
      }

      _lastConversationState = conversation.state;

      setState(() {
        _conversation = conversation;
      });
    });
    _conversation = component.client.currentConversation;
    _lastConversationState = _conversation.state;

    // If already receiving response when we init, ensure start time is tracked
    if (_conversation.state == ConversationState.receivingResponse) {
      AgentResponseTimes.startIfNeeded(component.client.sessionId);
    }

    // Initialize idle detection (starts timer if conversation is already idle)
    initIdleDetection();
  }

  @override
  void dispose() {
    _conversationSubscription?.cancel();
    disposeIdleDetection();
    super.dispose();
  }

  void _sendMessage(Message message) {
    // Stop idle timer and clear idle message when user sends a message
    stopIdleTimer();
    context.read(idleMessageProvider.notifier).state = null;

    // Generate creative loading words with Haiku in the background
    _generateLoadingWords(message.text);

    // Send the actual message
    component.client.sendMessage(message);
  }

  /// Helper to generate loading words using MessageEnhancementService
  void _generateLoadingWords(String userMessage) async {
    await MessageEnhancementService.generateLoadingWords(
      userMessage,
      (words) {
        if (mounted) {
          context.read(loadingWordsProvider.notifier).state = words;
        }
      },
    );
  }

  /// Gets cumulative output token count across the conversation.
  int? _getOutputTokens() {
    final total = _conversation.totalOutputTokens;
    return total > 0 ? total : null;
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

  @override
  Component build(BuildContext context) {
    // Get the current permission queue state from the provider
    final permissionQueueState = context.watch(permissionStateProvider);
    final currentPermissionRequest = permissionQueueState.current;

    // Get dynamic loading words from provider
    final dynamicLoadingWords = context.watch(loadingWordsProvider);

    // Get idle message from provider
    final idleMessage = context.watch(idleMessageProvider);

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
                    MessageRenderer(
                      message: message,
                      dynamicLoadingWords: dynamicLoadingWords,
                      agentSessionId: component.client.sessionId,
                      workingDirectory: component.client.workingDirectory,
                      executionId: component.networkId,
                      outputTokens: _getOutputTokens(),
                    ),
                ],
              ),
            ),

            // Input area - conditionally show permission dialog or text field
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Show typing indicator with hint when processing or last message still streaming
                if (_conversation.isProcessing || _conversation.lastAssistantMessage?.isStreaming == true)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      EnhancedLoadingIndicator(
                        responseStartTime: AgentResponseTimes.get(component.client.sessionId),
                        outputTokens: _getOutputTokens(),
                        dynamicWords: dynamicLoadingWords,
                      ),
                      SizedBox(width: 2),
                      Text(
                        '(Press ESC to stop)',
                        style: TextStyle(color: Colors.white.withOpacity(TextOpacity.tertiary)),
                      ),
                    ],
                  ),

                // Show quit warning if active
                if (component.showQuitWarning)
                  Text(
                    '(Press Ctrl+C again to quit)',
                    style: TextStyle(color: Colors.white.withOpacity(TextOpacity.tertiary)),
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
                            style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AttachmentTextField(
                        enabled: true,
                        placeholder: 'Type a message...',
                        onSubmit: _sendMessage,
                        onChanged: (_) => resetIdleTimer(),
                      ),
                      // Show idle message when agent has been waiting for user input
                      if (idleMessage != null && _conversation.state == ConversationState.idle)
                        Container(
                          padding: EdgeInsets.only(top: 0),
                          child: Text(
                            idleMessage,
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontStyle: FontStyle.italic),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
