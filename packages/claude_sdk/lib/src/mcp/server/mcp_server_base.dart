import 'dart:async';
import 'dart:io';
import 'package:claude_sdk/claude_sdk.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:sentry/sentry.dart';

abstract class McpServerBase {
  final String name;
  final String version;
  late int _assignedPort;
  HttpServer? _server;
  McpServer? _mcpServer;
  StreamableHTTPServerTransport? _httpTransport;

  final _stateController = StreamController<ServerState>.broadcast();
  Stream<ServerState> get stateStream => _stateController.stream;

  int get port {
    return _assignedPort;
  }

  bool get isRunning => _server != null;

  McpServerBase({required this.name, required this.version});

  /// Called by framework with assigned port
  /// [preDefinedPort] is the port to use, if null, a random port will be used
  Future<void> start({int? port}) async {
    if (_server != null) {
      throw StateError('Server already running');
    }

    _assignedPort = port ?? await PortManager.findAvailablePort();
    try {
      // Create MCP server
      _mcpServer = McpServer(
        Implementation(name: name, version: version),
        options: ServerOptions(
          capabilities: ServerCapabilities(tools: ServerCapabilitiesTools()),
        ),
      );

      // Register tools
      registerTools(_mcpServer!);

      // Setup Streamable HTTP transport (replaces deprecated SSE transport)
      // This transport has built-in keep-alive support and is the current MCP standard
      _httpTransport = StreamableHTTPServerTransport(
        options: StreamableHTTPServerTransportOptions(
          // Stateless mode - no session management needed for local MCP servers
          sessionIdGenerator: () => null,
        ),
      );

      // Connect to MCP server (this internally starts the transport)
      await _mcpServer!.connect(_httpTransport!);

      // Create HTTP server
      _server = await HttpServer.bind('localhost', _assignedPort);

      // Disable idle timeout to allow long-running MCP tool operations
      // (e.g., sub-agents that take several minutes to complete)
      // Setting to null means connections never timeout due to inactivity
      _server!.idleTimeout = null;

      // Handle incoming requests
      _handleRequests();

      _stateController.add(ServerState.running);

      // Call lifecycle hook
      await onStart();
    } catch (e, stackTrace) {
      _stateController.add(ServerState.error);
      print('Error starting MCP server: $e');
      // Report to Sentry with context
      await Sentry.configureScope((scope) {
        scope.setTag('mcp_server', name);
        scope.setTag('mcp_operation', 'start');
        scope.setContexts('mcp_context', {
          'port': _assignedPort,
          'server_version': version,
        });
      });
      await Sentry.captureException(e, stackTrace: stackTrace);
      PortManager.releasePort(_assignedPort);
      rethrow;
    }
  }

  void _handleRequests() async {
    if (_server == null || _httpTransport == null) {
      return;
    }

    await for (final request in _server!) {
      // Route all requests to /mcp endpoint for Streamable HTTP transport
      if (request.uri.path == '/mcp' || request.uri.path == '/') {
        await _httpTransport!.handleRequest(request);
      } else {
        // Return 404 for unknown paths
        request.response.statusCode = HttpStatus.notFound;
        request.response.write('Not Found');
        await request.response.close();
      }
    }
  }

  /// Stop the server
  Future<void> stop() async {
    await onStop();
    await _httpTransport?.close();
    await _mcpServer?.close();
    await _server?.close();
    _httpTransport = null;
    _mcpServer = null;
    _server = null;

    _stateController.add(ServerState.stopped);
  }

  /// Register tools with the MCP server
  void registerTools(McpServer server);

  /// Get list of tool names provided by this server
  /// Override this to return the actual tool names
  List<String> get toolNames => [];

  /// Lifecycle hooks
  Future<void> onStart() async {}
  Future<void> onStop() async {}
  Future<void> onClientConnected(String clientId) async {}
  Future<void> onClientDisconnected(String clientId) async {}

  /// Generate Claude Code configuration
  ///
  /// Throws [StateError] if the server has not been started yet.
  Map<String, dynamic> toClaudeConfig() {
    if (!isRunning) {
      throw StateError(
        'MCP server "$name" has not been started. Call start() before toClaudeConfig().',
      );
    }
    // Return config in Claude Code's expected format
    // Using Streamable HTTP transport (replaces deprecated SSE)
    final config = {
      'type': 'http',
      'url': 'http://localhost:$_assignedPort/mcp',
    };
    return config;
  }

  void dispose() {
    _stateController.close();
  }
}

enum ServerState { stopped, running, error }
