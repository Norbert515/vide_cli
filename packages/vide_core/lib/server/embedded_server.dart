/// Embedded HTTP/WebSocket server for remote client connections.
///
/// This server can be started on-demand to allow remote clients to connect
/// to an existing session and view/interact with it.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:riverpod/riverpod.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:uuid/uuid.dart';
import 'package:vide_interface/vide_interface.dart' as interface_;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../transport/direct_session_transport.dart';
import 'join_request.dart';

// Use ConnectedClient from vide_interface (private to avoid export conflict)
typedef _ConnectedClient = interface_.ConnectedClient;

/// An HTTP/WebSocket server that can be started on-demand to allow remote
/// clients to connect to a session.
///
/// The server integrates with the existing [DirectSessionTransport] to
/// forward events to remote clients. Join requests must be explicitly
/// approved or denied via [respondToJoinRequest].
class EmbeddedServer {
  EmbeddedServer({
    required ProviderContainer container,
    required String sessionId,
  })  : _container = container,
        _sessionId = sessionId;

  final ProviderContainer _container;
  final String _sessionId;

  /// The underlying HTTP server.
  HttpServer? _server;

  /// Transport for the session (created on start).
  DirectSessionTransport? _transport;

  /// Subscription to the transport's event stream.
  StreamSubscription<interface_.SessionEvent>? _transportSubscription;

  /// Connected clients indexed by their ID.
  final Map<String, _ClientConnection> _clients = {};

  /// Pending join requests indexed by request ID.
  final Map<String, _PendingJoinRequest> _pendingRequests = {};

  /// Stream controller for join requests.
  final _joinRequestsController = StreamController<JoinRequest>.broadcast();

  /// Whether the server is currently running.
  bool get isRunning => _server != null;

  /// Connected remote clients.
  List<_ConnectedClient> get clients =>
      _clients.values.map((c) => c.toConnectedClient()).toList();

  /// Stream of join requests from new clients.
  /// UI should listen to this and call [respondToJoinRequest].
  Stream<JoinRequest> get joinRequests => _joinRequestsController.stream;

  /// Start accepting remote connections.
  ///
  /// Returns server info (address, port) on success.
  /// If [port] is null or 0, a random available port will be used.
  Future<interface_.ServerInfo> start({int? port}) async {
    if (_server != null) {
      throw StateError('Server is already running');
    }

    // Create and initialize the transport
    _transport = DirectSessionTransport(
      sessionId: _sessionId,
      container: _container,
    );
    await _transport!.initialize();

    // Subscribe to transport events
    _transportSubscription = _transport!.events.listen(_broadcastEvent);

    // Build the shelf handler
    final handler = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addHandler(_router);

    // Start the HTTP server
    _server = await shelf_io.serve(
      handler,
      InternetAddress.loopbackIPv4,
      port ?? 0,
    );

    return interface_.ServerInfo(
      address: _server!.address.host,
      port: _server!.port,
    );
  }

  /// Stop server and disconnect all clients.
  Future<void> stop() async {
    // Cancel pending requests (copy to avoid concurrent modification)
    final pendingToCancel = List.of(_pendingRequests.values);
    _pendingRequests.clear();
    for (final pending in pendingToCancel) {
      pending.completer.complete(JoinResponse.deny);
    }

    // Disconnect all clients (copy to avoid concurrent modification)
    final clientsToClose = List.of(_clients.values);
    _clients.clear();
    for (final client in clientsToClose) {
      await client.channel.sink.close();
    }

    // Cancel transport subscription
    await _transportSubscription?.cancel();
    _transportSubscription = null;

    // Close the transport
    await _transport?.close();
    _transport = null;

    // Close the server
    await _server?.close();
    _server = null;

    // Close the join requests stream
    await _joinRequestsController.close();
  }

  /// Approve or deny a join request.
  Future<void> respondToJoinRequest(
    String requestId,
    JoinResponse response,
  ) async {
    final pending = _pendingRequests.remove(requestId);
    if (pending == null) {
      return; // Request already handled or doesn't exist
    }
    pending.completer.complete(response);
  }

