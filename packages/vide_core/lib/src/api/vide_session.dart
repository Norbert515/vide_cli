/// LocalVideSession - In-process session implementation for the VideCore API.
///
/// This provides the concrete local implementation of [VideSession],
/// wrapping services and claude_sdk types.
library;

import 'dart:async';

import 'package:claude_sdk/claude_sdk.dart' as claude;
import 'package:uuid/uuid.dart';
import 'package:vide_interface/vide_interface.dart';

import '../models/agent_metadata.dart';
import '../models/agent_status.dart' as internal;
import '../services/agent_network_manager.dart';
import '../services/permissions/permission_checker.dart';
import '../services/permissions/tool_input.dart';
import '../services/session_services.dart';

/// An active local (in-process) session with a network of agents.
///
/// This is the concrete implementation of [VideSession] that runs agents
/// locally using the claude_sdk. Created by [VideCore.startSession] or
/// [VideCore.resumeSession].
///
/// For a remote (WebSocket-based) implementation, see `RemoteVideSession`
/// in the vide_client package.
class LocalVideSession implements VideSession {
  final String _networkId;
  final SessionServices _services;
  final SessionEventHub _hub;

  /// Subscriptions to clean up on dispose.
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  /// Tracks state for each agent's conversation stream.
  final Map<String, _AgentStreamState> _agentStates = {};

  /// Pending permission completers by request ID.
  final Map<String, Completer<claude.PermissionResult>> _pendingPermissions =
      {};

  /// Pending AskUserQuestion completers by request ID.
  final Map<String, Completer<Map<String, String>>> _pendingAskUserQuestions =
      {};

  /// Permission checker for business logic (allow lists, deny lists, etc.).
  late final PermissionChecker _permissionChecker;

  /// Whether the session has been disposed.
  bool _disposed = false;

  LocalVideSession._({
    required String networkId,
    required SessionServices services,
    PermissionCheckerConfig? permissionConfig,
  }) : _networkId = networkId,
       _services = services,
       _hub = SessionEventHub(syncController: true) {
    // Create permission checker for this session
    _permissionChecker = PermissionChecker(
      config: permissionConfig ?? PermissionCheckerConfig.tui,
    );
  }

  /// Creates a new LocalVideSession for an existing network.
  ///
  /// This is called internally by [VideCore.startSession] and [VideCore.resumeSession].
  /// The [permissionConfig] controls how permissions are checked (TUI vs REST API behavior).
  static LocalVideSession create({
    required String networkId,
    required SessionServices services,
    PermissionCheckerConfig? permissionConfig,
    String? initialMessage,
  }) {
    final session = LocalVideSession._(
      networkId: networkId,
      services: services,
      permissionConfig: permissionConfig,
    );
    session._initialize();
    // Emit the initial user message so it appears in the event stream
    // and server history. The message was already sent to the agent by
    // AgentNetworkManager.startNew before the session was created.
    if (initialMessage != null) {
      final mainAgentId = session.mainAgent?.id;
      if (mainAgentId != null) {
        session._emitUserMessage(initialMessage, agentId: mainAgentId);
      }
    }
    return session;
  }

  void _initialize() {
    // Subscribe to network changes to detect agent spawn/terminate
    _subscribeToNetworkChanges();

    // Subscribe to all existing agents
    final network = _services.networkManager.state.currentNetwork;
    if (network != null) {
      for (final agent in network.agents) {
        _subscribeToAgent(agent);
      }
    }
  }

  @override
  String get id => _networkId;

  @override
  ConversationStateManager get conversationState =>
      _hub.conversationStateManager;

  @override
  Stream<VideEvent> get events => _hub.events;

  @override
  List<VideAgent> get agents {
    final network = _services.networkManager.state.currentNetwork;
    if (network == null || network.id != _networkId) return [];
    return network.agents.map(_mapAgent).toList();
  }

  @override
  Stream<List<VideAgent>> get agentsStream {
    return _hub.events
        .where((e) => e is AgentSpawnedEvent || e is AgentTerminatedEvent)
        .map((_) => agents);
  }

  @override
  VideAgent? get mainAgent => agents.isNotEmpty ? agents.first : null;

