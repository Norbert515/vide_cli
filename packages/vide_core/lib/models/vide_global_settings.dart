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

  /// Whether to show thinking/reasoning tokens in the UI.
  /// Defaults to false (hidden).
  @JsonKey(defaultValue: false)
  final bool showThinking;

  const VideGlobalSettings({
    this.firstRunComplete = false,
    this.theme,
    this.showThinking = false,
  });

  factory VideGlobalSettings.defaults() => const VideGlobalSettings();

  factory VideGlobalSettings.fromJson(Map<String, dynamic> json) =>
      _$VideGlobalSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$VideGlobalSettingsToJson(this);

  VideGlobalSettings copyWith({
    bool? firstRunComplete,
    String? Function()? theme,
    bool? showThinking,
  }) {
    return VideGlobalSettings(
      firstRunComplete: firstRunComplete ?? this.firstRunComplete,
      theme: theme != null ? theme() : this.theme,
      showThinking: showThinking ?? this.showThinking,
    );
  }
}
