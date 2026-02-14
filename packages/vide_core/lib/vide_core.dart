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
// Shared Interface Types (from vide_interface)
// =============================================================================
export 'package:vide_interface/vide_interface.dart';

// =============================================================================
// API Classes
// =============================================================================
export 'src/api/vide_session.dart' show LocalVideSession;
export 'src/api/local_vide_session_manager.dart' show LocalVideSessionManager;

// =============================================================================
// Models (shared across features)
// =============================================================================
export 'src/models/agent_network.dart';
export 'src/models/agent_metadata.dart';
export 'src/models/agent_id.dart';
export 'src/models/agent_status.dart';
export 'src/models/permission_mode.dart';

// =============================================================================
// Agent Network
// =============================================================================
export 'src/agent_network/agent_status_manager.dart';
export 'src/agent_network/agent_network_persistence_manager.dart';

// =============================================================================
// Claude
// =============================================================================
export 'src/claude/claude_manager.dart'
    show claudeStatusProvider, claudeProvider;

// =============================================================================
// Permissions
// =============================================================================
export 'src/permissions/permission_provider.dart'
    show PermissionHandler, permissionHandlerProvider;
export 'src/permissions/permission_matcher.dart';
export 'src/permissions/bash_command_parser.dart';
export 'src/permissions/safe_commands.dart';
export 'src/permissions/pattern_inference.dart';
export 'src/permissions/tool_input.dart';
export 'src/permissions/permissions.dart';

// =============================================================================
// Configuration
// =============================================================================
export 'src/configuration/vide_core_config.dart';
export 'src/configuration/vide_config_manager.dart';
export 'src/configuration/local_settings_manager.dart';
export 'src/configuration/working_dir_provider.dart';

// =============================================================================
// Team Framework
// =============================================================================
export 'src/team_framework/team_framework.dart';
export 'src/team_framework/team_framework_loader.dart';

// =============================================================================
// Logging
// =============================================================================
export 'src/logging/vide_logger.dart';

// =============================================================================
// Analytics
// =============================================================================
export 'src/analytics/bashboard_service.dart';
export 'src/analytics/auto_update_service.dart';

// =============================================================================
// Git (public models + client + service)
// =============================================================================
export 'src/mcp/git/git_client.dart';
export 'src/mcp/git/git_models.dart';
export 'src/mcp/git/git_providers.dart'
    show gitStatusStreamProvider, isGitRepoProvider;
export 'src/git/git_service.dart';

// =============================================================================
// Claude SDK Re-exports (types needed by TUI for rendering/settings)
// =============================================================================
export 'package:claude_sdk/claude_sdk.dart'
    show
        McpServerBase,
        McpServerStatus,
        McpStatusResponse,
        McpServerStatusInfo,
        ClaudeStatus,
        ClaudeSettingsManager,
        ProcessManager;
