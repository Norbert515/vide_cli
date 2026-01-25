import 'package:claude_sdk/claude_sdk.dart';
import 'package:riverpod/riverpod.dart';

import '../models/agent_id.dart';
import '../agents/agent_configuration.dart';
import '../mcp/mcp_provider.dart';
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
  final Ref _ref;

  ClaudeClientFactoryImpl({
    required String Function() getWorkingDirectory,
    required Ref ref,
  }) : _getWorkingDirectory = getWorkingDirectory,
       _ref = ref;

  /// Gets the enableStreaming setting from global settings.
  bool get _enableStreaming {
    final configManager = _ref.read(videConfigManagerProvider);
    return configManager.readGlobalSettings().enableStreaming;
  }

  /// Gets the dangerouslySkipPermissions setting from global settings.
  /// DANGEROUS: Only true in sandboxed environments (Docker).
  bool get _dangerouslySkipPermissions {
    final configManager = _ref.read(videConfigManagerProvider);
    return configManager.readGlobalSettings().dangerouslySkipPermissions;
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

    final mcpServers =
        config.mcpServers
            ?.map(
              (server) => _ref.watch(
                genericMcpServerProvider(
                  AgentIdAndMcpServerType(
                    agentId: agentId,
                    mcpServerType: server,
                    projectPath: cwd,
                  ),
                ),
              ),
            )
            .toList() ??
        [];

    final callbackFactory = _ref.read(canUseToolCallbackFactoryProvider);
    final canUseTool = callbackFactory?.call(
      PermissionCallbackContext(
        cwd: cwd,
        agentId: agentId,
        agentName: config.name,
        agentType: agentType,
        permissionMode: config.permissionMode,
        networkId: networkId,
      ),
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

    final mcpServers =
        config.mcpServers
            ?.map(
              (server) => _ref.watch(
                genericMcpServerProvider(
                  AgentIdAndMcpServerType(
                    agentId: agentId,
                    mcpServerType: server,
                    projectPath: cwd,
                  ),
                ),
              ),
            )
            .toList() ??
        [];

    final callbackFactory = _ref.read(canUseToolCallbackFactoryProvider);
    final canUseTool = callbackFactory?.call(
      PermissionCallbackContext(
        cwd: cwd,
        agentId: agentId,
        agentName: config.name,
        agentType: agentType,
        permissionMode: config.permissionMode,
        networkId: networkId,
      ),
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

    final mcpServers =
        config.mcpServers
            ?.map(
              (server) => _ref.watch(
                genericMcpServerProvider(
                  AgentIdAndMcpServerType(
                    agentId: agentId,
                    mcpServerType: server,
                    projectPath: cwd,
                  ),
                ),
              ),
            )
            .toList() ??
        [];

    final callbackFactory = _ref.read(canUseToolCallbackFactoryProvider);
    final canUseTool = callbackFactory?.call(
      PermissionCallbackContext(
        cwd: cwd,
        agentId: agentId,
        agentName: config.name,
        agentType: agentType,
        permissionMode: config.permissionMode,
        networkId: networkId,
      ),
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
}
