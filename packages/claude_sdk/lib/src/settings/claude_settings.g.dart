// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'claude_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ClaudeSettings _$ClaudeSettingsFromJson(
  Map<String, dynamic> json,
) => ClaudeSettings(
  permissions: json['permissions'] == null
      ? null
      : PermissionsConfig.fromJson(json['permissions'] as Map<String, dynamic>),
  enableAllProjectMcpServers: json['enableAllProjectMcpServers'] as bool?,
  enabledMcpjsonServers: (json['enabledMcpjsonServers'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  disabledMcpjsonServers: (json['disabledMcpjsonServers'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  allowedMcpServers: (json['allowedMcpServers'] as List<dynamic>?)
      ?.map((e) => McpServerRule.fromJson(e as Map<String, dynamic>))
      .toList(),
  deniedMcpServers: (json['deniedMcpServers'] as List<dynamic>?)
      ?.map((e) => McpServerRule.fromJson(e as Map<String, dynamic>))
      .toList(),
  hooks: json['hooks'] == null
      ? null
      : HooksConfig.fromJson(json['hooks'] as Map<String, dynamic>),
  disableAllHooks: json['disableAllHooks'] as bool?,
  allowManagedHooksOnly: json['allowManagedHooksOnly'] as bool?,
  sandbox: json['sandbox'] == null
      ? null
      : SandboxConfig.fromJson(json['sandbox'] as Map<String, dynamic>),
  model: json['model'] as String?,
  outputStyle: json['outputStyle'] as String?,
  alwaysThinkingEnabled: json['alwaysThinkingEnabled'] as bool?,
  env: (json['env'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, e as String),
  ),
  apiKeyHelper: json['apiKeyHelper'] as String?,
  cleanupPeriodDays: (json['cleanupPeriodDays'] as num?)?.toInt(),
  attribution: json['attribution'] == null
      ? null
      : AttributionConfig.fromJson(json['attribution'] as Map<String, dynamic>),
  respectGitignore: json['respectGitignore'] as bool? ?? true,
  forceLoginMethod: json['forceLoginMethod'] as String?,
  forceLoginOrgUUID: json['forceLoginOrgUUID'] as String?,
  language: json['language'] as String?,
  plansDirectory: json['plansDirectory'] as String?,
  showTurnDuration: json['showTurnDuration'] as bool?,
  autoUpdatesChannel: json['autoUpdatesChannel'] as String?,
  companyAnnouncements: (json['companyAnnouncements'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  otelHeadersHelper: json['otelHeadersHelper'] as String?,
);

Map<String, dynamic> _$ClaudeSettingsToJson(
  ClaudeSettings instance,
) => <String, dynamic>{
  if (instance.permissions?.toJson() case final value?) 'permissions': value,
  if (instance.enableAllProjectMcpServers case final value?)
    'enableAllProjectMcpServers': value,
  if (instance.enabledMcpjsonServers case final value?)
    'enabledMcpjsonServers': value,
  if (instance.disabledMcpjsonServers case final value?)
    'disabledMcpjsonServers': value,
  if (instance.allowedMcpServers?.map((e) => e.toJson()).toList()
      case final value?)
    'allowedMcpServers': value,
  if (instance.deniedMcpServers?.map((e) => e.toJson()).toList()
      case final value?)
    'deniedMcpServers': value,
  if (instance.hooks?.toJson() case final value?) 'hooks': value,
  if (instance.disableAllHooks case final value?) 'disableAllHooks': value,
  if (instance.allowManagedHooksOnly case final value?)
    'allowManagedHooksOnly': value,
  if (instance.sandbox?.toJson() case final value?) 'sandbox': value,
  if (instance.model case final value?) 'model': value,
  if (instance.outputStyle case final value?) 'outputStyle': value,
  if (instance.alwaysThinkingEnabled case final value?)
    'alwaysThinkingEnabled': value,
  if (instance.env case final value?) 'env': value,
  if (instance.apiKeyHelper case final value?) 'apiKeyHelper': value,
  if (instance.cleanupPeriodDays case final value?) 'cleanupPeriodDays': value,
  if (instance.attribution?.toJson() case final value?) 'attribution': value,
  if (instance.respectGitignore case final value?) 'respectGitignore': value,
  if (instance.forceLoginMethod case final value?) 'forceLoginMethod': value,
  if (instance.forceLoginOrgUUID case final value?) 'forceLoginOrgUUID': value,
  if (instance.language case final value?) 'language': value,
  if (instance.plansDirectory case final value?) 'plansDirectory': value,
  if (instance.showTurnDuration case final value?) 'showTurnDuration': value,
  if (instance.autoUpdatesChannel case final value?)
    'autoUpdatesChannel': value,
  if (instance.companyAnnouncements case final value?)
    'companyAnnouncements': value,
  if (instance.otelHeadersHelper case final value?) 'otelHeadersHelper': value,
};
