// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hooks_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HooksConfig _$HooksConfigFromJson(Map<String, dynamic> json) => HooksConfig(
  preToolUse: json['PreToolUse'],
  postToolUse: json['PostToolUse'],
  preMessage: json['PreMessage'],
  postMessage: json['PostMessage'],
  promptSubmit: json['PromptSubmit'],
  sessionStart: json['SessionStart'],
  sessionEnd: json['SessionEnd'],
);

Map<String, dynamic> _$HooksConfigToJson(HooksConfig instance) =>
    <String, dynamic>{
      if (instance.preToolUse case final value?) 'PreToolUse': value,
      if (instance.postToolUse case final value?) 'PostToolUse': value,
      if (instance.preMessage case final value?) 'PreMessage': value,
      if (instance.postMessage case final value?) 'PostMessage': value,
      if (instance.promptSubmit case final value?) 'PromptSubmit': value,
      if (instance.sessionStart case final value?) 'SessionStart': value,
      if (instance.sessionEnd case final value?) 'SessionEnd': value,
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
  timeout: (json['timeout'] as num?)?.toInt(),
);

Map<String, dynamic> _$HookCommandToJson(HookCommand instance) =>
    <String, dynamic>{
      'type': instance.type,
      'command': instance.command,
      if (instance.timeout case final value?) 'timeout': value,
    };
