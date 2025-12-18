// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'claude_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ClaudeSettings _$ClaudeSettingsFromJson(Map<String, dynamic> json) =>
    ClaudeSettings(
      permissions: PermissionsConfig.fromJson(
        json['permissions'] as Map<String, dynamic>,
      ),
      hooks: json['hooks'] == null
          ? null
          : HooksConfig.fromJson(json['hooks'] as Map<String, dynamic>),
      videFirstRunComplete: json['vide_first_run_complete'] as bool?,
    );

Map<String, dynamic> _$ClaudeSettingsToJson(ClaudeSettings instance) =>
    <String, dynamic>{
      'permissions': instance.permissions.toJson(),
      'hooks': instance.hooks?.toJson(),
      'vide_first_run_complete': instance.videFirstRunComplete,
    };

PermissionsConfig _$PermissionsConfigFromJson(Map<String, dynamic> json) =>
    PermissionsConfig(
      allow: (json['allow'] as List<dynamic>).map((e) => e as String).toList(),
      deny: (json['deny'] as List<dynamic>).map((e) => e as String).toList(),
      ask: (json['ask'] as List<dynamic>).map((e) => e as String).toList(),
    );

Map<String, dynamic> _$PermissionsConfigToJson(PermissionsConfig instance) =>
    <String, dynamic>{
      'allow': instance.allow,
      'deny': instance.deny,
      'ask': instance.ask,
    };

HooksConfig _$HooksConfigFromJson(Map<String, dynamic> json) => HooksConfig(
  preToolUse: (json['PreToolUse'] as List<dynamic>)
      .map((e) => PreToolUseHook.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$HooksConfigToJson(HooksConfig instance) =>
    <String, dynamic>{
      'PreToolUse': instance.preToolUse.map((e) => e.toJson()).toList(),
    };

PreToolUseHook _$PreToolUseHookFromJson(Map<String, dynamic> json) =>
    PreToolUseHook(
      matcher: json['matcher'] as String,
      hooks: (json['hooks'] as List<dynamic>)
          .map((e) => HookCommand.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$PreToolUseHookToJson(PreToolUseHook instance) =>
    <String, dynamic>{
      'matcher': instance.matcher,
      'hooks': instance.hooks.map((e) => e.toJson()).toList(),
    };

HookCommand _$HookCommandFromJson(Map<String, dynamic> json) => HookCommand(
  type: json['type'] as String,
  command: json['command'] as String,
  timeout: (json['timeout'] as num).toInt(),
);

Map<String, dynamic> _$HookCommandToJson(HookCommand instance) =>
    <String, dynamic>{
      'type': instance.type,
      'command': instance.command,
      'timeout': instance.timeout,
    };
