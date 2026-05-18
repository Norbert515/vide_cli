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
      dangerouslySkipPermissions:
          json['dangerouslySkipPermissions'] as bool? ?? false,
      gitSidebarEnabled: json['gitSidebarEnabled'] as bool? ?? true,
      daemonModeEnabled: json['daemonModeEnabled'] as bool? ?? true,
      daemonHost: json['daemonHost'] as String? ?? '127.0.0.1',
      daemonPort: (json['daemonPort'] as num?)?.toInt() ?? 8080,
      telemetryEnabled: json['telemetryEnabled'] as bool? ?? true,
      showThinking: json['showThinking'] as bool? ?? true,
      soundNotificationsEnabled:
          json['soundNotificationsEnabled'] as bool? ?? true,
      customTaskCompleteSound: json['customTaskCompleteSound'] as String?,
      customAttentionNeededSound: json['customAttentionNeededSound'] as String?,
      extremeTeamEnabled: json['extremeTeamEnabled'] as bool? ?? false,
    );

Map<String, dynamic> _$VideGlobalSettingsToJson(VideGlobalSettings instance) =>
    <String, dynamic>{
      'firstRunComplete': instance.firstRunComplete,
      if (instance.theme case final value?) 'theme': value,
      'enableStreaming': instance.enableStreaming,
      'autoUpdatesEnabled': instance.autoUpdatesEnabled,
      'dangerouslySkipPermissions': instance.dangerouslySkipPermissions,
      'gitSidebarEnabled': instance.gitSidebarEnabled,
      'daemonModeEnabled': instance.daemonModeEnabled,
      'daemonHost': instance.daemonHost,
      'daemonPort': instance.daemonPort,
      'telemetryEnabled': instance.telemetryEnabled,
      'showThinking': instance.showThinking,
      'soundNotificationsEnabled': instance.soundNotificationsEnabled,
      if (instance.customTaskCompleteSound case final value?)
        'customTaskCompleteSound': value,
      if (instance.customAttentionNeededSound case final value?)
        'customAttentionNeededSound': value,
      'extremeTeamEnabled': instance.extremeTeamEnabled,
    };
