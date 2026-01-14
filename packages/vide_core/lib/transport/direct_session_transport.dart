/// Direct in-process session transport for vide.
///
/// This transport talks directly to the AgentNetworkManager without
/// network overhead, useful for embedded/local usage.
import 'dart:async';

import 'package:claude_sdk/claude_sdk.dart';
import 'package:riverpod/riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:vide_interface/vide_interface.dart' as interface_;

import '../models/agent_metadata.dart';
import '../models/agent_status.dart';
import '../services/agent_network_manager.dart';
import '../services/claude_manager.dart';
import '../state/agent_status_manager.dart';

/// Direct in-process transport that talks directly to AgentNetworkManager.
///
/// This transport is always "connected" since it runs in-process.
/// Events are emitted by subscribing to the internal agent streams.
///
/// **Permission Handling:** This transport does not currently emit
/// [PermissionRequestEvent]s. Permission handling must be configured
/// separately via the ClaudeClient's permission hooks or an external
/// permission manager. Future versions may integrate permission event
/// forwarding.
class DirectSessionTransport implements interface_.SessionTransport {
  DirectSessionTransport({
    required this.sessionId,
    required ProviderContainer container,
  }) : _container = container;

  @override
  final String sessionId;

  final ProviderContainer _container;

  /// Stream controller for emitting session events.
  final _eventsController =
      StreamController<interface_.SessionEvent>.broadcast();

  /// Stream controller for connection state changes.
  final _connectionStateController =
      StreamController<interface_.ConnectionState>.broadcast();

  /// Current connection state (always connected for direct transport).
  interface_.ConnectionState _currentState = interface_.ConnectionState.connected;

  /// Tracks which agents we're subscribed to.
  final Map<String, _AgentSubscription> _agentSubscriptions = {};

  /// Subscription to network state changes (for agent spawn/terminate).
  ProviderSubscription<AgentNetworkState>? _networkSubscription;

  /// Current message event ID for streaming (shared across chunks).
  final Map<String, String> _currentMessageEventIds = {};

  /// Whether the transport has been initialized.
  bool _initialized = false;

  @override
  Stream<interface_.SessionEvent> get events => _eventsController.stream;

  @override
  Stream<interface_.ConnectionState> get connectionState =>
      _connectionStateController.stream;

  @override
  interface_.ConnectionState get currentState => _currentState;

  /// Initialize the transport and start listening to agents.
  ///
  /// This must be called after construction to begin receiving events.
  /// The transport will emit a [ConnectedEvent] with session info.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final network =
        _container.read(agentNetworkManagerProvider).currentNetwork;
    if (network == null || network.id != sessionId) {
      _emitError('Session not found', code: 'NOT_FOUND');
      return;
    }

    // Subscribe to network state changes FIRST
    _subscribeToNetworkChanges();

    // Subscribe to all existing agents
    for (final agent in network.agents) {
      _subscribeToAgent(agent);
    }

