import 'package:agent_sdk/agent_sdk.dart';
import 'package:claude_sdk/claude_sdk.dart';

import '../logging/vide_logger.dart';
import '../models/agent_id.dart';
import 'agent_configuration.dart';
import '../mcp/mcp_server_type.dart';
import '../permissions/permission_provider.dart';
import '../configuration/vide_config_manager.dart';

/// Factory for creating AgentClient instances with proper configuration.
///
/// This separates client creation from network orchestration, making
/// AgentNetworkManager focused on agent lifecycle management.
abstract class AgentClientFactory {
  /// Creates an AgentClient synchronously with background initialization.
  /// The client will be usable immediately but may queue messages until init completes.
  ///
  /// [networkId] is the ID of the agent network (session ID in REST API).
  /// [agentType] is the type of agent (e.g., 'main', 'implementation').
  /// [workingDirectory] is an optional override for the working directory.
  /// If null, uses the session's effective working directory.
  AgentClient createSync({
    required AgentId agentId,
    required AgentConfiguration config,
    String? networkId,
    String? agentType,
    String? workingDirectory,
  });

  /// Creates an AgentClient asynchronously, waiting for full initialization.
  ///
  /// [networkId] is the ID of the agent network (session ID in REST API).
  /// [agentType] is the type of agent (e.g., 'main', 'implementation').
  /// [workingDirectory] is an optional override for the working directory.
  /// If null, uses the session's effective working directory.
  Future<AgentClient> create({
    required AgentId agentId,
    required AgentConfiguration config,
    String? networkId,
    String? agentType,
    String? workingDirectory,
  });

  /// Creates an AgentClient by forking an existing session.
  ///
  /// Uses Claude Code's native --fork-session capability to branch the conversation.
  /// The new client will have the full conversation history from the source session.
  ///
  /// [agentId] - The ID for the new forked agent
  /// [config] - Agent configuration for the new agent
  /// [networkId] - The ID of the agent network
  /// [agentType] - The type of agent (e.g., 'main', 'implementation')
  /// [resumeSessionId] - The session ID to fork from
  /// [sourceConversation] - The conversation from the source agent (for immediate UI display).
  /// [workingDirectory] - Optional override for the working directory.
  /// If null, uses the session's effective working directory.
  Future<AgentClient> createForked({
    required AgentId agentId,
    required AgentConfiguration config,
    String? networkId,
    String? agentType,
    required String resumeSessionId,
    AgentConversation? sourceConversation,
    String? workingDirectory,
  });
}

/// Claude-specific implementation of AgentClientFactory.
///
/// Creates ClaudeClient instances internally and wraps them in
/// ClaudeAgentClient to expose the AgentClient interface.
class ClaudeAgentClientFactory implements AgentClientFactory {
  final String Function() _getWorkingDirectory;
  final VideConfigManager _configManager;
  final bool Function() _getDangerouslySkipPermissions;
  final McpServerBase Function(AgentId agentId, McpServerType type, String projectPath) _createMcpServer;
  final PermissionHandler? _permissionHandler;

  ClaudeAgentClientFactory({
    required String Function() getWorkingDirectory,
    required VideConfigManager configManager,
    required bool Function() getDangerouslySkipPermissions,
    required McpServerBase Function(AgentId agentId, McpServerType type, String projectPath) createMcpServer,
    PermissionHandler? permissionHandler,
  }) : _getWorkingDirectory = getWorkingDirectory,
       _configManager = configManager,
       _getDangerouslySkipPermissions = getDangerouslySkipPermissions,
       _createMcpServer = createMcpServer,
       _permissionHandler = permissionHandler;

  /// Gets the enableStreaming setting from global settings.
  bool get _enableStreaming {
    return _configManager.readGlobalSettings().enableStreaming;
  }

  /// Gets the dangerouslySkipPermissions setting.
  ///
  /// Returns true if EITHER:
  /// - The session-scoped provider is true (set via CLI flag, session-only)
  /// - The global setting is true (set via settings UI, persistent)
  ///
  /// DANGEROUS: Only true in sandboxed environments (Docker).
  bool get _dangerouslySkipPermissions {
    return _getDangerouslySkipPermissions();
  }

