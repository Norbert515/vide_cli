import 'package:freezed_annotation/freezed_annotation.dart';

part 'agent.freezed.dart';
part 'agent.g.dart';

/// The current status of an agent.
@JsonEnum(fieldRename: FieldRename.kebab)
enum AgentStatus {
  working,
  @JsonValue('waiting-for-agent')
  waitingForAgent,
  @JsonValue('waiting-for-user')
  waitingForUser,
  idle,
}

/// Represents an agent in the session.
@freezed
class Agent with _$Agent {
  const factory Agent({
    required String id,
    required String type,
    required String name,
    @Default(AgentStatus.idle) AgentStatus status,
    @JsonKey(name: 'task-name') String? taskName,
  }) = _Agent;

  factory Agent.fromJson(Map<String, dynamic> json) => _$AgentFromJson(json);
}
