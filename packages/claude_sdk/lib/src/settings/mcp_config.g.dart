// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mcp_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

McpServerRule _$McpServerRuleFromJson(Map<String, dynamic> json) =>
    McpServerRule(serverName: json['serverName'] as String);

Map<String, dynamic> _$McpServerRuleToJson(McpServerRule instance) =>
    <String, dynamic>{'serverName': instance.serverName};

McpJsonConfig _$McpJsonConfigFromJson(Map<String, dynamic> json) =>
    McpJsonConfig(
      mcpServers: (json['mcpServers'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(
          k,
          McpServerDefinition.fromJson(e as Map<String, dynamic>),
        ),
      ),
    );

Map<String, dynamic> _$McpJsonConfigToJson(McpJsonConfig instance) =>
    <String, dynamic>{
      if (instance.mcpServers?.map((k, e) => MapEntry(k, e.toJson()))
          case final value?)
        'mcpServers': value,
    };

McpServerDefinition _$McpServerDefinitionFromJson(Map<String, dynamic> json) =>
    McpServerDefinition(
      command: json['command'] as String,
      args: (json['args'] as List<dynamic>?)?.map((e) => e as String).toList(),
      env: (json['env'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
      cwd: json['cwd'] as String?,
    );

Map<String, dynamic> _$McpServerDefinitionToJson(
  McpServerDefinition instance,
) => <String, dynamic>{
  'command': instance.command,
  if (instance.args case final value?) 'args': value,
  if (instance.env case final value?) 'env': value,
  if (instance.cwd case final value?) 'cwd': value,
};
