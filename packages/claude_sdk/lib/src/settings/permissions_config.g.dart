// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'permissions_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PermissionsConfig _$PermissionsConfigFromJson(
  Map<String, dynamic> json,
) => PermissionsConfig(
  allow: (json['allow'] as List<dynamic>?)?.map((e) => e as String).toList(),
  deny: (json['deny'] as List<dynamic>?)?.map((e) => e as String).toList(),
  ask: (json['ask'] as List<dynamic>?)?.map((e) => e as String).toList(),
  additionalDirectories: (json['additionalDirectories'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  defaultMode: json['defaultMode'] as String?,
  disableBypassPermissionsMode: json['disableBypassPermissionsMode'] as bool?,
);

Map<String, dynamic> _$PermissionsConfigToJson(PermissionsConfig instance) =>
    <String, dynamic>{
      if (instance.allow case final value?) 'allow': value,
      if (instance.deny case final value?) 'deny': value,
      if (instance.ask case final value?) 'ask': value,
      if (instance.additionalDirectories case final value?)
        'additionalDirectories': value,
      if (instance.defaultMode case final value?) 'defaultMode': value,
      if (instance.disableBypassPermissionsMode case final value?)
        'disableBypassPermissionsMode': value,
    };
