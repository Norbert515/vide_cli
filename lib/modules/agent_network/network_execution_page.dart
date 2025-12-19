import 'dart:async';
import 'dart:io';

import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:claude_api/claude_api.dart';
import 'package:vide_cli/components/attachment_text_field.dart';
import 'package:vide_cli/components/enhanced_loading_indicator.dart';
import 'package:vide_cli/modules/haiku/haiku_service.dart';
import 'package:vide_cli/modules/haiku/haiku_providers.dart';
import 'package:vide_cli/modules/haiku/prompts/loading_words_prompt.dart';
import 'package:vide_cli/modules/haiku/prompts/idle_prompt.dart';
import 'package:vide_cli/modules/haiku/fact_source_service.dart';
import 'package:vide_cli/modules/haiku/prompts/code_sommelier_prompt.dart';
import 'package:vide_cli/utils/code_detector.dart';
import 'package:vide_cli/services/vide_settings.dart';
import 'package:vide_cli/components/permission_dialog.dart';
import 'package:vide_cli/components/tool_invocations/tool_invocation_router.dart';
import 'package:vide_cli/components/tool_invocations/todo_list_component.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/modules/agent_network/components/running_agents_bar.dart';
import 'package:vide_cli/modules/agent_network/models/agent_id.dart';
import 'package:vide_cli/modules/agent_network/models/agent_status.dart';
import 'package:vide_cli/modules/agent_network/service/agent_network_manager.dart';
import 'package:vide_cli/modules/agent_network/state/agent_status_manager.dart';
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

  void _handleCtrlC(BuildContext context) {
    final now = DateTime.now();

    if (_lastCtrlCPress != null && now.difference(_lastCtrlCPress!) < _quitTimeWindow) {
      // Second press within time window - quit app
      shutdownApp();
    } else {
      // First press - abort current agent session if it's processing
      final networkState = context.read(agentNetworkManagerProvider);
      if (networkState.agentIds.isNotEmpty) {
        final safeIndex = selectedAgentIndex.clamp(0, networkState.agentIds.length - 1);
        final agentId = networkState.agentIds[safeIndex];
        final client = context.read(claudeProvider(agentId));
        if (client != null && client.currentConversation.isProcessing) {
          // Abort the current agent session
          client.abort();
        }
      }

      // Show warning for second press
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

          // Ctrl+C: Abort current session (first press) or quit app (double press)
          if (event.logicalKey == LogicalKey.keyC && event.isControlPressed) {
            _handleCtrlC(context);
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

  // Track conversation state changes (response start time is in AgentResponseTimes)
  ConversationState? _lastConversationState;

  // Idle detection state
  Timer? _idleTimer;
  DateTime? _idleStartTime;
  static const _idleThreshold = Duration(minutes: 2);
  bool _isGeneratingIdleMessage = false;

  // Activity tip state
  Timer? _activityTipTimer;
  static const _activityTipThreshold = Duration(seconds: 4);
  bool _isGeneratingActivityTip = false;

  // Minimum fact display duration tracking
  DateTime? _factShownAt;
  Timer? _factDisplayTimer;
  static const _minimumFactDisplayDuration = Duration(seconds: 8);

  // Token tracking - track last known values to compute deltas
  int _lastInputTokens = 0;
  int _lastOutputTokens = 0;

  // Message input controller - persists across permission dialog appearances
  late final AttachmentTextEditingController _inputController;

  void _debugLog(String message) {
    if (Platform.environment['VIDE_DEBUG_HAIKU'] == '1') {
      final timestamp = DateTime.now().toIso8601String();
      File('/tmp/vide_haiku.log').writeAsStringSync(
        '[$timestamp] [ActivityTip] $message\n',
        mode: FileMode.append,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _inputController = AttachmentTextEditingController();

    // Listen to conversation updates
    _conversationSubscription = component.client.conversation.listen((conversation) {
      _debugLog('conversation listener: state=${conversation.state}, lastState=$_lastConversationState');
      // Track when response starts
      if (conversation.state == ConversationState.receivingResponse &&
          _lastConversationState != ConversationState.receivingResponse) {
        _debugLog('  -> transitioning INTO receivingResponse, starting timer');
        AgentResponseTimes.startIfNeeded(component.client.sessionId);
        // Stop idle timer when agent is responding
        _stopIdleTimer();
        // Clear any idle message when agent starts responding
        context.read(idleMessageProvider.notifier).state = null;
        // Start activity tip timer
        _startActivityTipTimer();
      } else if (_lastConversationState == ConversationState.receivingResponse &&
          conversation.state != ConversationState.receivingResponse) {
        AgentResponseTimes.clear(component.client.sessionId);
        // Stop activity tip timer when response ends (not just when not receiving)
        _stopActivityTipTimer();
        // Only clear the fact immediately if minimum display duration has elapsed
        // Otherwise, let the _factDisplayTimer handle cleanup
        if (_factShownAt != null) {
          final elapsed = DateTime.now().difference(_factShownAt!);
          if (elapsed >= _minimumFactDisplayDuration) {
            // Minimum time elapsed, safe to clear immediately
            _factDisplayTimer?.cancel();
            _factDisplayTimer = null;
            _factShownAt = null;
            context.read(activityTipProvider.notifier).state = null;
          }
          // else: let _factDisplayTimer handle cleanup after minimum duration
        } else {
          // No fact showing, just clear
          context.read(activityTipProvider.notifier).state = null;
        }
      }

      // When response completes, pre-generate words for the next message
      if (_lastConversationState == ConversationState.receivingResponse &&
          conversation.state == ConversationState.idle) {
        _preGenerateWordsForNextMessage(conversation);
        // Start idle timer when agent becomes idle
        _startIdleTimer();
        // Update session token usage
        _updateSessionTokens(conversation);
      }

      _lastConversationState = conversation.state;

      setState(() {
        _conversation = conversation;
      });
    });
    _conversation = component.client.currentConversation;
    _lastConversationState = _conversation.state;

    // If already receiving response when we init, ensure start time is tracked
    // (uses putIfAbsent so it won't reset if already set from another tab)
    if (_conversation.state == ConversationState.receivingResponse) {
      AgentResponseTimes.startIfNeeded(component.client.sessionId);
      // Also start activity tip timer since we missed the transition
      _startActivityTipTimer();
    }

    // If conversation is already idle (e.g., resumed session), start idle timer
    if (_conversation.state == ConversationState.idle) {
      _startIdleTimer();
    }
  }

  @override
  void dispose() {
    _conversationSubscription?.cancel();
    _idleTimer?.cancel();
    _activityTipTimer?.cancel();
    _factDisplayTimer?.cancel();
    _inputController.dispose();
    super.dispose();
  }

  void _sendMessage(Message message) {
    // Log immediately to confirm _sendMessage is called
    try {
      File('/tmp/vide_haiku.log').writeAsStringSync(
        '[${DateTime.now().toIso8601String()}] [_sendMessage] called, textLen=${message.text.length}\n',
        mode: FileMode.append,
      );
    } catch (e) {
      // ignore
    }

    // Stop idle timer and clear idle message when user sends a message
    _stopIdleTimer();
    context.read(idleMessageProvider.notifier).state = null;

    // Clear any previous sommelier commentary
    context.read(codeSommelierProvider.notifier).state = null;

    // Generate creative loading words with Haiku in the background
    // Don't clear existing words - keep showing them until new ones arrive
    _generateLoadingWords(message.text);

    // Check for code and trigger sommelier if enabled (delayed to avoid race with loading words)
    final textToCheck = message.text;
    Future.delayed(const Duration(milliseconds: 500), () {
      final sommelierEnabled = VideSettingsManager.instance.settings.codeSommelierEnabled;
      final hasCode = CodeDetector.containsCode(textToCheck);
      // Log to haiku log file for debugging
      try {
        File('/tmp/vide_haiku.log').writeAsStringSync(
          '[${DateTime.now().toIso8601String()}] [Sommelier] enabled=$sommelierEnabled, hasCode=$hasCode, textLen=${textToCheck.length}\n',
          mode: FileMode.append,
        );
      } catch (e) {
        // ignore
      }
      if (mounted && sommelierEnabled && hasCode) {
        _generateSommelierCommentary(textToCheck);
      }
    });

    // Send the actual message
    component.client.sendMessage(message);
  }

  /// Helper to generate loading words using the new HaikuService
  void _generateLoadingWords(String userMessage) async {
    final systemPrompt = LoadingWordsPrompt.build(DateTime.now());
    final wrappedMessage = 'Generate loading words for this task: "$userMessage"';

    final words = await HaikuService.invokeForList(
      systemPrompt: systemPrompt,
      userMessage: wrappedMessage,
      lineEnding: '...',
      maxItems: 5,
    );
    if (!mounted) return;
    if (words != null) {
      context.read(loadingWordsProvider.notifier).state = words;
    }
  }

  /// Generate wine-tasting style commentary for pasted code
  void _generateSommelierCommentary(String text) async {
    final code = CodeDetector.extractCode(text);
    if (code.isEmpty) return;

    // Limit code length to avoid huge prompts
    final truncatedCode = code.length > 2000 ? '${code.substring(0, 2000)}...' : code;

    final systemPrompt = CodeSommelierPrompt.build(truncatedCode);
    final result = await HaikuService.invoke(
      systemPrompt: systemPrompt,
      userMessage: 'Analyze this code.',
      delay: Duration.zero,
      timeout: const Duration(seconds: 15),
    );

    if (!mounted) return;

    if (result != null) {
      context.read(codeSommelierProvider.notifier).state = result;

      // Auto-clear after 30 seconds
      Future.delayed(const Duration(seconds: 30), () {
        if (mounted) {
          context.read(codeSommelierProvider.notifier).state = null;
        }
      });
    }
  }

  /// Pre-generate loading words for the next message based on the completed response.
  /// This way we have words ready before the user sends their next message.
  void _preGenerateWordsForNextMessage(Conversation conversation) {
    // Get the last assistant response to use as context
    String contextForNextMessage = '';
    for (final message in conversation.messages.reversed) {
      if (message.role == MessageRole.assistant && message.responses.isNotEmpty) {
        // Get the first text response as context
        for (final response in message.responses) {
          if (response is TextResponse) {
            // Use first 200 chars of the response as context
            contextForNextMessage = response.content.length > 200
                ? response.content.substring(0, 200)
                : response.content;
            break;
          }
        }
        break;
      }
    }

    if (contextForNextMessage.isEmpty) return;

    // Generate words in background - these will be ready for the next message
    _generateLoadingWords('Continue discussing: $contextForNextMessage');
  }

  // ========== Idle Detection Methods ==========

  void _startIdleTimer() {
    _stopIdleTimer();
    _idleStartTime = DateTime.now();
    _idleTimer = Timer(_idleThreshold, _onIdleThresholdReached);
  }

  void _stopIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = null;
    _idleStartTime = null;
  }

  void _resetIdleTimer() {
    // Clear any existing idle message and restart the timer
    context.read(idleMessageProvider.notifier).state = null;
    if (_conversation.state == ConversationState.idle) {
      _startIdleTimer();
    }
  }

  void _onIdleThresholdReached() async {
    if (!mounted || _isGeneratingIdleMessage) return;
    if (_conversation.state != ConversationState.idle) return;

    // Check if ANY agent in the network is currently working
    final networkState = context.read(agentNetworkManagerProvider);
    for (final agentId in networkState.agentIds) {
      final client = context.read(claudeProvider(agentId));
      if (client != null && client.currentConversation.state != ConversationState.idle) {
        // Some agent is still working, don't show idle message
        // Restart timer to check again later
        _startIdleTimer();
        return;
      }
    }

    _isGeneratingIdleMessage = true;

    final idleTime = _idleStartTime != null
        ? DateTime.now().difference(_idleStartTime!)
        : _idleThreshold;

    final systemPrompt = IdlePrompt.build(idleTime);
    final result = await HaikuService.invoke(
      systemPrompt: systemPrompt,
      userMessage: 'Generate an idle message for ${idleTime.inSeconds} seconds of inactivity.',
      delay: Duration.zero,
    );

    _isGeneratingIdleMessage = false;
    if (!mounted) return;

    if (result != null) {
      context.read(idleMessageProvider.notifier).state = result;
    }
  }

  // ========== Activity Tip Methods ==========

  void _startActivityTipTimer() {
    _debugLog('_startActivityTipTimer() called');
    _stopActivityTipTimer();
    _activityTipTimer = Timer(_activityTipThreshold, _onActivityTipThresholdReached);
  }

  void _stopActivityTipTimer() {
    _debugLog('_stopActivityTipTimer() called, hadTimer=${_activityTipTimer != null}');
    _activityTipTimer?.cancel();
    _activityTipTimer = null;
    _isGeneratingActivityTip = false;
  }

  /// Check if we should show activity tips.
  /// Tips show when: agent is receiving response OR waiting for subagents.
  bool _shouldShowActivityTips() {
    final isReceiving = _conversation.state == ConversationState.receivingResponse;
    final agentStatus = context.read(agentStatusProvider(component.client.sessionId));
    final isWaitingForAgent = agentStatus == AgentStatus.waitingForAgent;
    _debugLog('_shouldShowActivityTips: isReceiving=$isReceiving, agentStatus=$agentStatus, isWaitingForAgent=$isWaitingForAgent');
    return isReceiving || isWaitingForAgent;
  }

  void _onActivityTipThresholdReached() {
    _debugLog('_onActivityTipThresholdReached() called');
    if (!mounted || _isGeneratingActivityTip) {
      _debugLog('  -> early return: mounted=$mounted, isGenerating=$_isGeneratingActivityTip');
      return;
    }

    final shouldShow = _shouldShowActivityTips();
    _debugLog('  -> shouldShowActivityTips=$shouldShow');
    if (!shouldShow) return;

    _isGeneratingActivityTip = true;

    // Get a random pre-generated fact directly (no Haiku needed)
    final fact = FactSourceService.instance.getRandomFact();
    _debugLog('  -> getRandomFact returned: ${fact != null ? "fact (${fact.length} chars)" : "null"}');

    _isGeneratingActivityTip = false;
    if (!mounted) return;

    final shouldShowNow = _shouldShowActivityTips();
    _debugLog('  -> shouldShowActivityTips (2nd check)=$shouldShowNow');

    if (fact != null && shouldShowNow) {
      _debugLog('  -> Setting activityTip!');
      context.read(activityTipProvider.notifier).state = fact;
      // Record when fact was shown and start timer to clear after minimum duration
      _factShownAt = DateTime.now();
      _factDisplayTimer?.cancel();
      _factDisplayTimer = Timer(_minimumFactDisplayDuration, _onFactDisplayTimerExpired);
    }
  }

  /// Called when the minimum fact display duration has elapsed.
  /// Clears the fact if conditions no longer warrant showing it.
  void _onFactDisplayTimerExpired() {
    _factDisplayTimer = null;
    _factShownAt = null;
    if (!mounted) return;
    // Only clear if we're no longer in a state that should show tips
    if (!_shouldShowActivityTips()) {
      context.read(activityTipProvider.notifier).state = null;
    }
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

  /// Gets cumulative output token count across the conversation.
  /// Shows total tokens used so far (updated after each response completes).
  int? _getOutputTokens() {
    final total = _conversation.totalOutputTokens;
    return total > 0 ? total : null;
  }

  /// Update session-wide token usage by computing delta from last known values
  void _updateSessionTokens(Conversation conversation) {
    final currentInput = conversation.totalInputTokens;
    final currentOutput = conversation.totalOutputTokens;

    final inputDelta = currentInput - _lastInputTokens;
    final outputDelta = currentOutput - _lastOutputTokens;

    if (inputDelta > 0 || outputDelta > 0) {
      final current = context.read(sessionTokenUsageProvider);
      context.read(sessionTokenUsageProvider.notifier).state = current.add(
        input: inputDelta,
        output: outputDelta,
      );
    }

    _lastInputTokens = currentInput;
    _lastOutputTokens = currentOutput;
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

    // Get idle message and activity tip from providers
    final idleMessage = context.watch(idleMessageProvider);
    final activityTip = context.watch(activityTipProvider);
    final sommelierCommentary = context.watch(codeSommelierProvider);

    // Watch agent status to show activity tips when waiting for subagents
    final agentStatus = context.watch(agentStatusProvider(component.client.sessionId));
    final isActivelyWorking = _conversation.isProcessing || _conversation.lastAssistantMessage?.isStreaming == true;
    final shouldShowTips = isActivelyWorking || agentStatus == AgentStatus.waitingForAgent;

    // Manage activity tip timer based on agent status
    // Start timer when waiting for agent (if not already running)
    if (agentStatus == AgentStatus.waitingForAgent && _activityTipTimer == null && !_isGeneratingActivityTip) {
      // Use Future.microtask to avoid setState during build
      Future.microtask(() {
        if (mounted) _startActivityTipTimer();
      });
    }
    // Stop timer when no longer waiting for agent and not receiving response
    else if (agentStatus != AgentStatus.waitingForAgent &&
        _conversation.state != ConversationState.receivingResponse &&
        _activityTipTimer != null) {
      Future.microtask(() {
        if (mounted) {
          _stopActivityTipTimer();
          // Only clear the fact immediately if minimum display duration has elapsed
          // Otherwise, let the _factDisplayTimer handle cleanup
          if (_factShownAt != null) {
            final elapsed = DateTime.now().difference(_factShownAt!);
            if (elapsed >= _minimumFactDisplayDuration) {
              // Minimum time elapsed, safe to clear immediately
              _factDisplayTimer?.cancel();
              _factDisplayTimer = null;
              _factShownAt = null;
              context.read(activityTipProvider.notifier).state = null;
            }
            // else: let _factDisplayTimer handle cleanup after minimum duration
          } else {
            // No fact showing, just clear
            context.read(activityTipProvider.notifier).state = null;
          }
        }
      });
    }

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
                  for (final message in _conversation.messages.reversed) _buildMessage(message, dynamicLoadingWords),
                ],
              ),
            ),

            // Input area - conditionally show permission dialog or text field
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Show typing indicator with hint when processing or last message still streaming
                // isProcessing covers active states, isStreaming handles gap between tool result and next turn
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
                      // Show code sommelier commentary when available
                      if (sommelierCommentary != null)
                        Container(
                          padding: EdgeInsets.symmetric(vertical: 1),
                          child: Text(
                            '🍷 $sommelierCommentary',
                            style: TextStyle(color: Colors.magenta.withOpacity(0.8), fontStyle: FontStyle.italic),
                          ),
                        ),
                      AttachmentTextField(
                        controller: _inputController,
                        enabled: true,
                        placeholder: 'Type a message...',
                        onSubmit: _sendMessage,
                        onChanged: (_) => _resetIdleTimer(),
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

                // Show activity tip below the input field when agent is working or waiting for subagent
                if (activityTip != null && shouldShowTips)
                  Text(
                    activityTip,
                    style: TextStyle(color: Colors.green.withOpacity(0.7)),
                  ),

                // Session token usage - bottom right
                _SessionTokenCounter(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Component _buildMessage(ConversationMessage message, List<String>? dynamicLoadingWords) {
    if (message.role == MessageRole.user) {
      return Container(
        padding: EdgeInsets.only(bottom: 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('> ${message.content}', style: TextStyle(color: Colors.white)),
            if (message.attachments != null && message.attachments!.isNotEmpty)
              for (var attachment in message.attachments!)
                Text(
                  '  📎 ${attachment.path ?? "image"}',
                  style: TextStyle(color: Colors.white.withOpacity(TextOpacity.secondary)),
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
            widgets.add(EnhancedLoadingIndicator(
              responseStartTime: AgentResponseTimes.get(component.client.sessionId),
              outputTokens: _getOutputTokens(),
              dynamicWords: dynamicLoadingWords,
            ));
          } else {
            widgets.add(MarkdownText(response.content));
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
                child: Text('[orphaned result: ${response.content}]', style: TextStyle(color: Colors.red)),
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
            if (message.responses.isEmpty && message.isStreaming)
              EnhancedLoadingIndicator(
                responseStartTime: AgentResponseTimes.get(component.client.sessionId),
                outputTokens: _getOutputTokens(),
                dynamicWords: dynamicLoadingWords,
              ),

            if (message.error != null)
              Container(
                padding: EdgeInsets.only(left: 2, top: 1),
                child: Text(
                  '[error: ${message.error}]',
                  style: TextStyle(color: Colors.white.withOpacity(TextOpacity.secondary)),
                ),
              ),
          ],
        ),
      );
    }
  }
}

/// Displays session token usage in the bottom right corner
class _SessionTokenCounter extends StatelessComponent {
  const _SessionTokenCounter();

  String _formatTokens(int tokens) {
    if (tokens >= 1000000) {
      return '${(tokens / 1000000).toStringAsFixed(1)}M';
    } else if (tokens >= 1000) {
      return '${(tokens / 1000).toStringAsFixed(1)}k';
    }
    return tokens.toString();
  }

  @override
  Component build(BuildContext context) {
    final usage = context.watch(sessionTokenUsageProvider);

    // Don't show if no tokens used yet
    if (usage.totalTokens == 0) return SizedBox();

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '↑${_formatTokens(usage.inputTokens)} ↓${_formatTokens(usage.outputTokens)}',
          style: TextStyle(color: Colors.white.withOpacity(0.3)),
        ),
      ],
    );
  }
}
