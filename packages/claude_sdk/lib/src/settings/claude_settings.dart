import 'package:json_annotation/json_annotation.dart';

import 'permissions_config.dart';
import 'hooks_config.dart';
import 'mcp_config.dart';
import 'sandbox_config.dart';
import 'attribution_config.dart';

part 'claude_settings.g.dart';

/// Claude Code settings configuration.
///
/// This model represents the settings stored in:
/// - `~/.claude/settings.json` (user-level, all projects)
/// - `.claude/settings.json` (project-level, shared via git)
/// - `.claude/settings.local.json` (project-level, personal/gitignored)
///
/// Settings follow a hierarchy where more specific settings override general ones:
/// 1. Managed settings (managed-settings.json)
/// 2. Command-line arguments
/// 3. Local project settings (.claude/settings.local.json)
/// 4. Shared project settings (.claude/settings.json)
/// 5. User settings (~/.claude/settings.json)
///
/// See: https://code.claude.com/docs/en/settings
@JsonSerializable(explicitToJson: true, includeIfNull: false)
class ClaudeSettings {
  // ============================================
  // Permissions
  // ============================================

  /// Permission rules for tool access.
  final PermissionsConfig? permissions;

  // ============================================
  // MCP Server Configuration
  // ============================================

  /// Enable all project MCP servers from .mcp.json without prompting.
  final bool? enableAllProjectMcpServers;

  /// List of enabled MCP server names from .mcp.json.
  /// Servers in this list are loaded without prompting.
  final List<String>? enabledMcpjsonServers;

  /// List of disabled MCP server names from .mcp.json.
  /// These servers will not be loaded even if in .mcp.json.
  final List<String>? disabledMcpjsonServers;

  /// List of allowed MCP servers (by server name).
  final List<McpServerRule>? allowedMcpServers;

  /// List of denied MCP servers (by server name).
  final List<McpServerRule>? deniedMcpServers;

  // ============================================
  // Hooks
  // ============================================

  /// Hook configuration for tool use events.
  final HooksConfig? hooks;

  /// Disable all hooks globally.
  final bool? disableAllHooks;

  /// Only allow hooks defined in managed settings.
  final bool? allowManagedHooksOnly;

  // ============================================
  // Sandbox
  // ============================================

  /// Sandbox configuration for command execution.
  final SandboxConfig? sandbox;

  // ============================================
  // Model Configuration
  // ============================================

  /// Override the default model for Claude Code.
  /// Example: "claude-sonnet-4-20250514"
  final String? model;

  /// Adjust system prompt style.
  /// Example: "Explanatory"
  final String? outputStyle;

  /// Enable extended thinking by default.
  final bool? alwaysThinkingEnabled;

  // ============================================
  // Environment & Session
  // ============================================

  /// Environment variables applied to every session.
  final Map<String, String>? env;

  /// Script to generate auth values for model requests.
  /// Should output JSON with optional headers and cookies.
  final String? apiKeyHelper;

  /// Sessions inactive longer than this are deleted (default: 30 days).
  final int? cleanupPeriodDays;

  // ============================================
  // Git Integration
  // ============================================

  /// Customize git commit and PR attribution.
  final AttributionConfig? attribution;

  /// Whether to respect .gitignore when searching files.
  @JsonKey(defaultValue: true)
  final bool? respectGitignore;

  // ============================================
  // Login & Organization
  // ============================================

  /// Restrict login method.
  /// Values: "claudeai", "console"
  final String? forceLoginMethod;

  /// Auto-select organization during login.
  final String? forceLoginOrgUUID;

  // ============================================
  // UI & Preferences
  // ============================================

  /// Claude's preferred response language.
  final String? language;

  /// Where plan files are stored.
  final String? plansDirectory;

  /// Display turn duration after responses.
  final bool? showTurnDuration;

  /// Release channel for auto-updates.
  /// Values: "stable", "latest"
  final String? autoUpdatesChannel;

  /// Announcements displayed at startup.
  final List<String>? companyAnnouncements;

  // ============================================
  // Telemetry & Debugging
  // ============================================

  /// Script generating OpenTelemetry headers.
  final String? otelHeadersHelper;

  const ClaudeSettings({
    this.permissions,
    this.enableAllProjectMcpServers,
    this.enabledMcpjsonServers,
    this.disabledMcpjsonServers,
    this.allowedMcpServers,
    this.deniedMcpServers,
    this.hooks,
    this.disableAllHooks,
    this.allowManagedHooksOnly,
    this.sandbox,
    this.model,
    this.outputStyle,
    this.alwaysThinkingEnabled,
    this.env,
    this.apiKeyHelper,
    this.cleanupPeriodDays,
    this.attribution,
    this.respectGitignore,
    this.forceLoginMethod,
    this.forceLoginOrgUUID,
    this.language,
    this.plansDirectory,
    this.showTurnDuration,
    this.autoUpdatesChannel,
    this.companyAnnouncements,
    this.otelHeadersHelper,
  });

  /// Creates an empty settings object with default values.
  factory ClaudeSettings.empty() => const ClaudeSettings();

  factory ClaudeSettings.fromJson(Map<String, dynamic> json) =>
      _$ClaudeSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$ClaudeSettingsToJson(this);

