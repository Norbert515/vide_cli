import 'dart:async';
import 'package:claude_sdk/claude_sdk.dart';
import 'package:riverpod/riverpod.dart';
import 'package:uuid/uuid.dart';

import '../agents/main_agent_config.dart';
import '../models/agent_id.dart';
import '../utils/working_dir_provider.dart';
import 'claude_client_factory.dart';

/// Holds the initial Claude client created at app startup.
class InitialClaudeClient {
  final ClaudeClient client;
  final AgentId agentId;
  final String workingDirectory;

  /// Stream of MCP status updates.
  Stream<McpStatusResponse> get mcpStatusStream => _mcpStatusController.stream;

  /// Current MCP status, or null if not yet fetched.
  McpStatusResponse? get mcpStatus => _mcpStatus;

  final _mcpStatusController = StreamController<McpStatusResponse>.broadcast();
  McpStatusResponse? _mcpStatus;
  bool _disposed = false;

  InitialClaudeClient({
    required this.client,
    required this.agentId,
    required this.workingDirectory,
  }) {
    // Wait for client to initialize, then fetch MCP status
    _fetchMcpStatusWhenReady();
  }

  Future<void> _fetchMcpStatusWhenReady() async {
    try {
      // Wait for the client to be fully initialized
      await client.initialized;
      if (_disposed) return;

      final status = await client.getMcpStatus();
      if (_disposed) return;

      _mcpStatus = status;
      _mcpStatusController.add(status);
    } catch (e) {
      // MCP status fetch failed - not critical
      print('[InitialClaudeClient] Failed to fetch MCP status: $e');
    }
  }

  void dispose() {
    _disposed = true;
    _mcpStatusController.close();
  }
}

/// Provider for the initial Claude client.
///
/// This client is created when the app starts (before user submits their first message)
/// so that Claude CLI is already initialized and ready when the user types.
///
/// The client is created lazily on first access. Call `ref.read(initialClaudeClientProvider)`
/// early (e.g., in initState) to trigger initialization.
final initialClaudeClientProvider = Provider<InitialClaudeClient>((ref) {
  final workingDirectory = ref.watch(workingDirProvider);
  final agentId = const Uuid().v4();

  final factory = ClaudeClientFactoryImpl(
    getWorkingDirectory: () => workingDirectory,
    ref: ref,
  );

  final config = MainAgentConfig.create();
  final client = factory.createSync(
    agentId: agentId,
    config: config,
    networkId: null, // No network yet
    agentType: 'main',
  );

  final initialClient = InitialClaudeClient(
    client: client,
    agentId: agentId,
    workingDirectory: workingDirectory,
  );

  ref.onDispose(() => initialClient.dispose());

  return initialClient;
});
