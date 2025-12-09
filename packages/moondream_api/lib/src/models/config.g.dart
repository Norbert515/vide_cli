// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MoondreamConfig _$MoondreamConfigFromJson(Map<String, dynamic> json) =>
    MoondreamConfig(
      apiKey: json['apiKey'] as String?,
      baseUrl: json['baseUrl'] as String? ?? 'https://api.moondream.ai/v1',
      timeout: json['timeout'] == null
          ? const Duration(seconds: 30)
          : MoondreamConfig._durationFromMillis(
              (json['timeout'] as num).toInt(),
            ),
      retryAttempts: (json['retryAttempts'] as num?)?.toInt() ?? 3,
      retryDelay: json['retryDelay'] == null
          ? const Duration(seconds: 1)
          : MoondreamConfig._durationFromMillis(
              (json['retryDelay'] as num).toInt(),
            ),
      verbose: json['verbose'] as bool? ?? false,
    );

Map<String, dynamic> _$MoondreamConfigToJson(MoondreamConfig instance) =>
    <String, dynamic>{
      'apiKey': instance.apiKey,
      'baseUrl': instance.baseUrl,
      'timeout': MoondreamConfig._durationToMillis(instance.timeout),
      'retryAttempts': instance.retryAttempts,
      'retryDelay': MoondreamConfig._durationToMillis(instance.retryDelay),
      'verbose': instance.verbose,
    };
