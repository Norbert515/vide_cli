import '../utils/project_detector.dart';

import 'agent_configuration.dart';
import '../mcp/mcp_server_type.dart';
import '../utils/system_prompt_builder.dart';
import 'prompt_sections/agent/flutter_tester_agent_section.dart';
import 'prompt_sections/agent_conversation_etiquette_section.dart';
import 'prompt_sections/communication_style_section.dart';
import 'prompt_sections/task_management_section.dart';
import 'prompt_sections/tool_usage_section.dart';

/// Configuration for the Flutter tester agent that tests Flutter applications
class FlutterTesterAgentConfig {
  static const String agentName = 'Flutter Tester Agent';
  static const String version = '1.0.0';

  /// Creates a configuration for the Flutter tester agent
  static AgentConfiguration create({
    ProjectType projectType = ProjectType.unknown,
  }) {
    return AgentConfiguration(
      name: agentName,
      description: 'Tests Flutter applications using automated testing tools',
      systemPrompt: _buildSystemPrompt(projectType),
      permissionMode: 'acceptEdits',
      // Flutter tester needs Flutter Runtime, Memory, TaskManagement, and Agent (for inter-agent communication)
      mcpServers: [
        McpServerType.flutterRuntime,
        McpServerType.memory,
        McpServerType.taskManagement,
        McpServerType.agent,
      ],
    );
  }

  static String _buildSystemPrompt(ProjectType projectType) {
    final builder = SystemPromptBuilder()
      ..addSection(FlutterTesterAgentSection())
      ..addSection(AgentConversationEtiquetteSection())
      ..addSection(CommunicationStyleSection())
      ..addSection(ToolUsageSection())
      ..addSection(TaskManagementSection());

    return builder.build();
  }
}
