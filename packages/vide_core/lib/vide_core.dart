/// Vide Core - Shared business logic for Vide CLI
///
/// This library provides the core business logic shared between the TUI
/// and REST API implementations of Vide.
library vide_core;

// Models
export 'models/agent_network.dart';
export 'models/agent_metadata.dart';
export 'models/agent_id.dart';
export 'models/agent_status.dart';
export 'models/memory_entry.dart';
export 'models/permission.dart';

// Services
export 'services/memory_service.dart';
export 'services/vide_config_manager.dart';
export 'services/posthog_service.dart';
export 'services/permission_provider.dart';
export 'services/agent_network_persistence_manager.dart';
export 'services/agent_network_manager.dart';
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
export 'mcp/git/git/git_client.dart';
export 'mcp/git/git/git_models.dart';

// Utilities
export 'utils/project_detector.dart';
export 'utils/system_prompt_builder.dart';
export 'utils/working_dir_provider.dart';

// State Management
export 'state/agent_status_manager.dart';
