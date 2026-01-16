// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sandbox_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SandboxConfig _$SandboxConfigFromJson(Map<String, dynamic> json) =>
    SandboxConfig(
      enabled: json['enabled'] as bool?,
      autoAllowBashIfSandboxed: json['autoAllowBashIfSandboxed'] as bool?,
      excludedCommands: (json['excludedCommands'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      allowUnsandboxedCommands: json['allowUnsandboxedCommands'] as bool?,
      network: json['network'] == null
          ? null
          : SandboxNetworkConfig.fromJson(
              json['network'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$SandboxConfigToJson(
  SandboxConfig instance,
) => <String, dynamic>{
  if (instance.enabled case final value?) 'enabled': value,
  if (instance.autoAllowBashIfSandboxed case final value?)
    'autoAllowBashIfSandboxed': value,
  if (instance.excludedCommands case final value?) 'excludedCommands': value,
  if (instance.allowUnsandboxedCommands case final value?)
    'allowUnsandboxedCommands': value,
  if (instance.network?.toJson() case final value?) 'network': value,
};

SandboxNetworkConfig _$SandboxNetworkConfigFromJson(
  Map<String, dynamic> json,
) => SandboxNetworkConfig(
  allowUnixSockets: (json['allowUnixSockets'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  allowLocalBinding: json['allowLocalBinding'] as bool?,
  httpProxyPort: (json['httpProxyPort'] as num?)?.toInt(),
  socksProxyPort: (json['socksProxyPort'] as num?)?.toInt(),
);

Map<String, dynamic> _$SandboxNetworkConfigToJson(
  SandboxNetworkConfig instance,
) => <String, dynamic>{
  if (instance.allowUnixSockets case final value?) 'allowUnixSockets': value,
  if (instance.allowLocalBinding case final value?) 'allowLocalBinding': value,
  if (instance.httpProxyPort case final value?) 'httpProxyPort': value,
  if (instance.socksProxyPort case final value?) 'socksProxyPort': value,
};
