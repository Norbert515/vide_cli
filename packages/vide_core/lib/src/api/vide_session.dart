/// VideSession - Active session wrapper for the VideCore API.
///
/// This provides a clean interface to an agent network session,
/// hiding the internal Riverpod providers and claude_sdk types.
library;

import 'dart:async';

import 'package:claude_sdk/claude_sdk.dart';
import 'package:riverpod/riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/agent_metadata.dart';
import '../models/agent_status.dart' as internal;
import '../services/agent_network_manager.dart';
import '../services/claude_manager.dart';
import '../state/agent_status_manager.dart';
import 'conversation_state.dart';
import 'vide_agent.dart';
import 'vide_event.dart';

/// An active session with a network of agents.
///
/// Use [VideCore.startSession] or [VideCore.resumeSession] to create a session.
///
/// The session provides:
/// - A single [events] stream with all events from all agents
/// - Access to the current list of [agents]
/// - Methods to [sendMessage], [respondToPermission], and [abort]
///
/// Example:
/// ```dart
/// final session = await core.startSession(config);
///
/// session.events.listen((event) {
///   switch (event) {
///     case MessageEvent e:
///       stdout.write(e.content);
///     case ToolUseEvent e:
///       print('Tool: ${e.toolName}');
///     case PermissionRequestEvent e:
///       session.respondToPermission(e.requestId, allow: true);
///     // ... handle other events
///   }
/// });
///
/// // Send follow-up message
/// session.sendMessage('What else can you help with?');
///
/// // Clean up when done
/// await session.dispose();
/// ```
class VideSession {
  final String _networkId;
  final ProviderContainer _container;
  final StreamController<VideEvent> _eventController;

  /// Subscriptions to clean up on dispose.
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final List<ProviderSubscription<dynamic>> _providerSubscriptions = [];

  /// Tracks state for each agent's conversation stream.
  final Map<String, _AgentStreamState> _agentStates = {};

  /// Pending permission completers by request ID.
  final Map<String, Completer<PermissionResult>> _pendingPermissions = {};

  /// Conversation state manager that accumulates events from the start.
  ///
  /// This is created immediately when the session is created, so no events are missed.
  late final ConversationStateManager _conversationStateManager;

  /// Whether the session has been disposed.
  bool _disposed = false;

  VideSession._({
    required String networkId,
    required ProviderContainer container,
  })  : _networkId = networkId,
        _container = container,
        _eventController = StreamController<VideEvent>.broadcast() {
    // Create conversation state manager immediately and subscribe to events
    _conversationStateManager = ConversationStateManager();
    _eventController.stream.listen((event) {
      _conversationStateManager.handleEvent(event);
    });
  }

  /// Creates a new VideSession for an existing network.
  ///
  /// This is called internally by [VideCore.startSession] and [VideCore.resumeSession].
  static VideSession create({
    required String networkId,
    required ProviderContainer container,
  }) {
    final session = VideSession._(
      networkId: networkId,
      container: container,
    );
    session._initialize();
    return session;
  }

  void _initialize() {
    // Subscribe to network changes to detect agent spawn/terminate
    _subscribeToNetworkChanges();

    // Subscribe to all existing agents
    final network = _container.read(agentNetworkManagerProvider).currentNetwork;
    if (network != null) {
      for (final agent in network.agents) {
        _subscribeToAgent(agent);
      }
    }
  }

  /// Unique identifier for this session.
  String get id => _networkId;

  /// Get the conversation state manager for this session.
  ///
  /// This accumulates all events into a renderable conversation structure.
  /// The manager is created when the session is created, so all events are captured.
  ConversationStateManager get conversationState => _conversationStateManager;

  /// Stream of all events from all agents in the session.
  ///
  /// Events are emitted in real-time as agents work. The stream includes:
  /// - [MessageEvent] - Text content from agents
  /// - [ToolUseEvent] - Tool invocations
  /// - [ToolResultEvent] - Tool execution results
  /// - [StatusEvent] - Agent status changes
  /// - [TurnCompleteEvent] - When an agent completes its turn
  /// - [AgentSpawnedEvent] - When a new agent is spawned
  /// - [AgentTerminatedEvent] - When an agent is terminated
  /// - [PermissionRequestEvent] - When permission is needed
  /// - [ErrorEvent] - When an error occurs
  Stream<VideEvent> get events => _eventController.stream;

