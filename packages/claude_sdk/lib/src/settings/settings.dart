/// Claude Code settings types and management.
///
/// This library provides type-safe access to Claude Code settings files:
/// - `~/.claude/settings.json` (user-level)
/// - `.claude/settings.json` (project-level shared)
/// - `.claude/settings.local.json` (project-level local)
/// - `.mcp.json` (MCP server definitions)
///
/// Example usage:
/// ```dart
/// import 'package:claude_sdk/settings.dart';
///
/// final manager = ClaudeSettingsManager(
///   projectRoot: '/path/to/project',
/// );
///
/// // Read merged settings
/// final settings = await manager.readMergedSettings();
///
/// // Check if MCP server is enabled
/// final enabled = manager.isMcpServerEnabled('my-server');
///
/// // Enable an MCP server
/// await manager.enableMcpServer('my-server');
///
/// // Add to permission allow list
/// await manager.addToAllowList('Bash(npm run:*)');
/// ```
library settings;

export 'claude_settings.dart';
export 'permissions_config.dart';
export 'hooks_config.dart';
export 'mcp_config.dart';
export 'sandbox_config.dart';
export 'attribution_config.dart';
export 'settings_manager.dart';
