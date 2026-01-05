import '../utils/project_detector.dart';

import 'agent_configuration.dart';
import '../mcp/mcp_server_type.dart';
import '../utils/system_prompt_builder.dart';
import 'prompt_sections/agent/planning_agent_section.dart';
import 'prompt_sections/agent_conversation_etiquette_section.dart';
import 'prompt_sections/communication_style_section.dart';
import 'prompt_sections/framework/dart_section.dart';
import 'prompt_sections/framework/flutter_section.dart';
import 'prompt_sections/framework/nocterm_section.dart';
import 'prompt_sections/task_management_section.dart';
import 'prompt_sections/tool_usage_section.dart';

/// Configuration for the Planning Agent
///
/// This agent creates detailed implementation plans for complex tasks
/// and presents them for user approval before implementation begins.
class PlanningAgentConfig {
  static const String agentName = 'Planning Agent';
  static const String version = '1.0.0';

  /// Creates a configuration for the planning agent
  static AgentConfiguration create({
    ProjectType projectType = ProjectType.unknown,
  }) {
    return AgentConfiguration(
      name: agentName,
      description: 'Creates detailed implementation plans for complex tasks',
      systemPrompt: _buildSystemPrompt(projectType),
      permissionMode: 'plan', // Planning agent should not execute code
      // Planning agent needs read access + memory, but no Git/Flutter Runtime
      mcpServers: [
        McpServerType.memory,
        McpServerType.taskManagement,
        McpServerType.agent,
      ],
    );
  }

  static String _buildSystemPrompt(ProjectType projectType) {
    final builder = SystemPromptBuilder()
      ..addSection(PlanningAgentSection())
      ..addSection(AgentConversationEtiquetteSection())
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