  @override
  List<String> get agentIds {
    final network = _services.networkManager.state.currentNetwork;
    if (network == null || network.id != _networkId) return [];
    return network.agentIds;
  }

  @override
  bool get isProcessing {
    for (final agentId in _agentStates.keys) {
      final client = _services.clientRegistry[agentId];
      if (client?.currentConversation.isProcessing ?? false) {
        return true;
      }
    }
    return false;
  }

  @override
  String get workingDirectory {
    final manager = _services.networkManager;
    return manager.effectiveWorkingDirectory;
  }

  @override
  String get goal {
    final network = _services.networkManager.state.currentNetwork;
    return network?.goal ?? 'Session';
  }

  @override
  Stream<String> get goalStream {
    return _hub.events.where((e) => e is TaskNameChangedEvent).map((_) => goal);
  }

  @override
  Stream<bool> get connectionStateStream => const Stream<bool>.empty();

  @override
  String get team {
    final network = _services.networkManager.state.currentNetwork;
    return network?.team ?? 'vide';
  }

  @override
  void sendMessage(VideMessage message, {String? agentId}) {
    _checkNotDisposed();
    final manager = _services.networkManager;
    final targetAgent = agentId ?? mainAgent?.id;
    if (targetAgent == null) {
      throw StateError('No agents in session');
    }
    _emitUserMessage(message.text, agentId: targetAgent);
    // Convert VideMessage to claude_sdk.Message
    final claudeAttachments = message.attachments?.map((a) {
      return claude.Attachment(
        type: a.type,
        path: a.filePath,
        content: a.content,
        mimeType: a.mimeType,
      );
    }).toList();
    final claudeMessage = claude.Message(
      text: message.text,
      attachments: claudeAttachments,
    );
    manager.sendMessage(targetAgent, claudeMessage);
  }

  void _emitUserMessage(String content, {required String agentId}) {
    _hub.emit(
      MessageEvent(
        agentId: agentId,
        agentType: 'user',
        eventId: const Uuid().v4(),
        role: 'user',
        content: content,
        isPartial: false,
      ),
    );
  }

  @override
  void respondToPermission(
    String requestId, {
    required bool allow,
    String? message,
  }) {
    _checkNotDisposed();
    final completer = _pendingPermissions.remove(requestId);
    if (completer != null) {
      if (allow) {
        completer.complete(const claude.PermissionResultAllow());
      } else {
        completer.complete(
          claude.PermissionResultDeny(message: message ?? 'Permission denied'),
        );
      }
    }
  }

  @override
  Future<void> abort() async {
    _checkNotDisposed();
    final network = _services.networkManager.state.currentNetwork;
    if (network == null || network.id != _networkId) return;

    final clients = _services.clientRegistry.all;
    for (final agent in network.agents) {
      final client = clients[agent.id];
      if (client != null) {
        await client.abort();
      }
    }
  }

  @override
  Future<void> abortAgent(String agentId) async {
    _checkNotDisposed();
    final client = _services.clientRegistry[agentId];
    if (client != null) {
      await client.abort();
    }
  }

  @override
  Future<void> clearConversation({String? agentId}) async {
    _checkNotDisposed();
    final targetId = agentId ?? mainAgent?.id;
    if (targetId == null) return;

    final client = _services.clientRegistry[targetId];
    await client?.clearConversation();
  }

  @override
  Future<void> setWorktreePath(String? path) async {
    _checkNotDisposed();
    final manager = _services.networkManager;
    await manager.setWorktreePath(path);
  }

  @override
  VideConversation? getConversation(String agentId) {
    _checkNotDisposed();
    final client = _services.clientRegistry[agentId];
    final conversation = client?.currentConversation;
    if (conversation == null) return null;
    return _convertConversation(conversation);
  }

  @override
  Stream<VideConversation> conversationStream(String agentId) {
    _checkNotDisposed();
    final client = _services.clientRegistry[agentId];
    if (client == null) return const Stream.empty();
    return client.conversation.map(_convertConversation);
  }