  /// Route handler for the shelf server.
  FutureOr<shelf.Response> _router(shelf.Request request) {
    final path = request.url.path;

    // WebSocket upgrade for session streaming
    if (path == 'ws' || path == 'api/v1/sessions/$_sessionId/stream') {
      return _handleWebSocketUpgrade(request);
    }

    // Health check endpoint
    if (path == 'health' && request.method == 'GET') {
      return shelf.Response.ok(
        jsonEncode({'status': 'ok'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    return shelf.Response.notFound('Not found');
  }

  /// Handle WebSocket upgrade requests.
  FutureOr<shelf.Response> _handleWebSocketUpgrade(shelf.Request request) {
    return webSocketHandler((WebSocketChannel channel, String? protocol) async {
      final clientId = const Uuid().v4();
      final remoteAddress =
          request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
      final address = remoteAddress?.remoteAddress.address ?? 'unknown';

      // Create join request
      final requestId = const Uuid().v4();
      final joinRequest = JoinRequest(
        id: requestId,
        remoteAddress: address,
        requestedAt: DateTime.now(),
      );

      // Create completer for the response
      final completer = Completer<JoinResponse>();
      _pendingRequests[requestId] = _PendingJoinRequest(
        request: joinRequest,
        channel: channel,
        clientId: clientId,
        completer: completer,
      );

      // Emit join request for UI to handle
      _joinRequestsController.add(joinRequest);

      // Wait for response
      final response = await completer.future;

      // Handle based on response
      if (response == JoinResponse.deny) {
        channel.sink.add(jsonEncode({
          'type': 'error',
          'code': 'ACCESS_DENIED',
          'message': 'Connection request denied',
        }));
        await channel.sink.close();
        return;
      }

      // Client approved - add to connected clients
      final clientConnection = _ClientConnection(
        id: clientId,
        remoteAddress: address,
        permission: response,
        connectedAt: DateTime.now(),
        channel: channel,
      );
      _clients[clientId] = clientConnection;

      // Send connected event to the client
      final transport = _transport;
      if (transport != null) {
        // Get current session info from transport's last connected event
        // For now, send a simple connected acknowledgment
        channel.sink.add(jsonEncode({
          'type': 'connected',
          'timestamp': DateTime.now().toIso8601String(),
          'client-id': clientId,
          'permission': response.name,
        }));
      }

      // Emit client-joined event to all clients
      _broadcastEvent(interface_.ClientJoinedEvent(
        timestamp: DateTime.now(),
        clientId: clientId,
        remoteAddress: address,
      ));

      // Listen to client messages
      channel.stream.listen(
        (message) => _handleClientMessage(clientId, message),
        onDone: () => _handleClientDisconnect(clientId),
        onError: (_) => _handleClientDisconnect(clientId),
      );
    })(request);
  }

  /// Broadcast an event to all connected clients.
  void _broadcastEvent(interface_.SessionEvent event) {
    final json = jsonEncode(event.toJson());
    for (final client in _clients.values) {
      client.channel.sink.add(json);
    }
  }

  /// Handle a message from a connected client.
  void _handleClientMessage(String clientId, dynamic message) {
    final client = _clients[clientId];
    if (client == null) return;

    // Check if client has permission to send messages
    if (client.permission == JoinResponse.allowReadOnly) {
      // Read-only clients cannot send messages
      client.channel.sink.add(jsonEncode({
        'type': 'error',
        'code': 'PERMISSION_DENIED',
        'message': 'Read-only clients cannot send messages',
      }));
      return;
    }

    // Parse and forward to transport
    try {
      final json = jsonDecode(message as String) as Map<String, dynamic>;
      final clientMessage = interface_.ClientMessage.fromJson(json);

      // Forward to transport
      _transport?.send(clientMessage);
    } catch (e) {
      client.channel.sink.add(jsonEncode({
        'type': 'error',
        'code': 'INVALID_MESSAGE',
        'message': 'Failed to parse message: $e',
      }));
    }
  }

  /// Handle client disconnection.
  void _handleClientDisconnect(String clientId) {
    final client = _clients.remove(clientId);
    if (client == null) return;

    // Emit client-left event
    _broadcastEvent(interface_.ClientLeftEvent(
      timestamp: DateTime.now(),
      clientId: clientId,
    ));
  }
}

/// Internal class for tracking a connected client.
class _ClientConnection {
  final String id;
  final String remoteAddress;
  final JoinResponse permission;
  final DateTime connectedAt;
  final WebSocketChannel channel;

  _ClientConnection({
    required this.id,
    required this.remoteAddress,
    required this.permission,
    required this.connectedAt,
    required this.channel,
  });

  _ConnectedClient toConnectedClient() => _ConnectedClient(
        id: id,
        remoteAddress: remoteAddress,
        permission: _mapPermission(permission),
        connectedAt: connectedAt,
      );

  interface_.ClientPermission _mapPermission(JoinResponse response) {
    return switch (response) {
      JoinResponse.allow => interface_.ClientPermission.interact,
      JoinResponse.allowReadOnly => interface_.ClientPermission.view,
      JoinResponse.deny => interface_.ClientPermission.view, // Should not happen
    };
  }
}

/// Internal class for tracking pending join requests.
class _PendingJoinRequest {
  final JoinRequest request;
  final WebSocketChannel channel;
  final String clientId;
  final Completer<JoinResponse> completer;

  _PendingJoinRequest({
    required this.request,
    required this.channel,
    required this.clientId,
    required this.completer,
  });
}
