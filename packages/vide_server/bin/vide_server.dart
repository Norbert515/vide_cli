#!/usr/bin/env dart

import 'dart:io';
import 'package:args/args.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:path/path.dart' as path;
import 'package:logging/logging.dart';
import 'package:vide_core/vide_core.dart';
import 'package:vide_server/services/server_config.dart';
import 'package:vide_server/middleware/cors_middleware.dart';
import 'package:vide_server/routes/filesystem_routes.dart';
import 'package:vide_server/routes/session_routes.dart';

void main(List<String> arguments) async {
  // Parse command-line arguments
  final parser = ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show this help message',
    )
    ..addOption(
      'port',
      abbr: 'p',
      help: 'Port number to listen on (default: auto-select)',
    );

  void printUsage() {
    print('Vide API Server');
    print('');
    print('Usage: dart run bin/vide_server.dart [options]');
    print('');
    print('Options:');
    print(parser.usage);
    print('');
    print('Examples:');
    print('  dart run bin/vide_server.dart');
    print('  dart run bin/vide_server.dart --port 8080');
    print('  dart run bin/vide_server.dart -p 8888');
  }

  ArgResults argResults;
  try {
    argResults = parser.parse(arguments);
  } catch (e) {
    print('Error: $e');
    print('');
    printUsage();
    exit(1);
  }

  if (argResults['help'] as bool) {
    printUsage();
    exit(0);
  }

  // Parse port if provided
  int? port;
  final portStr = argResults['port'] as String?;
  if (portStr != null) {
    port = int.tryParse(portStr);
    if (port == null) {
      print('Error: Port must be a valid number, got: $portStr');
      print('');
      printUsage();
      exit(1);
    }
  }

  // Set up logging
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print(
      '[${record.time}] ${record.level.name}: ${record.loggerName}: ${record.message}',
    );
    if (record.error != null) print('  Error: ${record.error}');
    if (record.stackTrace != null) print('  Stack: ${record.stackTrace}');
  });

  final log = Logger('VideServer');
  log.info('Starting Vide API Server...');
  log.fine('Port: ${port ?? "auto"}');

  // Load server configuration
  final serverConfig = await ServerConfig.load();
  log.info('Permission timeout: ${serverConfig.permissionTimeoutSeconds}s');
  if (serverConfig.autoApproveAll) {
    log.warning(
      'Auto-approve-all is enabled - all permissions will be granted!',
    );
  }

  // Get home directory
  final homeDir =
      Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      Directory.current.path;

  // Use ~/.vide/api for REST API config (isolated from TUI)
  final configRoot = path.join(homeDir, '.vide', 'api');

  // Create VideCore instance - the single interface for session management
  final videCore = VideCore(VideCoreConfig(configDir: configRoot));

  // Simple session cache for WebSocket access
  final sessionCache = <String, VideSession>{};

  // Create HTTP handler with routes
  final handler = _createHandler(videCore, sessionCache, serverConfig);

  // Start server on localhost only (no authentication for MVP)
  final server = await shelf_io.serve(
    handler,
    InternetAddress.loopbackIPv4,
    port ?? 0, // 0 = auto-select available port
  );

  // Print server information
  print('╔════════════════════════════════════════════════════════════════╗');
  print('║                    Vide API Server                             ║');
  print('╠════════════════════════════════════════════════════════════════╣');
  print(
    '║  URL: http://${server.address.host}:${server.port.toString().padRight(54)}║',
  );
  print('║  Config: ${configRoot.padRight(52)}║');
  print('╠════════════════════════════════════════════════════════════════╣');
  print('║  ⚠️  WARNING: No authentication - localhost only!              ║');
  print('║  ⚠️  Do NOT expose this server to the internet!               ║');
  print('╚════════════════════════════════════════════════════════════════╝');
  print('');
  print('Server ready. Press Ctrl+C to stop.');
}

/// Create the HTTP handler with routes and middleware
Handler _createHandler(
  VideCore videCore,
  Map<String, VideSession> sessionCache,
  ServerConfig serverConfig,
) {
  final router = Router();

  // Phase 2.5 API routes (session-based, kebab-case)
  router.post('/api/v1/sessions', (Request request) {
    return createSession(request, videCore, sessionCache);
  });

  router.get('/api/v1/sessions/<sessionId>/stream', (
    Request request,
    String sessionId,
  ) {
    return streamSessionWebSocket(sessionId, videCore, sessionCache, serverConfig)(request);
  });

  // Filesystem browsing API
  router.get('/api/v1/filesystem', (Request request) {
    return listDirectory(request, serverConfig);
  });

  router.post('/api/v1/filesystem', (Request request) {
    return createDirectory(request, serverConfig);
  });

  // Health check endpoint
  router.get('/health', (Request request) {
    return Response.ok('OK');
  });

  // WebSocket test endpoint - echo server
  router.get(
    '/test-ws',
    webSocketHandler((WebSocketChannel channel, String? protocol) {
      print('[WebSocket] Client connected');

      // Send welcome message
      channel.sink.add('Welcome to Vide WebSocket test!');

      // Echo back any messages received
      channel.stream.listen(
        (message) {
          print('[WebSocket] Received: $message');
          channel.sink.add('Echo: $message');
        },
        onDone: () {
          print('[WebSocket] Client disconnected');
        },
        onError: (error) {
          print('[WebSocket] Error: $error');
        },
      );
    }),
  );

  // Build middleware pipeline
  // NOTE: logRequests() buffers the entire response, so it breaks streaming (WebSocket/SSE)
  // We use custom logging in the routes instead
  final pipeline = Pipeline()
      .addMiddleware(corsMiddleware())
      .addHandler(router);

  return pipeline;
}
