import 'package:freezed_annotation/freezed_annotation.dart';

import 'agent.dart';

part 'session_event.freezed.dart';
part 'session_event.g.dart';

/// Union type for all WebSocket events from the server.
@Freezed(unionKey: 'type', unionValueCase: FreezedUnionCase.kebab)
sealed class SessionEvent with _$SessionEvent {
  /// Sent on initial WebSocket connection with session metadata.
  const factory SessionEvent.connected({
    required int seq,
    @JsonKey(name: 'event-id') required String eventId,
    @JsonKey(name: 'session-id') required String sessionId,
    @JsonKey(name: 'main-agent-id') required String mainAgentId,
    @JsonKey(name: 'last-seq') required int lastSeq,
    required List<SessionEventAgent> agents,
    required DateTime timestamp,
  }) = ConnectedEvent;

  /// History events for reconnection state recovery.
  const factory SessionEvent.history({
    required int seq,
    @JsonKey(name: 'event-id') required String eventId,
    required List<Map<String, dynamic>> events,
    required DateTime timestamp,
  }) = HistoryEvent;

  /// Streaming message from an agent.
  const factory SessionEvent.message({
    required int seq,
    @JsonKey(name: 'event-id') required String eventId,
    @JsonKey(name: 'agent-id') required String agentId,
    @JsonKey(name: 'agent-type') required String agentType,
    @JsonKey(name: 'agent-name') String? agentName,
    @JsonKey(name: 'task-name') String? taskName,
    required SessionEventMessageData data,
    @JsonKey(name: 'is-partial') @Default(false) bool isPartial,
    required DateTime timestamp,
  }) = MessageEvent;

  /// Agent status change.
  const factory SessionEvent.status({
    required int seq,
    @JsonKey(name: 'event-id') required String eventId,
    @JsonKey(name: 'agent-id') required String agentId,
    @JsonKey(name: 'agent-type') required String agentType,
    @JsonKey(name: 'agent-name') String? agentName,
    @JsonKey(name: 'task-name') String? taskName,
    required AgentStatus status,
    required DateTime timestamp,
  }) = StatusEvent;

  /// Tool invocation by an agent.
  const factory SessionEvent.toolUse({
    required int seq,
    @JsonKey(name: 'event-id') required String eventId,
    @JsonKey(name: 'agent-id') required String agentId,
    @JsonKey(name: 'agent-type') required String agentType,
    @JsonKey(name: 'agent-name') String? agentName,
    @JsonKey(name: 'task-name') String? taskName,
    @JsonKey(name: 'tool-use-id') required String toolUseId,
    @JsonKey(name: 'tool-name') required String toolName,
    required Map<String, dynamic> input,
    required DateTime timestamp,
  }) = ToolUseEvent;

  /// Result of a tool invocation.
  const factory SessionEvent.toolResult({
    required int seq,
    @JsonKey(name: 'event-id') required String eventId,
    @JsonKey(name: 'agent-id') required String agentId,
    @JsonKey(name: 'agent-type') required String agentType,
    @JsonKey(name: 'agent-name') String? agentName,
    @JsonKey(name: 'task-name') String? taskName,
    @JsonKey(name: 'tool-use-id') required String toolUseId,
    @JsonKey(name: 'tool-name') required String toolName,
    required dynamic result,
    @JsonKey(name: 'is-error') @Default(false) bool isError,
    required DateTime timestamp,
  }) = ToolResultEvent;

  /// Permission request for a tool.
  const factory SessionEvent.permissionRequest({
    required int seq,
    @JsonKey(name: 'event-id') required String eventId,
    @JsonKey(name: 'agent-id') required String agentId,
    @JsonKey(name: 'agent-type') required String agentType,
    @JsonKey(name: 'agent-name') String? agentName,
    @JsonKey(name: 'task-name') String? taskName,
    @JsonKey(name: 'request-id') required String requestId,
    @JsonKey(name: 'tool-name') required String toolName,
    @JsonKey(name: 'tool-input') required Map<String, dynamic> toolInput,
    @JsonKey(name: 'permission-suggestions') List<String>? permissionSuggestions,
    required DateTime timestamp,
  }) = PermissionRequestEvent;

