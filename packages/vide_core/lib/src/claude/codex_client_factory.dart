import 'dart:async';

import 'package:agent_sdk/agent_sdk.dart';
import 'package:claude_sdk/claude_sdk.dart' show McpServerBase;
import 'package:codex_sdk/codex_sdk.dart';

import '../logging/vide_logger.dart';
import '../models/agent_id.dart';
import '../mcp/mcp_server_type.dart';
import 'agent_configuration.dart';
import 'claude_client_factory.dart';

/// Codex-specific implementation of [AgentClientFactory].
///
/// Creates [CodexClient] instances internally and wraps them in
/// [CodexAgentClient] to expose the [AgentClient] interface.
///
/// Unlike [ClaudeAgentClientFactory], this factory does not support:
/// - Permission callbacks (Codex has its own approval system)
/// - Session forking
/// - Streaming configuration
/// - DangerouslySkipPermissions
class CodexAgentClientFactory implements AgentClientFactory {
  final String Function() _getWorkingDirectory;
  final McpServerBase Function(
    AgentId agentId,
    McpServerType type,
    String projectPath,
  ) _createMcpServer;

  CodexAgentClientFactory({
    required String Function() getWorkingDirectory,
    required McpServerBase Function(
      AgentId agentId,
      McpServerType type,
      String projectPath,
    ) createMcpServer,
  }) : _getWorkingDirectory = getWorkingDirectory,
       _createMcpServer = createMcpServer;

  @override
  bool get supportsFork => false;

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
      'CodexAgentClientFactory',
      'createSync: agent=$agentId type=$agentType cwd=$cwd',
      sessionId: networkId,
    );
    final codexConfig = _buildConfig(config, agentId, cwd);

    final mcpServers = config.mcpServers
            ?.map((server) => _createMcpServer(agentId, server, cwd))
            .toList() ??
        [];

    final client = CodexClient(
      codexConfig: codexConfig,
      mcpServers: mcpServers,
    );

    // Fire-and-forget init — client queues messages until ready
    unawaited(client.init());

    return CodexAgentClient(client);
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
      'CodexAgentClientFactory',
      'create (async): agent=$agentId type=$agentType cwd=$cwd',
      sessionId: networkId,
    );
    final codexConfig = _buildConfig(config, agentId, cwd);

    final mcpServers = config.mcpServers
            ?.map((server) => _createMcpServer(agentId, server, cwd))
            .toList() ??
        [];

    final client = CodexClient(
      codexConfig: codexConfig,
      mcpServers: mcpServers,
    );

    await client.init();

    return CodexAgentClient(client);
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
  }) {
    throw UnsupportedError('Codex does not support session forking');
  }

  CodexConfig _buildConfig(
    AgentConfiguration config,
    AgentId agentId,
    String cwd,
  ) {
    return CodexConfig(
      // Don't pass config.model — AgentConfiguration uses Claude model names
      // (e.g., "opus") which are invalid for Codex. Let Codex use its default.
      workingDirectory: cwd,
      sessionId: agentId.toString(),
      appendSystemPrompt: config.systemPrompt,
    );
  }
}