  @override
  AgentClient createSync({
    required AgentId agentId,
    required AgentConfiguration config,
    String? networkId,
    String? agentType,
    String? workingDirectory,
  }) {
    final cwd = workingDirectory ?? _getWorkingDirectory();
    VideLogger.instance.info(
      'AgentClientFactory',
      'createSync: agent=$agentId type=$agentType cwd=$cwd '
      'permissionHandler=${_permissionHandler != null}',
      sessionId: networkId,
    );
    final claudeConfig = config.toClaudeConfig(
      workingDirectory: cwd,
      sessionId: agentId.toString(),
      enableStreaming: _enableStreaming,
      dangerouslySkipPermissions: _dangerouslySkipPermissions,
    );

    final mcpServers =
        config.mcpServers
            ?.map(
              (server) => _createMcpServer(agentId, server, cwd),
            )
            .toList() ??
        [];

    final canUseTool = _createPermissionCallback(
      cwd: cwd,
      agentId: agentId,
      agentName: config.name,
      agentType: agentType,
      permissionMode: config.permissionMode,
    );

    final claudeClient = ClaudeClient.createNonBlocking(
      config: claudeConfig,
      mcpServers: mcpServers,
      canUseTool: canUseTool,
    );

    return ClaudeAgentClient(claudeClient);
  }

  @override
  Future<AgentClient> create({
    required AgentId agentId,
    required AgentConfiguration config,
    String? networkId,
    String? agentType,
    String? workingDirectory,
  }) async {
    final cwd = workingDirectory ?? _getWorkingDirectory();
    VideLogger.instance.info(
      'AgentClientFactory',
      'create (async): agent=$agentId type=$agentType cwd=$cwd',
      sessionId: networkId,
    );
    final claudeConfig = config.toClaudeConfig(
      workingDirectory: cwd,
      sessionId: agentId.toString(),
      enableStreaming: _enableStreaming,
      dangerouslySkipPermissions: _dangerouslySkipPermissions,
    );

    final mcpServers =
        config.mcpServers
            ?.map(
              (server) => _createMcpServer(agentId, server, cwd),
            )
            .toList() ??
        [];

    final canUseTool = _createPermissionCallback(
      cwd: cwd,
      agentId: agentId,
      agentName: config.name,
      agentType: agentType,
      permissionMode: config.permissionMode,
    );

    final claudeClient = await ClaudeClient.create(
      config: claudeConfig,
      mcpServers: mcpServers,
      canUseTool: canUseTool,
    );

    return ClaudeAgentClient(claudeClient);
  }

  @override
  Future<AgentClient> createForked({
    required AgentId agentId,
    required AgentConfiguration config,
    String? networkId,
    String? agentType,
    required String resumeSessionId,
    AgentConversation? sourceConversation,
    String? workingDirectory,
  }) async {
    final cwd = workingDirectory ?? _getWorkingDirectory();
    VideLogger.instance.info(
      'AgentClientFactory',
      'createForked: agent=$agentId type=$agentType '
      'forkFrom=$resumeSessionId cwd=$cwd',
      sessionId: networkId,
    );

    // Create config with fork settings
    final baseConfig = config.toClaudeConfig(
      workingDirectory: cwd,
      sessionId: agentId.toString(),
      enableStreaming: _enableStreaming,
      dangerouslySkipPermissions: _dangerouslySkipPermissions,
    );

    // Apply fork settings
    final claudeConfig = baseConfig.copyWith(
      resumeSessionId: resumeSessionId,
      forkSession: true,
    );

    final mcpServers =
        config.mcpServers
            ?.map(
              (server) => _createMcpServer(agentId, server, cwd),
            )
            .toList() ??
        [];

    final canUseTool = _createPermissionCallback(
      cwd: cwd,
      agentId: agentId,
      agentName: config.name,
      agentType: agentType,
      permissionMode: config.permissionMode,
    );

    // Use createNonBlocking to avoid hanging on init
    // Pass sourceConversation so the forked agent shows the same history immediately
    final claudeClient = ClaudeClient.createNonBlocking(
      config: claudeConfig,
      mcpServers: mcpServers,
      canUseTool: canUseTool,
      initialConversation: sourceConversation != null
          ? AgentConversationMapper.toClaude(sourceConversation)
          : null,
    );

    return ClaudeAgentClient(claudeClient);
  }

  /// Creates a permission callback for the given agent context.
  ///
  /// Gets an [AgentCanUseToolCallback] from the [PermissionHandler] and
  /// bridges it to the claude_sdk [CanUseToolCallback] type.
  CanUseToolCallback? _createPermissionCallback({
    required String cwd,
    required AgentId agentId,
    required String? agentName,
    required String? agentType,
    String? permissionMode,
  }) {
    final handler = _permissionHandler;
    if (handler == null) {
      // No permission handler - no permission checking (auto-allow)
      return null;
    }

    final agentCallback = handler.createCallback(
      cwd: cwd,
      agentId: agentId,
      agentName: agentName,
      agentType: agentType,
      permissionMode: permissionMode,
    );

    // Bridge from AgentCanUseToolCallback to claude_sdk CanUseToolCallback
    return (String toolName, Map<String, dynamic> input, ToolPermissionContext context) async {
      final agentContext = AgentPermissionContextMapper.fromClaude(context);
      final agentResult = await agentCallback(toolName, input, agentContext);
      return AgentPermissionMapper.toClaude(agentResult);
    };
  }
}
