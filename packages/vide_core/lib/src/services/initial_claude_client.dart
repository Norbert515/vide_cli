import 'dart:async';
import 'package:claude_sdk/claude_sdk.dart';

import '../agents/agent_configuration.dart';
import '../mcp/mcp_server_type.dart';
import 'team_framework_loader.dart';

/// Holds the initial Claude client created at app startup.
class InitialClaudeClient {
  final ClaudeClient client;
  final String agentId;
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

/// Create a minimal temporary config for the main agent.
/// This is used while the real config is being loaded from the team framework.
AgentConfiguration createTemporaryMainAgentConfig() {
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
Future<void> loadAndApplyRealConfig({
  required TeamFrameworkLoader teamFrameworkLoader,
  required ClaudeClient client,
  required String agentId,
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
