import 'dart:async';
import 'dart:convert';

import 'package:vide_interface/vide_interface.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocket implementation of [SessionTransport].
///
/// Connects to a vide server's WebSocket endpoint and provides typed
/// event streaming and message sending.
///
/// ## Reconnection
///
/// The transport supports automatic reconnection with exponential backoff.
/// Use [connectionState] to monitor connection status changes.
///
/// ## Usage
///
/// ```dart
/// final transport = WebSocketSessionTransport(
///   uri: Uri.parse('ws://localhost:8080/api/v1/sessions/abc/stream'),
///   sessionId: 'abc',
/// );
///
/// // Connect
/// await transport.connect();
///
/// // Listen for events
/// transport.events.listen((event) => print(event));
///
/// // Send messages
/// transport.send(SendUserMessage(content: 'Hello'));
///
/// // Close
/// await transport.close();
/// ```
class WebSocketSessionTransport implements SessionTransport {
  /// Creates a new WebSocket transport.
  ///
  /// The [uri] should be the full WebSocket URL including the session ID.
  /// The [sessionId] is used for the [SessionTransport.sessionId] getter.
  WebSocketSessionTransport({
    required Uri uri,
    required String sessionId,
    Duration initialReconnectDelay = const Duration(milliseconds: 500),
    Duration maxReconnectDelay = const Duration(seconds: 30),
    int maxReconnectAttempts = 10,
  })  : _uri = uri,
        _sessionId = sessionId,
        _initialReconnectDelay = initialReconnectDelay,
        _maxReconnectDelay = maxReconnectDelay,
        _maxReconnectAttempts = maxReconnectAttempts;

  final Uri _uri;
  final String _sessionId;
  final Duration _initialReconnectDelay;
  final Duration _maxReconnectDelay;
  final int _maxReconnectAttempts;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  final _eventController = StreamController<SessionEvent>.broadcast();
  final _connectionStateController =
      StreamController<ConnectionState>.broadcast();
  ConnectionState _currentState = ConnectionState.disconnected;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  bool _closed = false;

  @override
  String get sessionId => _sessionId;

  @override
  Stream<SessionEvent> get events => _eventController.stream;

  @override
  Stream<ConnectionState> get connectionState =>
      _connectionStateController.stream;

  @override
  ConnectionState get currentState => _currentState;

  /// Connect to the WebSocket server.
  ///
  /// This is called automatically by [VideClient.connect], but can be called
  /// manually if you create the transport directly.
  Future<void> connect() async {
    if (_closed) {
      throw StateError('Transport has been closed');
    }

    _setConnectionState(ConnectionState.connecting);

    try {
      _channel = WebSocketChannel.connect(_uri);
      await _channel!.ready;

      _reconnectAttempts = 0;
      _setConnectionState(ConnectionState.connected);

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );
    } catch (e) {
      _setConnectionState(ConnectionState.disconnected);
      _scheduleReconnect();
      rethrow;
    }
  }

  void _onMessage(dynamic data) {
    try {
      final json = jsonDecode(data as String) as Map<String, dynamic>;
      final event = SessionEvent.fromJson(json);
      _eventController.add(event);
    } catch (e) {
      _eventController.addError(e);
    }
  }

  void _onError(Object error) {
    _eventController.addError(error);
    _scheduleReconnect();
  }

  void _onDone() {
    if (_closed) return;

    _setConnectionState(ConnectionState.disconnected);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_closed) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _eventController.addError(
        VideTransportException('Max reconnection attempts reached'),
      );
      return;
    }

    _setConnectionState(ConnectionState.reconnecting);

    final delay = _calculateReconnectDelay();
    _reconnectTimer = Timer(delay, () async {
      _reconnectAttempts++;
      try {
        await _cleanup();
        await connect();
      } catch (_) {
        // connect() will schedule another reconnect if needed
      }
    });
  }

  Duration _calculateReconnectDelay() {
    // Exponential backoff with jitter
    final exponentialDelay = _initialReconnectDelay *
        (1 << _reconnectAttempts.clamp(0, 10));
    final cappedDelay = exponentialDelay > _maxReconnectDelay
        ? _maxReconnectDelay
        : exponentialDelay;
    return cappedDelay;
  }

  void _setConnectionState(ConnectionState state) {
    if (_currentState == state) return;
    _currentState = state;
    _connectionStateController.add(state);
  }

  Future<void> _cleanup() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  @override
  void send(ClientMessage message) {
    if (_closed) {
      throw StateError('Transport has been closed');
    }
    if (_currentState != ConnectionState.connected) {
      throw StateError('Transport is not connected');
    }
    if (_channel == null) {
      throw StateError('WebSocket channel is not available');
    }

    final json = jsonEncode(message.toJson());
    _channel!.sink.add(json);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;

    await _cleanup();
    _setConnectionState(ConnectionState.disconnected);
    await _eventController.close();
    await _connectionStateController.close();
  }
}

/// Exception thrown by [WebSocketSessionTransport].
class VideTransportException implements Exception {
  final String message;

  VideTransportException(this.message);

  @override
  String toString() => 'VideTransportException: $message';
}
