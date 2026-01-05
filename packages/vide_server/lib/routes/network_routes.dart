/// Network routes for agent network management.
///
/// Error Response Formats:
/// - HTTP endpoints return JSON: `{"error": "message"}`
/// - WebSocket streams use SSEEvent: `{"type": "error", "data": {"message": "..."}}`
///
/// This difference is intentional - HTTP uses standard REST conventions while
/// WebSocket uses our structured event format for consistency with other events.
import 'dart:async' show StreamSubscription;
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:riverpod/riverpod.dart';
import 'package:logging/logging.dart';
import 'package:vide_core/models/agent_network.dart';
import 'package:vide_core/services/agent_network_manager.dart';
import 'package:vide_core/services/claude_manager.dart';
import 'package:claude_sdk/claude_sdk.dart';
import '../dto/network_dto.dart';
import '../services/network_cache_manager.dart';

final _log = Logger('NetworkRoutes');

/// Bundles common agent metadata used in SSE events.
class _AgentContext {
  final String agentId;
  final String agentType;
  final String? agentName;
  final String? taskName;
  final WebSocketChannel channel;

  /// Maps toolUseId to toolName for correlating tool results with their invocations
  final Map<String, String> _toolNamesByUseId = {};

  _AgentContext({
    required this.agentId,
    required this.agentType,
    this.agentName,
    this.taskName,
    required this.channel,
  });

  /// Send tool use and tool result events for a message's responses
  void sendToolEvents(ConversationMessage message) {
    for (final response in message.responses) {
      if (response is ToolUseResponse) {
        // Track tool name by use ID for later result correlation
        if (response.toolUseId != null) {
          _toolNamesByUseId[response.toolUseId!] = response.toolName;
        }
        final event = SSEEvent.toolUse(
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          taskName: taskName,
          toolName: response.toolName,
          toolInput: response.parameters,
        );
        channel.sink.add(jsonEncode(event.toJson()));
      } else if (response is ToolResultResponse) {
        // Look up the tool name from the original tool_use event
        final toolName = _toolNamesByUseId[response.toolUseId] ?? 'unknown';
        final event = SSEEvent.toolResult(
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          taskName: taskName,
          toolName: toolName,
          result: response.content,
          isError: response.isError,
        );
        channel.sink.add(jsonEncode(event.toJson()));
      }
    }
  }

  /// Send an error event if conversation has an error
  void sendErrorIfPresent(Conversation conversation) {
    if (conversation.currentError != null) {
      final event = SSEEvent.error(
        agentId: agentId,
        agentType: agentType,
        agentName: agentName,
        taskName: taskName,
        message: conversation.currentError!,
      );
      channel.sink.add(jsonEncode(event.toJson()));
    }
  }
}

/// Resume network if not already active
///
/// Returns true if network was resumed, false if already active.
Future<bool> _ensureNetworkActive(
  ProviderContainer container,
  AgentNetworkManager manager,
  AgentNetwork network,
) async {
  final currentNetwork = container
      .read(agentNetworkManagerProvider)
      .currentNetwork;
  if (currentNetwork?.id != network.id) {
    await manager.resume(network);
    return true;
  }
  return false;
}

