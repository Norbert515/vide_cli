import 'package:freezed_annotation/freezed_annotation.dart';

part 'tool_event.freezed.dart';
part 'tool_event.g.dart';

/// Represents a tool invocation by an agent.
@freezed
class ToolUse with _$ToolUse {
  const factory ToolUse({
    @JsonKey(name: 'tool-use-id') required String toolUseId,
    @JsonKey(name: 'tool-name') required String toolName,
    required Map<String, dynamic> input,
    @JsonKey(name: 'agent-id') required String agentId,
    @JsonKey(name: 'agent-name') String? agentName,
    required DateTime timestamp,
  }) = _ToolUse;

  factory ToolUse.fromJson(Map<String, dynamic> json) =>
      _$ToolUseFromJson(json);
}

/// Represents the result of a tool invocation.
@freezed
class ToolResult with _$ToolResult {
  const factory ToolResult({
    @JsonKey(name: 'tool-use-id') required String toolUseId,
    @JsonKey(name: 'tool-name') required String toolName,
    required dynamic result,
    @JsonKey(name: 'is-error') required bool isError,
    required DateTime timestamp,
  }) = _ToolResult;

  factory ToolResult.fromJson(Map<String, dynamic> json) =>
      _$ToolResultFromJson(json);
}
