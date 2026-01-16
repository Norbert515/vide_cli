// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attribution_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AttributionConfig _$AttributionConfigFromJson(Map<String, dynamic> json) =>
    AttributionConfig(
      includeInCommitMessage: json['includeInCommitMessage'] as bool?,
      includeInPrDescription: json['includeInPrDescription'] as bool?,
      includeCoAuthoredBy: json['includeCoAuthoredBy'] as bool?,
    );

Map<String, dynamic> _$AttributionConfigToJson(AttributionConfig instance) =>
    <String, dynamic>{
      if (instance.includeInCommitMessage case final value?)
        'includeInCommitMessage': value,
      if (instance.includeInPrDescription case final value?)
        'includeInPrDescription': value,
      if (instance.includeCoAuthoredBy case final value?)
        'includeCoAuthoredBy': value,
    };
