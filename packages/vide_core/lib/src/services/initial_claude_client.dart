import 'dart:async';
import 'package:claude_sdk/claude_sdk.dart';
import 'package:riverpod/riverpod.dart';
import 'package:uuid/uuid.dart';

import '../agents/agent_configuration.dart';
import '../models/agent_id.dart';
import '../mcp/mcp_server_type.dart';
import '../utils/working_dir_provider.dart';
import 'claude_client_factory.dart';
import 'permission_provider.dart';
import 'team_framework_loader.dart';

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
///
/// Loads the main agent configuration from the team framework. Uses 'vide' team
/// as the default team for the main (lead) agent.
final initialClaudeClientProvider = Provider<InitialClaudeClient>((ref) {
  final workingDirectory = ref.watch(workingDirProvider);
  final agentId = const Uuid().v4();

  final factory = ClaudeClientFactoryImpl(
    getWorkingDirectory: () => workingDirectory,
    ref: ref,
    permissionHandler: ref.read(permissionHandlerProvider),
  );

  // NOTE: We create a temporary fallback config synchronously to avoid blocking.
  // The real config is loaded asynchronously once the client is initialized.
  // This ensures the UI doesn't block while loading team framework definitions.
  final tempConfig = _createTemporaryMainAgentConfig();

  final client = factory.createSync(
    agentId: agentId,
    config: tempConfig,
    networkId: null, // No network yet
    agentType: 'main',
  );

  // Load and apply the real config asynchronously
  _loadAndApplyRealConfig(
    teamFrameworkLoader: TeamFrameworkLoader(
      workingDirectory: workingDirectory,
    ),
    client: client,
    factory: factory,
    agentId: agentId,
  );

  final initialClient = InitialClaudeClient(
    client: client,
    agentId: agentId,
    workingDirectory: workingDirectory,
  );

  ref.onDispose(() => initialClient.dispose());

  return initialClient;
});

/// Create a minimal temporary config for the main agent.
/// This is used while the real config is being loaded from the team framework.
AgentConfiguration _createTemporaryMainAgentConfig() {
  return AgentConfiguration(
    name: 'Main Triage & Operations Agent',
    description: 'Loading from team framework...',
    systemPrompt: 'Initializing main agent...',
    permissionMode: 'acceptEdits',
    mcpServers: [
      McpServerType.git,
      McpServerType.agent,
      McpServerType.taskManagement,
    ],
    allowedTools: ['Skill'],
  );
}

/// Load the real main agent config from team framework and apply the model setting.
///
/// NOTE: System prompts can't be updated at runtime, but the model CAN be changed.
/// The real config will also be used for any spawned agents.
Future<void> _loadAndApplyRealConfig({
  required TeamFrameworkLoader teamFrameworkLoader,
  required ClaudeClient client,
  required ClaudeClientFactory factory,
  required AgentId agentId,
}) async {
  try {
    // Get main agent from default team (vide)
    final team = await teamFrameworkLoader.getTeam('vide');
    if (team == null) {
      print('Warning: Team "vide" not found in team framework');
      return;
    }

    final mainAgentName = team.mainAgent;

    final config = await teamFrameworkLoader.buildAgentConfiguration(
      mainAgentName,
      teamName: 'vide',
    );
    if (config == null) {
      print('Warning: Agent configuration not found for: $mainAgentName');
      return;
    }

    // Apply the model from the config if specified
    if (config.model != null) {
      await client.initialized;
      await client.setModel(config.model!);
      print('[InitialClaudeClient] Set model to: ${config.model}');
    }

    print(
      '[InitialClaudeClient] Loaded main agent config from team framework: $mainAgentName',
    );
  } catch (e) {
    print('Error loading team framework config: $e');
  }
}
