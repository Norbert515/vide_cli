import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/session_event.dart';

/// Exception thrown when WebSocket operations fail.
class VideWebSocketException implements Exception {
  final String message;
  final Object? cause;

  VideWebSocketException(this.message, {this.cause});

  @override
  String toString() => 'VideWebSocketException: $message';
}

/// WebSocket client for streaming session events.
class VideWebSocketClient {
  final String sessionId;
  final String host;
  final int port;
  final bool isSecure;

  WebSocketChannel? _channel;
  final _eventController = StreamController<SessionEvent>.broadcast();
  StreamSubscription<dynamic>? _subscription;
  int _lastSeq = 0;

  VideWebSocketClient({
    required this.sessionId,
    required this.host,
    required this.port,
    this.isSecure = false,
  });

  void _log(String message) {
    developer.log(message, name: 'VideWebSocketClient');
  }

  /// Stream of session events.
  Stream<SessionEvent> get events => _eventController.stream;

  /// Whether the WebSocket is connected.
  bool get isConnected => _channel != null;

  /// The last sequence number received.
  int get lastSeq => _lastSeq;

  /// The WebSocket URL for this session.
  String get wsUrl {
    final protocol = isSecure ? 'wss' : 'ws';
    return '$protocol://$host:$port/api/v1/sessions/$sessionId/stream';
  }

  /// Connects to the WebSocket server.
  Future<void> connect() async {
    if (_channel != null) {
      _log('Already connected');
      return;
    }

    _log('Connecting to $wsUrl');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // Wait for connection to be ready
      await _channel!.ready;
      _log('WebSocket connected');

      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDone,
      );
    } catch (e) {
      _log('Connection error: $e');
      _channel = null;
      throw VideWebSocketException('Failed to connect', cause: e);
    }
  }

  /// Disconnects from the WebSocket server.
  void disconnect() {
    _log('Disconnecting');
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }

  /// Sends a user message to the session.
  void sendMessage(
    String content, {
    String? model,
    String? permissionMode,
  }) {
    _ensureConnected();
    _log('Sending message: $content');

    final message = <String, dynamic>{
      'type': 'user-message',
      'content': content,
    };

    if (model != null) {
      message['model'] = model;
    }
    if (permissionMode != null) {
      message['permission-mode'] = permissionMode;
    }

    _send(message);
  }

  /// Sends a permission response.
  void sendPermissionResponse(
    String requestId,
    bool allow, {
    String? message,
  }) {
    _ensureConnected();
    _log('Sending permission response: $requestId -> $allow');

    final response = <String, dynamic>{
      'type': 'permission-response',
      'request-id': requestId,
      'allow': allow,
    };

    if (message != null) {
      response['message'] = message;
    }

    _send(response);
  }

  /// Aborts all active agents.
  void abort() {
    _ensureConnected();
    _log('Sending abort');

    _send({'type': 'abort'});
  }

  void _ensureConnected() {
    if (_channel == null) {
      throw VideWebSocketException('Not connected');
    }
  }

  void _send(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode(message));
  }

  void _handleMessage(dynamic message) {
    try {
      final json = jsonDecode(message as String) as Map<String, dynamic>;
      final seq = json['seq'] as int? ?? 0;

      // Skip duplicate events on reconnect
      if (seq <= _lastSeq && seq > 0) {
        _log('Skipping duplicate event seq=$seq (lastSeq=$_lastSeq)');
        return;
      }

      if (seq > 0) {
        _lastSeq = seq;
      }

      final event = SessionEvent.fromJson(json);
      _log('Received event: ${event.runtimeType} (seq=$seq)');
      _eventController.add(event);
    } catch (e, stack) {
      _log('Error parsing message: $e');
      developer.log('Stack trace: $stack', name: 'VideWebSocketClient');
    }
  }

  void _handleError(Object error) {
    _log('WebSocket error: $error');
    _eventController.addError(VideWebSocketException('WebSocket error', cause: error));
  }

  void _handleDone() {
    _log('WebSocket closed');
    _channel = null;
    _subscription = null;
  }

  /// Disposes of resources.
  void dispose() {
    disconnect();
    _eventController.close();
  }
}