  @override
  void updateAgentTokenStats(
    String agentId, {
    required int totalInputTokens,
    required int totalOutputTokens,
    required int totalCacheReadInputTokens,
    required int totalCacheCreationInputTokens,
    required double totalCostUsd,
  }) {
    _checkNotDisposed();
    final manager = _services.networkManager;
    manager.updateAgentTokenStats(
      agentId,
      totalInputTokens: totalInputTokens,
      totalOutputTokens: totalOutputTokens,
      totalCacheReadInputTokens: totalCacheReadInputTokens,
      totalCacheCreationInputTokens: totalCacheCreationInputTokens,
      totalCostUsd: totalCostUsd,
    );
  }

  @override
  Future<void> terminateAgent(
    String agentId, {
    required String terminatedBy,
    String? reason,
  }) async {
    _checkNotDisposed();
    final manager = _services.networkManager;
    await manager.terminateAgent(
      targetAgentId: agentId,
      terminatedBy: terminatedBy,
      reason: reason,
    );
  }

  @override
  Future<String> forkAgent(String agentId, {String? name}) async {
    _checkNotDisposed();
    final manager = _services.networkManager;
    return await manager.forkAgent(sourceAgentId: agentId, name: name);
  }

  @override
  Future<String> spawnAgent({
    required String agentType,
    required String name,
    required String initialPrompt,
    required String spawnedBy,
  }) async {
    _checkNotDisposed();
    final manager = _services.networkManager;
    return await manager.spawnAgent(
      agentType: agentType,
      name: name,
      initialPrompt: initialPrompt,
      spawnedBy: spawnedBy,
    );
  }

  @override
  Future<String?> getQueuedMessage(String agentId) async {
    final client = _services.clientRegistry[agentId];
    return client?.currentQueuedMessage;
  }

  @override
  Stream<String?> queuedMessageStream(String agentId) {
    final client = _services.clientRegistry[agentId];
    return client?.queuedMessage ?? const Stream.empty();
  }

  @override
  Future<void> clearQueuedMessage(String agentId) async {
    _checkNotDisposed();
    final client = _services.clientRegistry[agentId];
    client?.clearQueuedMessage();
  }

  @override
  Future<String?> getModel(String agentId) async {
    _checkNotDisposed();
    final client = _services.clientRegistry[agentId];
    return client?.initData?.model;
  }

  @override
  Stream<String?> modelStream(String agentId) {
    _checkNotDisposed();
    final client = _services.clientRegistry[agentId];
    if (client == null) return Stream.value(null);
    return client.initDataStream.map((meta) => meta.model);
  }

  @override
  void respondToAskUserQuestion(
    String requestId, {
    required Map<String, String> answers,
  }) {
    _checkNotDisposed();
    final completer = _pendingAskUserQuestions.remove(requestId);
    completer?.complete(answers);
  }

  /// Get MCP status from a specific agent's Claude client.
  ///
  /// Returns null if the agent doesn't exist or the client isn't ready.
  Future<claude.McpStatusResponse?> getMcpStatus(String agentId) async {
    _checkNotDisposed();
    final client = _services.clientRegistry[agentId];
    if (client == null) return null;
    await client.initialized;
    return await client.getMcpStatus();
  }

  @override
  Future<void> addSessionPermissionPattern(String pattern) async {
    _permissionChecker.addSessionPattern(pattern);
  }

  @override
  Future<bool> isAllowedBySessionCache(
    String toolName,
    Map<String, dynamic> input,
  ) async {
    final typedInput = ToolInput.fromJson(toolName, input);
    return _permissionChecker.isAllowedBySessionCache(toolName, typedInput);
  }

  @override
  Future<void> clearSessionPermissionCache() async {
    _permissionChecker.clearSessionCache();
  }

  @override
  VideCanUseToolCallback createPermissionCallback({
    required String agentId,
    required String? agentName,
    required String? agentType,
    required String cwd,
    String? permissionMode,
  }) {
    // Return a VideCanUseToolCallback that wraps the internal claude_sdk permission logic
    return (
      String toolName,
      Map<String, dynamic> input,
      VidePermissionContext context,
    ) async {
      // Delegate to the internal implementation which uses claude_sdk types
      final claudeResult = await _createPermissionCallbackInternal(
        agentId: agentId,
        agentName: agentName,
        agentType: agentType,
        cwd: cwd,
        permissionMode: permissionMode,
        toolName: toolName,
        input: input,
      );
      // Convert claude_sdk PermissionResult to VidePermissionResult
      return switch (claudeResult) {
        claude.PermissionResultAllow(:final updatedInput) =>
          VidePermissionAllow(updatedInput: updatedInput),
        claude.PermissionResultDeny(:final message) => VidePermissionDeny(
          message: message,
        ),
      };
    };
  }

