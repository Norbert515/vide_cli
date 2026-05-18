// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_connection.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ServerConnectionImpl _$$ServerConnectionImplFromJson(
        Map<String, dynamic> json) =>
    _$ServerConnectionImpl(
      id: json['id'] as String,
      host: json['host'] as String,
      port: (json['port'] as num).toInt(),
      isSecure: json['isSecure'] as bool? ?? false,
      name: json['name'] as String?,
    );

Map<String, dynamic> _$$ServerConnectionImplToJson(
        _$ServerConnectionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'host': instance.host,
      'port': instance.port,
      'isSecure': instance.isSecure,
      'name': instance.name,
    };
