import 'package:json_annotation/json_annotation.dart';

part 'request.g.dart';

/// Base class for all request types
abstract class MoondreamRequest {
  const MoondreamRequest();

  Map<String, dynamic> toJson();
}

/// Request for visual question answering
@JsonSerializable(includeIfNull: false)
class QueryRequest extends MoondreamRequest {
  @JsonKey(name: 'image_url')
  final String imageUrl;

  final String question;

  final bool? stream;

  const QueryRequest({
    required this.imageUrl,
    required this.question,
    this.stream,
  });

  factory QueryRequest.fromJson(Map<String, dynamic> json) =>
      _$QueryRequestFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$QueryRequestToJson(this);
}

/// Caption length options
enum CaptionLength {
  @JsonValue('short')
  short,
  @JsonValue('normal')
  normal,
  @JsonValue('long')
  long,
}

/// Request for image captioning
@JsonSerializable(includeIfNull: false)
class CaptionRequest extends MoondreamRequest {
  @JsonKey(name: 'image_url')
  final String imageUrl;

  final CaptionLength? length;

  final bool? stream;

  const CaptionRequest({required this.imageUrl, this.length, this.stream});

  factory CaptionRequest.fromJson(Map<String, dynamic> json) =>
      _$CaptionRequestFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$CaptionRequestToJson(this);
}

/// Request for object detection
@JsonSerializable()
class DetectRequest extends MoondreamRequest {
  @JsonKey(name: 'image_url')
  final String imageUrl;

  final String object;

  const DetectRequest({required this.imageUrl, required this.object});

  factory DetectRequest.fromJson(Map<String, dynamic> json) =>
      _$DetectRequestFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$DetectRequestToJson(this);
}

/// Request for object pointing
@JsonSerializable()
class PointRequest extends MoondreamRequest {
  @JsonKey(name: 'image_url')
  final String imageUrl;

  final String object;

  const PointRequest({required this.imageUrl, required this.object});

  factory PointRequest.fromJson(Map<String, dynamic> json) =>
      _$PointRequestFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$PointRequestToJson(this);
}