  /// Current agents in the session.
  ///
  /// This returns an immutable snapshot of the current agents.
  /// Subscribe to [events] to receive [AgentSpawnedEvent] and
  /// [AgentTerminatedEvent] for real-time updates.
  List<VideAgent> get agents {
    final network = _container.read(agentNetworkManagerProvider).currentNetwork;
    if (network == null || network.id != _networkId) return [];
    return network.agents.map(_mapAgent).toList();
  }

  /// The main agent (first agent in the network).
  VideAgent? get mainAgent => agents.isNotEmpty ? agents.first : null;

  /// List of agent IDs in the session.
  ///
  /// This is useful when you need quick access to IDs without
  /// mapping the full [VideAgent] objects.
  List<String> get agentIds {
    final network = _container.read(agentNetworkManagerProvider).currentNetwork;
    if (network == null || network.id != _networkId) return [];
    return network.agentIds;
  }

  /// Whether any agent in the session is currently processing.
  ///
  /// This checks all agents in the network and returns true if any
  /// of them have an active conversation that is processing.
  bool get isProcessing {
    for (final agentId in _agentStates.keys) {
      final client = _container.read(claudeProvider(agentId));
      if (client?.currentConversation.isProcessing ?? false) {
        return true;
      }
    }
    return false;
  }

  /// The effective working directory for this session.
  ///
  /// This may be different from the configured working directory if a
  /// worktree has been set.
  String get workingDirectory {
    final manager = _container.read(agentNetworkManagerProvider.notifier);
    return manager.effectiveWorkingDirectory;
  }

  /// Send a message to an agent.
  ///
  /// If [agentId] is not specified, the message is sent to the main agent.
  void sendMessage(String content, {String? agentId}) {
    _checkNotDisposed();
    final manager = _container.read(agentNetworkManagerProvider.notifier);
    final targetAgent = agentId ?? mainAgent?.id;
    if (targetAgent == null) {
      throw StateError('No agents in session');
    }
    manager.sendMessage(targetAgent, Message.text(content));
  }

  /// Respond to a permission request.
  ///
  /// Call this when you receive a [PermissionRequestEvent] to allow or deny
  /// the tool invocation.
  void respondToPermission(
    String requestId, {
    required bool allow,
    String? message,
  }) {
    _checkNotDisposed();
    final completer = _pendingPermissions.remove(requestId);
    if (completer != null) {
      if (allow) {
        completer.complete(const PermissionResultAllow());
      } else {
        completer.complete(PermissionResultDeny(
          message: message ?? 'Permission denied',
        ));
      }
    }
  }

  /// Abort all agents in the session.
  ///
  /// This cancels any in-progress work across all agents.
  Future<void> abort() async {
    _checkNotDisposed();
    final network = _container.read(agentNetworkManagerProvider).currentNetwork;
    if (network == null || network.id != _networkId) return;

    final clients = _container.read(claudeManagerProvider);
    for (final agent in network.agents) {
      final client = clients[agent.id];
      if (client != null) {
        await client.abort();
      }
    }
  }

  /// Abort a specific agent.
  ///
  /// This cancels any in-progress work for the specified agent.
  Future<void> abortAgent(String agentId) async {
    _checkNotDisposed();
    final client = _container.read(claudeProvider(agentId));
    if (client != null) {
      await client.abort();
    }
  }

  /// Clear the conversation for an agent (resets context).
  ///
  /// If [agentId] is not specified, clears the main agent's conversation.
  /// This is useful for implementing a `/clear` command or resetting context.
  Future<void> clearConversation({String? agentId}) async {
    _checkNotDisposed();
    final targetId = agentId ?? mainAgent?.id;
    if (targetId == null) return;

    final client = _container.read(claudeProvider(targetId));
    await client?.clearConversation();
  }

