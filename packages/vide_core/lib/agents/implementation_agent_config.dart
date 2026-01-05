import '../utils/project_detector.dart';

import 'agent_configuration.dart';
import '../mcp/mcp_server_type.dart';
import '../utils/system_prompt_builder.dart';
import 'prompt_sections/agent/implementation_agent_section.dart';
import 'prompt_sections/agent_conversation_etiquette_section.dart';
import 'prompt_sections/communication_style_section.dart';
import 'prompt_sections/framework/dart_section.dart';
import 'prompt_sections/framework/flutter_section.dart';
import 'prompt_sections/framework/nocterm_section.dart';
import 'prompt_sections/git_workflow_section.dart';
import 'prompt_sections/task_management_section.dart';
import 'prompt_sections/tool_usage_section.dart';

/// Configuration for the implementation agent that receives handoff from clarification agent
class ImplementationAgentConfig {
  static const String agentName = 'Implementation Agent';
  static const String version = '1.0.0';

  /// Creates a configuration for the implementation agent
  static AgentConfiguration create({
    ProjectType projectType = ProjectType.unknown,
  }) {
    return AgentConfiguration(
      name: agentName,
      description: 'Implements features and fixes based on clear requirements',
      systemPrompt: _buildSystemPrompt(projectType),
      permissionMode: 'acceptEdits',
      // Implementation agent needs Git, Memory, TaskManagement, Dart, and Flutter Runtime
      // but NOT SubAgent (should not spawn more agents)
      mcpServers: [
        McpServerType.git,
        McpServerType.memory,
        McpServerType.taskManagement,
        McpServerType.flutterRuntime,
        McpServerType.agent,
      ],
    );
  }

  static String _buildSystemPrompt(ProjectType projectType) {
    final builder = SystemPromptBuilder()
      ..addSection(ImplementationAgentSection())
      ..addSection(AgentConversationEtiquetteSection())
      ..addSection(GitWorkflowSection())
      ..addSection(CommunicationStyleSection())
      ..addSection(ToolUsageSection())
      ..addSection(TaskManagementSection());

    // Add framework-specific section
    switch (projectType) {
      case ProjectType.flutter:
        builder.addSection(FlutterSection());
        break;
      case ProjectType.dart:
        builder.addSection(DartSection());
        break;
      case ProjectType.nocterm:
        builder.addSection(NoctermSection());
        break;
      case ProjectType.unknown:
        // No framework-specific section
        break;
    }

    return builder.build();
  }
}
