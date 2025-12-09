// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

QueryRequest _$QueryRequestFromJson(Map<String, dynamic> json) => QueryRequest(
  imageUrl: json['image_url'] as String,
  question: json['question'] as String,
  stream: json['stream'] as bool?,
);

Map<String, dynamic> _$QueryRequestToJson(QueryRequest instance) =>
    <String, dynamic>{
      'image_url': instance.imageUrl,
      'question': instance.question,
      'stream': ?instance.stream,
    };

CaptionRequest _$CaptionRequestFromJson(Map<String, dynamic> json) =>
    CaptionRequest(
      imageUrl: json['image_url'] as String,
      length: $enumDecodeNullable(_$CaptionLengthEnumMap, json['length']),
      stream: json['stream'] as bool?,
    );

Map<String, dynamic> _$CaptionRequestToJson(CaptionRequest instance) =>
    <String, dynamic>{
      'image_url': instance.imageUrl,
      'length': ?_$CaptionLengthEnumMap[instance.length],
      'stream': ?instance.stream,
    };

const _$CaptionLengthEnumMap = {
  CaptionLength.short: 'short',
  CaptionLength.normal: 'normal',
  CaptionLength.long: 'long',
};

DetectRequest _$DetectRequestFromJson(Map<String, dynamic> json) =>
    DetectRequest(
      imageUrl: json['image_url'] as String,
      object: json['object'] as String,
    );

Map<String, dynamic> _$DetectRequestToJson(DetectRequest instance) =>
    <String, dynamic>{
      'image_url': instance.imageUrl,
      'object': instance.object,
    };

PointRequest _$PointRequestFromJson(Map<String, dynamic> json) => PointRequest(
  imageUrl: json['image_url'] as String,
  object: json['object'] as String,
);

Map<String, dynamic> _$PointRequestToJson(PointRequest instance) =>
    <String, dynamic>{
      'image_url': instance.imageUrl,
      'object': instance.object,
    };
