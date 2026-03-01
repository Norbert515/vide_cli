import 'package:json_annotation/json_annotation.dart';

part 'vide_global_settings.g.dart';

/// Global settings for Vide CLI stored at ~/.vide/settings.json
///
/// These settings apply across all projects, unlike per-project settings
/// stored in .claude/settings.local.json
@JsonSerializable()
class VideGlobalSettings {
  /// Whether the first-run onboarding has been completed
  @JsonKey(defaultValue: false)
  final bool firstRunComplete;

  /// The selected theme name. Null means auto-detect based on terminal.
  /// Valid values: 'dark', 'light', 'nord', 'dracula', 'catppuccinMocha', 'gruvboxDark'
  @JsonKey(includeIfNull: false)
  final String? theme;

  /// Whether to enable streaming of partial messages.
  /// When true, text is streamed character-by-character as it's generated.
  /// When false, only complete messages are returned.
  /// Defaults to true.
  @JsonKey(defaultValue: true)
  final bool enableStreaming;

  /// Whether auto-updates are enabled
  @JsonKey(defaultValue: true)
  final bool autoUpdatesEnabled;

  /// Whether to skip all permission checks.
  ///
  /// DANGEROUS: Only use in sandboxed environments (Docker) where filesystem
  /// isolation protects the host system. This bypasses ALL safety checks.
  @JsonKey(defaultValue: false)
  final bool dangerouslySkipPermissions;

  /// Whether the git sidebar is enabled.
  /// The sidebar will only show if this is true AND the current directory is a git repo.
  @JsonKey(defaultValue: true)
  final bool gitSidebarEnabled;

  /// Whether daemon mode is enabled.
  /// When true, sessions run on a persistent daemon process.
  /// When false, sessions run locally in the TUI process.
  @JsonKey(defaultValue: true)
  final bool daemonModeEnabled;

  /// Host for the daemon when daemon mode is enabled.
  @JsonKey(defaultValue: '127.0.0.1')
  final String daemonHost;

  /// Port for the daemon when daemon mode is enabled.
  @JsonKey(defaultValue: 8080)
  final int daemonPort;

  /// Whether telemetry (anonymous usage analytics) is enabled.
  @JsonKey(defaultValue: true)
  final bool telemetryEnabled;

  /// Whether to display model thinking blocks in the conversation view.
  @JsonKey(defaultValue: true)
  final bool showThinking;

  /// Whether to use the Codex (OpenAI) backend instead of Claude.
  /// Debug setting for testing the Codex integration.
  @JsonKey(defaultValue: false)
  final bool useCodexBackend;

  /// Whether to play sounds when agents finish or need user attention.
  @JsonKey(defaultValue: true)
  final bool soundNotificationsEnabled;

  /// Custom audio file path for the task-complete sound.
  /// When set, plays this file instead of the system default.
  /// Supports formats handled by the OS player (mp3, wav, aiff on macOS).
  @JsonKey(includeIfNull: false)
  final String? customTaskCompleteSound;

  /// Custom audio file path for the attention-needed sound.
  /// When set, plays this file instead of the system default.
  @JsonKey(includeIfNull: false)
  final String? customAttentionNeededSound;

  /// Whether to use the "extreme" team instead of "enterprise".
  /// Extreme mode uses dual-harness parallel analysis with agent debates,
  /// a dedicated verification strategist, and dual-model code review.
  @JsonKey(defaultValue: false)
  final bool extremeTeamEnabled;

  const VideGlobalSettings({
    this.firstRunComplete = false,
    this.theme,
    this.enableStreaming = true,
    this.autoUpdatesEnabled = true,
    this.dangerouslySkipPermissions = false,
    this.gitSidebarEnabled = true,
    this.daemonModeEnabled = true,
    this.daemonHost = '127.0.0.1',
    this.daemonPort = 8080,
    this.telemetryEnabled = true,
    this.showThinking = true,
    this.useCodexBackend = false,
    this.soundNotificationsEnabled = true,
    this.customTaskCompleteSound,
    this.customAttentionNeededSound,
    this.extremeTeamEnabled = false,
  });

  factory VideGlobalSettings.defaults() => const VideGlobalSettings();

  factory VideGlobalSettings.fromJson(Map<String, dynamic> json) =>
      _$VideGlobalSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$VideGlobalSettingsToJson(this);

  VideGlobalSettings copyWith({
    bool? firstRunComplete,
    String? Function()? theme,
    bool? enableStreaming,
    bool? autoUpdatesEnabled,
    bool? dangerouslySkipPermissions,
    bool? gitSidebarEnabled,
    bool? daemonModeEnabled,
    String? daemonHost,
    int? daemonPort,
    bool? telemetryEnabled,
    bool? showThinking,
    bool? useCodexBackend,
    bool? soundNotificationsEnabled,
    String? Function()? customTaskCompleteSound,
    String? Function()? customAttentionNeededSound,
    bool? extremeTeamEnabled,
  }) {
    return VideGlobalSettings(
      firstRunComplete: firstRunComplete ?? this.firstRunComplete,
      theme: theme != null ? theme() : this.theme,
      enableStreaming: enableStreaming ?? this.enableStreaming,
      autoUpdatesEnabled: autoUpdatesEnabled ?? this.autoUpdatesEnabled,
      dangerouslySkipPermissions:
          dangerouslySkipPermissions ?? this.dangerouslySkipPermissions,
      gitSidebarEnabled: gitSidebarEnabled ?? this.gitSidebarEnabled,
      daemonModeEnabled: daemonModeEnabled ?? this.daemonModeEnabled,
      daemonHost: daemonHost ?? this.daemonHost,
      daemonPort: daemonPort ?? this.daemonPort,
      telemetryEnabled: telemetryEnabled ?? this.telemetryEnabled,
      showThinking: showThinking ?? this.showThinking,
      useCodexBackend: useCodexBackend ?? this.useCodexBackend,
      soundNotificationsEnabled:
          soundNotificationsEnabled ?? this.soundNotificationsEnabled,
      customTaskCompleteSound: customTaskCompleteSound != null
          ? customTaskCompleteSound()
          : this.customTaskCompleteSound,
      customAttentionNeededSound: customAttentionNeededSound != null
          ? customAttentionNeededSound()
          : this.customAttentionNeededSound,
      extremeTeamEnabled: extremeTeamEnabled ?? this.extremeTeamEnabled,
    );
  }
}
