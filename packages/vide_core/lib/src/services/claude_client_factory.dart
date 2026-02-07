import 'package:claude_sdk/claude_sdk.dart';

import '../models/agent_id.dart';
import '../agents/agent_configuration.dart';
import '../mcp/mcp_server_factory.dart';
import 'permission_provider.dart';
import 'vide_config_manager.dart';

/// Factory for creating ClaudeClient instances with proper configuration.
///
/// This separates client creation from network orchestration, making
/// AgentNetworkManager focused on agent lifecycle management.
abstract class ClaudeClientFactory {
  /// Creates a ClaudeClient synchronously with background initialization.
  /// The client will be usable immediately but may queue messages until init completes.
  ///
  /// [networkId] is the ID of the agent network (session ID in REST API).
  /// [agentType] is the type of agent (e.g., 'main', 'implementation').
  /// [workingDirectory] is an optional override for the working directory.
  /// If null, uses the session's effective working directory.
  ClaudeClient createSync({
    required AgentId agentId,
    required AgentConfiguration config,
    String? networkId,
    String? agentType,
    String? workingDirectory,
  });

  /// Creates a ClaudeClient asynchronously, waiting for full initialization.
  ///
  /// [networkId] is the ID of the agent network (session ID in REST API).
  /// [agentType] is the type of agent (e.g., 'main', 'implementation').
  /// [workingDirectory] is an optional override for the working directory.
  /// If null, uses the session's effective working directory.
  Future<ClaudeClient> create({
    required AgentId agentId,
    required AgentConfiguration config,
    String? networkId,
    String? agentType,
    String? workingDirectory,
  });

  /// Creates a ClaudeClient by forking an existing session.
  ///
  /// Uses Claude Code's native --fork-session capability to branch the conversation.
  /// The new client will have the full conversation history from the source session.
  ///
  /// [agentId] - The ID for the new forked agent
  /// [config] - Agent configuration for the new agent
  /// [networkId] - The ID of the agent network
  /// [agentType] - The type of agent (e.g., 'main', 'implementation')
  /// [resumeSessionId] - The session ID to fork from
  /// [sourceConversation] - The conversation from the source agent (for immediate UI display)
  /// [workingDirectory] - Optional override for the working directory.
  /// If null, uses the session's effective working directory.
  Future<ClaudeClient> createForked({
    required AgentId agentId,
    required AgentConfiguration config,
    String? networkId,
    String? agentType,
    required String resumeSessionId,
    Conversation? sourceConversation,
    String? workingDirectory,
  });
}

/// Default implementation of ClaudeClientFactory.
class ClaudeClientFactoryImpl implements ClaudeClientFactory {
  final String Function() _getWorkingDirectory;
  final VideConfigManager _configManager;
  final PermissionHandler? _permissionHandler;
  final McpServerFactory _mcpServerFactory;
  final bool Function() _getDangerouslySkipPermissions;

  ClaudeClientFactoryImpl({
    required String Function() getWorkingDirectory,
    required VideConfigManager configManager,
    required PermissionHandler permissionHandler,
    required McpServerFactory mcpServerFactory,
    required bool Function() getDangerouslySkipPermissions,
  }) : _getWorkingDirectory = getWorkingDirectory,
       _configManager = configManager,
       _permissionHandler = permissionHandler,
       _mcpServerFactory = mcpServerFactory,
       _getDangerouslySkipPermissions = getDangerouslySkipPermissions;

  /// Gets the enableStreaming setting from global settings.
  bool get _enableStreaming {
    return _configManager.readGlobalSettings().enableStreaming;
  }

  /// Gets the dangerouslySkipPermissions setting.
  ///
  /// Returns true if EITHER:
  /// - The session-scoped flag is true (set via CLI flag, session-only)
  /// - The global setting is true (set via settings UI, persistent)
  ///
  /// DANGEROUS: Only true in sandboxed environments (Docker).
  bool get _dangerouslySkipPermissions {
    // Check session-scoped override first (CLI flag)
    if (_getDangerouslySkipPermissions()) {
      return true;
    }
    // Fall back to global setting (settings UI)
    return _configManager.readGlobalSettings().dangerouslySkipPermissions;
  }

