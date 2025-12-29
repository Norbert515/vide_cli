/// Vide Core - Shared business logic for Vide CLI
///
/// This library provides the core business logic shared between the TUI
/// and REST API implementations of Vide.
library vide_core;

// Version
export 'version.dart';

// Models
export 'models/agent_network.dart';
export 'models/agent_metadata.dart';
export 'models/agent_id.dart';
export 'models/agent_status.dart';
export 'models/memory_entry.dart';
export 'models/vide_global_settings.dart';

// Services
export 'services/memory_service.dart';
export 'services/vide_config_manager.dart';
export 'services/posthog_service.dart';
export 'services/auto_update_service.dart';
export 'services/permission_provider.dart';
export 'services/agent_network_persistence_manager.dart';
export 'services/agent_network_manager.dart';
export 'services/claude_client_factory.dart';
export 'services/claude_manager.dart';

// Agents
export 'agents/agent_configuration.dart';
export 'agents/user_defined_agent.dart';
export 'agents/agent_loader.dart';
export 'agents/main_agent_config.dart';
export 'agents/implementation_agent_config.dart';
export 'agents/context_collection_agent_config.dart';
export 'agents/planning_agent_config.dart';
export 'agents/flutter_tester_agent_config.dart';

// MCP Servers
export 'mcp/mcp_server_type.dart';
export 'mcp/mcp_provider.dart';
export 'mcp/memory_mcp_server.dart';
export 'mcp/git/git_client.dart';
export 'mcp/git/git_models.dart';
export 'mcp/git/git_exception.dart';
export 'mcp/ask_user_question/ask_user_question_types.dart';
export 'mcp/ask_user_question/ask_user_question_service.dart';
export 'mcp/ask_user_question/ask_user_question_server.dart';

// Utilities
export 'utils/project_detector.dart';
export 'utils/system_prompt_builder.dart';
export 'utils/working_dir_provider.dart';

// State Management
export 'state/agent_status_manager.dart';

// Permissions
export 'services/permissions/permission_matcher.dart';
export 'services/permissions/bash_command_parser.dart';
export 'services/permissions/safe_commands.dart';
export 'services/permissions/pattern_inference.dart';
export 'services/permissions/gitignore_matcher.dart';
export 'services/permissions/permission_checker.dart';
export 'services/permissions/tool_input.dart';

// Settings
export 'services/settings/local_settings_manager.dart';
export 'models/claude_settings.dart';
