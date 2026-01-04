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
  ClaudeClient createSync({
    required AgentId agentId,
    required AgentConfiguration config,
    String? networkId,
    String? agentType,
  });

  /// Creates a ClaudeClient asynchronously, waiting for full initialization.
  ///
  /// [networkId] is the ID of the agent network (session ID in REST API).
  /// [agentType] is the type of agent (e.g., 'main', 'implementation').
  Future<ClaudeClient> create({
    required AgentId agentId,
    required AgentConfiguration config,
    String? networkId,
    String? agentType,
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

  @override
  ClaudeClient createSync({
    required AgentId agentId,
    required AgentConfiguration config,
    String? networkId,
    String? agentType,
  }) {
    final cwd = _getWorkingDirectory();
    final claudeConfig = config.toClaudeConfig(
      workingDirectory: cwd,
      sessionId: agentId.toString(),
      enableStreaming: _enableStreaming,
    );

    final mcpServers = config.mcpServers
            ?.map((server) => _ref.watch(genericMcpServerProvider(
                  AgentIdAndMcpServerType(
                    agentId: agentId,
                    mcpServerType: server,
                    projectPath: cwd,
                  ),
                )))
            .toList() ??
        [];

    final callbackFactory = _ref.read(canUseToolCallbackFactoryProvider);
    final canUseTool = callbackFactory?.call(PermissionCallbackContext(
      cwd: cwd,
      agentId: agentId,
      agentName: config.name,
      agentType: agentType,
      permissionMode: config.permissionMode,
      networkId: networkId,
    ));

    return ClaudeClient.createNonBlocking(
      config: claudeConfig,
      mcpServers: mcpServers,
      canUseTool: canUseTool,
    );
  }

  @override
  Future<ClaudeClient> create({
    required AgentId agentId,
    required AgentConfiguration config,
    String? networkId,
    String? agentType,
  }) async {
    final cwd = _getWorkingDirectory();
    final claudeConfig = config.toClaudeConfig(
      workingDirectory: cwd,
      sessionId: agentId.toString(),
      enableStreaming: _enableStreaming,
    );

    final mcpServers = config.mcpServers
            ?.map((server) => _ref.watch(genericMcpServerProvider(
                  AgentIdAndMcpServerType(
                    agentId: agentId,
                    mcpServerType: server,
                    projectPath: cwd,
                  ),
                )))
            .toList() ??
        [];

    final callbackFactory = _ref.read(canUseToolCallbackFactoryProvider);
    final canUseTool = callbackFactory?.call(PermissionCallbackContext(
      cwd: cwd,
      agentId: agentId,
      agentName: config.name,
      agentType: agentType,
      permissionMode: config.permissionMode,
      networkId: networkId,
    ));

    return await ClaudeClient.create(
      config: claudeConfig,
      mcpServers: mcpServers,
      canUseTool: canUseTool,
    );
  }
}
