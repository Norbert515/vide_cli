/// Embedded HTTP/WebSocket server for the VideCore API.
///
/// This provides a lightweight server that can be started alongside
/// a VideSession to allow external clients (phones, web apps, etc.)
/// to connect and interact with the session.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'vide_agent.dart';
import 'vide_event.dart';
import 'vide_session.dart';

/// A lightweight embedded HTTP/WebSocket server for a [VideSession].
///
/// Example:
/// ```dart
/// final session = await core.startSession(config);
/// final server = await VideEmbeddedServer.start(
///   session: session,
///   port: 8080,
/// );
///
/// print('Server running at http://localhost:${server.port}');
/// print('WebSocket at ws://localhost:${server.port}/ws');
///
/// // Later...
/// await server.stop();
/// ```
class VideEmbeddedServer {
  final VideSession _session;
  final HttpServer _httpServer;
  final List<WebSocket> _clients = [];
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  /// Sequence number for events (for client ordering).
  int _seq = 0;

  VideEmbeddedServer._(this._session, this._httpServer);

  /// Start an embedded server for the given session.
  ///
  /// [port] - The port to listen on (default: 8080).
  /// [address] - The address to bind to (default: localhost only).
  static Future<VideEmbeddedServer> start({
    required VideSession session,
    int port = 8080,
    InternetAddress? address,
  }) async {
    final bindAddress = address ?? InternetAddress.loopbackIPv4;
    final httpServer = await HttpServer.bind(bindAddress, port);

    final server = VideEmbeddedServer._(session, httpServer);
    server._startListening();
    return server;
  }

  /// The port the server is listening on.
  int get port => _httpServer.port;

  /// The address the server is bound to.
  InternetAddress get address => _httpServer.address;

  /// Stop the server and disconnect all clients.
  Future<void> stop() async {
    // Cancel subscriptions
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();

    // Close all WebSocket connections
    for (final client in _clients) {
      await client.close(1001, 'Server shutting down');
    }
    _clients.clear();

    // Close the HTTP server
    await _httpServer.close(force: true);
  }

