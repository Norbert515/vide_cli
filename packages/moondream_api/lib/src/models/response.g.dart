// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

QueryResponse _$QueryResponseFromJson(Map<String, dynamic> json) =>
    QueryResponse(
      answer: json['answer'] as String,
    );

Map<String, dynamic> _$QueryResponseToJson(QueryResponse instance) =>
    <String, dynamic>{
      'answer': instance.answer,
    };

CaptionResponse _$CaptionResponseFromJson(Map<String, dynamic> json) =>
    CaptionResponse(
      caption: json['caption'] as String,
    );

Map<String, dynamic> _$CaptionResponseToJson(CaptionResponse instance) =>
    <String, dynamic>{
      'caption': instance.caption,
    };

BoundingBox _$BoundingBoxFromJson(Map<String, dynamic> json) => BoundingBox(
      xMin: (json['x_min'] as num).toDouble(),
      yMin: (json['y_min'] as num).toDouble(),
      xMax: (json['x_max'] as num).toDouble(),
      yMax: (json['y_max'] as num).toDouble(),
    );

Map<String, dynamic> _$BoundingBoxToJson(BoundingBox instance) =>
    <String, dynamic>{
      'x_min': instance.xMin,
      'y_min': instance.yMin,
      'x_max': instance.xMax,
      'y_max': instance.yMax,
    };

DetectResponse _$DetectResponseFromJson(Map<String, dynamic> json) =>
    DetectResponse(
      objects: (json['objects'] as List<dynamic>)
          .map((e) => BoundingBox.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$DetectResponseToJson(DetectResponse instance) =>
    <String, dynamic>{
      'objects': instance.objects,
    };

Point _$PointFromJson(Map<String, dynamic> json) => Point(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );

Map<String, dynamic> _$PointToJson(Point instance) => <String, dynamic>{
      'x': instance.x,
      'y': instance.y,
    };

PointResponse _$PointResponseFromJson(Map<String, dynamic> json) =>
    PointResponse(
      points: (json['points'] as List<dynamic>)
          .map((e) => Point.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$PointResponseToJson(PointResponse instance) =>
    <String, dynamic>{
      'points': instance.points,
    };

ErrorResponse _$ErrorResponseFromJson(Map<String, dynamic> json) =>
    ErrorResponse(
      error: ErrorDetails.fromJson(json['error'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ErrorResponseToJson(ErrorResponse instance) =>
    <String, dynamic>{
      'error': instance.error,
    };

ErrorDetails _$ErrorDetailsFromJson(Map<String, dynamic> json) => ErrorDetails(
      message: json['message'] as String,
      type: json['type'] as String?,
      param: json['param'] as String?,
      code: json['code'] as String?,
    );

Map<String, dynamic> _$ErrorDetailsToJson(ErrorDetails instance) =>
    <String, dynamic>{
      'message': instance.message,
      'type': instance.type,
      'param': instance.param,
      'code': instance.code,
    };
