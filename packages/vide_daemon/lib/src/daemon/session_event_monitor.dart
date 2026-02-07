import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Event types that indicate session activity.
class SessionEventTypes {
  static const message = 'message';
  static const toolUse = 'tool-use';
  static const toolResult = 'tool-result';
  static const status = 'status';
  static const agentSpawned = 'agent-spawned';
  static const agentTerminated = 'agent-terminated';
  static const permissionRequest = 'permission-request';
  static const permissionResolved = 'permission-resolved';
  static const done = 'done';
  static const aborted = 'aborted';
  static const error = 'error';

  /// All event types that count as activity.
  static const activityEvents = {
    message,
    toolUse,
    toolResult,
    status,
    agentSpawned,
    agentTerminated,
    permissionRequest,
    permissionResolved,
    done,
    aborted,
    error,
  };

  SessionEventTypes._();
}

/// Monitors a session's WebSocket event stream to track activity and agent count.
///
/// Extracted from SessionProcess to follow Single Responsibility Principle.
/// Handles WebSocket connection lifecycle with exponential backoff reconnection.
class SessionEventMonitor {
  final String wsUrl;
  final String sessionId;
  final void Function(DateTime timestamp)? onActivity;
  final void Function(int delta)? onAgentCountChanged;
  final void Function(String type, Map<String, dynamic> event)? onEvent;

  final Logger _log;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  bool _started = false;
  bool _stopping = false;

  /// Current reconnect attempt (for exponential backoff).
  int _reconnectAttempt = 0;

  /// Maximum reconnect delay in seconds.
  static const _maxReconnectDelaySecs = 30;

  /// Base reconnect delay in seconds.
  static const _baseReconnectDelaySecs = 1;

  SessionEventMonitor({
    required this.wsUrl,
    required this.sessionId,
    this.onActivity,
    this.onAgentCountChanged,
    this.onEvent,
  }) : _log = Logger('SessionEventMonitor[$sessionId]');

  /// Whether monitoring has been started.
  bool get isStarted => _started;

  /// Start monitoring the session's event stream.
  void start() {
    if (_started) return;
    _started = true;
    _stopping = false;
    _connect();
  }

  /// Stop monitoring and clean up resources.
  void stop() {
    _stopping = true;
    _started = false;
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }

  void _connect() {
    if (_stopping) return;

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _log.fine('Connecting to event stream: $wsUrl');

      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: (error) {
          _log.warning('Event stream error: $error');
          _scheduleReconnect();
        },
        onDone: () {
          _log.fine('Event stream closed');
          _scheduleReconnect();
        },
      );

      // Reset reconnect attempt on successful connection
      _reconnectAttempt = 0;
    } catch (e) {
      _log.warning('Failed to connect to event stream: $e');
      _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final json = jsonDecode(message as String) as Map<String, dynamic>;
      final type = json['type'] as String?;

      // Notify of any event
      if (type != null) {
        onEvent?.call(type, json);
      }

      // Update activity timestamp for activity events
      if (type != null && SessionEventTypes.activityEvents.contains(type)) {
        onActivity?.call(DateTime.now());
      }

      // Track agent count changes
      if (type == SessionEventTypes.agentSpawned) {
        onAgentCountChanged?.call(1);
        _log.fine('Agent spawned');
      } else if (type == SessionEventTypes.agentTerminated) {
        onAgentCountChanged?.call(-1);
        _log.fine('Agent terminated');
      }
    } catch (e, stackTrace) {
      _log.warning(
        'Failed to parse event: $e\nMessage: $message\nStack: $stackTrace',
      );
    }
  }

  void _scheduleReconnect() {
    if (_stopping) return;

    // Clean up existing connection
    _subscription?.cancel();
    _subscription = null;
    _channel = null;

    // Calculate delay with exponential backoff
    final delaySecs = min(
      _baseReconnectDelaySecs * pow(2, _reconnectAttempt).toInt(),
      _maxReconnectDelaySecs,
    );
    _reconnectAttempt++;

    _log.fine(
      'Scheduling reconnect in ${delaySecs}s (attempt $_reconnectAttempt)',
    );

    Future.delayed(Duration(seconds: delaySecs), () {
      if (!_stopping) {
        _connect();
      }
    });
  }
}
