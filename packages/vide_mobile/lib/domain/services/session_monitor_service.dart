import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vide_client/vide_client.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../data/repositories/connection_repository.dart';

part 'session_monitor_service.g.dart';

/// The type of the latest activity shown in the session card.
enum LatestActivityType { message, toolUse }

/// Represents the latest activity in a session (message or tool call).
class LatestActivity {
  final LatestActivityType type;

  /// For messages: the text content. For tools: the display name.
  final String text;

  /// For tools: a contextual subtitle (file path, command, etc).
  final String? subtitle;

  const LatestActivity({
    required this.type,
    required this.text,
    this.subtitle,
  });
}

/// A pending permission request that can be acted on from the session card.
class PendingPermission {
  final String requestId;
  final String toolName;
  final Map<String, dynamic> toolInput;
  final String? agentName;

  const PendingPermission({
    required this.requestId,
    required this.toolName,
    required this.toolInput,
    this.agentName,
  });
}

/// Live metadata derived from a session's WebSocket stream.
class SessionLiveMetadata {
  final String? latestMessage;
  final LatestActivity? latestActivity;
  final PendingPermission? pendingPermission;
  final String? taskName;
  final VideAgentStatus? mainAgentStatus;
  final int agentCount;
  final bool isConnected;

  const SessionLiveMetadata({
    this.latestMessage,
    this.latestActivity,
    this.pendingPermission,
    this.taskName,
    this.mainAgentStatus,
    this.agentCount = 1,
    this.isConnected = false,
  });

  SessionLiveMetadata copyWith({
    String? Function()? latestMessage,
    LatestActivity? Function()? latestActivity,
    PendingPermission? Function()? pendingPermission,
    String? Function()? taskName,
    VideAgentStatus? Function()? mainAgentStatus,
    int? agentCount,
    bool? isConnected,
  }) {
    return SessionLiveMetadata(
      latestMessage: latestMessage != null
          ? latestMessage()
          : this.latestMessage,
      latestActivity: latestActivity != null
          ? latestActivity()
          : this.latestActivity,
      pendingPermission: pendingPermission != null
          ? pendingPermission()
          : this.pendingPermission,
      taskName: taskName != null ? taskName() : this.taskName,
      mainAgentStatus: mainAgentStatus != null
          ? mainAgentStatus()
          : this.mainAgentStatus,
      agentCount: agentCount ?? this.agentCount,
      isConnected: isConnected ?? this.isConnected,
    );
  }
}

/// Manages a single WebSocket connection to a session for metadata monitoring.
class _SessionConnection {
  final String sessionId;
  final int port;
  final String host;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _retryTimer;
  int _retryCount = 0;
  bool _disposed = false;

  /// Main agent ID (from connected event).
  String? _mainAgentId;

  /// Track message accumulation by event-id.
  final Map<String, StringBuffer> _messageBuffers = {};

  SessionLiveMetadata _metadata = const SessionLiveMetadata();
  final StreamController<SessionLiveMetadata> _metadataController =
      StreamController<SessionLiveMetadata>.broadcast();

  Stream<SessionLiveMetadata> get metadataStream => _metadataController.stream;
  SessionLiveMetadata get metadata => _metadata;

  _SessionConnection({
    required this.sessionId,
    required this.port,
    required this.host,
  });

  void connect() {
    if (_disposed) return;
    _connectWebSocket();
  }