  /// Get an MCP server instance for an agent.
  ///
  /// Returns null if the server is not found or agent doesn't exist.
  /// This is useful for accessing MCP servers directly, such as
  /// the flutter runtime MCP for UI rendering.
  T? getMcpServer<T extends McpServerBase>(String agentId, String serverName) {
    _checkNotDisposed();
    final client = _container.read(claudeProvider(agentId));
    return client?.getMcpServer<T>(serverName);
  }

  /// Set the working directory (worktree path) for this session.
  ///
  /// This affects all new operations in the session. Pass null or
  /// an empty string to clear the worktree and return to the original directory.
  ///
  /// Note: Agent conversation history may be cleared since Claude CLI
  /// cannot change its working directory mid-session.
  Future<void> setWorktreePath(String? path) async {
    _checkNotDisposed();
    final manager = _container.read(agentNetworkManagerProvider.notifier);
    await manager.setWorktreePath(path);
  }

  /// Get the current conversation for an agent.
  ///
  /// Returns null if the agent doesn't exist. This provides direct
  /// access to the conversation for rendering messages and token counts.
  Conversation? getConversation(String agentId) {
    _checkNotDisposed();
    final client = _container.read(claudeProvider(agentId));
    return client?.currentConversation;
  }

  /// Stream of conversation updates for an agent.
  ///
  /// Returns an empty stream if the agent doesn't exist.
  /// This allows subscribing to conversation changes for real-time updates.
  Stream<Conversation> conversationStream(String agentId) {
    _checkNotDisposed();
    final client = _container.read(claudeProvider(agentId));
    return client?.conversation ?? const Stream.empty();
  }

  /// Update token/cost statistics for an agent.
  ///
  /// This is called by UI when conversation updates to persist stats.
  /// Token stats will be persisted on the next network save.
  void updateAgentTokenStats(
    String agentId, {
    required int totalInputTokens,
    required int totalOutputTokens,
    required int totalCacheReadInputTokens,
    required int totalCacheCreationInputTokens,
    required double totalCostUsd,
  }) {
    _checkNotDisposed();
    final manager = _container.read(agentNetworkManagerProvider.notifier);
    manager.updateAgentTokenStats(
      agentId,
      totalInputTokens: totalInputTokens,
      totalOutputTokens: totalOutputTokens,
      totalCacheReadInputTokens: totalCacheReadInputTokens,
      totalCacheCreationInputTokens: totalCacheCreationInputTokens,
      totalCostUsd: totalCostUsd,
    );
  }

  /// Terminate an agent and remove it from the network.
  ///
  /// [agentId] is the agent to terminate.
  /// [terminatedBy] is the ID of the agent requesting termination (typically main agent).
  ///
  /// Once terminated, the agent cannot be resumed. Use [abort] to pause
  /// an agent temporarily.
  Future<void> terminateAgent(
    String agentId, {
    required String terminatedBy,
    String? reason,
  }) async {
    _checkNotDisposed();
    final manager = _container.read(agentNetworkManagerProvider.notifier);
    await manager.terminateAgent(
      targetAgentId: agentId,
      terminatedBy: terminatedBy,
      reason: reason,
    );
  }

  /// Fork an agent to create a new conversation branch.
  ///
  /// Returns the ID of the newly created agent.
  Future<String> forkAgent(String agentId, {String? name}) async {
    _checkNotDisposed();
    final manager = _container.read(agentNetworkManagerProvider.notifier);
    return await manager.forkAgent(sourceAgentId: agentId, name: name);
  }

  /// Spawn a new agent by agent type.
  ///
  /// [agentType] is the agent personality name from the team's agents list
  /// (e.g., 'solid-implementer', 'deep-researcher', 'creative-explorer').
  /// [name] is the display name for the agent.
  /// [initialPrompt] is the initial message to send to the agent.
  /// [spawnedBy] is the ID of the agent requesting the spawn (typically main agent).
  ///
  /// Returns the ID of the newly created agent.
  Future<String> spawnAgent({
    required String agentType,
    required String name,
    required String initialPrompt,
    required String spawnedBy,
  }) async {
    _checkNotDisposed();
    final manager = _container.read(agentNetworkManagerProvider.notifier);
    return await manager.spawnAgent(
      agentType: agentType,
      name: name,
      initialPrompt: initialPrompt,
      spawnedBy: spawnedBy,
    );
  }

