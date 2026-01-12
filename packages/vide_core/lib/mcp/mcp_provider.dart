import 'package:claude_sdk/claude_sdk.dart';
import 'package:flutter_runtime_mcp/flutter_runtime_mcp.dart';
import 'agent/agent_mcp_server.dart';
import 'ask_user_question/ask_user_question_server.dart';
import 'git/git_server.dart';
import 'mcp_server_type.dart';
import 'task_management/task_management_server.dart';
import 'memory_mcp_server.dart';
import 'package:riverpod/riverpod.dart';

import '../models/agent_id.dart';
import '../services/vide_config_manager.dart';

final flutterRuntimeServerProvider =
    Provider.family<FlutterRuntimeServer, AgentId>((ref, agentId) {
      final configManager = ref.read(videConfigManagerProvider);
      final useLocal = configManager.readGlobalSettings().useLocalMoondream;
      return FlutterRuntimeServer(useLocalMoondream: useLocal);
    });

/// Parameters for creating an MCP server instance.
///
/// Includes the agent ID, server type, and the project path (working directory)
/// that the server should be scoped to. This ensures MCP servers use the correct
/// project context, not the server's working directory.
class AgentIdAndMcpServerType {
  final AgentId agentId;
  final McpServerType mcpServerType;
  final String projectPath;

  AgentIdAndMcpServerType({
    required this.agentId,
    required this.mcpServerType,
    required this.projectPath,
  });

  @override
  String toString() {
    return 'AgentIdAndMcpServerType(agentId: $agentId, mcpServerType: $mcpServerType, projectPath: $projectPath)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AgentIdAndMcpServerType &&
        other.agentId == agentId &&
        other.mcpServerType == mcpServerType &&
        other.projectPath == projectPath;
  }

  @override
  int get hashCode => agentId.hashCode ^ mcpServerType.hashCode ^ projectPath.hashCode;
}

final genericMcpServerProvider = Provider.family<McpServerBase, AgentIdAndMcpServerType>((
  ref,
  params,
) {
  return switch (params.mcpServerType) {
    McpServerType.git => ref.watch(gitServerProvider(params.agentId)),
    McpServerType.agent => ref.watch(agentServerProvider(params.agentId)),
    McpServerType.memory => ref.watch(memoryServerProvider((
          agentId: params.agentId,
          projectPath: params.projectPath,
        ))),
    McpServerType.taskManagement => ref.watch(taskManagementServerProvider(params.agentId)),
    McpServerType.askUserQuestion => ref.watch(askUserQuestionServerProvider(params.agentId)),
    McpServerType.flutterRuntime => ref.watch(flutterRuntimeServerProvider(params.agentId)),
    _ => throw Exception('MCP server type not supported: ${params.mcpServerType}'),
  };
});
