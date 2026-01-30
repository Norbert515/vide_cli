import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../protocol/daemon_events.dart';
import '../protocol/daemon_messages.dart';
import 'session_registry.dart';

/// HTTP/WebSocket server for daemon control and session discovery.
class DaemonServer {
  final SessionRegistry registry;
  final int port;
  final String? authToken;
  final bool bindAllInterfaces;
  final DateTime startedAt = DateTime.now();

  HttpServer? _server;
  final List<WebSocketChannel> _wsClients = [];
  StreamSubscription<DaemonEvent>? _eventSubscription;

  final Logger _log = Logger('DaemonServer');

  DaemonServer({
    required this.registry,
    required this.port,
    this.authToken,
    this.bindAllInterfaces = false,
  });

  /// Start the daemon server.
  Future<void> start() async {
    _log.info('Starting daemon server on port $port');

    // Subscribe to registry events to broadcast to WebSocket clients
    _eventSubscription = registry.events.listen(_broadcastEvent);

    final handler = _createHandler();

    final address =
        bindAllInterfaces ? InternetAddress.anyIPv4 : InternetAddress.loopbackIPv4;
    _server = await shelf_io.serve(handler, address, port);

    final host = bindAllInterfaces ? '0.0.0.0' : '127.0.0.1';
    _log.info('Daemon server listening on http://$host:$port');
  }

  /// Stop the daemon server.
  Future<void> stop() async {
    _log.info('Stopping daemon server');

    await _eventSubscription?.cancel();

    // Close all WebSocket connections
    for (final client in _wsClients) {
      await client.sink.close();
    }
    _wsClients.clear();

    await _server?.close(force: true);
    _server = null;
  }

  Handler _createHandler() {
    final router = Router();

    // Health check
    router.get('/health', _handleHealth);

    // Session management
    router.post('/sessions', _handleCreateSession);
    router.get('/sessions', _handleListSessions);
    router.get('/sessions/<sessionId>', _handleGetSession);
    router.delete('/sessions/<sessionId>', _handleStopSession);

    // WebSocket for daemon events
    router.get('/daemon', _handleDaemonWebSocket);

    // Build middleware pipeline
    final pipeline = Pipeline()
        .addMiddleware(_corsMiddleware())
        .addMiddleware(_authMiddleware())
        .addHandler(router);

    return pipeline;
  }

  Middleware _corsMiddleware() {
    return (Handler handler) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok(
            '',
            headers: {
              'Access-Control-Allow-Origin': '*',
              'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
              'Access-Control-Allow-Headers': 'Content-Type, Authorization',
            },
          );
        }

        final response = await handler(request);
        return response.change(headers: {'Access-Control-Allow-Origin': '*'});
      };
    };
  }

  Middleware _authMiddleware() {
    return (Handler handler) {
      return (Request request) async {
        // Skip auth if no token is configured
        if (authToken == null) {
          return handler(request);
        }

        // Skip auth for health check
        if (request.url.path == 'health') {
          return handler(request);
        }

        // Check Authorization header
        final authHeader = request.headers['authorization'];
        if (authHeader == null) {
          return Response.forbidden(
            jsonEncode({'error': 'Authorization header required'}),
            headers: {'Content-Type': 'application/json'},
          );
        }

        // Expect "Bearer <token>" format
        if (!authHeader.startsWith('Bearer ')) {
          return Response.forbidden(
            jsonEncode({'error': 'Invalid authorization format'}),
            headers: {'Content-Type': 'application/json'},
          );
        }

        final token = authHeader.substring(7);
        if (token != authToken) {
          return Response.forbidden(
            jsonEncode({'error': 'Invalid token'}),
            headers: {'Content-Type': 'application/json'},
          );
        }

        return handler(request);
      };
    };
  }

  Future<Response> _handleHealth(Request request) async {
    return Response.ok(
      jsonEncode({
        'status': 'ok',
        'version': '0.1.0',
        'session-count': registry.sessionCount,
        'uptime-seconds': DateTime.now().difference(startedAt).inSeconds,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> _handleCreateSession(Request request) async {
    try {
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final createRequest = CreateSessionRequest.fromJson(json);

      _log.info('Creating session for: ${createRequest.workingDirectory}');

      final session = await registry.createSession(
        initialMessage: createRequest.initialMessage,
        workingDirectory: createRequest.workingDirectory,
        model: createRequest.model,
        permissionMode: createRequest.permissionMode,
        team: createRequest.team,
      );

      final response = CreateSessionResponse(
        sessionId: session.sessionId,
        mainAgentId: session.mainAgentId,
        wsUrl: session.wsUrl,
        httpUrl: session.httpUrl,
        port: session.port,
        createdAt: session.createdAt,
      );

      return Response.ok(
        jsonEncode(response.toJson()),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, st) {
      _log.severe('Failed to create session: $e', e, st);
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _handleListSessions(Request request) async {
    final sessions = registry.listSessions();
    final response = ListSessionsResponse(sessions: sessions);

    return Response.ok(
      jsonEncode(response.toJson()),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> _handleGetSession(Request request, String sessionId) async {
    final session = registry.getSession(sessionId);
    if (session == null) {
      return Response.notFound(
        jsonEncode({'error': 'Session not found'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final response = session.toDetails();
    return Response.ok(
      jsonEncode(response.toJson()),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> _handleStopSession(Request request, String sessionId) async {
    final session = registry.getSession(sessionId);
    if (session == null) {
      return Response.notFound(
        jsonEncode({'error': 'Session not found'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Check for force flag
    final force = request.url.queryParameters['force'] == 'true';

    if (force) {
      await registry.killSession(sessionId);
    } else {
      await registry.stopSession(sessionId);
    }

    return Response.ok(
      jsonEncode({'status': 'stopped', 'session-id': sessionId}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  FutureOr<Response> _handleDaemonWebSocket(Request request) {
    return webSocketHandler((WebSocketChannel channel, String? protocol) {
      _log.info('WebSocket client connected');
      _wsClients.add(channel);

      // Send initial status
      channel.sink.add(
        DaemonStatusEvent(
          sessionCount: registry.sessionCount,
          startedAt: startedAt,
          version: '0.1.0',
        ).toJsonString(),
      );

      channel.stream.listen(
        (message) {
          // Daemon WebSocket is currently read-only for clients
          _log.fine('Received message from client: $message');
        },
        onDone: () {
          _log.info('WebSocket client disconnected');
          _wsClients.remove(channel);
        },
        onError: (error) {
          _log.warning('WebSocket error: $error');
          _wsClients.remove(channel);
        },
      );
    })(request);
  }

  void _broadcastEvent(DaemonEvent event) {
    final message = event.toJsonString();
    for (final client in _wsClients) {
      try {
        client.sink.add(message);
      } catch (e) {
        _log.warning('Failed to send event to client: $e');
      }
    }
  }
}