  /// Get the queued message for an agent, if any.
  ///
  /// A queued message is a message that will be sent when the agent
  /// completes its current turn.
  String? getQueuedMessage(String agentId) {
    final client = _container.read(claudeProvider(agentId));
    return client?.currentQueuedMessage;
  }

  /// Stream of queued message changes for an agent.
  ///
  /// Emits whenever the queued message changes (set or cleared).
  Stream<String?> queuedMessageStream(String agentId) {
    final client = _container.read(claudeProvider(agentId));
    return client?.queuedMessage ?? const Stream.empty();
  }

  /// Clear the queued message for an agent.
  void clearQueuedMessage(String agentId) {
    _checkNotDisposed();
    final client = _container.read(claudeProvider(agentId));
    client?.clearQueuedMessage();
  }

  /// Get the model name for an agent (e.g., "claude-sonnet-4-5-20250929").
  ///
  /// Returns null if the agent doesn't exist or hasn't initialized yet.
  String? getModel(String agentId) {
    _checkNotDisposed();
    final client = _container.read(claudeProvider(agentId));
    return client?.initData?.model;
  }

  /// Stream of model changes for an agent.
  ///
  /// Emits when the agent's init data is received (which contains the model).
  Stream<String?> modelStream(String agentId) {
    _checkNotDisposed();
    final client = _container.read(claudeProvider(agentId));
    if (client == null) return Stream.value(null);
    return client.initDataStream.map((meta) => meta.model);
  }

  /// Dispose the session and release resources.
  ///
  /// After calling dispose, the session can no longer be used.
  /// The underlying agent network is NOT deleted - it can be resumed
  /// with [VideCore.resumeSession].
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    // Cancel all subscriptions
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();

    for (final sub in _providerSubscriptions) {
      sub.close();
    }
    _providerSubscriptions.clear();

    // Complete any pending permissions with deny
    for (final completer in _pendingPermissions.values) {
      if (!completer.isCompleted) {
        completer.complete(const PermissionResultDeny(
          message: 'Session disposed',
        ));
      }
    }
    _pendingPermissions.clear();

    // Clear agent states
    _agentStates.clear();

    // Dispose conversation state manager
    _conversationStateManager.dispose();