  void _connectWebSocket() {
    if (_disposed) return;

    final uri = Uri.parse(
      'ws://$host:$port/sessions/$sessionId/stream',
    );

    try {
      _channel = WebSocketChannel.connect(uri);
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: (_) => _handleDisconnect(),
        onDone: _handleDisconnect,
      );
    } catch (_) {
      _scheduleRetry();
    }
  }

  void _handleMessage(dynamic rawMessage) {
    if (rawMessage is! String) return;

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(rawMessage) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final type = json['type'] as String?;
    if (type == null) return;

    // Reset retry count on successful message
    _retryCount = 0;

    switch (type) {
      case 'connected':
        _handleConnected(json);
      case 'history':
        _handleHistory(json);
      case 'message':
        _handleMessageEvent(json);
      case 'tool-use':
        _handleToolUseEvent(json);
      case 'status':
        _handleStatusEvent(json);
      case 'agent-spawned':
        _handleAgentSpawned();
      case 'agent-terminated':
        _handleAgentTerminated();
      case 'permission-request':
        _handlePermissionRequest(json);
      case 'permission-resolved':
      case 'permission-timeout':
        _handlePermissionCleared();
      case 'task-name-changed':
        _handleTaskNameChanged(json);
      case 'done':
      case 'aborted':
        _handleDoneOrAborted(json);
    }
  }

  void _handleConnected(Map<String, dynamic> json) {
    _mainAgentId = json['main-agent-id'] as String?;
    final agents = json['agents'] as List<dynamic>?;
    final agentCount = agents?.length ?? 1;

    _updateMetadata(_metadata.copyWith(
      isConnected: true,
      agentCount: agentCount,
    ));
  }

  void _handleHistory(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    final events = data?['events'] as List<dynamic>? ?? [];

    // Process history to derive current state.
    // Track agent count from spawn/terminate events.
    final knownAgents = <String>{};
    String? lastAssistantMessage;
    LatestActivity? latestActivity;
    PendingPermission? pendingPermission;
    String? taskName;
    VideAgentStatus? mainStatus;

    for (final rawEvent in events) {
      if (rawEvent is! Map<String, dynamic>) continue;
      final eventType = rawEvent['type'] as String?;
      final agentId = rawEvent['agent-id'] as String? ?? '';
      final eventData = rawEvent['data'] as Map<String, dynamic>?;

      switch (eventType) {
        case 'agent-spawned':
          knownAgents.add(agentId);
        case 'agent-terminated':
          knownAgents.remove(agentId);
        case 'message':
          final role = eventData?['role'] as String?;
          final content = eventData?['content'] as String? ?? '';
          final isPartial = rawEvent['is-partial'] as bool? ?? false;
          if (role == 'assistant' && !isPartial && content.isNotEmpty) {
            lastAssistantMessage = content;
            latestActivity = LatestActivity(
              type: LatestActivityType.message,
              text: content,
            );
          } else if (role == 'user' && content.isNotEmpty) {
            latestActivity = LatestActivity(
              type: LatestActivityType.message,
              text: content,
            );
          }
        case 'tool-use':
          final toolName = eventData?['tool-name'] as String? ?? '';
          final toolInput =
              eventData?['tool-input'] as Map<String, dynamic>? ?? {};
          final displayName = _toolDisplayName(toolName);
          final subtitle = _toolSubtitle(displayName, toolInput);
          latestActivity = LatestActivity(
            type: LatestActivityType.toolUse,
            text: displayName,
            subtitle: subtitle,
          );
        case 'permission-request':
          final requestId = eventData?['request-id'] as String? ?? '';
          final toolData = eventData?['tool'] as Map<String, dynamic>?;
          final toolName = toolData?['name'] as String? ?? '';
          final toolInput =
              toolData?['input'] as Map<String, dynamic>? ?? {};
          final agentName = rawEvent['agent-name'] as String?;
          pendingPermission = PendingPermission(
            requestId: requestId,
            toolName: toolName,
            toolInput: toolInput,
            agentName: agentName,
          );
        case 'permission-resolved':
        case 'permission-timeout':
          pendingPermission = null;
        case 'task-name-changed':
          final newGoal = eventData?['new-goal'] as String?;
          if (newGoal != null && newGoal.isNotEmpty) {
            taskName = newGoal;
          }
        case 'status':
          if (agentId == _mainAgentId) {
            final statusStr = eventData?['status'] as String?;
            mainStatus = VideAgentStatus.fromWireString(statusStr);
          }
        case 'done':
        case 'aborted':
          if (agentId == _mainAgentId) {
            mainStatus = VideAgentStatus.idle;
          }
      }
    }

    // Agent count = known agents + 1 (main agent which isn't spawned)
    final agentCount = knownAgents.length + 1;

    _updateMetadata(_metadata.copyWith(
      agentCount: agentCount,
      latestMessage: lastAssistantMessage != null
          ? () => lastAssistantMessage
          : null,
      latestActivity: latestActivity != null ? () => latestActivity : null,
      pendingPermission: () => pendingPermission,
      taskName: taskName != null ? () => taskName : null,
      mainAgentStatus: mainStatus != null ? () => mainStatus : null,
    ));
  }

  void _handleMessageEvent(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    final role = data?['role'] as String?;
    final content = data?['content'] as String? ?? '';
    final isPartial = json['is-partial'] as bool? ?? false;
    final eventId = json['event-id'] as String? ?? '';

    if (role == 'assistant') {
      // Assistant messages stream as partial chunks.
      if (isPartial) {
        _messageBuffers.putIfAbsent(eventId, () => StringBuffer())
            .write(content);
      } else {
        final buffer = _messageBuffers.remove(eventId);
        final fullContent = buffer != null
            ? (buffer..write(content)).toString()
            : content;

        if (fullContent.isNotEmpty) {
          _updateMetadata(_metadata.copyWith(
            latestMessage: () => fullContent,
            latestActivity: () => LatestActivity(
              type: LatestActivityType.message,
              text: fullContent,
            ),
          ));
        }
      }
    } else if (role == 'user' && content.isNotEmpty) {
      // User messages arrive as a single event.
      _updateMetadata(_metadata.copyWith(
        latestActivity: () => LatestActivity(
          type: LatestActivityType.message,
          text: content,
        ),
      ));
    }
  }

  void _handleToolUseEvent(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    final toolName = data?['tool-name'] as String? ?? '';
    final toolInput = data?['tool-input'] as Map<String, dynamic>? ?? {};

    final displayName = _toolDisplayName(toolName);
    final subtitle = _toolSubtitle(displayName, toolInput);

    _updateMetadata(_metadata.copyWith(
      latestActivity: () => LatestActivity(
        type: LatestActivityType.toolUse,
        text: displayName,
        subtitle: subtitle,
      ),
    ));
  }

  void _handlePermissionRequest(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    final requestId = data?['request-id'] as String? ?? '';
    final toolData = data?['tool'] as Map<String, dynamic>?;
    final toolName = toolData?['name'] as String? ?? '';
    final toolInput = toolData?['input'] as Map<String, dynamic>? ?? {};
    final agentName = json['agent-name'] as String?;

    _updateMetadata(_metadata.copyWith(
      pendingPermission: () => PendingPermission(
        requestId: requestId,
        toolName: toolName,
        toolInput: toolInput,
        agentName: agentName,
      ),
    ));
  }

  void _handleTaskNameChanged(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    final newGoal = data?['new-goal'] as String?;
    if (newGoal != null && newGoal.isNotEmpty) {
      _updateMetadata(_metadata.copyWith(
        taskName: () => newGoal,
      ));
    }
  }

  void _handlePermissionCleared() {
    if (_metadata.pendingPermission != null) {
      _updateMetadata(_metadata.copyWith(
        pendingPermission: () => null,
      ));
    }
  }

  /// Strips MCP prefixes from tool names.
  static String _toolDisplayName(String toolName) {
    final mcpPrefix = RegExp(r'^mcp__[^_]+__');
    return toolName.replaceFirst(mcpPrefix, '');
  }

  /// Extracts a contextual subtitle from the tool input.
  static String? _toolSubtitle(String displayName, Map<String, dynamic> input) {
    switch (displayName) {
      case 'Read':
      case 'Edit':
      case 'Write':
        return input['file_path'] as String?;
      case 'Bash':
        return input['command'] as String?;
      case 'Grep':
        final pattern = input['pattern'] as String?;
        final path = input['path'] as String?;
        if (pattern != null && path != null) return '"$pattern" in $path';
        return pattern != null ? '"$pattern"' : null;
      case 'Glob':
        return input['pattern'] as String?;
      case 'WebFetch':
        return input['url'] as String?;
      case 'WebSearch':
        return input['query'] as String?;
      default:
        return input['file_path'] as String? ??
            input['command'] as String? ??
            input['pattern'] as String? ??
            input['description'] as String?;
    }
  }

  void _handleStatusEvent(Map<String, dynamic> json) {
    final agentId = json['agent-id'] as String? ?? '';
    if (agentId != _mainAgentId) return;

    final data = json['data'] as Map<String, dynamic>?;
    final statusStr = data?['status'] as String?;
    final status = VideAgentStatus.fromWireString(statusStr);

    _updateMetadata(_metadata.copyWith(
      mainAgentStatus: () => status,
    ));
  }

  void _handleAgentSpawned() {
    _updateMetadata(_metadata.copyWith(
      agentCount: _metadata.agentCount + 1,
    ));
  }

  void _handleAgentTerminated() {
    _updateMetadata(_metadata.copyWith(
      agentCount: (_metadata.agentCount - 1).clamp(1, 999),
    ));
  }

  void _handleDoneOrAborted(Map<String, dynamic> json) {
    final agentId = json['agent-id'] as String? ?? '';
    if (agentId != _mainAgentId) return;

    _updateMetadata(_metadata.copyWith(
      mainAgentStatus: () => VideAgentStatus.idle,
    ));
  }

  void _updateMetadata(SessionLiveMetadata newMetadata) {
    _metadata = newMetadata;
    if (!_metadataController.isClosed) {
      _metadataController.add(newMetadata);
    }
  }

  /// Send a permission response via the WebSocket.
  void respondToPermission(String requestId, {required bool allow}) {
    final channel = _channel;
    if (channel == null) return;

    channel.sink.add(jsonEncode({
      'type': 'permission-response',
      'request-id': requestId,
      'allow': allow,
    }));

    // Optimistically clear the pending permission.
    if (_metadata.pendingPermission != null) {
      _updateMetadata(_metadata.copyWith(
        pendingPermission: () => null,
      ));
    }
  }

  void _handleDisconnect() {
    if (_disposed) return;

    _updateMetadata(_metadata.copyWith(isConnected: false));
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _messageBuffers.clear();
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (_disposed) return;
    if (_retryCount >= 10) return; // Give up after 10 retries

    final delay = Duration(
      milliseconds: (1000 * (1 << _retryCount.clamp(0, 5))).clamp(1000, 30000),
    );
    _retryCount++;

    _retryTimer?.cancel();
    _retryTimer = Timer(delay, _connectWebSocket);
  }

  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _metadataController.close();
    _messageBuffers.clear();
  }
}