  @override
  Future<void> dispose({bool fireEndTrigger = true}) async {
    if (_disposed) return;
    _disposed = true;

    // Fire onSessionEnd trigger before cleanup (if enabled)
    if (fireEndTrigger) {
      try {
        final manager = _services.networkManager;
        await manager.fireSessionEndTrigger();
      } catch (e) {
        // Don't fail dispose if trigger fails
        print('[LocalVideSession] Error firing onSessionEnd trigger: $e');
      }
    }

    // Cancel all subscriptions
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();

    // Complete any pending permissions with deny
    for (final completer in _pendingPermissions.values) {
      if (!completer.isCompleted) {
        completer.complete(
          const claude.PermissionResultDeny(message: 'Session disposed'),
        );
      }
    }
    _pendingPermissions.clear();

    // Complete any pending AskUserQuestion with empty answers
    for (final completer in _pendingAskUserQuestions.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Session disposed'));
      }
    }
    _pendingAskUserQuestions.clear();

    // Clear agent states
    _agentStates.clear();

    // Dispose permission checker and event hub
    _permissionChecker.dispose();
    _hub.dispose();
  }

  // ===========================================================================
  // Internal methods
  // ===========================================================================

  void _checkNotDisposed() {
    if (_disposed) {
      throw StateError('Session has been disposed');
    }
  }

  /// Whether to skip all permission checks (auto-approve everything).
  bool get _dangerouslySkipPermissions {
    if (_services.dangerouslySkipPermissions) return true;
    return _services.configManager
        .readGlobalSettings()
        .dangerouslySkipPermissions;
  }

  /// Internal permission callback implementation using claude_sdk types.
  Future<claude.PermissionResult> _createPermissionCallbackInternal({
    required String agentId,
    required String? agentName,
    required String? agentType,
    required String cwd,
    String? permissionMode,
    required String toolName,
    required Map<String, dynamic> input,
  }) async {
    // Skip all permission checks when dangerously-skip-permissions is enabled
    if (_dangerouslySkipPermissions) {
      return const claude.PermissionResultAllow();
    }

    // Get current task name
    final state = _agentStates[agentId];

    // Special handling for AskUserQuestion tool
    if (toolName == 'AskUserQuestion') {
      return _handleAskUserQuestion(
        agentId: agentId,
        agentName: agentName,
        agentType: agentType,
        taskName: state?.taskName,
        toolInput: input,
      );
    }

    // Convert raw map to type-safe ToolInput for PermissionChecker
    final typedInput = ToolInput.fromJson(toolName, input);

    // Check with PermissionChecker first (allow lists, deny lists, etc.)
    final checkResult = await _permissionChecker.checkPermission(
      toolName: toolName,
      input: typedInput,
      cwd: cwd,
      permissionMode: permissionMode,
    );

    // Handle the result from PermissionChecker
    switch (checkResult) {
      case PermissionAllow():
        return const claude.PermissionResultAllow();

      case PermissionDeny(reason: final reason):
        return claude.PermissionResultDeny(message: reason);

      case PermissionAskUser(inferredPattern: final inferredPattern):
        // Need to ask the user - emit event and wait
        final requestId = const Uuid().v4();
        final completer = Completer<claude.PermissionResult>();
        _pendingPermissions[requestId] = completer;

        // Emit permission request event
        _hub.emit(
          PermissionRequestEvent(
            agentId: agentId,
            agentType: agentType ?? 'unknown',
            agentName: agentName,
            taskName: state?.taskName,
            requestId: requestId,
            toolName: toolName,
            toolInput: input,
            inferredPattern: inferredPattern,
          ),
        );

        // Wait for response indefinitely - user can take as long as needed
        try {
          return await completer.future;
        } catch (e) {
          _pendingPermissions.remove(requestId);
          return claude.PermissionResultDeny(message: 'Error: $e');
        }
    }
  }

  /// Also expose a claude_sdk-native permission callback for internal use.
  ///
  /// This is used by the agent network manager which still operates with
  /// claude_sdk types internally.
  claude.CanUseToolCallback createClaudePermissionCallback({
    required String agentId,
    required String? agentName,
    required String? agentType,
    required String cwd,
    String? permissionMode,
  }) {
    return (
      String toolName,
      Map<String, dynamic> input,
      claude.ToolPermissionContext context,
    ) async {
      return _createPermissionCallbackInternal(
        agentId: agentId,
        agentName: agentName,
        agentType: agentType,
        cwd: cwd,
        permissionMode: permissionMode,
        toolName: toolName,
        input: input,
      );
    };
  }

  Future<claude.PermissionResult> _handleAskUserQuestion({
    required String agentId,
    required String? agentName,
    required String? agentType,
    required String? taskName,
    required Map<String, dynamic> toolInput,
  }) async {
    try {
      // Parse questions from tool input
      final questionsJson = toolInput['questions'] as List<dynamic>?;
      if (questionsJson == null || questionsJson.isEmpty) {
        return const claude.PermissionResultAllow();
      }

      // Convert to event data format
      final questions = questionsJson.map((q) {
        final qMap = q as Map<String, dynamic>;
        final optionsList = qMap['options'] as List<dynamic>? ?? [];
        return AskUserQuestionData(
          question: qMap['question'] as String,
          header: qMap['header'] as String?,
          multiSelect: qMap['multiSelect'] as bool? ?? false,
          options: optionsList.map((o) {
            final oMap = o as Map<String, dynamic>;
            return AskUserQuestionOptionData(
              label: oMap['label'] as String,
              description: oMap['description'] as String? ?? '',
            );
          }).toList(),
        );
      }).toList();

      // Create completer and emit event
      final requestId = const Uuid().v4();
      final completer = Completer<Map<String, String>>();
      _pendingAskUserQuestions[requestId] = completer;

      _hub.emit(
        AskUserQuestionEvent(
          agentId: agentId,
          agentType: agentType ?? 'unknown',
          agentName: agentName,
          taskName: taskName,
          requestId: requestId,
          questions: questions,
        ),
      );

      final answers = await completer.future;

      return claude.PermissionResultAllow(
        updatedInput: {...toolInput, 'answers': answers},
      );
    } catch (e) {
      return claude.PermissionResultDeny(
        message: 'Failed to process AskUserQuestion: $e',
      );
    }
  }

  void _subscribeToNetworkChanges() {
    // Track the previous state for diffing
    AgentNetworkState? previousState = _services.networkManager.state;

    final subscription = _services.networkManager.stateStream.listen((next) {
      if (next.currentNetwork?.id != _networkId) {
        previousState = next;
        return;
      }

      final prevAgentIds =
          previousState?.currentNetwork?.agents.map((a) => a.id).toSet() ?? {};
      final nextAgentIds =
          next.currentNetwork?.agents.map((a) => a.id).toSet() ?? {};

      // Check for goal changes
      final prevGoal = previousState?.currentNetwork?.goal;
      final nextGoal = next.currentNetwork?.goal;
      if (prevGoal != nextGoal && nextGoal != null) {
        final mainAgent = next.currentNetwork!.agents.isNotEmpty
            ? next.currentNetwork!.agents.first
            : null;

        _hub.emit(
          TaskNameChangedEvent(
            agentId: mainAgent?.id ?? 'unknown',
            agentType: mainAgent?.type ?? 'main',
            agentName: mainAgent?.name,
            taskName: mainAgent?.taskName,
            newGoal: nextGoal,
            previousGoal: prevGoal,
          ),
        );
      }

      // Check for new agents (spawned)
      for (final agentId in nextAgentIds.difference(prevAgentIds)) {
        final agent = next.currentNetwork!.agents.firstWhere(
          (a) => a.id == agentId,
        );

        _hub.emit(
          AgentSpawnedEvent(
            agentId: agent.id,
            agentType: agent.type,
            agentName: agent.name,
            taskName: agent.taskName,
            spawnedBy: agent.spawnedBy ?? 'unknown',
          ),
        );

        _subscribeToAgent(agent);
      }

      // Check for removed agents (terminated)
      for (final agentId in prevAgentIds.difference(nextAgentIds)) {
        final agent = previousState!.currentNetwork!.agents.firstWhere(
          (a) => a.id == agentId,
        );

        _hub.emit(
          AgentTerminatedEvent(
            agentId: agent.id,
            agentType: agent.type,
            agentName: agent.name,
            taskName: agent.taskName,
          ),
        );

        _unsubscribeFromAgent(agentId);
      }

      previousState = next;
    });
    _subscriptions.add(subscription);
  }

  void _subscribeToAgent(AgentMetadata agent) {
    if (_agentStates.containsKey(agent.id)) return;

    final client = _services.clientRegistry[agent.id];
    if (client == null) return;

    _agentStates[agent.id] = _AgentStreamState(
      agentId: agent.id,
      agentType: agent.type,
      agentName: agent.name,
    );

    final initialStatus = _services.statusRegistry.getStatus(agent.id);
    _hub.emit(
      StatusEvent(
        agentId: agent.id,
        agentType: agent.type,
        agentName: agent.name,
        taskName: agent.taskName,
        status: _mapStatus(initialStatus),
      ),
    );

    final currentConversation = client.currentConversation;
    if (currentConversation.messages.isNotEmpty) {
      _handleConversation(agent, currentConversation);
    }

    final conversationSub = client.conversation.listen(
      (conversation) => _handleConversation(agent, conversation),
      onError: (error) {
        _hub.emit(
          ErrorEvent(
            agentId: agent.id,
            agentType: agent.type,
            agentName: agent.name,
            message: error.toString(),
          ),
        );
      },
    );
    _subscriptions.add(conversationSub);

    final turnCompleteSub = client.onTurnComplete.listen((_) {
      final state = _agentStates[agent.id];
      if (state != null && state.currentMessageEventId != null) {
        _hub.emit(
          MessageEvent(
            agentId: agent.id,
            agentType: agent.type,
            agentName: agent.name,
            taskName: state.taskName,
            eventId: state.currentMessageEventId!,
            role: 'assistant',
            content: '',
            isPartial: false,
          ),
        );
        state.currentMessageEventId = null;
      }

      final conversation = client.currentConversation;
      _hub.emit(
        TurnCompleteEvent(
          agentId: agent.id,
          agentType: agent.type,
          agentName: agent.name,
          taskName: state?.taskName,
          reason: 'end_turn',
          totalInputTokens: conversation.totalInputTokens,
          totalOutputTokens: conversation.totalOutputTokens,
          totalCacheReadInputTokens: conversation.totalCacheReadInputTokens,
          totalCacheCreationInputTokens:
              conversation.totalCacheCreationInputTokens,
          totalCostUsd: conversation.totalCostUsd,
          currentContextInputTokens: conversation.currentContextInputTokens,
          currentContextCacheReadTokens:
              conversation.currentContextCacheReadTokens,
          currentContextCacheCreationTokens:
              conversation.currentContextCacheCreationTokens,
        ),
      );
    });
    _subscriptions.add(turnCompleteSub);

    // Subscribe to status changes for this agent via the registry stream
    final statusSub = _services.statusRegistry.changes
        .where((change) => change.agentId == agent.id)
        .listen((change) {
          final network = _services.networkManager.state.currentNetwork;
          final agentMeta = network?.agents
              .where((a) => a.id == agent.id)
              .firstOrNull;
          final state = _agentStates[agent.id];
          if (state != null && agentMeta != null) {
            state.taskName = agentMeta.taskName;
          }

          _hub.emit(
            StatusEvent(
              agentId: agent.id,
              agentType: agent.type,
              agentName: agent.name,
              taskName: state?.taskName,
              status: _mapStatus(change.newStatus),
            ),
          );
        });
    _subscriptions.add(statusSub);
  }

  void _unsubscribeFromAgent(String agentId) {
    _agentStates.remove(agentId);
  }

  void _handleConversation(
    AgentMetadata agent,
    claude.Conversation conversation,
  ) {
    if (conversation.messages.isEmpty) return;

    final state = _agentStates[agent.id];
    if (state == null) return;

    final network = _services.networkManager.state.currentNetwork;
    final agentMeta = network?.agents
        .where((a) => a.id == agent.id)
        .firstOrNull;
    if (agentMeta != null) {
      state.taskName = agentMeta.taskName;
    }

    final currentMessageCount = conversation.messages.length;

    if (currentMessageCount > state.lastMessageCount) {
      for (int i = state.lastMessageCount; i < currentMessageCount; i++) {
        final message = conversation.messages[i];
        final eventId = const Uuid().v4();

        if (i == currentMessageCount - 1) {
          state.currentMessageEventId = eventId;
          state.lastContentLength = message.content.length;
          state.lastResponseCount = 0;
        }

        if (message.content.isNotEmpty) {
          _hub.emit(
            MessageEvent(
              agentId: agent.id,
              agentType: agent.type,
              agentName: agent.name,
              taskName: state.taskName,
              eventId: eventId,
              role: message.role == claude.MessageRole.user
                  ? 'user'
                  : 'assistant',
              content: message.content,
              isPartial: i == currentMessageCount - 1,
            ),
          );
        }

        if (i == currentMessageCount - 1) {
          _emitToolEvents(agent, message, state);
        }
      }

      state.lastMessageCount = currentMessageCount;
    } else {
      final latestMessage = conversation.messages.last;
      final currentContentLength = latestMessage.content.length;

      if (currentContentLength > state.lastContentLength) {
        final delta = latestMessage.content.substring(state.lastContentLength);
        if (delta.isNotEmpty) {
          final eventId = state.currentMessageEventId ?? const Uuid().v4();
          _hub.emit(
            MessageEvent(
              agentId: agent.id,
              agentType: agent.type,
              agentName: agent.name,
              taskName: state.taskName,
              eventId: eventId,
              role: latestMessage.role == claude.MessageRole.user
                  ? 'user'
                  : 'assistant',
              content: delta,
              isPartial: true,
            ),
          );
        }
        state.lastContentLength = currentContentLength;
      }

      _emitToolEvents(agent, latestMessage, state);
    }

    if (conversation.currentError != null) {
      _hub.emit(
        ErrorEvent(
          agentId: agent.id,
          agentType: agent.type,
          agentName: agent.name,
          taskName: state.taskName,
          message: conversation.currentError!,
        ),
      );
    }
  }

  void _emitToolEvents(
    AgentMetadata agent,
    claude.ConversationMessage message,
    _AgentStreamState state,
  ) {
    final responses = message.responses;
    final startIndex = state.lastResponseCount;

    for (int i = startIndex; i < responses.length; i++) {
      final response = responses[i];
      if (response is claude.ToolUseResponse) {
        final toolUseId = response.toolUseId ?? const Uuid().v4();
        state.toolNamesByUseId[toolUseId] = response.toolName;

        _hub.emit(
          ToolUseEvent(
            agentId: agent.id,
            agentType: agent.type,
            agentName: agent.name,
            taskName: state.taskName,
            toolUseId: toolUseId,
            toolName: response.toolName,
            toolInput: response.parameters,
          ),
        );
      } else if (response is claude.ToolResultResponse) {
        final toolName =
            state.toolNamesByUseId[response.toolUseId] ?? 'unknown';
        _hub.emit(
          ToolResultEvent(
            agentId: agent.id,
            agentType: agent.type,
            agentName: agent.name,
            taskName: state.taskName,
            toolUseId: response.toolUseId,
            toolName: toolName,
            result: response.content,
            isError: response.isError,
          ),
        );
      }
    }

    state.lastResponseCount = responses.length;
  }

  // ===========================================================================
  // Adapter methods
  // ===========================================================================

  /// Convert a claude_sdk Conversation to a VideConversation.
  VideConversation _convertConversation(claude.Conversation conversation) {
    return VideConversation(
      messages: conversation.messages.map(_convertMessage).toList(),
      state: conversation.isProcessing
          ? VideConversationState.processing
          : VideConversationState.idle,
      totalInputTokens: conversation.totalInputTokens,
      totalOutputTokens: conversation.totalOutputTokens,
      totalCacheReadInputTokens: conversation.totalCacheReadInputTokens,
      totalCacheCreationInputTokens: conversation.totalCacheCreationInputTokens,
      totalCostUsd: conversation.totalCostUsd,
      currentContextInputTokens: conversation.currentContextInputTokens,
      currentContextCacheReadTokens: conversation.currentContextCacheReadTokens,
      currentContextCacheCreationTokens:
          conversation.currentContextCacheCreationTokens,
      currentError: conversation.currentError,
    );
  }

  /// Convert a claude_sdk ConversationMessage to VideConversationMessage.
  VideConversationMessage _convertMessage(claude.ConversationMessage message) {
    return VideConversationMessage(
      id: message.id,
      role: message.role == claude.MessageRole.user
          ? MessageRole.user
          : MessageRole.assistant,
      content: message.content,
      timestamp: message.timestamp,
      responses: message.responses
          .map(_convertResponse)
          .whereType<VideResponse>()
          .toList(),
      isStreaming: message.isStreaming,
      isComplete: message.isComplete,
      messageType: message.role == claude.MessageRole.user
          ? VideMessageType.userMessage
          : VideMessageType.assistantText,
    );
  }

  /// Convert a claude_sdk response to VideResponse, or null if the response
  /// should be filtered out (metadata-only types like CompletionResponse).
  VideResponse? _convertResponse(claude.ClaudeResponse response) {
    return switch (response) {
      claude.TextResponse r => VideTextResponse(
        id: r.id,
        timestamp: r.timestamp,
        content: r.content,
        isPartial: r.isPartial,
        isCumulative: r.isCumulative,
      ),
      claude.ToolUseResponse r => VideToolUseResponse(
        id: r.id,
        timestamp: r.timestamp,
        toolName: r.toolName,
        parameters: r.parameters,
        toolUseId: r.toolUseId,
      ),
      claude.ToolResultResponse r => VideToolResultResponse(
        id: r.id,
        timestamp: r.timestamp,
        toolUseId: r.toolUseId,
        content: r.content,
        isError: r.isError,
      ),
      // Metadata-only responses — no renderable content
      claude.CompletionResponse() => null,
      claude.ErrorResponse() => null,
      claude.ApiErrorResponse() => null,
      claude.StatusResponse() => null,
      claude.MetaResponse() => null,
      claude.TurnDurationResponse() => null,
      claude.LocalCommandResponse() => null,
      claude.CompactBoundaryResponse() => null,
      claude.CompactSummaryResponse() => null,
      claude.UserMessageResponse() => null,
      claude.UnknownResponse() => null,
    };
  }

  VideAgent _mapAgent(AgentMetadata agent) {
    final status = _services.statusRegistry.getStatus(agent.id);
    return VideAgent(
      id: agent.id,
      name: agent.name,
      type: agent.type,
      status: _mapStatus(status),
      spawnedBy: agent.spawnedBy,
      taskName: agent.taskName,
      createdAt: agent.createdAt,
      totalInputTokens: agent.totalInputTokens,
      totalOutputTokens: agent.totalOutputTokens,
      totalCacheReadInputTokens: agent.totalCacheReadInputTokens,
      totalCacheCreationInputTokens: agent.totalCacheCreationInputTokens,
      totalCostUsd: agent.totalCostUsd,
    );
  }

  VideAgentStatus _mapStatus(internal.AgentStatus status) {
    return switch (status) {
      internal.AgentStatus.working => VideAgentStatus.working,
      internal.AgentStatus.waitingForAgent => VideAgentStatus.waitingForAgent,
      internal.AgentStatus.waitingForUser => VideAgentStatus.waitingForUser,
      internal.AgentStatus.idle => VideAgentStatus.idle,
    };
  }
}

/// Tracks state for a single agent's event stream.
class _AgentStreamState {
  final String agentId;
  final String agentType;
  final String? agentName;
  String? taskName;

  int lastMessageCount = 0;
  int lastContentLength = 0;
  int lastResponseCount = 0;

  String? currentMessageEventId;
  final Map<String, String> toolNamesByUseId = {};

  _AgentStreamState({
    required this.agentId,
    required this.agentType,
    this.agentName,
  });
}
