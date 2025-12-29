// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vide_global_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VideGlobalSettings _$VideGlobalSettingsFromJson(Map<String, dynamic> json) =>
    VideGlobalSettings(
      firstRunComplete: json['firstRunComplete'] as bool? ?? false,
      theme: json['theme'] as String?,
      showThinking: json['showThinking'] as bool? ?? false,
    );

Map<String, dynamic> _$VideGlobalSettingsToJson(VideGlobalSettings instance) =>
    <String, dynamic>{
      'firstRunComplete': instance.firstRunComplete,
      if (instance.theme case final value?) 'theme': value,
      'showThinking': instance.showThinking,
    };
