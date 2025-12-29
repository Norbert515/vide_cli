#!/usr/bin/env dart
import 'dart:io';
import 'package:args/args.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:riverpod/riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:logging/logging.dart';
import 'package:vide_core/services/vide_config_manager.dart';
import 'package:vide_core/services/agent_network_persistence_manager.dart';
import 'package:vide_core/services/agent_network_manager.dart';
import 'package:vide_core/services/permission_provider.dart';
import 'package:vide_core/utils/working_dir_provider.dart';
import 'package:vide_server/services/simple_permission_service.dart';
import 'package:vide_server/services/network_cache_manager.dart';
import 'package:vide_server/middleware/cors_middleware.dart';
import 'package:vide_server/routes/network_routes.dart';

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

  // Get home directory
  final homeDir =
      Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      Directory.current.path;

  // Use ~/.vide/api for REST API config (isolated from TUI)
  final configRoot = path.join(homeDir, '.vide', 'api');

  // Create provider container with REST-specific overrides
  final container = ProviderContainer(
    overrides: [
      // Config manager with REST API config root
      videConfigManagerProvider.overrideWithValue(
        VideConfigManager(configRoot: configRoot),
      ),
      // Permission callback factory with auto-approve/deny rules
      canUseToolCallbackFactoryProvider.overrideWithValue(
        createSimplePermissionCallback,
      ),
      // Working directory provider - uses current directory as default
      //
      // NOTE: This is used by MCP servers (e.g., MemoryMCPServer for projectPath).
      // The actual working directory for agent operations comes from the explicit
      // parameter passed to startNew(workingDirectory: ...), which sets the network's
      // worktreePath. The fix in AgentNetworkManager._inflateClaudeClient ensures
      // it uses the network's worktreePath instead of reading from this provider.
      //
      // LIMITATION: MCP servers currently use this shared default instead of per-network
      // worktreePath. This could be improved in the future if MCP servers need per-network
      // isolation (e.g., memory storage scoped to network working directory).
      workingDirProvider.overrideWithValue(Directory.current.path),
      // Override AgentNetworkManager provider to use a dummy working directory
      // The actual working directory is passed explicitly to startNew()
      agentNetworkManagerProvider.overrideWith((ref) {
        return AgentNetworkManager(
          workingDirectory:
              Directory.current.path, // Dummy default, overridden by startNew()
          ref: ref,
        );
      }),
    ],
  );

  // Create network cache manager
  final persistenceManager = container.read(
    agentNetworkPersistenceManagerProvider,
  );
  final cacheManager = NetworkCacheManager(persistenceManager);

  // Create HTTP handler with routes
  final handler = _createHandler(container, cacheManager);

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
  ProviderContainer container,
  NetworkCacheManager cacheManager,
) {
  final router = Router();

  // API routes
  router.post('/api/v1/networks', (Request request) {
    return createNetwork(request, container, cacheManager);
  });

  router.post('/api/v1/networks/<networkId>/messages', (
    Request request,
    String networkId,
  ) {
    return sendMessage(request, networkId, container, cacheManager);
  });

  router.get('/api/v1/networks/<networkId>/agents/<agentId>/stream', (
    Request request,
    String networkId,
    String agentId,
  ) {
    return streamAgentWebSocket(networkId, agentId, container, cacheManager)(
      request,
    );
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
