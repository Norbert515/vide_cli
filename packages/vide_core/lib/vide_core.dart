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
// Shared Interface Types (from vide_interface)
// =============================================================================
export 'package:vide_interface/vide_interface.dart';

// =============================================================================
// API Classes
// =============================================================================
export 'src/api/vide_session.dart' show LocalVideSession;
export 'src/api/vide_config.dart' show VideCoreConfig;

// =============================================================================
// Models
// =============================================================================
export 'src/models/agent_network.dart';
export 'src/models/agent_metadata.dart';
export 'src/models/agent_id.dart';
export 'src/models/agent_status.dart';
export 'src/models/team_framework/team_framework.dart';

// =============================================================================
// Services
// =============================================================================
export 'src/services/vide_config_manager.dart';
export 'src/services/bashboard_service.dart';
export 'src/services/permission_provider.dart'
    show PermissionHandler, permissionHandlerProvider;
export 'src/services/agent_network_persistence_manager.dart';
export 'src/services/team_framework_loader.dart';
export 'src/services/auto_update_service.dart';
export 'src/services/claude_manager.dart' show claudeStatusProvider;

// Permissions (public utilities used by TUI)
export 'src/services/permissions/permission_matcher.dart';
export 'src/services/permissions/bash_command_parser.dart';
export 'src/services/permissions/safe_commands.dart';
export 'src/services/permissions/pattern_inference.dart';
export 'src/services/permissions/tool_input.dart';
export 'src/services/permissions/permissions.dart';

// Settings
export 'src/services/settings/local_settings_manager.dart';

// =============================================================================
// Git (public models + client)
// =============================================================================
export 'src/mcp/git/git_client.dart';
export 'src/mcp/git/git_models.dart';
export 'src/mcp/git/git_providers.dart'
    show gitStatusStreamProvider, isGitRepoProvider;

// =============================================================================
// Utilities
// =============================================================================
export 'src/state/agent_status_manager.dart';
export 'src/utils/project_detector.dart';
export 'src/utils/working_dir_provider.dart';
export 'src/utils/dangerously_skip_permissions_provider.dart';

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
