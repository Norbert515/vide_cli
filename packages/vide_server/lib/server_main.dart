/// Entry point for starting the vide_server.
///
/// This module provides the [startServer] function which can be called
/// from either:
/// - `bin/vide_server.dart` (standalone server)
/// - `vide session-server` (embedded in vide binary)
library;

import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:riverpod/riverpod.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:vide_core/vide_core.dart';

import 'middleware/cors_middleware.dart';
import 'routes/filesystem_routes.dart';
import 'routes/git_routes.dart';
import 'routes/session_routes.dart';
import 'routes/team_routes.dart';
import 'services/server_config.dart';

/// Configuration for starting the server.
class VideServerConfig {
  /// Port to listen on (null = auto-select).
  final int? port;

  /// Working directory override (defaults to current directory).
  final String? workingDirectory;

  /// Whether to skip all permission checks for sessions.
  ///
  /// DANGEROUS: Only for sandboxed environments. Propagated from daemon
  /// via VIDE_DANGEROUSLY_SKIP_PERMISSIONS environment variable.
  final bool dangerouslySkipPermissions;

  const VideServerConfig({
    this.port,
    this.workingDirectory,
    this.dangerouslySkipPermissions = false,
  });
}

/// Start the vide_server and return the running HttpServer.
///
/// This function:
/// 1. Sets up logging
/// 2. Loads server configuration
/// 3. Creates session manager with isolated containers
/// 4. Starts HTTP server with routes
///
/// The caller is responsible for keeping the process alive.
Future<HttpServer> startServer(VideServerConfig config) async {
  // Initialize structured logging
  VideLogger.init('${VideConfigManager().configRoot}/logs');

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
  if (serverConfig.autoApproveAll) {
    log.warning(
      'Auto-approve-all is enabled - all permissions will be granted!',
    );
  }

  if (config.dangerouslySkipPermissions) {
    log.warning(
      'dangerously-skip-permissions is enabled - all permissions will be auto-approved!',
    );
  }

  // Create session manager with isolated containers (each session gets its own providers).
  final permissionHandler = PermissionHandler();
  final container = ProviderContainer(
    overrides: [
      videCoreConfigProvider.overrideWithValue(VideCoreConfig(
        workingDirectory: Directory.current.path,
        configManager: VideConfigManager(),
        permissionHandler: permissionHandler,
        dangerouslySkipPermissions: config.dangerouslySkipPermissions,
      )),
    ],
  );
  final sessionManager = LocalVideSessionManager.isolated(
    container,
    permissionHandler,
  );

  // Simple session cache for WebSocket access
  final sessionCache = <String, VideSession>{};

  // Create HTTP handler with routes
  final handler = _createHandler(sessionManager, sessionCache, serverConfig);

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
  print('║  Config: ${VideConfigManager().configRoot.padRight(52)}║');
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
  VideSessionManager sessionManager,
  Map<String, VideSession> sessionCache,
  ServerConfig serverConfig,
) {
  final router = Router();

  // Phase 2.5 API routes (session-based, kebab-case)
  router.post('/api/v1/sessions', (Request request) {
    return createSession(request, sessionManager, sessionCache);
  });

  router.get('/api/v1/sessions', (Request request) {
    return listSessions(request, sessionManager);
  });

  router.post('/api/v1/sessions/<sessionId>/resume', (
    Request request,
    String sessionId,
  ) {
    return resumeSession(request, sessionId, sessionManager, sessionCache);
  });

  router.get('/api/v1/sessions/<sessionId>/stream', (
    Request request,
    String sessionId,
  ) {
    return streamSessionWebSocket(sessionId, sessionCache)(request);
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

  // Git API
  router.get('/api/v1/git/status', (Request request) {
    return gitStatus(request, serverConfig);
  });

  router.get('/api/v1/git/branches', (Request request) {
    return gitBranches(request, serverConfig);
  });

  router.get('/api/v1/git/log', (Request request) {
    return gitLog(request, serverConfig);
  });

  router.get('/api/v1/git/diff', (Request request) {
    return gitDiff(request, serverConfig);
  });

  router.get('/api/v1/git/worktrees', (Request request) {
    return gitWorktrees(request, serverConfig);
  });

  router.get('/api/v1/git/stash/list', (Request request) {
    return gitStashList(request, serverConfig);
  });

  router.post('/api/v1/git/commit', (Request request) {
    return gitCommit(request, serverConfig);
  });

  router.post('/api/v1/git/stage', (Request request) {
    return gitStage(request, serverConfig);
  });

  router.post('/api/v1/git/checkout', (Request request) {
    return gitCheckout(request, serverConfig);
  });

  router.post('/api/v1/git/push', (Request request) {
    return gitPush(request, serverConfig);
  });

  router.post('/api/v1/git/pull', (Request request) {
    return gitPull(request, serverConfig);
  });

  router.post('/api/v1/git/fetch', (Request request) {
    return gitFetch(request, serverConfig);
  });

  router.post('/api/v1/git/sync', (Request request) {
    return gitSync(request, serverConfig);
  });

  router.post('/api/v1/git/merge', (Request request) {
    return gitMerge(request, serverConfig);
  });

  router.post('/api/v1/git/stash', (Request request) {
    return gitStash(request, serverConfig);
  });

  router.post('/api/v1/git/worktree/add', (Request request) {
    return gitWorktreeAdd(request, serverConfig);
  });

  router.post('/api/v1/git/worktree/remove', (Request request) {
    return gitWorktreeRemove(request, serverConfig);
  });

  // Health check endpoint
  router.get('/health', (Request request) {
    return Response.ok('OK');
  });

  // Build middleware pipeline
  // NOTE: logRequests() buffers the entire response, so it breaks streaming (WebSocket/SSE)
  // We use custom logging in the routes instead
  final pipeline = Pipeline()
      .addMiddleware(corsMiddleware())
      .addHandler(router);

  return pipeline;
}