  /// Permission request timed out.
  const factory SessionEvent.permissionTimeout({
    required int seq,
    @JsonKey(name: 'event-id') required String eventId,
    @JsonKey(name: 'agent-id') required String agentId,
    @JsonKey(name: 'agent-type') required String agentType,
    @JsonKey(name: 'agent-name') String? agentName,
    @JsonKey(name: 'task-name') String? taskName,
    @JsonKey(name: 'request-id') required String requestId,
    required DateTime timestamp,
  }) = PermissionTimeoutEvent;

  /// Agent turn completed.
  const factory SessionEvent.done({
    required int seq,
    @JsonKey(name: 'event-id') required String eventId,
    @JsonKey(name: 'agent-id') required String agentId,
    @JsonKey(name: 'agent-type') required String agentType,
    @JsonKey(name: 'agent-name') String? agentName,
    @JsonKey(name: 'task-name') String? taskName,
    required String reason,
    required DateTime timestamp,
  }) = DoneEvent;

  /// Operation was aborted.
  const factory SessionEvent.aborted({
    required int seq,
    @JsonKey(name: 'event-id') required String eventId,
    @JsonKey(name: 'agent-id') required String agentId,
    @JsonKey(name: 'agent-type') required String agentType,
    @JsonKey(name: 'agent-name') String? agentName,
    @JsonKey(name: 'task-name') String? taskName,
    required DateTime timestamp,
  }) = AbortedEvent;

  /// New agent spawned.
  const factory SessionEvent.agentSpawned({
    required int seq,
    @JsonKey(name: 'event-id') required String eventId,
    @JsonKey(name: 'agent-id') required String agentId,
    @JsonKey(name: 'agent-type') required String agentType,
    @JsonKey(name: 'agent-name') required String agentName,
    @JsonKey(name: 'parent-agent-id') String? parentAgentId,
    required DateTime timestamp,
  }) = AgentSpawnedEvent;

  /// Agent terminated.
  const factory SessionEvent.agentTerminated({
    required int seq,
    @JsonKey(name: 'event-id') required String eventId,
    @JsonKey(name: 'agent-id') required String agentId,
    @JsonKey(name: 'agent-type') required String agentType,
    @JsonKey(name: 'agent-name') String? agentName,
    String? reason,
    required DateTime timestamp,
  }) = AgentTerminatedEvent;

  /// Error occurred.
  const factory SessionEvent.error({
    required int seq,
    @JsonKey(name: 'event-id') required String eventId,
    @JsonKey(name: 'agent-id') String? agentId,
    @JsonKey(name: 'agent-type') String? agentType,
    @JsonKey(name: 'agent-name') String? agentName,
    @JsonKey(name: 'task-name') String? taskName,
    required String code,
    required String message,
    required DateTime timestamp,
  }) = ErrorEvent;

  factory SessionEvent.fromJson(Map<String, dynamic> json) =>
      _$SessionEventFromJson(json);
}

/// Agent info included in connected event.
@freezed
class SessionEventAgent with _$SessionEventAgent {
  const factory SessionEventAgent({
    required String id,
    required String type,
    required String name,
    required AgentStatus status,
    @JsonKey(name: 'task-name') String? taskName,
  }) = _SessionEventAgent;

  factory SessionEventAgent.fromJson(Map<String, dynamic> json) =>
      _$SessionEventAgentFromJson(json);
}

/// Message data included in message events.
@freezed
class SessionEventMessageData with _$SessionEventMessageData {
  const factory SessionEventMessageData({
    required String role,
    required String content,
  }) = _SessionEventMessageData;

  factory SessionEventMessageData.fromJson(Map<String, dynamic> json) =>
      _$SessionEventMessageDataFromJson(json);
}
