import 'package:freezed_annotation/freezed_annotation.dart';

part 'permission_request.freezed.dart';
part 'permission_request.g.dart';

/// Represents a permission request from an agent.
@freezed
class PermissionRequest with _$PermissionRequest {
  const factory PermissionRequest({
    @JsonKey(name: 'request-id') required String requestId,
    @JsonKey(name: 'tool-name') required String toolName,
    @JsonKey(name: 'tool-input') required Map<String, dynamic> toolInput,
    @JsonKey(name: 'agent-id') required String agentId,
    @JsonKey(name: 'agent-name') String? agentName,
    @JsonKey(name: 'permission-suggestions') List<String>? permissionSuggestions,
    required DateTime timestamp,
  }) = _PermissionRequest;

  factory PermissionRequest.fromJson(Map<String, dynamic> json) =>
      _$PermissionRequestFromJson(json);
}