  List<McpServerBase> _createMcpServers({
    required AgentConfiguration config,
    required AgentId agentId,
    required String cwd,
  }) {
    return config.mcpServers
            ?.map(
              (server) => _mcpServerFactory.create(
                type: server,
                agentId: agentId,
                projectPath: cwd,
              ),
            )
            .toList() ??
        [];
  }

  @override
  ClaudeClient createSync({
    required AgentId agentId,
    required AgentConfiguration config,
    String? networkId,
    String? agentType,
    String? workingDirectory,
  }) {
    final cwd = workingDirectory ?? _getWorkingDirectory();
    final claudeConfig = config.toClaudeConfig(
      workingDirectory: cwd,
      sessionId: agentId.toString(),
      enableStreaming: _enableStreaming,
      dangerouslySkipPermissions: _dangerouslySkipPermissions,
    );

    final mcpServers = _createMcpServers(
      config: config,
      agentId: agentId,
      cwd: cwd,
    );

    final canUseTool = _createPermissionCallback(
      cwd: cwd,
      agentId: agentId,
      agentName: config.name,
      agentType: agentType,
      permissionMode: config.permissionMode,
    );

    final client = ClaudeClient.createNonBlocking(
      config: claudeConfig,
      mcpServers: mcpServers,
      canUseTool: canUseTool,
    );

    return client;
  }

  @override
  Future<ClaudeClient> create({
    required AgentId agentId,
    required AgentConfiguration config,
    String? networkId,
    String? agentType,
    String? workingDirectory,
  }) async {
    final cwd = workingDirectory ?? _getWorkingDirectory();
    final claudeConfig = config.toClaudeConfig(
      workingDirectory: cwd,
      sessionId: agentId.toString(),
      enableStreaming: _enableStreaming,
      dangerouslySkipPermissions: _dangerouslySkipPermissions,
    );

    final mcpServers = _createMcpServers(
      config: config,
      agentId: agentId,
      cwd: cwd,
    );

    final canUseTool = _createPermissionCallback(
      cwd: cwd,
      agentId: agentId,
      agentName: config.name,
      agentType: agentType,
      permissionMode: config.permissionMode,
    );

    final client = await ClaudeClient.create(
      config: claudeConfig,
      mcpServers: mcpServers,
      canUseTool: canUseTool,
    );

    return client;
  }

  @override
  Future<ClaudeClient> createForked({
    required AgentId agentId,
    required AgentConfiguration config,
    String? networkId,
    String? agentType,
    required String resumeSessionId,
    Conversation? sourceConversation,
    String? workingDirectory,
  }) async {
    final cwd = workingDirectory ?? _getWorkingDirectory();

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

    final mcpServers = _createMcpServers(
      config: config,
      agentId: agentId,
      cwd: cwd,
    );

    final canUseTool = _createPermissionCallback(
      cwd: cwd,
      agentId: agentId,
      agentName: config.name,
      agentType: agentType,
      permissionMode: config.permissionMode,
    );

    // Use createNonBlocking to avoid hanging on init
    // Pass sourceConversation so the forked agent shows the same history immediately
    final client = ClaudeClient.createNonBlocking(
      config: claudeConfig,
      mcpServers: mcpServers,
      canUseTool: canUseTool,
      initialConversation: sourceConversation,
    );

    return client;
  }

  /// Creates a permission callback for the given agent context.
  ///
  /// Uses the PermissionHandler for late session binding if available.
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

    return handler.createCallback(
      cwd: cwd,
      agentId: agentId,
      agentName: agentName,
      agentType: agentType,
      permissionMode: permissionMode,
    );
  }
}
