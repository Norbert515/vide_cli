/// Entry point for starting the vide_server.
///
/// This module provides the [startServer] function which can be called
/// from either:
/// - `bin/vide_server.dart` (standalone server)
/// - `bin/vide.dart --session-server` (embedded in vide binary)
library;

import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:vide_core/vide_core.dart';

import 'middleware/cors_middleware.dart';
import 'routes/filesystem_routes.dart';
import 'routes/session_routes.dart';
import 'routes/team_routes.dart';
import 'services/server_config.dart';

/// Configuration for starting the server.
class VideServerConfig {
  /// Port to listen on (null = auto-select).
  final int? port;

  /// Working directory override (defaults to current directory).
  final String? workingDirectory;

  const VideServerConfig({
    this.port,
    this.workingDirectory,
  });
}

/// Start the vide_server and return the running HttpServer.
///
/// This function:
/// 1. Sets up logging
/// 2. Loads server configuration
/// 3. Creates VideCore instance
/// 4. Starts HTTP server with routes
///
/// The caller is responsible for keeping the process alive.
Future<HttpServer> startServer(VideServerConfig config) async {
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
  log.fine('Port: ${config.port ?? "auto"}');

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

  // Create VideCore instance with permission handler - the single interface for session management
  final permissionHandler = PermissionHandler();
  final videCore = VideCore(
    VideCoreConfig(
      configDir: configRoot,
      permissionHandler: permissionHandler,
    ),
  );

  // Simple session cache for WebSocket access
  final sessionCache = <String, VideSession>{};

  // Create HTTP handler with routes
  final handler = _createHandler(videCore, sessionCache, serverConfig);

  // Start server on localhost only (no authentication for MVP)
  final server = await shelf_io.serve(
    handler,
    InternetAddress.loopbackIPv4,
    config.port ?? 0, // 0 = auto-select available port
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

  return server;
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
    return streamSessionWebSocket(
      sessionId,
      videCore,
      sessionCache,
      serverConfig,
    )(request);
  });

  // Teams API
  router.get('/api/v1/teams', (Request request) {
    return listTeams(request);
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

  // Build middleware pipeline
  // NOTE: logRequests() buffers the entire response, so it breaks streaming (WebSocket/SSE)
  // We use custom logging in the routes instead
  final pipeline = Pipeline().addMiddleware(corsMiddleware()).addHandler(router);

  return pipeline;
}