    // Emit connected event
    final connectedEvent = interface_.ConnectedEvent(
      timestamp: DateTime.now(),
      sessionInfo: interface_.SessionInfo(
        sessionId: network.id,
        mainAgentId: network.agents.first.id,
        goal: network.goal,
        createdAt: network.createdAt,
        agents: network.agents
            .map(
              (a) => interface_.AgentInfo(
                id: a.id,
                name: a.name,
                type: a.type,
                status: _mapAgentStatusToInterface(a.status),
              ),
            )
            .toList(),
      ),
      clients: [], // No remote clients for direct transport
    );
    _eventsController.add(connectedEvent);
  }

  void _subscribeToNetworkChanges() {
    _networkSubscription = _container.listen(agentNetworkManagerProvider, (
      previous,
      next,
    ) {
      if (next.currentNetwork?.id != sessionId) return;

      final prevAgentIds =
          previous?.currentNetwork?.agents.map((a) => a.id).toSet() ?? {};
      final nextAgentIds =
          next.currentNetwork?.agents.map((a) => a.id).toSet() ?? {};

      // Check for new agents (spawned)
      for (final agentId in nextAgentIds.difference(prevAgentIds)) {
        final agent = next.currentNetwork!.agents.firstWhere(
          (a) => a.id == agentId,
        );

        // Emit agent-spawned event
        final event = interface_.AgentSpawnedEvent(
          timestamp: DateTime.now(),
          agentId: agent.spawnedBy,
          spawnedAgentId: agent.id,
          name: agent.name,
          type: agent.type,
        );
        _eventsController.add(event);

        // Subscribe to the new agent
        _subscribeToAgent(agent);
      }

      // Check for removed agents (terminated)
      for (final agentId in prevAgentIds.difference(nextAgentIds)) {
        final agent = previous!.currentNetwork!.agents.firstWhere(
          (a) => a.id == agentId,
        );

        // Emit agent-terminated event
        final event = interface_.AgentTerminatedEvent(
          timestamp: DateTime.now(),
          agentId: null, // System-level event
          terminatedAgentId: agent.id,
          reason: null,
        );
        _eventsController.add(event);

        // Unsubscribe from the terminated agent
        _unsubscribeFromAgent(agentId);
      }
    }, fireImmediately: false);
  }

  void _subscribeToAgent(AgentMetadata agent) {
    if (_agentSubscriptions.containsKey(agent.id)) return;

    final claudeClient = _container.read(claudeProvider(agent.id));
    if (claudeClient == null) {
      // Agent not yet initialized, skip for now (will be subscribed when ready)
      return;
    }

    final subscription = _AgentSubscription(agentId: agent.id);

    // Subscribe to conversation updates
    subscription.conversationSubscription = claudeClient.conversation.listen(
      (conversation) {
        _handleConversationUpdate(conversation, subscription, agent);
      },
      onError: (error) {
        final event = interface_.ErrorEvent(
          timestamp: DateTime.now(),
          agentId: agent.id,
          code: 'CONVERSATION_ERROR',
          message: error.toString(),
        );
        _eventsController.add(event);
      },
    );

    // Subscribe to turn complete events
    subscription.turnCompleteSubscription = claudeClient.onTurnComplete.listen((
      _,
    ) {
      // Finalize any in-progress message
      final eventId = _currentMessageEventIds[agent.id];
      if (eventId != null) {
        final finalEvent = interface_.MessageEvent(
          timestamp: DateTime.now(),
          agentId: agent.id,
          eventId: eventId,
          role: 'assistant',
          content: '',
          isPartial: false,
        );
        _eventsController.add(finalEvent);
        _currentMessageEventIds.remove(agent.id);
      }

      final event = interface_.TurnCompleteEvent(
        timestamp: DateTime.now(),
        agentId: agent.id,
      );
      _eventsController.add(event);
    });

    // Emit initial status
    final initialStatus = _container.read(agentStatusProvider(agent.id));
    final initialStatusEvent = interface_.AgentStatusEvent(
      timestamp: DateTime.now(),
      agentId: agent.id,
      statusAgentId: agent.id,
      status: _mapAgentStatusToInterface(initialStatus),
    );
    _eventsController.add(initialStatusEvent);

    // Subscribe to agent status changes
    subscription.statusSubscription = _container.listen<AgentStatus>(
      agentStatusProvider(agent.id),
      (previous, next) {
        if (previous != null && previous != next) {
          final event = interface_.AgentStatusEvent(
            timestamp: DateTime.now(),
            agentId: agent.id,
            statusAgentId: agent.id,
            status: _mapAgentStatusToInterface(next),
          );
          _eventsController.add(event);
        }
      },
      fireImmediately: false,
    );

    _agentSubscriptions[agent.id] = subscription;
  }

  void _unsubscribeFromAgent(String agentId) {
    final subscription = _agentSubscriptions.remove(agentId);
    subscription?.cancel();
    _currentMessageEventIds.remove(agentId);
  }

  void _handleConversationUpdate(
    Conversation conversation,
    _AgentSubscription subscription,
    AgentMetadata agent,
  ) {
    if (conversation.messages.isEmpty) return;

    final currentMessageCount = conversation.messages.length;
    final latestMessage = conversation.messages.last;
    final currentContentLength = latestMessage.content.length;

    // New message started
    if (currentMessageCount > subscription.lastMessageCount) {
      // Reset response count for the new message
      subscription.lastResponseCount = 0;

      // Generate new event ID for this message
      final eventId = const Uuid().v4();
      _currentMessageEventIds[subscription.agentId] = eventId;

      if (latestMessage.content.isNotEmpty) {
        final event = interface_.MessageEvent(
          timestamp: DateTime.now(),
          agentId: subscription.agentId,
          eventId: eventId,
          role: latestMessage.role == MessageRole.user ? 'user' : 'assistant',
          content: latestMessage.content,
          isPartial: true,
        );
        _eventsController.add(event);
      }

      subscription.lastMessageCount = currentMessageCount;
      subscription.lastContentLength = currentContentLength;
    }
    // Same message, content grew (streaming delta)
    else if (currentContentLength > subscription.lastContentLength) {
      final delta = latestMessage.content.substring(
        subscription.lastContentLength,
      );
      if (delta.isNotEmpty) {
        final eventId =
            _currentMessageEventIds[subscription.agentId] ?? const Uuid().v4();
        final event = interface_.MessageEvent(
          timestamp: DateTime.now(),
          agentId: subscription.agentId,
          eventId: eventId,
          role: latestMessage.role == MessageRole.user ? 'user' : 'assistant',
          content: delta,
          isPartial: true,
        );
        _eventsController.add(event);
      }
      subscription.lastContentLength = currentContentLength;
    }

    // Always check for new tool events
    _sendToolEvents(latestMessage, subscription);

    // Check for errors
    if (conversation.currentError != null) {
      final event = interface_.ErrorEvent(
        timestamp: DateTime.now(),
        agentId: subscription.agentId,
        code: 'AGENT_ERROR',
        message: conversation.currentError!,
      );
      _eventsController.add(event);
    }
  }

  void _sendToolEvents(
    ConversationMessage message,
    _AgentSubscription subscription,
  ) {
    final responses = message.responses;
    final startIndex = subscription.lastResponseCount;

    // Only process new responses (those after lastResponseCount)
    for (int i = startIndex; i < responses.length; i++) {
      final response = responses[i];
      if (response is ToolUseResponse) {
        final toolId = response.toolUseId ?? const Uuid().v4();
        subscription.toolNamesByUseId[toolId] = response.toolName;
        final event = interface_.ToolUseEvent(
          timestamp: DateTime.now(),
          agentId: subscription.agentId,
          toolId: toolId,
          toolName: response.toolName,
          input: response.parameters,
        );
        _eventsController.add(event);
      } else if (response is ToolResultResponse) {
        final event = interface_.ToolResultEvent(
          timestamp: DateTime.now(),
          agentId: subscription.agentId,
          toolId: response.toolUseId,
          output: response.content,
          isError: response.isError,
        );
        _eventsController.add(event);
      }
    }

    // Update the count to mark all responses as processed
    subscription.lastResponseCount = responses.length;
  }

  /// Map vide_core AgentStatus to vide_interface AgentStatus.
  interface_.AgentStatus _mapAgentStatusToInterface(AgentStatus status) {
    return switch (status) {
      AgentStatus.working => interface_.AgentStatus.working,
      AgentStatus.waitingForAgent => interface_.AgentStatus.waitingForAgent,
      AgentStatus.waitingForUser => interface_.AgentStatus.waitingForUser,
      AgentStatus.idle => interface_.AgentStatus.idle,
    };
  }

  void _emitError(String message, {String? code}) {
    final event = interface_.ErrorEvent(
      timestamp: DateTime.now(),
      agentId: null,
      code: code ?? 'ERROR',
      message: message,
    );
    _eventsController.add(event);
  }

  @override
  void send(interface_.ClientMessage message) {
    switch (message) {
      case interface_.SendUserMessage msg:
        _handleUserMessage(msg);
      case interface_.PermissionResponse msg:
        _handlePermissionResponse(msg);
      case interface_.AbortRequest _:
        _handleAbort();
    }
  }

  void _handleUserMessage(interface_.SendUserMessage msg) {
    final network =
        _container.read(agentNetworkManagerProvider).currentNetwork;
    if (network == null || network.id != sessionId) {
      _emitError('Session not active', code: 'NOT_FOUND');
      return;
    }

    // Send to main agent
    final mainAgentId = network.agents.first.id;
    final manager = _container.read(agentNetworkManagerProvider.notifier);
    manager.sendMessage(mainAgentId, Message.text(msg.content));
  }

  void _handlePermissionResponse(interface_.PermissionResponse msg) {
    // Direct transport delegates permission handling to the consumer
    // via the onPermissionRequest callback. The consumer is expected to
    // call back into whatever permission system they're using.
    // For now, log that we received it - actual handling depends on
    // the permission infrastructure being used.
    print(
      '[DirectSessionTransport] Permission response received: ${msg.requestId} = ${msg.allow}',
    );
  }

  void _handleAbort() {
    final network =
        _container.read(agentNetworkManagerProvider).currentNetwork;
    if (network == null || network.id != sessionId) return;

    // Abort all agents
    final claudeClients = _container.read(claudeManagerProvider);
    for (final agent in network.agents) {
      final client = claudeClients[agent.id];
      if (client != null) {
        client.abort();
        final event = interface_.AbortedEvent(
          timestamp: DateTime.now(),
          agentId: agent.id,
        );
        _eventsController.add(event);
      }
    }
  }

  @override
  Future<void> close() async {
    _networkSubscription?.close();
    for (final subscription in _agentSubscriptions.values) {
      subscription.cancel();
    }
    _agentSubscriptions.clear();

    _currentState = interface_.ConnectionState.disconnected;
    _connectionStateController.add(_currentState);

    await _eventsController.close();
    await _connectionStateController.close();
  }
}

/// Tracks subscription state for a single agent.
class _AgentSubscription {
  final String agentId;

  StreamSubscription<Conversation>? conversationSubscription;
  StreamSubscription<void>? turnCompleteSubscription;
  ProviderSubscription<AgentStatus>? statusSubscription;

  int lastMessageCount = 0;
  int lastContentLength = 0;
  int lastResponseCount = 0;

  final Map<String, String> toolNamesByUseId = {};

  _AgentSubscription({required this.agentId});

  void cancel() {
    conversationSubscription?.cancel();
    turnCompleteSubscription?.cancel();
    statusSubscription?.close();
  }
}
