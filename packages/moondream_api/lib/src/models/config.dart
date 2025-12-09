import 'package:json_annotation/json_annotation.dart';

part 'config.g.dart';

/// Configuration for Moondream API client
@JsonSerializable()
class MoondreamConfig {
  /// API key for authentication (can be null if using local endpoint)
  final String? apiKey;

  /// Base URL for API requests
  final String baseUrl;

  /// Request timeout duration
  @JsonKey(fromJson: _durationFromMillis, toJson: _durationToMillis)
  final Duration timeout;

  /// Number of retry attempts for failed requests
  final int retryAttempts;

  /// Delay between retry attempts
  @JsonKey(fromJson: _durationFromMillis, toJson: _durationToMillis)
  final Duration retryDelay;

  /// Enable verbose logging
  final bool verbose;

  const MoondreamConfig({
    this.apiKey,
    this.baseUrl = 'https://api.moondream.ai/v1',
    this.timeout = const Duration(seconds: 30),
    this.retryAttempts = 3,
    this.retryDelay = const Duration(seconds: 1),
    this.verbose = false,
  });

  /// Create config with default values
  factory MoondreamConfig.defaults() => const MoondreamConfig();

  /// Create config from JSON
  factory MoondreamConfig.fromJson(Map<String, dynamic> json) =>
      _$MoondreamConfigFromJson(json);

  /// Convert to JSON
  Map<String, dynamic> toJson() => _$MoondreamConfigToJson(this);

  /// Create a copy with modified fields
  MoondreamConfig copyWith({
    String? apiKey,
    String? baseUrl,
    Duration? timeout,
    int? retryAttempts,
    Duration? retryDelay,
    bool? verbose,
  }) {
    return MoondreamConfig(
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      timeout: timeout ?? this.timeout,
      retryAttempts: retryAttempts ?? this.retryAttempts,
      retryDelay: retryDelay ?? this.retryDelay,
      verbose: verbose ?? this.verbose,
    );
  }

  static Duration _durationFromMillis(int millis) =>
      Duration(milliseconds: millis);

  static int _durationToMillis(Duration duration) => duration.inMilliseconds;
}
