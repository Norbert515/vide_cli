// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vide_global_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VideGlobalSettings _$VideGlobalSettingsFromJson(
  Map<String, dynamic> json,
) => VideGlobalSettings(
  firstRunComplete: json['firstRunComplete'] as bool? ?? false,
  theme: json['theme'] as String?,
  enableStreaming: json['enableStreaming'] as bool? ?? true,
  autoUpdatesEnabled: json['autoUpdatesEnabled'] as bool? ?? true,
  ideModeEnabled: json['ideModeEnabled'] as bool? ?? false,
  dangerouslySkipPermissions:
      json['dangerouslySkipPermissions'] as bool? ?? false,
  gitSidebarEnabled: json['gitSidebarEnabled'] as bool? ?? true,
  daemonModeEnabled: json['daemonModeEnabled'] as bool? ?? false,
  daemonHost: json['daemonHost'] as String? ?? '127.0.0.1',
  daemonPort: (json['daemonPort'] as num?)?.toInt() ?? 8080,
  telemetryEnabled: json['telemetryEnabled'] as bool? ?? true,
  showThinking: json['showThinking'] as bool? ?? true,
  useCodexBackend: json['useCodexBackend'] as bool? ?? false,
  experimentAutoTeamSelection:
      json['experimentAutoTeamSelection'] as bool? ?? false,
  experimentParallelAgents: json['experimentParallelAgents'] as bool? ?? false,
  experimentAgentMemory: json['experimentAgentMemory'] as bool? ?? false,
  experimentVerboseHandoffs:
      json['experimentVerboseHandoffs'] as bool? ?? false,
  soundNotificationsEnabled: json['soundNotificationsEnabled'] as bool? ?? true,
  customTaskCompleteSound: json['customTaskCompleteSound'] as String?,
  customAttentionNeededSound: json['customAttentionNeededSound'] as String?,
);

Map<String, dynamic> _$VideGlobalSettingsToJson(VideGlobalSettings instance) =>
    <String, dynamic>{
      'firstRunComplete': instance.firstRunComplete,
      if (instance.theme case final value?) 'theme': value,
      'enableStreaming': instance.enableStreaming,
      'autoUpdatesEnabled': instance.autoUpdatesEnabled,
      'ideModeEnabled': instance.ideModeEnabled,
      'dangerouslySkipPermissions': instance.dangerouslySkipPermissions,
      'gitSidebarEnabled': instance.gitSidebarEnabled,
      'daemonModeEnabled': instance.daemonModeEnabled,
      'daemonHost': instance.daemonHost,
      'daemonPort': instance.daemonPort,
      'telemetryEnabled': instance.telemetryEnabled,
      'showThinking': instance.showThinking,
      'useCodexBackend': instance.useCodexBackend,
      'experimentAutoTeamSelection': instance.experimentAutoTeamSelection,
      'experimentParallelAgents': instance.experimentParallelAgents,
      'experimentAgentMemory': instance.experimentAgentMemory,
      'experimentVerboseHandoffs': instance.experimentVerboseHandoffs,
      'soundNotificationsEnabled': instance.soundNotificationsEnabled,
      if (instance.customTaskCompleteSound case final value?)
        'customTaskCompleteSound': value,
      if (instance.customAttentionNeededSound case final value?)
        'customAttentionNeededSound': value,
    };
