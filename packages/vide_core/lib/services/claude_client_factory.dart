import 'package:claude_api/claude_api.dart';
import 'package:riverpod/riverpod.dart';

import '../models/agent_id.dart';
import '../agents/agent_configuration.dart';
import '../mcp/mcp_provider.dart';
import 'permission_provider.dart';

/// Factory for creating ClaudeClient instances with proper configuration.
///
/// This separates client creation from network orchestration, making
/// AgentNetworkManager focused on agent lifecycle management.
abstract class ClaudeClientFactory {
  /// Creates a ClaudeClient synchronously with background initialization.
  /// The client will be usable immediately but may queue messages until init completes.
  ClaudeClient createSync({
    required AgentId agentId,
    required AgentConfiguration config,
  });

  /// Creates a ClaudeClient asynchronously, waiting for full initialization.
  Future<ClaudeClient> create({
    required AgentId agentId,
    required AgentConfiguration config,
  });
}

/// Default implementation of ClaudeClientFactory.
class ClaudeClientFactoryImpl implements ClaudeClientFactory {
  final String Function() _getWorkingDirectory;
  final Ref _ref;

  ClaudeClientFactoryImpl({
    required String Function() getWorkingDirectory,
    required Ref ref,
  })  : _getWorkingDirectory = getWorkingDirectory,
        _ref = ref;

  @override
  ClaudeClient createSync({
    required AgentId agentId,
    required AgentConfiguration config,
  }) {
    final cwd = _getWorkingDirectory();
    final claudeConfig = config.toClaudeConfig(
      workingDirectory: cwd,
      sessionId: agentId.toString(),
    );

    final mcpServers = config.mcpServers
            ?.map((server) => _ref.watch(genericMcpServerProvider(
                  AgentIdAndMcpServerType(agentId: agentId, mcpServerType: server),
                )))
            .toList() ??
        [];

    final callbackFactory = _ref.read(canUseToolCallbackFactoryProvider);
    final canUseTool = callbackFactory?.call(cwd);

    return ClaudeClient.createAndInitInBackground(
      config: claudeConfig,
      mcpServers: mcpServers,
      canUseTool: canUseTool,
    );
  }

  @override
  Future<ClaudeClient> create({
    required AgentId agentId,
    required AgentConfiguration config,
  }) async {
    final cwd = _getWorkingDirectory();
    final claudeConfig = config.toClaudeConfig(
      workingDirectory: cwd,
      sessionId: agentId.toString(),
    );

    final mcpServers = config.mcpServers
            ?.map((server) => _ref.watch(genericMcpServerProvider(
                  AgentIdAndMcpServerType(agentId: agentId, mcpServerType: server),
                )))
            .toList() ??
        [];

    final callbackFactory = _ref.read(canUseToolCallbackFactoryProvider);
    final canUseTool = callbackFactory?.call(cwd);

    return await ClaudeClient.create(
      config: claudeConfig,
      mcpServers: mcpServers,
      canUseTool: canUseTool,
    );
  }
}
