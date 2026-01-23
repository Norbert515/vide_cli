/// vide_core - Shared business logic for Vide CLI.
///
/// This is the single barrel export for vide_core.
/// Import this file to access all vide_core functionality.
///
/// ```dart
/// import 'package:vide_core/vide_core.dart';
/// ```
library vide_core;

// Version
export 'version.dart';

// =============================================================================
// Main Entry Point
// =============================================================================
export 'src/vide_core_impl.dart' show VideCore;

// =============================================================================
// API Classes
// =============================================================================
export 'src/api/vide_session.dart';
export 'src/api/vide_event.dart';
export 'src/api/vide_agent.dart';
export 'src/api/vide_config.dart';
export 'src/api/embedded_server.dart';
export 'src/api/conversation_state.dart';

// =============================================================================
// Models
// =============================================================================
export 'src/models/agent_network.dart';
export 'src/models/agent_metadata.dart';
export 'src/models/agent_id.dart';
export 'src/models/agent_status.dart';
export 'src/models/mcp_server_info.dart';
export 'src/models/vide_global_settings.dart';
export 'src/models/claude_settings.dart';
export 'src/models/team_framework/team_framework.dart';

// =============================================================================
// Services
// =============================================================================
export 'src/services/vide_config_manager.dart';
export 'src/services/posthog_service.dart';
export 'src/services/auto_update_service.dart';
export 'src/services/permission_provider.dart';
export 'src/services/agent_network_persistence_manager.dart';
export 'src/services/agent_network_manager.dart';
export 'src/services/claude_client_factory.dart';
export 'src/services/claude_manager.dart';
export 'src/services/initial_claude_client.dart';
export 'src/services/team_framework_loader.dart';
export 'src/services/team_framework_asset_initializer.dart';
export 'src/services/trigger_service.dart';

// Permissions
export 'src/services/permissions/permission_matcher.dart';
export 'src/services/permissions/bash_command_parser.dart';
export 'src/services/permissions/safe_commands.dart';
export 'src/services/permissions/pattern_inference.dart';
export 'src/services/permissions/gitignore_matcher.dart';
export 'src/services/permissions/permission_checker.dart';
export 'src/services/permissions/tool_input.dart';
export 'src/services/permissions/permissions.dart';

// Settings
export 'src/services/settings/local_settings_manager.dart';

// =============================================================================
// Agents
// =============================================================================
export 'src/agents/agent_configuration.dart';
export 'src/agents/user_defined_agent.dart';
export 'src/agents/agent_loader.dart';

// =============================================================================
// MCP Servers
// =============================================================================
export 'src/mcp/mcp_server_type.dart';
export 'src/mcp/mcp_provider.dart';
export 'src/mcp/agent/agent_mcp_server.dart';
export 'src/mcp/task_management/task_management_server.dart';

// Git
export 'src/mcp/git/git_client.dart';
export 'src/mcp/git/git_models.dart';
export 'src/mcp/git/git_exception.dart';
export 'src/mcp/git/git_status_watcher.dart';
export 'src/mcp/git/git_providers.dart';
export 'src/mcp/git/git_server.dart';

// Ask User Question
export 'src/mcp/ask_user_question/ask_user_question_types.dart';
export 'src/mcp/ask_user_question/ask_user_question_service.dart';
export 'src/mcp/ask_user_question/ask_user_question_server.dart';

// Knowledge
export 'src/mcp/knowledge/knowledge_service.dart';
export 'src/mcp/knowledge/knowledge_mcp_server.dart';

// =============================================================================
// Utilities
// =============================================================================
export 'src/utils/project_detector.dart';
export 'src/utils/working_dir_provider.dart';

// =============================================================================
// State Management
// =============================================================================
export 'src/state/agent_status_manager.dart';

// =============================================================================
// Claude SDK Re-exports
// =============================================================================
export 'package:claude_sdk/claude_sdk.dart'
    show
        Conversation,
        ConversationMessage,
        MessageRole,
        McpServerBase,
        McpStatusResponse,
        McpServerStatusInfo,
        Message,
        Attachment,
        ClaudeStatus,
        ToolPermissionContext,
        PermissionResult,
        PermissionResultAllow,
        PermissionResultDeny,
        ClaudeSettingsManager;
