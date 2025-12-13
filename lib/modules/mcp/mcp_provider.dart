import 'package:claude_api/claude_api.dart';
import 'package:flutter_runtime_mcp/flutter_runtime_mcp.dart';
import 'package:vide_cli/modules/mcp/agent/agent_mcp_server.dart';
import 'package:vide_cli/modules/mcp/git/git_server.dart';
import 'package:vide_cli/modules/mcp/models/mcp_server_type.dart';
import 'package:vide_cli/modules/mcp/task_management/task_management_server.dart';
import 'package:vide_cli/modules/memory/memory_mcp_server.dart';
import 'package:riverpod/riverpod.dart';

import '../agent_network/models/agent_id.dart';

final flutterRuntimeServerProvider = Provider.family<FlutterRuntimeServer, AgentId>((ref, agentId) {
  return FlutterRuntimeServer();
});

class AgentIdAndMcpServerType {
  final AgentId agentId;
  final McpServerType mcpServerType;

  AgentIdAndMcpServerType({required this.agentId, required this.mcpServerType});

  @override
  String toString() {
    return 'AgentIdAndMcpServerType(agentId: $agentId, mcpServerType: $mcpServerType)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AgentIdAndMcpServerType && other.agentId == agentId && other.mcpServerType == mcpServerType;
  }

  @override
  int get hashCode => agentId.hashCode ^ mcpServerType.hashCode;
}

final genericMcpServerProvider = Provider.family<McpServerBase, AgentIdAndMcpServerType>((
  ref,
  agentIdAndMcpServerType,
) {
  return switch (agentIdAndMcpServerType.mcpServerType) {
    McpServerType.git => ref.watch(gitServerProvider(agentIdAndMcpServerType.agentId)),
    McpServerType.agent => ref.watch(agentServerProvider(agentIdAndMcpServerType.agentId)),
    McpServerType.memory => ref.watch(memoryServerProvider(agentIdAndMcpServerType.agentId)),
    McpServerType.taskManagement => ref.watch(taskManagementServerProvider(agentIdAndMcpServerType.agentId)),
    McpServerType.flutterRuntime => ref.watch(flutterRuntimeServerProvider(agentIdAndMcpServerType.agentId)),
    _ => throw Exception('MCP server type not supported: ${agentIdAndMcpServerType.mcpServerType}'),
  };
});
