import 'package:json_annotation/json_annotation.dart';

part 'response.g.dart';

/// Base class for all response types
sealed class MoondreamResponse {
  const MoondreamResponse();

  factory MoondreamResponse.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('answer')) {
      return QueryResponse.fromJson(json);
    } else if (json.containsKey('caption')) {
      return CaptionResponse.fromJson(json);
    } else if (json.containsKey('objects')) {
      return DetectResponse.fromJson(json);
    } else if (json.containsKey('x') && json.containsKey('y')) {
      return PointResponse.fromJson(json);
    } else if (json.containsKey('error')) {
      return ErrorResponse.fromJson(json);
    }
    throw FormatException('Unknown response format: $json');
  }
}

/// Response from query endpoint
@JsonSerializable()
class QueryResponse extends MoondreamResponse {
  final String answer;

  const QueryResponse({required this.answer});

  factory QueryResponse.fromJson(Map<String, dynamic> json) =>
      _$QueryResponseFromJson(json);

  Map<String, dynamic> toJson() => _$QueryResponseToJson(this);
}

/// Response from caption endpoint
@JsonSerializable()
class CaptionResponse extends MoondreamResponse {
  final String caption;

  const CaptionResponse({required this.caption});

  factory CaptionResponse.fromJson(Map<String, dynamic> json) =>
      _$CaptionResponseFromJson(json);

  Map<String, dynamic> toJson() => _$CaptionResponseToJson(this);
}

/// Bounding box for detected objects
@JsonSerializable()
class BoundingBox {
  @JsonKey(name: 'x_min')
  final double xMin;

  @JsonKey(name: 'y_min')
  final double yMin;

  @JsonKey(name: 'x_max')
  final double xMax;

  @JsonKey(name: 'y_max')
  final double yMax;

  const BoundingBox({
    required this.xMin,
    required this.yMin,
    required this.xMax,
    required this.yMax,
  });

  factory BoundingBox.fromJson(Map<String, dynamic> json) =>
      _$BoundingBoxFromJson(json);

  Map<String, dynamic> toJson() => _$BoundingBoxToJson(this);

  /// Calculate width of bounding box
  double get width => xMax - xMin;

  /// Calculate height of bounding box
  double get height => yMax - yMin;

  /// Calculate area of bounding box
  double get area => width * height;

  /// Calculate center point
  ({double x, double y}) get center =>
      (x: xMin + width / 2, y: yMin + height / 2);
}

/// Response from detect endpoint
@JsonSerializable()
class DetectResponse extends MoondreamResponse {
  final List<BoundingBox> objects;

  const DetectResponse({required this.objects});

  factory DetectResponse.fromJson(Map<String, dynamic> json) =>
      _$DetectResponseFromJson(json);

  Map<String, dynamic> toJson() => _$DetectResponseToJson(this);
}

/// Coordinate point for object location
@JsonSerializable()
class Point {
  final double x;
  final double y;

  const Point({required this.x, required this.y});

  factory Point.fromJson(Map<String, dynamic> json) => _$PointFromJson(json);

  Map<String, dynamic> toJson() => _$PointToJson(this);
}

/// Response from point endpoint
@JsonSerializable()
class PointResponse extends MoondreamResponse {
  final List<Point> points;

  const PointResponse({required this.points});

  factory PointResponse.fromJson(Map<String, dynamic> json) =>
      _$PointResponseFromJson(json);

  Map<String, dynamic> toJson() => _$PointResponseToJson(this);

  /// Get the first point (most relevant result)
  Point? get firstPoint => points.isNotEmpty ? points.first : null;

  /// Get x coordinate of first point (normalized 0-1)
  double? get x => firstPoint?.x;

  /// Get y coordinate of first point (normalized 0-1)
  double? get y => firstPoint?.y;
}

/// Error response from API
@JsonSerializable()
class ErrorResponse extends MoondreamResponse {
  final ErrorDetails error;

  const ErrorResponse({required this.error});

  factory ErrorResponse.fromJson(Map<String, dynamic> json) =>
      _$ErrorResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ErrorResponseToJson(this);
}

/// Error details
@JsonSerializable()
class ErrorDetails {
  final String message;
  final String? type;
  final String? param;
  final String? code;

  const ErrorDetails({required this.message, this.type, this.param, this.code});

  factory ErrorDetails.fromJson(Map<String, dynamic> json) =>
      _$ErrorDetailsFromJson(json);

  Map<String, dynamic> toJson() => _$ErrorDetailsToJson(this);
}
