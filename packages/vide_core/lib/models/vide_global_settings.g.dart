// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vide_global_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VideGlobalSettings _$VideGlobalSettingsFromJson(Map<String, dynamic> json) =>
    VideGlobalSettings(
      firstRunComplete: json['firstRunComplete'] as bool? ?? false,
      theme: json['theme'] as String?,
      enableStreaming: json['enableStreaming'] as bool? ?? true,
      autoUpdatesEnabled: json['autoUpdatesEnabled'] as bool? ?? true,
    );

Map<String, dynamic> _$VideGlobalSettingsToJson(VideGlobalSettings instance) =>
    <String, dynamic>{
      'firstRunComplete': instance.firstRunComplete,
      if (instance.theme case final value?) 'theme': value,
      'enableStreaming': instance.enableStreaming,
      'autoUpdatesEnabled': instance.autoUpdatesEnabled,
    };
