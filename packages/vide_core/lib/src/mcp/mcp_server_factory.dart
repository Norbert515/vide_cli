import 'package:claude_sdk/claude_sdk.dart';
import 'package:flutter_runtime_mcp/flutter_runtime_mcp.dart';

import '../models/agent_id.dart';
import '../services/agent_network_manager.dart';
import '../services/agent_status_registry.dart';
import '../services/trigger_service.dart';
import '../mcp/mcp_server_type.dart';
import 'agent/agent_mcp_server.dart';
import 'ask_user_question/ask_user_question_server.dart';
import 'ask_user_question/ask_user_question_service.dart';
import 'git/git_server.dart';
import 'knowledge/knowledge_mcp_server.dart';
import 'task_management/task_management_server.dart';

/// Factory for creating MCP server instances.
///
/// Replaces the Riverpod `genericMcpServerProvider.family` and individual
/// MCP server providers.
class McpServerFactory {
  final AgentNetworkManager Function() _getNetworkManager;
  final AgentStatusRegistry _statusRegistry;
  final TriggerService _triggerService;
  final AskUserQuestionService _askUserQuestionService;

  McpServerFactory({
    required AgentNetworkManager Function() getNetworkManager,
    required AgentStatusRegistry statusRegistry,
    required TriggerService triggerService,
    required AskUserQuestionService askUserQuestionService,
  }) : _getNetworkManager = getNetworkManager,
       _statusRegistry = statusRegistry,
       _triggerService = triggerService,
       _askUserQuestionService = askUserQuestionService;

  /// Create an MCP server instance for the given type and agent.
  McpServerBase create({
    required McpServerType type,
    required AgentId agentId,
    required String projectPath,
  }) {
    return switch (type) {
      McpServerType.git => GitServer(),
      McpServerType.agent => AgentMCPServer(
        callerAgentId: agentId,
        networkManager: _getNetworkManager(),
        statusRegistry: _statusRegistry,
        triggerService: _triggerService,
      ),
      McpServerType.taskManagement => TaskManagementServer(
        callerAgentId: agentId,
        networkManager: _getNetworkManager(),
        triggerService: _triggerService,
      ),
      McpServerType.askUserQuestion => AskUserQuestionServer(
        callerAgentId: agentId,
        service: _askUserQuestionService,
      ),
      McpServerType.flutterRuntime => FlutterRuntimeServer(),
      McpServerType.knowledge => KnowledgeMcpServer(
        callerAgentId: agentId,
        projectPath: projectPath,
      ),
      _ => throw Exception('MCP server type not supported: $type'),
    };
  }
}
