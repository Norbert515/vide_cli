import 'package:json_annotation/json_annotation.dart';

part 'claude_settings.g.dart';

@JsonSerializable(explicitToJson: true)
class ClaudeSettings {
  final PermissionsConfig permissions;
  @JsonKey(defaultValue: null)
  final HooksConfig? hooks;
  @JsonKey(name: 'vide_first_run_complete', defaultValue: null)
  final bool? videFirstRunComplete;

  const ClaudeSettings({
    required this.permissions,
    this.hooks,
    this.videFirstRunComplete,
  });

  factory ClaudeSettings.defaults() => ClaudeSettings(
    permissions: PermissionsConfig.empty(),
    hooks: HooksConfig.empty(),
  );

  factory ClaudeSettings.fromJson(Map<String, dynamic> json) {
    final settings = _$ClaudeSettingsFromJson(json);
    // If hooks is null, use empty HooksConfig
    return ClaudeSettings(
      permissions: settings.permissions,
      hooks: settings.hooks ?? HooksConfig.empty(),
      videFirstRunComplete: settings.videFirstRunComplete,
    );
  }

  Map<String, dynamic> toJson() => _$ClaudeSettingsToJson(this);

  ClaudeSettings copyWith({
    PermissionsConfig? permissions,
    HooksConfig? hooks,
    bool? videFirstRunComplete,
  }) {
    return ClaudeSettings(
      permissions: permissions ?? this.permissions,
      hooks: hooks ?? this.hooks,
      videFirstRunComplete: videFirstRunComplete ?? this.videFirstRunComplete,
    );
  }
}

@JsonSerializable(explicitToJson: true)
class PermissionsConfig {
  final List<String> allow;
  final List<String> deny;
  final List<String> ask;

  const PermissionsConfig({
    required this.allow,
    required this.deny,
    required this.ask,
  });

  factory PermissionsConfig.empty() =>
      const PermissionsConfig(allow: [], deny: [], ask: []);

  factory PermissionsConfig.fromJson(Map<String, dynamic> json) =>
      _$PermissionsConfigFromJson(json);

  Map<String, dynamic> toJson() => _$PermissionsConfigToJson(this);

  PermissionsConfig copyWith({
    List<String>? allow,
    List<String>? deny,
    List<String>? ask,
  }) {
    return PermissionsConfig(
      allow: allow ?? this.allow,
      deny: deny ?? this.deny,
      ask: ask ?? this.ask,
    );
  }
}

@JsonSerializable(explicitToJson: true)
class HooksConfig {
  @JsonKey(name: 'PreToolUse')
  final List<PreToolUseHook> preToolUse;

  const HooksConfig({required this.preToolUse});

  factory HooksConfig.empty() => const HooksConfig(preToolUse: []);

  factory HooksConfig.fromJson(Map<String, dynamic> json) =>
      _$HooksConfigFromJson(json);

  Map<String, dynamic> toJson() => _$HooksConfigToJson(this);
}

@JsonSerializable(explicitToJson: true)
class PreToolUseHook {
  final String matcher;
  final List<HookCommand> hooks;

  const PreToolUseHook({required this.matcher, required this.hooks});

  factory PreToolUseHook.fromJson(Map<String, dynamic> json) =>
      _$PreToolUseHookFromJson(json);

  Map<String, dynamic> toJson() => _$PreToolUseHookToJson(this);
}

@JsonSerializable(explicitToJson: true)
class HookCommand {
  final String type;
  final String command;
  final int timeout;

  const HookCommand({
    required this.type,
    required this.command,
    required this.timeout,
  });

  factory HookCommand.fromJson(Map<String, dynamic> json) =>
      _$HookCommandFromJson(json);

  Map<String, dynamic> toJson() => _$HookCommandToJson(this);
}
