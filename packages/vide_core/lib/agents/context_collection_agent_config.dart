import '../utils/project_detector.dart';

import 'agent_configuration.dart';
import '../mcp/mcp_server_type.dart';
import '../utils/system_prompt_builder.dart';
import 'prompt_sections/agent/context_collection_agent_section.dart';
import 'prompt_sections/agent_conversation_etiquette_section.dart';
import 'prompt_sections/communication_style_section.dart';
import 'prompt_sections/framework/dart_section.dart';
import 'prompt_sections/framework/flutter_section.dart';
import 'prompt_sections/framework/nocterm_section.dart';
import 'prompt_sections/task_management_section.dart';
import 'prompt_sections/tool_usage_section.dart';

/// Configuration for the context collection agent that performs deep research
/// and information gathering about frameworks, packages, and technologies.
class ContextCollectionAgentConfig {
  static const String agentName = 'Context Collection Agent';
  static const String version = '1.0.0';

  /// Creates a configuration for the context collection agent
  static AgentConfiguration create({
    ProjectType projectType = ProjectType.unknown,
  }) {
    return AgentConfiguration(
      name: agentName,
      description:
          'Performs deep research and information gathering about frameworks, packages, and technologies',
      systemPrompt: _buildSystemPrompt(projectType),
      // Context collection agent only needs read-only tools + web search
      // No Git, no SubAgent, no Flutter Runtime
      mcpServers: [
        McpServerType.memory,
        McpServerType.taskManagement,
        McpServerType.agent,
      ],
    );
  }

  static String _buildSystemPrompt(ProjectType projectType) {
    final builder = SystemPromptBuilder()
      ..addSection(ContextCollectionAgentSection())
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