/// Service that eagerly connects to all active session WebSockets
/// to get live metadata (latest message, agent status, agent count).
@Riverpod(keepAlive: true)
class SessionMonitor extends _$SessionMonitor {
  final Map<String, _SessionConnection> _connections = {};
  final Map<String, StreamSubscription<SessionLiveMetadata>> _subscriptions = {};

  void _log(String message) {
    developer.log(message, name: 'SessionMonitor');
  }

  @override
  Map<String, SessionLiveMetadata> build() {
    ref.onDispose(() {
      for (final sub in _subscriptions.values) {
        sub.cancel();
      }
      _subscriptions.clear();
      for (final conn in _connections.values) {
        conn.dispose();
      }
      _connections.clear();
    });
    return const {};
  }

  /// Update the list of sessions to monitor.
  ///
  /// Connects to new sessions, disconnects from removed ones.
  void updateSessions(List<SessionSummary> sessions) {
    final connectionState = ref.read(connectionRepositoryProvider);
    final host = connectionState.connection?.host ?? '127.0.0.1';
    final daemonPort = connectionState.connection?.port ?? 0;

    final currentIds = _connections.keys.toSet();
    final newIds = sessions.map((s) => s.sessionId).toSet();

    // Remove connections for sessions that no longer exist
    final removedIds = currentIds.difference(newIds);
    for (final id in removedIds) {
      _log('Removing monitor for session $id');
      _subscriptions[id]?.cancel();
      _subscriptions.remove(id);
      _connections[id]?.dispose();
      _connections.remove(id);
    }

    // Add connections for new sessions
    for (final session in sessions) {
      if (!currentIds.contains(session.sessionId)) {
        _log('Adding monitor for session ${session.sessionId} via daemon port $daemonPort');
        final connection = _SessionConnection(
          sessionId: session.sessionId,
          port: daemonPort,
          host: host,
        );

        _connections[session.sessionId] = connection;

        _subscriptions[session.sessionId] = connection.metadataStream.listen(
          (metadata) {
            state = {...state, session.sessionId: metadata};
          },
        );

        connection.connect();
      }
    }

    // Remove metadata for sessions that no longer exist
    if (removedIds.isNotEmpty) {
      state = Map.fromEntries(
        state.entries.where((e) => newIds.contains(e.key)),
      );
    }
  }

  /// Get metadata for a specific session.
  SessionLiveMetadata? getMetadata(String sessionId) {
    return state[sessionId];
  }

  /// Respond to a permission request for a specific session.
  void respondToPermission(
    String sessionId,
    String requestId, {
    required bool allow,
  }) {
    final connection = _connections[sessionId];
    if (connection == null) {
      _log('No connection for session $sessionId to respond to permission');
      return;
    }
    connection.respondToPermission(requestId, allow: allow);
  }
}
