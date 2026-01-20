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

  /// Whether IDE mode (git sidebar) is enabled
  @JsonKey(defaultValue: false)
  final bool ideModeEnabled;

  /// Whether to skip all permission checks.
  ///
  /// DANGEROUS: Only use in sandboxed environments (Docker) where filesystem
  /// isolation protects the host system. This bypasses ALL safety checks.
  @JsonKey(defaultValue: false)
  final bool dangerouslySkipPermissions;

  const VideGlobalSettings({
    this.firstRunComplete = false,
    this.theme,
    this.enableStreaming = true,
    this.autoUpdatesEnabled = true,
    this.ideModeEnabled = false,
    this.dangerouslySkipPermissions = false,
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
    bool? ideModeEnabled,
    bool? dangerouslySkipPermissions,
  }) {
    return VideGlobalSettings(
      firstRunComplete: firstRunComplete ?? this.firstRunComplete,
      theme: theme != null ? theme() : this.theme,
      enableStreaming: enableStreaming ?? this.enableStreaming,
      autoUpdatesEnabled: autoUpdatesEnabled ?? this.autoUpdatesEnabled,
      ideModeEnabled: ideModeEnabled ?? this.ideModeEnabled,
      dangerouslySkipPermissions:
          dangerouslySkipPermissions ?? this.dangerouslySkipPermissions,
    );
  }
}
