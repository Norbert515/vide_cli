import '../utils/project_detector.dart';

import 'agent_configuration.dart';
import '../mcp/mcp_server_type.dart';
import '../utils/system_prompt_builder.dart';
import 'prompt_sections/agent/core_identity_section.dart';
import 'prompt_sections/agent/main_agent_orchestration_section.dart';
import 'prompt_sections/agent_conversation_etiquette_section.dart';
import 'prompt_sections/communication_style_section.dart';
import 'prompt_sections/framework/dart_section.dart';
import 'prompt_sections/framework/nocterm_section.dart';
import 'prompt_sections/git_workflow_section.dart';
import 'prompt_sections/task_management_section.dart';
import 'prompt_sections/tool_usage_section.dart';

/// Configuration for the Main Triage & Operations Agent
///
/// This agent acts as an experienced operations/triage expert that:
/// - Assesses task complexity and certainty before acting
/// - Prioritizes caution and seeks clarification when uncertain
/// - Acts decisively only on bulletproof-certain tasks
/// - Explores the codebase to gather context
/// - Delegates to specialized sub-agents appropriately
/// - Coordinates the overall workflow
class MainAgentConfig {
  static const String agentName = 'Main Triage & Operations Agent';
  static const String version = '2.0.0';

  /// Creates a configuration for the main triage agent
  static AgentConfiguration create({
    ProjectType projectType = ProjectType.unknown,
  }) {
    return AgentConfiguration(
      name: agentName,
      description:
          'Triage & operations expert that assesses tasks, seeks clarification, and delegates to specialized agents',
      systemPrompt: _buildSystemPrompt(projectType),
      permissionMode: 'acceptEdits',
      // Main agent has access to all MCP servers EXCEPT Flutter Runtime
      // (Flutter testing is delegated to the flutter-tester sub-agent)
      mcpServers: [
        McpServerType.git,
        McpServerType.agent,
        McpServerType.memory,
        McpServerType.taskManagement,
        McpServerType.askUserQuestion,
        //McpServerType.dart,
        //McpServerType.figma,
      ],
    );
  }

  static String _buildSystemPrompt(ProjectType projectType) {
    final builder = SystemPromptBuilder()
      ..addSection(CoreIdentitySection())
      ..addSection(MainAgentOrchestrationSection())
      ..addSection(AgentConversationEtiquetteSection())
      ..addSection(GitWorkflowSection())
      ..addSection(CommunicationStyleSection())
      ..addSection(ToolUsageSection())
      ..addSection(TaskManagementSection());

    // Add framework-specific section
    // Note: Main agent does NOT get FlutterSection since it doesn't have
    // Flutter Runtime MCP access - it delegates to flutter-tester instead
    switch (projectType) {
      case ProjectType.flutter:
        // Main agent already has Flutter delegation guidance in
        // MainAgentOrchestrationSection, so no FlutterSection needed
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
