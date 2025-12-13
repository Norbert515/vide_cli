import 'dart:async';
import 'dart:io';
import 'package:claude_api/claude_api.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:sentry/sentry.dart';

abstract class McpServerBase {
  final String name;
  final String version;
  late int _assignedPort;
  HttpServer? _server;
  McpServer? _mcpServer;
  SseServerManager? _sseManager;

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
        options: ServerOptions(capabilities: ServerCapabilities(tools: ServerCapabilitiesTools())),
      );

      // Register tools
      registerTools(_mcpServer!);

      // Setup SSE manager for HTTP transport
      _sseManager = SseServerManager(_mcpServer!);

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
    if (_server == null || _sseManager == null) {
      return;
    }

    await for (final request in _server!) {
      await _sseManager!.handleRequest(request);
    }
  }

  /// Stop the server
  Future<void> stop() async {
    await onStop();
    await _mcpServer?.close();
    await _server?.close();
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
  Map<String, dynamic> toClaudeConfig() {
    // Return config in Claude Code's expected format
    final config = {'type': 'sse', 'url': 'http://localhost:${_assignedPort}/sse'};
    return config;
  }

  void dispose() {
    _stateController.close();
  }
}

enum ServerState { stopped, running, error }