/// Create a new agent network
Future<Response> createNetwork(
  Request request,
  ProviderContainer container,
  NetworkCacheManager cacheManager,
) async {
  try {
    _log.info('POST /networks - Creating new network');

    // Parse request body
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final req = CreateNetworkRequest.fromJson(json);

    final messagePreview = req.initialMessage.length > 50
        ? '${req.initialMessage.substring(0, 50)}...'
        : req.initialMessage;
    _log.fine(
      'Request: initialMessage="$messagePreview", workingDirectory="${req.workingDirectory}"',
    );

    // Validate working directory
    if (req.workingDirectory.trim().isEmpty) {
      _log.warning('Invalid request: workingDirectory is empty');
      return Response.badRequest(
        body: jsonEncode({'error': 'workingDirectory is required'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Canonicalize and verify directory exists
    final canonicalPath = p.canonicalize(req.workingDirectory);
    final dir = Directory(canonicalPath);
    if (!await dir.exists()) {
      _log.warning(
        'Invalid request: workingDirectory does not exist: $canonicalPath',
      );
      return Response.badRequest(
        body: jsonEncode({
          'error': 'workingDirectory does not exist: $canonicalPath',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Validate initialMessage is not empty
    if (req.initialMessage.trim().isEmpty) {
      _log.warning('Invalid request: initialMessage is empty');
      return Response.badRequest(
        body: jsonEncode({'error': 'initialMessage is required'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Create the network immediately (like TUI does)
    final manager = container.read(agentNetworkManagerProvider.notifier);
    final network = await manager.startNew(
      Message.text(req.initialMessage),
      workingDirectory: canonicalPath,
    );

    _log.info('Network created: ${network.id}');

    // Cache the network for later retrieval
    cacheManager.cacheNetwork(network);

    final mainAgent = network.agents.first;
    final response = CreateNetworkResponse(
      networkId: network.id,
      mainAgentId: mainAgent.id,
      createdAt: network.createdAt,
    );

    _log.info(
      'Response sent: networkId=${network.id}, mainAgentId=${mainAgent.id}',
    );
    return Response.ok(
      response.toJsonString(),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e, stack) {
    _log.severe('Error creating network', e, stack);
    return Response.internalServerError(
      body: jsonEncode({'error': 'Failed to create network: $e'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

/// Send a message to an agent network
Future<Response> sendMessage(
  Request request,
  String networkId,
  ProviderContainer container,
  NetworkCacheManager cacheManager,
) async {
  try {
    _log.info('[sendMessage] POST /messages - networkId=$networkId');

    // Parse request body
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final req = SendMessageRequest.fromJson(json);

    final preview = req.content.length > 50
        ? '${req.content.substring(0, 50)}...'
        : req.content;
    _log.info('[sendMessage] Message content: "$preview"');

    // Load network from cache or persistence
    var network = await cacheManager.getNetwork(networkId);
    if (network == null) {
      _log.warning('[sendMessage] Network not found: $networkId');
      return Response.notFound(
        jsonEncode({'error': 'Network not found'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
    _log.fine('[sendMessage] Network loaded: ${network.id}');

    // Resume network if not already active
    final manager = container.read(agentNetworkManagerProvider.notifier);
    final wasResumed = await _ensureNetworkActive(container, manager, network);
    if (wasResumed) {
      _log.info('[sendMessage] Network resumed: $networkId');
    } else {
      _log.fine('[sendMessage] Network already active');
    }

    // Get main agent (first agent)
    final mainAgent = network.agents.first;
    _log.info('[sendMessage] Sending message to agent: ${mainAgent.id}');

    // Send message to main agent
    manager.sendMessage(mainAgent.id, Message.text(req.content));
    _log.info('[sendMessage] Message sent to AgentNetworkManager');

    return Response.ok(
      jsonEncode({'status': 'sent', 'agentId': mainAgent.id}),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e, stack) {
    _log.severe('[sendMessage] Error: $e', e, stack);
    return Response.internalServerError(
      body: jsonEncode({'error': 'Failed to send message: $e'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

/// Stream agent conversation via WebSocket
Handler streamAgentWebSocket(
  String networkId,
  String agentId,
  ProviderContainer container,
  NetworkCacheManager cacheManager,
) {
  return webSocketHandler((WebSocketChannel channel, String? protocol) {
    _log.info(
      '[WebSocket] Client connected for networkId=$networkId, agentId=$agentId',
    );

    // Send welcome message
    channel.sink.add(
      jsonEncode({
        'type': 'connected',
        'networkId': networkId,
        'agentId': agentId,
      }),
    );

    // Start agent stream setup (async operation continues in background)
    _setupAgentWebSocket(
      channel,
      networkId,
      agentId,
      container,
      cacheManager,
    ).catchError((error, stack) {
      _log.severe('[WebSocket] Setup error: $error', error, stack);
      channel.sink.add(
        jsonEncode({
          'type': 'error',
          'message': 'Failed to setup stream: $error',
        }),
      );
      channel.sink.close();
    });
  });
}

/// Set up the WebSocket stream for an agent
Future<void> _setupAgentWebSocket(
  WebSocketChannel channel,
  String networkId,
  String agentId,
  ProviderContainer container,
  NetworkCacheManager cacheManager,
) async {
  try {
    _log.info(
      'GET /stream - Setting up WebSocket for networkId=$networkId, agentId=$agentId',
    );

    final manager = container.read(agentNetworkManagerProvider.notifier);

    // Load existing network (should already exist from POST /networks)
    final network = await cacheManager.getNetwork(networkId);
    if (network == null) {
      _log.warning('Network not found: $networkId');
      final errorEvent = SSEEvent.error(
        agentId: agentId,
        agentType: 'unknown',
        message: 'Network not found - create it first via POST /networks',
      );
      channel.sink.add(jsonEncode(errorEvent.toJson()));
      await channel.sink.close();
      return;
    }

    _log.info('Network loaded from cache: ${network.id}');

    // Resume network if not already active
    final wasResumed = await _ensureNetworkActive(container, manager, network);
    if (wasResumed) {
      _log.info('Network resumed: ${network.id}');
    } else {
      _log.fine('Network already active');
    }

    // Find agent metadata
    _log.fine('Looking up agent metadata for agentId=$agentId');
    final agentMetadata = network.agents
        .where((a) => a.id == agentId)
        .firstOrNull;

    if (agentMetadata == null) {
      _log.warning('Agent not found in network: $agentId');
      final errorEvent = SSEEvent.error(
        agentId: agentId,
        agentType: 'unknown',
        message: 'Agent not found in network',
      );
      channel.sink.add(jsonEncode(errorEvent.toJson()));
      await channel.sink.close();
      return;
    }
    _log.info(
      'Agent metadata found: ${agentMetadata.name} (${agentMetadata.type})',
    );

    // Get Claude client for this agent
    _log.fine('Getting Claude client for agent: $agentId');
    final claudeClient = container.read(claudeProvider(agentMetadata.id));
    if (claudeClient == null) {
      _log.warning('Claude client not initialized for agent: $agentId');
      final errorEvent = SSEEvent.error(
        agentId: agentId,
        agentType: agentMetadata.type,
        agentName: agentMetadata.name,
        message: 'Claude client not initialized for agent',
      );
      channel.sink.add(jsonEncode(errorEvent.toJson()));
      await channel.sink.close();
      return;
    }
    _log.info('Claude client found for agent');

    // Brief delay to ensure WebSocket stream listener is attached before sending.
    // Without this, the first event can be missed by clients that connect and
    // immediately start listening in the same event loop iteration.
    await Future.delayed(const Duration(milliseconds: 10));

    final statusEvent = SSEEvent.status(
      agentId: agentId,
      agentType: agentMetadata.type,
      agentName: agentMetadata.name,
      taskName: agentMetadata.taskName,
      status: 'connected',
    );
    final statusJson = jsonEncode(statusEvent.toJson());
    _log.fine('Sending status event: $statusJson');
    channel.sink.add(statusJson);
    _log.fine('Status event sent successfully');

    // Track streaming state to send only deltas - use a state object for
    // immediate in-place updates to prevent race conditions with rapid updates
    final state = _StreamingState();

    // Create agent context for event helpers
    final ctx = _AgentContext(
      agentId: agentId,
      agentType: agentMetadata.type,
      agentName: agentMetadata.name,
      taskName: agentMetadata.taskName,
      channel: channel,
    );

    // Declare subscriptions as nullable for proper cleanup handling
    StreamSubscription<Conversation>? conversationSubscription;
    StreamSubscription<void>? turnCompleteSubscription;

    // Helper to clean up subscriptions safely
    void cleanupSubscriptions() {
      conversationSubscription?.cancel();
      turnCompleteSubscription?.cancel();
    }

    // Send current conversation state to catch up (if any messages exist)
    final currentConv = claudeClient.currentConversation;
    if (currentConv.messages.isNotEmpty) {
      _log.fine(
        'Sending current conversation state (${currentConv.messages.length} messages)',
      );
      _sendFullConversationState(currentConv, ctx);
      // Update tracking after sending full state
      state.lastMessageCount = currentConv.messages.length;
      state.lastContentLength = currentConv.messages.last.content.length;
    }

    conversationSubscription = claudeClient.conversation.listen(
      (conversation) {
        _log.info(
          '[WebSocket] Conversation update received: ${conversation.messages.length} messages',
        );
        _handleConversationUpdate(conversation, ctx, state);
      },
      onError: (error) {
        _log.warning('Conversation stream error: $error');
        final errorEvent = SSEEvent.error(
          agentId: ctx.agentId,
          agentType: ctx.agentType,
          agentName: ctx.agentName,
          taskName: ctx.taskName,
          message: error.toString(),
        );
        ctx.channel.sink.add(jsonEncode(errorEvent.toJson()));
      },
      onDone: () {
        _log.info('[WebSocket] Conversation stream done');
        ctx.channel.sink.close();
      },
    );

    // Subscribe to turn complete events
    turnCompleteSubscription = claudeClient.onTurnComplete.listen((_) {
      _log.info(
        '[WebSocket] Turn complete event received! Sending done event to client',
      );
      final doneEvent = SSEEvent.done(
        agentId: ctx.agentId,
        agentType: ctx.agentType,
        agentName: ctx.agentName,
        taskName: ctx.taskName,
      );
      ctx.channel.sink.add(jsonEncode(doneEvent.toJson()));
      _log.info('[WebSocket] Done event sent to client');
    });

    // Listen for client disconnect to clean up subscriptions.
    // Note: Client-to-server messages are not currently handled - use the
    // POST /networks/{id}/messages endpoint to send messages to agents.
    channel.stream.listen(
      (message) {
        _log.fine('[WebSocket] Received from client (ignored): $message');
      },
      onDone: () {
        _log.info(
          '[WebSocket] Client disconnected - cleaning up subscriptions',
        );
        cleanupSubscriptions();
      },
      onError: (error) {
        _log.warning('[WebSocket] Client stream error: $error');
        cleanupSubscriptions();
      },
    );
  } catch (e, stack) {
    _log.severe('[_setupAgentWebSocket] Error: $e', e, stack);
    final errorEvent = SSEEvent.error(
      agentId: agentId,
      agentType: 'unknown',
      message: 'Stream setup failed: $e',
      stack: stack.toString(),
    );
    channel.sink.add(jsonEncode(errorEvent.toJson()));
    await channel.sink.close();
  }
}

/// Send full conversation state (all messages) - used when catching up on existing conversation
void _sendFullConversationState(Conversation conversation, _AgentContext ctx) {
  if (conversation.messages.isEmpty) {
    return;
  }

  _log.info(
    '[_sendFullConversationState] Sending ${conversation.messages.length} messages',
  );

  // Send ALL messages in order
  for (var i = 0; i < conversation.messages.length; i++) {
    final message = conversation.messages[i];
    // Send message event for user or assistant messages
    if (message.content.isNotEmpty) {
      _log.info(
        '[_sendFullConversationState] Sending message $i: role=${message.role}, contentLength=${message.content.length}',
      );
      final messageEvent = SSEEvent.message(
        agentId: ctx.agentId,
        agentType: ctx.agentType,
        agentName: ctx.agentName,
        taskName: ctx.taskName,
        content: message.content,
        role: message.role == MessageRole.user ? 'user' : 'assistant',
      );
      ctx.channel.sink.add(jsonEncode(messageEvent.toJson()));
    }

    // Send tool use events
    ctx.sendToolEvents(message);
  }

  // Send error event if conversation has an error
  ctx.sendErrorIfPresent(conversation);
}

/// Mutable state object for tracking streaming progress.
/// Using a class ensures state updates are immediately visible to all readers,
/// preventing race conditions when multiple conversation updates arrive rapidly.
class _StreamingState {
  int lastMessageCount = 0;
  int lastContentLength = 0;
}

/// Handle conversation updates and convert to WebSocket events (streaming deltas)
void _handleConversationUpdate(
  Conversation conversation,
  _AgentContext ctx,
  _StreamingState state,
) {
  _log.fine(
    '[_handleConversationUpdate] Called with ${conversation.messages.length} messages',
  );

  // Get the latest message
  if (conversation.messages.isEmpty) {
    _log.fine('[_handleConversationUpdate] No messages, returning');
    return;
  }

  final currentMessageCount = conversation.messages.length;
  final latestMessage = conversation.messages.last;
  final currentContentLength = latestMessage.content.length;

  _log.fine(
    '[_handleConversationUpdate] lastMessageCount=${state.lastMessageCount}, currentMessageCount=$currentMessageCount',
  );
  _log.fine(
    '[_handleConversationUpdate] lastContentLength=${state.lastContentLength}, currentContentLength=$currentContentLength',
  );

  // Track whether we detected a new message (for tool use events below)
  var isNewMessage = false;

  // New message started - send full content
  if (currentMessageCount > state.lastMessageCount) {
    isNewMessage = true;
    _log.fine(
      '[_handleConversationUpdate] NEW MESSAGE: role=${latestMessage.role}, contentLength=$currentContentLength',
    );
    if (latestMessage.content.isNotEmpty) {
      final messageEvent = SSEEvent.message(
        agentId: ctx.agentId,
        agentType: ctx.agentType,
        agentName: ctx.agentName,
        taskName: ctx.taskName,
        content: latestMessage.content,
        role: latestMessage.role == MessageRole.user ? 'user' : 'assistant',
      );
      _log.info(
        '[_handleConversationUpdate] Sending message event to WebSocket: role=${latestMessage.role}',
      );
      ctx.channel.sink.add(jsonEncode(messageEvent.toJson()));
    }
    // Update state IMMEDIATELY after determining what to send
    state.lastMessageCount = currentMessageCount;
    state.lastContentLength = currentContentLength;
    _log.fine(
      '[WebSocket] Updated state: messageCount=${state.lastMessageCount}, contentLength=${state.lastContentLength}',
    );
  }
  // Same message, but content grew - send only the delta (streaming chunk)
  else if (currentContentLength > state.lastContentLength) {
    final delta = latestMessage.content.substring(state.lastContentLength);
    _log.fine('[_handleConversationUpdate] DELTA: ${delta.length} chars');
    if (delta.isNotEmpty) {
      final deltaEvent = SSEEvent.messageDelta(
        agentId: ctx.agentId,
        agentType: ctx.agentType,
        agentName: ctx.agentName,
        taskName: ctx.taskName,
        delta: delta,
        role: latestMessage.role == MessageRole.user ? 'user' : 'assistant',
      );
      _log.fine('[_handleConversationUpdate] Sending delta event to WebSocket');
      ctx.channel.sink.add(jsonEncode(deltaEvent.toJson()));
    }
    // Update state IMMEDIATELY after determining what to send
    state.lastMessageCount = currentMessageCount;
    state.lastContentLength = currentContentLength;
    _log.fine(
      '[WebSocket] Updated state: messageCount=${state.lastMessageCount}, contentLength=${state.lastContentLength}',
    );
  }

  // Send tool use events (only if new message detected above)
  if (isNewMessage) {
    ctx.sendToolEvents(latestMessage);
  }

  // Send error event if conversation has an error
  ctx.sendErrorIfPresent(conversation);
}