    // Close the event stream
    await _eventController.close();
  }

  void _checkNotDisposed() {
    if (_disposed) {
      throw StateError('Session has been disposed');
    }
  }

  void _subscribeToNetworkChanges() {
    final subscription = _container.listen(
      agentNetworkManagerProvider,
      (previous, next) {
        if (next.currentNetwork?.id != _networkId) return;

        final prevAgentIds =
            previous?.currentNetwork?.agents.map((a) => a.id).toSet() ?? {};
        final nextAgentIds =
            next.currentNetwork?.agents.map((a) => a.id).toSet() ?? {};

        // Check for new agents (spawned)
        for (final agentId in nextAgentIds.difference(prevAgentIds)) {
          final agent = next.currentNetwork!.agents.firstWhere(
            (a) => a.id == agentId,
          );

          // Emit spawn event
          _eventController.add(AgentSpawnedEvent(
            agentId: agent.id,
            agentType: agent.type,
            agentName: agent.name,
            taskName: agent.taskName,
            spawnedBy: agent.spawnedBy ?? 'unknown',
          ));

          // Subscribe to the new agent
          _subscribeToAgent(agent);
        }

        // Check for removed agents (terminated)
        for (final agentId in prevAgentIds.difference(nextAgentIds)) {
          final agent = previous!.currentNetwork!.agents.firstWhere(
            (a) => a.id == agentId,
          );

          // Emit terminate event
          _eventController.add(AgentTerminatedEvent(
            agentId: agent.id,
            agentType: agent.type,
            agentName: agent.name,
            taskName: agent.taskName,
          ));

          // Unsubscribe from the terminated agent
          _unsubscribeFromAgent(agentId);
        }
      },
      fireImmediately: false,
    );
    _providerSubscriptions.add(subscription);
  }

  void _subscribeToAgent(AgentMetadata agent) {
    if (_agentStates.containsKey(agent.id)) return;

    final client = _container.read(claudeProvider(agent.id));
    if (client == null) return;

    // Initialize state for this agent
    _agentStates[agent.id] = _AgentStreamState(
      agentId: agent.id,
      agentType: agent.type,
      agentName: agent.name,
    );

    // IMPORTANT: First replay the current conversation state
    // This catches up on any messages that were sent before we subscribed
    final currentConversation = client.currentConversation;
    if (currentConversation.messages.isNotEmpty) {
      _handleConversation(agent, currentConversation);
    }

    // Subscribe to conversation updates
    final conversationSub = client.conversation.listen(
      (conversation) => _handleConversation(agent, conversation),
      onError: (error) {
        _eventController.add(ErrorEvent(
          agentId: agent.id,
          agentType: agent.type,
          agentName: agent.name,
          message: error.toString(),
        ));
      },
    );
    _subscriptions.add(conversationSub);

    // Subscribe to turn complete
    final turnCompleteSub = client.onTurnComplete.listen((_) {
      // Finalize any in-progress message
      final state = _agentStates[agent.id];
      if (state != null && state.currentMessageEventId != null) {
        _eventController.add(MessageEvent(
          agentId: agent.id,
          agentType: agent.type,
          agentName: agent.name,
          taskName: state.taskName,
          eventId: state.currentMessageEventId!,
          role: 'assistant',
          content: '',
          isPartial: false,
        ));
        state.currentMessageEventId = null;
      }

      // Get token/cost data from current conversation
      final conversation = client.currentConversation;
      _eventController.add(TurnCompleteEvent(
        agentId: agent.id,
        agentType: agent.type,
        agentName: agent.name,
        taskName: state?.taskName,
        reason: 'end_turn',
        totalInputTokens: conversation.totalInputTokens,
        totalOutputTokens: conversation.totalOutputTokens,
        totalCacheReadInputTokens: conversation.totalCacheReadInputTokens,
        totalCacheCreationInputTokens: conversation.totalCacheCreationInputTokens,
        totalCostUsd: conversation.totalCostUsd,
        currentContextInputTokens: conversation.currentContextInputTokens,
        currentContextCacheReadTokens: conversation.currentContextCacheReadTokens,
        currentContextCacheCreationTokens: conversation.currentContextCacheCreationTokens,
      ));
    });
    _subscriptions.add(turnCompleteSub);

    // Subscribe to status changes
    final statusSub = _container.listen<internal.AgentStatus>(
      agentStatusProvider(agent.id),
      (previous, next) {
        if (previous != null && previous != next) {
          // Update task name from network state
          final network =
              _container.read(agentNetworkManagerProvider).currentNetwork;
          final agentMeta =
              network?.agents.where((a) => a.id == agent.id).firstOrNull;
          final state = _agentStates[agent.id];
          if (state != null && agentMeta != null) {
            state.taskName = agentMeta.taskName;
          }

          _eventController.add(StatusEvent(
            agentId: agent.id,
            agentType: agent.type,
            agentName: agent.name,
            taskName: state?.taskName,
            status: _mapStatus(next),
          ));
        }
      },
      fireImmediately: false,
    );
    _providerSubscriptions.add(statusSub);
  }

  void _unsubscribeFromAgent(String agentId) {
    _agentStates.remove(agentId);
    // Note: We don't remove subscriptions here because they're all in lists
    // and will be cleaned up on dispose. The agent's ClaudeClient will be
    // removed by AgentNetworkManager, so the streams will close naturally.
  }

  void _handleConversation(AgentMetadata agent, Conversation conversation) {
    if (conversation.messages.isEmpty) return;

    final state = _agentStates[agent.id];
    if (state == null) return;

    // Update task name from network state
    final network = _container.read(agentNetworkManagerProvider).currentNetwork;
    final agentMeta = network?.agents.where((a) => a.id == agent.id).firstOrNull;
    if (agentMeta != null) {
      state.taskName = agentMeta.taskName;
    }

    final currentMessageCount = conversation.messages.length;
    final latestMessage = conversation.messages.last;
    final currentContentLength = latestMessage.content.length;

    // New message started
    if (currentMessageCount > state.lastMessageCount) {
      state.lastResponseCount = 0;

      // Generate new event ID for this message
      final eventId = const Uuid().v4();
      state.currentMessageEventId = eventId;

      if (latestMessage.content.isNotEmpty) {
        _eventController.add(MessageEvent(
          agentId: agent.id,
          agentType: agent.type,
          agentName: agent.name,
          taskName: state.taskName,
          eventId: eventId,
          role: latestMessage.role == MessageRole.user ? 'user' : 'assistant',
          content: latestMessage.content,
          isPartial: true,
        ));
      }

      state.lastMessageCount = currentMessageCount;
      state.lastContentLength = currentContentLength;
    }
    // Same message, content grew (streaming delta)
    else if (currentContentLength > state.lastContentLength) {
      final delta = latestMessage.content.substring(state.lastContentLength);
      if (delta.isNotEmpty) {
        final eventId = state.currentMessageEventId ?? const Uuid().v4();
        _eventController.add(MessageEvent(
          agentId: agent.id,
          agentType: agent.type,
          agentName: agent.name,
          taskName: state.taskName,
          eventId: eventId,
          role: latestMessage.role == MessageRole.user ? 'user' : 'assistant',
          content: delta,
          isPartial: true,
        ));
      }
      state.lastContentLength = currentContentLength;
    }

    // Always check for new tool events
    _emitToolEvents(agent, latestMessage, state);

    // Check for errors
    if (conversation.currentError != null) {
      _eventController.add(ErrorEvent(
        agentId: agent.id,
        agentType: agent.type,
        agentName: agent.name,
        taskName: state.taskName,
        message: conversation.currentError!,
      ));
    }
  }

  void _emitToolEvents(
    AgentMetadata agent,
    ConversationMessage message,
    _AgentStreamState state,
  ) {
    final responses = message.responses;
    final startIndex = state.lastResponseCount;

    for (int i = startIndex; i < responses.length; i++) {
      final response = responses[i];
      if (response is ToolUseResponse) {
        final toolUseId = response.toolUseId ?? const Uuid().v4();
        state.toolNamesByUseId[toolUseId] = response.toolName;

        _eventController.add(ToolUseEvent(
          agentId: agent.id,
          agentType: agent.type,
          agentName: agent.name,
          taskName: state.taskName,
          toolUseId: toolUseId,
          toolName: response.toolName,
          toolInput: response.parameters,
        ));
      } else if (response is ToolResultResponse) {
        final toolName = state.toolNamesByUseId[response.toolUseId] ?? 'unknown';
        _eventController.add(ToolResultEvent(
          agentId: agent.id,
          agentType: agent.type,
          agentName: agent.name,
          taskName: state.taskName,
          toolUseId: response.toolUseId,
          toolName: toolName,
          result: response.content,
          isError: response.isError,
        ));
      }
    }

    state.lastResponseCount = responses.length;
  }

  /// Creates a permission callback that emits [PermissionRequestEvent]
  /// and waits for [respondToPermission] to be called.
  CanUseToolCallback createPermissionCallback({
    required String agentId,
    required String? agentName,
    required String? agentType,
  }) {
    return (
      String toolName,
      Map<String, dynamic> input,
      ToolPermissionContext context,
    ) async {
      final requestId = const Uuid().v4();
      final completer = Completer<PermissionResult>();
      _pendingPermissions[requestId] = completer;

      // Get current task name
      final state = _agentStates[agentId];

      // Emit permission request event
      _eventController.add(PermissionRequestEvent(
        agentId: agentId,
        agentType: agentType ?? 'unknown',
        agentName: agentName,
        taskName: state?.taskName,
        requestId: requestId,
        toolName: toolName,
        toolInput: input,
      ));

      // Wait for response (with timeout)
      try {
        return await completer.future.timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            _pendingPermissions.remove(requestId);
            return const PermissionResultDeny(
              message: 'Permission request timed out',
            );
          },
        );
      } catch (e) {
        _pendingPermissions.remove(requestId);
        return PermissionResultDeny(
          message: 'Error: $e',
        );
      }
    };
  }

  VideAgent _mapAgent(AgentMetadata agent) {
    final status = _container.read(agentStatusProvider(agent.id));
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
