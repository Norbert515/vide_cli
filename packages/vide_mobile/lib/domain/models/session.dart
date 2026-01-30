import 'package:freezed_annotation/freezed_annotation.dart';

part 'session.freezed.dart';
part 'session.g.dart';

/// Represents an active Vide session.
@freezed
class Session with _$Session {
  const factory Session({
    @JsonKey(name: 'session-id') required String sessionId,
    @JsonKey(name: 'main-agent-id') required String mainAgentId,
    @JsonKey(name: 'created-at') required DateTime createdAt,
    @JsonKey(name: 'working-directory') required String workingDirectory,
    @JsonKey(name: 'ws-url') String? wsUrl,
    String? model,
  }) = _Session;

  factory Session.fromJson(Map<String, dynamic> json) =>
      _$SessionFromJson(json);
}