  ClaudeSettings copyWith({
    PermissionsConfig? permissions,
    bool? enableAllProjectMcpServers,
    List<String>? enabledMcpjsonServers,
    List<String>? disabledMcpjsonServers,
    List<McpServerRule>? allowedMcpServers,
    List<McpServerRule>? deniedMcpServers,
    HooksConfig? hooks,
    bool? disableAllHooks,
    bool? allowManagedHooksOnly,
    SandboxConfig? sandbox,
    String? model,
    String? outputStyle,
    bool? alwaysThinkingEnabled,
    Map<String, String>? env,
    String? apiKeyHelper,
    int? cleanupPeriodDays,
    AttributionConfig? attribution,
    bool? respectGitignore,
    String? forceLoginMethod,
    String? forceLoginOrgUUID,
    String? language,
    String? plansDirectory,
    bool? showTurnDuration,
    String? autoUpdatesChannel,
    List<String>? companyAnnouncements,
    String? otelHeadersHelper,
  }) {
    return ClaudeSettings(
      permissions: permissions ?? this.permissions,
      enableAllProjectMcpServers:
          enableAllProjectMcpServers ?? this.enableAllProjectMcpServers,
      enabledMcpjsonServers:
          enabledMcpjsonServers ?? this.enabledMcpjsonServers,
      disabledMcpjsonServers:
          disabledMcpjsonServers ?? this.disabledMcpjsonServers,
      allowedMcpServers: allowedMcpServers ?? this.allowedMcpServers,
      deniedMcpServers: deniedMcpServers ?? this.deniedMcpServers,
      hooks: hooks ?? this.hooks,
      disableAllHooks: disableAllHooks ?? this.disableAllHooks,
      allowManagedHooksOnly:
          allowManagedHooksOnly ?? this.allowManagedHooksOnly,
      sandbox: sandbox ?? this.sandbox,
      model: model ?? this.model,
      outputStyle: outputStyle ?? this.outputStyle,
      alwaysThinkingEnabled:
          alwaysThinkingEnabled ?? this.alwaysThinkingEnabled,
      env: env ?? this.env,
      apiKeyHelper: apiKeyHelper ?? this.apiKeyHelper,
      cleanupPeriodDays: cleanupPeriodDays ?? this.cleanupPeriodDays,
      attribution: attribution ?? this.attribution,
      respectGitignore: respectGitignore ?? this.respectGitignore,
      forceLoginMethod: forceLoginMethod ?? this.forceLoginMethod,
      forceLoginOrgUUID: forceLoginOrgUUID ?? this.forceLoginOrgUUID,
      language: language ?? this.language,
      plansDirectory: plansDirectory ?? this.plansDirectory,
      showTurnDuration: showTurnDuration ?? this.showTurnDuration,
      autoUpdatesChannel: autoUpdatesChannel ?? this.autoUpdatesChannel,
      companyAnnouncements: companyAnnouncements ?? this.companyAnnouncements,
      otelHeadersHelper: otelHeadersHelper ?? this.otelHeadersHelper,
    );
  }

  /// Merges this settings with another, where [other] takes precedence.
  /// Used for merging settings from different scopes (user -> project -> local).
  ClaudeSettings merge(ClaudeSettings other) {
    return ClaudeSettings(
      permissions: other.permissions ?? permissions,
      enableAllProjectMcpServers:
          other.enableAllProjectMcpServers ?? enableAllProjectMcpServers,
      enabledMcpjsonServers:
          other.enabledMcpjsonServers ?? enabledMcpjsonServers,
      disabledMcpjsonServers:
          other.disabledMcpjsonServers ?? disabledMcpjsonServers,
      allowedMcpServers: other.allowedMcpServers ?? allowedMcpServers,
      deniedMcpServers: other.deniedMcpServers ?? deniedMcpServers,
      hooks: other.hooks ?? hooks,
      disableAllHooks: other.disableAllHooks ?? disableAllHooks,
      allowManagedHooksOnly:
          other.allowManagedHooksOnly ?? allowManagedHooksOnly,
      sandbox: other.sandbox ?? sandbox,
      model: other.model ?? model,
      outputStyle: other.outputStyle ?? outputStyle,
      alwaysThinkingEnabled:
          other.alwaysThinkingEnabled ?? alwaysThinkingEnabled,
      env: other.env ?? env,
      apiKeyHelper: other.apiKeyHelper ?? apiKeyHelper,
      cleanupPeriodDays: other.cleanupPeriodDays ?? cleanupPeriodDays,
      attribution: other.attribution ?? attribution,
      respectGitignore: other.respectGitignore ?? respectGitignore,
      forceLoginMethod: other.forceLoginMethod ?? forceLoginMethod,
      forceLoginOrgUUID: other.forceLoginOrgUUID ?? forceLoginOrgUUID,
      language: other.language ?? language,
      plansDirectory: other.plansDirectory ?? plansDirectory,
      showTurnDuration: other.showTurnDuration ?? showTurnDuration,
      autoUpdatesChannel: other.autoUpdatesChannel ?? autoUpdatesChannel,
      companyAnnouncements: other.companyAnnouncements ?? companyAnnouncements,
      otelHeadersHelper: other.otelHeadersHelper ?? otelHeadersHelper,
    );
  }
}