  void _startListening() {
    // Subscribe to session events
    final eventSub = _session.events.listen(_broadcastEvent);
    _subscriptions.add(eventSub);

    // Handle HTTP requests
    _httpServer.listen(_handleRequest);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final path = request.uri.path;

    // CORS headers for browser clients
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    try {
      switch (path) {
        case '/':
        case '/health':
          await _handleHealth(request);

        case '/ws':
          await _handleWebSocket(request);

        case '/session':
          await _handleSessionInfo(request);

        case '/agents':
          await _handleAgents(request);

        case '/message':
          await _handleMessage(request);

        case '/permission':
          await _handlePermission(request);

        case '/abort':
          await _handleAbort(request);

        default:
          request.response.statusCode = HttpStatus.notFound;
          request.response.write(jsonEncode({'error': 'Not found'}));
          await request.response.close();
      }
    } catch (e) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write(jsonEncode({'error': e.toString()}));
      await request.response.close();
    }
  }

  Future<void> _handleHealth(HttpRequest request) async {
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({
      'status': 'ok',
      'session_id': _session.id,
      'agents': _session.agents.length,
    }));
    await request.response.close();
  }

  Future<void> _handleWebSocket(HttpRequest request) async {
    final socket = await WebSocketTransformer.upgrade(request);
    _clients.add(socket);

    // Send connected event
    _sendToClient(socket, {
      'type': 'connected',
      'session_id': _session.id,
      'agents': _session.agents.map(_agentToJson).toList(),
    });

    // Handle incoming messages
    socket.listen(
      (data) => _handleWebSocketMessage(socket, data),
      onDone: () => _clients.remove(socket),
      onError: (_) => _clients.remove(socket),
    );
  }

  void _handleWebSocketMessage(WebSocket socket, dynamic data) {
    try {
      final message = jsonDecode(data as String) as Map<String, dynamic>;
      final type = message['type'] as String?;

      switch (type) {
        case 'message':
          final content = message['content'] as String?;
          final agentId = message['agent_id'] as String?;
          if (content != null && content.isNotEmpty) {
            _session.sendMessage(content, agentId: agentId);
          }

        case 'permission':
          final requestId = message['request_id'] as String?;
          final allow = message['allow'] as bool? ?? false;
          final msg = message['message'] as String?;
          if (requestId != null) {
            _session.respondToPermission(requestId, allow: allow, message: msg);
          }

        case 'abort':
          _session.abort();

        default:
          _sendToClient(socket, {
            'type': 'error',
            'message': 'Unknown message type: $type',
          });
      }
    } catch (e) {
      _sendToClient(socket, {
        'type': 'error',
        'message': 'Invalid message: $e',
      });
    }
  }

  Future<void> _handleSessionInfo(HttpRequest request) async {
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({
      'session_id': _session.id,
      'agents': _session.agents.map(_agentToJson).toList(),
    }));
    await request.response.close();
  }

  Future<void> _handleAgents(HttpRequest request) async {
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({
      'agents': _session.agents.map(_agentToJson).toList(),
    }));
    await request.response.close();
  }

  Future<void> _handleMessage(HttpRequest request) async {
    if (request.method != 'POST') {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      request.response.write(jsonEncode({'error': 'POST required'}));
      await request.response.close();
      return;
    }

    final body = await utf8.decoder.bind(request).join();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final content = data['content'] as String?;
    final agentId = data['agent_id'] as String?;

    if (content == null || content.isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write(jsonEncode({'error': 'content required'}));
      await request.response.close();
      return;
    }

    _session.sendMessage(content, agentId: agentId);

    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'status': 'sent'}));
    await request.response.close();
  }

  Future<void> _handlePermission(HttpRequest request) async {
    if (request.method != 'POST') {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      request.response.write(jsonEncode({'error': 'POST required'}));
      await request.response.close();
      return;
    }

    final body = await utf8.decoder.bind(request).join();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final requestId = data['request_id'] as String?;
    final allow = data['allow'] as bool? ?? false;
    final message = data['message'] as String?;

    if (requestId == null) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write(jsonEncode({'error': 'request_id required'}));
      await request.response.close();
      return;
    }

    _session.respondToPermission(requestId, allow: allow, message: message);

    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'status': 'responded'}));
    await request.response.close();
  }

  Future<void> _handleAbort(HttpRequest request) async {
    if (request.method != 'POST') {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      request.response.write(jsonEncode({'error': 'POST required'}));
      await request.response.close();
      return;
    }

    await _session.abort();

    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'status': 'aborted'}));
    await request.response.close();
  }

  void _broadcastEvent(VideEvent event) {
    final json = _eventToJson(event);
    final message = jsonEncode(json);

    // Remove disconnected clients
    _clients.removeWhere((client) => client.closeCode != null);

    // Broadcast to all connected clients
    for (final client in _clients) {
      try {
        client.add(message);
      } catch (_) {
        // Client disconnected
      }
    }
  }

  void _sendToClient(WebSocket client, Map<String, dynamic> data) {
    try {
      client.add(jsonEncode(data));
    } catch (_) {
      // Client disconnected
    }
  }

  Map<String, dynamic> _eventToJson(VideEvent event) {
    _seq++;
    final base = {
      'seq': _seq,
      'agent_id': event.agentId,
      'agent_type': event.agentType,
      'agent_name': event.agentName,
      'task_name': event.taskName,
      'timestamp': event.timestamp.toIso8601String(),
    };

    switch (event) {
      case MessageEvent e:
        return {
          ...base,
          'type': 'message',
          'event_id': e.eventId,
          'role': e.role,
          'content': e.content,
          'is_partial': e.isPartial,
        };

      case ToolUseEvent e:
        return {
          ...base,
          'type': 'tool_use',
          'tool_use_id': e.toolUseId,
          'tool_name': e.toolName,
          'tool_input': e.toolInput,
        };

      case ToolResultEvent e:
        return {
          ...base,
          'type': 'tool_result',
          'tool_use_id': e.toolUseId,
          'tool_name': e.toolName,
          'result': e.result,
          'is_error': e.isError,
        };

      case StatusEvent e:
        return {
          ...base,
          'type': 'status',
          'status': e.status.name,
        };

      case TurnCompleteEvent e:
        return {
          ...base,
          'type': 'turn_complete',
          'reason': e.reason,
        };

      case AgentSpawnedEvent e:
        return {
          ...base,
          'type': 'agent_spawned',
          'spawned_by': e.spawnedBy,
        };

      case AgentTerminatedEvent e:
        return {
          ...base,
          'type': 'agent_terminated',
          'reason': e.reason,
          'terminated_by': e.terminatedBy,
        };

      case PermissionRequestEvent e:
        return {
          ...base,
          'type': 'permission_request',
          'request_id': e.requestId,
          'tool_name': e.toolName,
          'tool_input': e.toolInput,
        };

      case ErrorEvent e:
        return {
          ...base,
          'type': 'error',
          'message': e.message,
          'code': e.code,
        };
    }
  }

  Map<String, dynamic> _agentToJson(VideAgent agent) {
    return {
      'id': agent.id,
      'name': agent.name,
      'type': agent.type,
      'status': agent.status.name,
      'spawned_by': agent.spawnedBy,
      'task_name': agent.taskName,
      'created_at': agent.createdAt.toIso8601String(),
      'total_input_tokens': agent.totalInputTokens,
      'total_output_tokens': agent.totalOutputTokens,
      'total_cost_usd': agent.totalCostUsd,
    };
  }
}
