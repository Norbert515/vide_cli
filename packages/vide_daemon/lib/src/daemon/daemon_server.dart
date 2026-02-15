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
  final String bindAddress;
  final DateTime startedAt = DateTime.now();

  HttpServer? _server;
  final Map<WebSocketChannel, _DaemonWebSocketClientContext> _wsClients = {};
  StreamSubscription<DaemonEvent>? _eventSubscription;

  final Logger _log = Logger('DaemonServer');

  DaemonServer({
    required this.registry,
    required this.port,
    this.bindAddress = '127.0.0.1',
  });

  /// Start the daemon server.
  Future<void> start() async {
    _log.info('Starting daemon server on port $port');

    // Subscribe to registry events to broadcast to WebSocket clients
    _eventSubscription = registry.events.listen(_broadcastEvent);

    final handler = _createHandler();

    final address = InternetAddress(bindAddress);
    _server = await shelf_io.serve(handler, address, port);

    _log.info('Daemon server listening on http://$bindAddress:$port');
  }

  /// Stop the daemon server.
  Future<void> stop() async {
    _log.info('Stopping daemon server');

    await _eventSubscription?.cancel();

    // Close all WebSocket connections
    for (final client in _wsClients.keys.toList()) {
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
    router.post('/sessions/<sessionId>/resume', _handleResumeSession);
    router.get('/sessions/<sessionId>/stream', _handleSessionStreamWebSocket);
    router.get('/sessions/<sessionId>', _handleGetSession);
    router.delete('/sessions/<sessionId>', _handleStopSession);

    // WebSocket for daemon events
    router.get('/daemon', _handleDaemonWebSocket);

    // Build middleware pipeline
    final pipeline = Pipeline()
        .addMiddleware(_corsMiddleware())
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
              'Access-Control-Allow-Headers': 'Content-Type',
            },
          );
        }

        final response = await handler(request);
        return response.change(headers: {'Access-Control-Allow-Origin': '*'});
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
        permissionMode: createRequest.permissionMode,
        team: createRequest.team,
        attachments: createRequest.attachments,
      );

      final response = CreateSessionResponse(
        sessionId: session.sessionId,
        mainAgentId: session.mainAgentId,
        wsUrl: _buildSessionProxyWsUrl(request, session.sessionId),
        httpUrl: _buildDaemonBaseHttpUrl(request),
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

  Future<Response> _handleResumeSession(
    Request request,
    String sessionId,
  ) async {
    try {
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final resumeRequest = ResumeSessionRequest.fromJson(json);

      _log.info(
        'Resuming session $sessionId for: ${resumeRequest.workingDirectory}',
      );

      final session = await registry.resumeSession(
        sessionId: sessionId,
        workingDirectory: resumeRequest.workingDirectory,
      );

      final response = CreateSessionResponse(
        sessionId: session.sessionId,
        mainAgentId: session.mainAgentId,
        wsUrl: _buildSessionProxyWsUrl(request, session.sessionId),
        httpUrl: _buildDaemonBaseHttpUrl(request),
        port: session.port,
        createdAt: session.createdAt,
      );

      return Response.ok(
        jsonEncode(response.toJson()),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, st) {
      _log.severe('Failed to resume session: $e', e, st);
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

    final sessionDetails = session.toDetails();
    final response = SessionDetailsResponse(
      sessionId: sessionDetails.sessionId,
      workingDirectory: sessionDetails.workingDirectory,
      wsUrl: _buildSessionProxyWsUrl(request, sessionId),
      httpUrl: _buildDaemonBaseHttpUrl(request),
      port: sessionDetails.port,
      createdAt: sessionDetails.createdAt,
      state: sessionDetails.state,
      connectedClients: sessionDetails.connectedClients,
      pid: sessionDetails.pid,
    );
    return Response.ok(
      jsonEncode(response.toJson()),
      headers: {'Content-Type': 'application/json'},
    );
  }

  FutureOr<Response> _handleSessionStreamWebSocket(
    Request request,
    String sessionId,
  ) {
    final session = registry.getSession(sessionId);
    if (session == null) {
      return Response.notFound(
        jsonEncode({'error': 'Session not found'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    return webSocketHandler((WebSocketChannel clientChannel, String? protocol) {
      final upstreamUrl = session.wsUrl;
      final upstreamChannel = WebSocketChannel.connect(Uri.parse(upstreamUrl));
      var closed = false;

      void closeProxy() {
        if (closed) return;
        closed = true;
        unawaited(clientChannel.sink.close());
        unawaited(upstreamChannel.sink.close());
      }

      clientChannel.stream.listen(
        (message) {
          if (closed) return;
          try {
            upstreamChannel.sink.add(message);
          } catch (error) {
            _log.warning(
              'Failed forwarding client message for session $sessionId: $error',
            );
            closeProxy();
          }
        },
        onError: (error) {
          _log.warning('Session proxy client error for $sessionId: $error');
          closeProxy();
        },
        onDone: closeProxy,
      );

      upstreamChannel.stream.listen(
        (message) {
          if (closed) return;
          try {
            clientChannel.sink.add(message);
          } catch (error) {
            _log.warning(
              'Failed forwarding upstream message for session $sessionId: $error',
            );
            closeProxy();
          }
        },
        onError: (error) {
          _log.warning('Session proxy upstream error for $sessionId: $error');
          closeProxy();
        },
        onDone: closeProxy,
      );
    })(request);
  }

  String _buildDaemonBaseHttpUrl(Request request) {
    final uri = request.requestedUri;
    final defaultPort = uri.scheme == 'https' ? 443 : 80;
    final baseUri = uri.port == defaultPort
        ? Uri(scheme: uri.scheme, host: uri.host)
        : Uri(scheme: uri.scheme, host: uri.host, port: uri.port);
    return baseUri.toString();
  }

  String _buildSessionProxyWsUrl(Request request, String sessionId) {
    final uri = request.requestedUri;
    final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final defaultPort = wsScheme == 'wss' ? 443 : 80;
    final streamUri = uri.port == defaultPort
        ? Uri(
            scheme: wsScheme,
            host: uri.host,
            path: '/sessions/$sessionId/stream',
          )
        : Uri(
            scheme: wsScheme,
            host: uri.host,
            port: uri.port,
            path: '/sessions/$sessionId/stream',
          );
    return streamUri.toString();
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
    final clientContext = _DaemonWebSocketClientContext.fromRequest(request);
    return webSocketHandler((WebSocketChannel channel, String? protocol) {
      _log.info('WebSocket client connected');
      _wsClients[channel] = clientContext;

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
    for (final entry in _wsClients.entries) {
      final client = entry.key;
      final clientContext = entry.value;
      final message = _rewriteEventForClient(
        event,
        clientContext,
      ).toJsonString();
      try {
        client.sink.add(message);
      } catch (e) {
        _log.warning('Failed to send event to client: $e');
      }
    }
  }

  DaemonEvent _rewriteEventForClient(
    DaemonEvent event,
    _DaemonWebSocketClientContext clientContext,
  ) {
    if (event is! SessionCreatedEvent) {
      return event;
    }

    return SessionCreatedEvent(
      sessionId: event.sessionId,
      workingDirectory: event.workingDirectory,
      wsUrl: clientContext.sessionStreamWsUrl(event.sessionId),
      httpUrl: clientContext.httpBaseUrl,
      port: event.port,
      createdAt: event.createdAt,
    );
  }
}

class _DaemonWebSocketClientContext {
  final String httpBaseUrl;
  final String wsBaseUrl;

  const _DaemonWebSocketClientContext({
    required this.httpBaseUrl,
    required this.wsBaseUrl,
  });

  factory _DaemonWebSocketClientContext.fromRequest(Request request) {
    final requestedUri = request.requestedUri;
    final httpDefaultPort = requestedUri.scheme == 'https' ? 443 : 80;
    final wsScheme = requestedUri.scheme == 'https' ? 'wss' : 'ws';
    final wsDefaultPort = wsScheme == 'wss' ? 443 : 80;

    final httpBaseUri = requestedUri.port == httpDefaultPort
        ? Uri(scheme: requestedUri.scheme, host: requestedUri.host)
        : Uri(
            scheme: requestedUri.scheme,
            host: requestedUri.host,
            port: requestedUri.port,
          );
    final wsBaseUri = requestedUri.port == wsDefaultPort
        ? Uri(scheme: wsScheme, host: requestedUri.host)
        : Uri(
            scheme: wsScheme,
            host: requestedUri.host,
            port: requestedUri.port,
          );

    return _DaemonWebSocketClientContext(
      httpBaseUrl: httpBaseUri.toString(),
      wsBaseUrl: wsBaseUri.toString(),
    );
  }

  String sessionStreamWsUrl(String sessionId) {
    return '$wsBaseUrl/sessions/$sessionId/stream';
  }
}
