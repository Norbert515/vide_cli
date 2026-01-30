// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

SessionEvent _$SessionEventFromJson(Map<String, dynamic> json) {
  switch (json['type']) {
    case 'connected':
      return ConnectedEvent.fromJson(json);
    case 'history':
      return HistoryEvent.fromJson(json);
    case 'message':
      return MessageEvent.fromJson(json);
    case 'status':
      return StatusEvent.fromJson(json);
    case 'tool-use':
      return ToolUseEvent.fromJson(json);
    case 'tool-result':
      return ToolResultEvent.fromJson(json);
    case 'permission-request':
      return PermissionRequestEvent.fromJson(json);
    case 'permission-timeout':
      return PermissionTimeoutEvent.fromJson(json);
    case 'done':
      return DoneEvent.fromJson(json);
    case 'aborted':
      return AbortedEvent.fromJson(json);
    case 'agent-spawned':
      return AgentSpawnedEvent.fromJson(json);
    case 'agent-terminated':
      return AgentTerminatedEvent.fromJson(json);
    case 'error':
      return ErrorEvent.fromJson(json);

    default:
      throw CheckedFromJsonException(json, 'type', 'SessionEvent',
          'Invalid union type "${json['type']}"!');
  }
}

/// @nodoc
mixin _$SessionEvent {
  int get seq => throw _privateConstructorUsedError;
  @JsonKey(name: 'event-id')
  String get eventId => throw _privateConstructorUsedError;
  DateTime get timestamp => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)
        connected,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events,
            DateTime timestamp)
        history,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)
        message,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)
        status,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)
        toolUse,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)
        toolResult,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)
        permissionRequest,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)
        permissionTimeout,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)
        done,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)
        aborted,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)
        agentSpawned,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)
        agentTerminated,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)
        error,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)?
        connected,
    TResult? Function(int seq, @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events, DateTime timestamp)?
        history,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)?
        message,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)?
        status,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)?
        toolUse,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)?
        toolResult,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)?
        permissionRequest,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)?
        permissionTimeout,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)?
        done,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)?
        aborted,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)?
        agentSpawned,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)?
        agentTerminated,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)?
        error,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)?
        connected,
    TResult Function(int seq, @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events, DateTime timestamp)?
        history,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)?
        message,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)?
        status,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)?
        toolUse,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)?
        toolResult,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)?
        permissionRequest,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)?
        permissionTimeout,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)?
        done,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)?
        aborted,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)?
        agentSpawned,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)?
        agentTerminated,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)?
        error,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConnectedEvent value) connected,
    required TResult Function(HistoryEvent value) history,
    required TResult Function(MessageEvent value) message,
    required TResult Function(StatusEvent value) status,
    required TResult Function(ToolUseEvent value) toolUse,
    required TResult Function(ToolResultEvent value) toolResult,
    required TResult Function(PermissionRequestEvent value) permissionRequest,
    required TResult Function(PermissionTimeoutEvent value) permissionTimeout,
    required TResult Function(DoneEvent value) done,
    required TResult Function(AbortedEvent value) aborted,
    required TResult Function(AgentSpawnedEvent value) agentSpawned,
    required TResult Function(AgentTerminatedEvent value) agentTerminated,
    required TResult Function(ErrorEvent value) error,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConnectedEvent value)? connected,
    TResult? Function(HistoryEvent value)? history,
    TResult? Function(MessageEvent value)? message,
    TResult? Function(StatusEvent value)? status,
    TResult? Function(ToolUseEvent value)? toolUse,
    TResult? Function(ToolResultEvent value)? toolResult,
    TResult? Function(PermissionRequestEvent value)? permissionRequest,
    TResult? Function(PermissionTimeoutEvent value)? permissionTimeout,
    TResult? Function(DoneEvent value)? done,
    TResult? Function(AbortedEvent value)? aborted,
    TResult? Function(AgentSpawnedEvent value)? agentSpawned,
    TResult? Function(AgentTerminatedEvent value)? agentTerminated,
    TResult? Function(ErrorEvent value)? error,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConnectedEvent value)? connected,
    TResult Function(HistoryEvent value)? history,
    TResult Function(MessageEvent value)? message,
    TResult Function(StatusEvent value)? status,
    TResult Function(ToolUseEvent value)? toolUse,
    TResult Function(ToolResultEvent value)? toolResult,
    TResult Function(PermissionRequestEvent value)? permissionRequest,
    TResult Function(PermissionTimeoutEvent value)? permissionTimeout,
    TResult Function(DoneEvent value)? done,
    TResult Function(AbortedEvent value)? aborted,
    TResult Function(AgentSpawnedEvent value)? agentSpawned,
    TResult Function(AgentTerminatedEvent value)? agentTerminated,
    TResult Function(ErrorEvent value)? error,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;

  /// Serializes this SessionEvent to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SessionEventCopyWith<SessionEvent> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SessionEventCopyWith<$Res> {
  factory $SessionEventCopyWith(
          SessionEvent value, $Res Function(SessionEvent) then) =
      _$SessionEventCopyWithImpl<$Res, SessionEvent>;
  @useResult
  $Res call(
      {int seq, @JsonKey(name: 'event-id') String eventId, DateTime timestamp});
}

/// @nodoc
class _$SessionEventCopyWithImpl<$Res, $Val extends SessionEvent>
    implements $SessionEventCopyWith<$Res> {
  _$SessionEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? seq = null,
    Object? eventId = null,
    Object? timestamp = null,
  }) {
    return _then(_value.copyWith(
      seq: null == seq
          ? _value.seq
          : seq // ignore: cast_nullable_to_non_nullable
              as int,
      eventId: null == eventId
          ? _value.eventId
          : eventId // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ConnectedEventImplCopyWith<$Res>
    implements $SessionEventCopyWith<$Res> {
  factory _$$ConnectedEventImplCopyWith(_$ConnectedEventImpl value,
          $Res Function(_$ConnectedEventImpl) then) =
      __$$ConnectedEventImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int seq,
      @JsonKey(name: 'event-id') String eventId,
      @JsonKey(name: 'session-id') String sessionId,
      @JsonKey(name: 'main-agent-id') String mainAgentId,
      @JsonKey(name: 'last-seq') int lastSeq,
      List<SessionEventAgent> agents,
      DateTime timestamp});
}

/// @nodoc
class __$$ConnectedEventImplCopyWithImpl<$Res>
    extends _$SessionEventCopyWithImpl<$Res, _$ConnectedEventImpl>
    implements _$$ConnectedEventImplCopyWith<$Res> {
  __$$ConnectedEventImplCopyWithImpl(
      _$ConnectedEventImpl _value, $Res Function(_$ConnectedEventImpl) _then)
      : super(_value, _then);

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? seq = null,
    Object? eventId = null,
    Object? sessionId = null,
    Object? mainAgentId = null,
    Object? lastSeq = null,
    Object? agents = null,
    Object? timestamp = null,
  }) {
    return _then(_$ConnectedEventImpl(
      seq: null == seq
          ? _value.seq
          : seq // ignore: cast_nullable_to_non_nullable
              as int,
      eventId: null == eventId
          ? _value.eventId
          : eventId // ignore: cast_nullable_to_non_nullable
              as String,
      sessionId: null == sessionId
          ? _value.sessionId
          : sessionId // ignore: cast_nullable_to_non_nullable
              as String,
      mainAgentId: null == mainAgentId
          ? _value.mainAgentId
          : mainAgentId // ignore: cast_nullable_to_non_nullable
              as String,
      lastSeq: null == lastSeq
          ? _value.lastSeq
          : lastSeq // ignore: cast_nullable_to_non_nullable
              as int,
      agents: null == agents
          ? _value._agents
          : agents // ignore: cast_nullable_to_non_nullable
              as List<SessionEventAgent>,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ConnectedEventImpl implements ConnectedEvent {
  const _$ConnectedEventImpl(
      {required this.seq,
      @JsonKey(name: 'event-id') required this.eventId,
      @JsonKey(name: 'session-id') required this.sessionId,
      @JsonKey(name: 'main-agent-id') required this.mainAgentId,
      @JsonKey(name: 'last-seq') required this.lastSeq,
      required final List<SessionEventAgent> agents,
      required this.timestamp,
      final String? $type})
      : _agents = agents,
        $type = $type ?? 'connected';

  factory _$ConnectedEventImpl.fromJson(Map<String, dynamic> json) =>
      _$$ConnectedEventImplFromJson(json);

  @override
  final int seq;
  @override
  @JsonKey(name: 'event-id')
  final String eventId;
  @override
  @JsonKey(name: 'session-id')
  final String sessionId;
  @override
  @JsonKey(name: 'main-agent-id')
  final String mainAgentId;
  @override
  @JsonKey(name: 'last-seq')
  final int lastSeq;
  final List<SessionEventAgent> _agents;
  @override
  List<SessionEventAgent> get agents {
    if (_agents is EqualUnmodifiableListView) return _agents;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_agents);
  }

  @override
  final DateTime timestamp;

  @JsonKey(name: 'type')
  final String $type;

  @override
  String toString() {
    return 'SessionEvent.connected(seq: $seq, eventId: $eventId, sessionId: $sessionId, mainAgentId: $mainAgentId, lastSeq: $lastSeq, agents: $agents, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConnectedEventImpl &&
            (identical(other.seq, seq) || other.seq == seq) &&
            (identical(other.eventId, eventId) || other.eventId == eventId) &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.mainAgentId, mainAgentId) ||
                other.mainAgentId == mainAgentId) &&
            (identical(other.lastSeq, lastSeq) || other.lastSeq == lastSeq) &&
            const DeepCollectionEquality().equals(other._agents, _agents) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      seq,
      eventId,
      sessionId,
      mainAgentId,
      lastSeq,
      const DeepCollectionEquality().hash(_agents),
      timestamp);

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConnectedEventImplCopyWith<_$ConnectedEventImpl> get copyWith =>
      __$$ConnectedEventImplCopyWithImpl<_$ConnectedEventImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)
        connected,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events,
            DateTime timestamp)
        history,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)
        message,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)
        status,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)
        toolUse,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)
        toolResult,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)
        permissionRequest,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)
        permissionTimeout,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)
        done,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)
        aborted,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)
        agentSpawned,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)
        agentTerminated,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)
        error,
  }) {
    return connected(
        seq, eventId, sessionId, mainAgentId, lastSeq, agents, timestamp);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)?
        connected,
    TResult? Function(int seq, @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events, DateTime timestamp)?
        history,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)?
        message,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)?
        status,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)?
        toolUse,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)?
        toolResult,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)?
        permissionRequest,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)?
        permissionTimeout,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)?
        done,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)?
        aborted,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)?
        agentSpawned,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)?
        agentTerminated,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)?
        error,
  }) {
    return connected?.call(
        seq, eventId, sessionId, mainAgentId, lastSeq, agents, timestamp);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)?
        connected,
    TResult Function(int seq, @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events, DateTime timestamp)?
        history,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)?
        message,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)?
        status,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)?
        toolUse,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)?
        toolResult,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)?
        permissionRequest,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)?
        permissionTimeout,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)?
        done,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)?
        aborted,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)?
        agentSpawned,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)?
        agentTerminated,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)?
        error,
    required TResult orElse(),
  }) {
    if (connected != null) {
      return connected(
          seq, eventId, sessionId, mainAgentId, lastSeq, agents, timestamp);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConnectedEvent value) connected,
    required TResult Function(HistoryEvent value) history,
    required TResult Function(MessageEvent value) message,
    required TResult Function(StatusEvent value) status,
    required TResult Function(ToolUseEvent value) toolUse,
    required TResult Function(ToolResultEvent value) toolResult,
    required TResult Function(PermissionRequestEvent value) permissionRequest,
    required TResult Function(PermissionTimeoutEvent value) permissionTimeout,
    required TResult Function(DoneEvent value) done,
    required TResult Function(AbortedEvent value) aborted,
    required TResult Function(AgentSpawnedEvent value) agentSpawned,
    required TResult Function(AgentTerminatedEvent value) agentTerminated,
    required TResult Function(ErrorEvent value) error,
  }) {
    return connected(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConnectedEvent value)? connected,
    TResult? Function(HistoryEvent value)? history,
    TResult? Function(MessageEvent value)? message,
    TResult? Function(StatusEvent value)? status,
    TResult? Function(ToolUseEvent value)? toolUse,
    TResult? Function(ToolResultEvent value)? toolResult,
    TResult? Function(PermissionRequestEvent value)? permissionRequest,
    TResult? Function(PermissionTimeoutEvent value)? permissionTimeout,
    TResult? Function(DoneEvent value)? done,
    TResult? Function(AbortedEvent value)? aborted,
    TResult? Function(AgentSpawnedEvent value)? agentSpawned,
    TResult? Function(AgentTerminatedEvent value)? agentTerminated,
    TResult? Function(ErrorEvent value)? error,
  }) {
    return connected?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConnectedEvent value)? connected,
    TResult Function(HistoryEvent value)? history,
    TResult Function(MessageEvent value)? message,
    TResult Function(StatusEvent value)? status,
    TResult Function(ToolUseEvent value)? toolUse,
    TResult Function(ToolResultEvent value)? toolResult,
    TResult Function(PermissionRequestEvent value)? permissionRequest,
    TResult Function(PermissionTimeoutEvent value)? permissionTimeout,
    TResult Function(DoneEvent value)? done,
    TResult Function(AbortedEvent value)? aborted,
    TResult Function(AgentSpawnedEvent value)? agentSpawned,
    TResult Function(AgentTerminatedEvent value)? agentTerminated,
    TResult Function(ErrorEvent value)? error,
    required TResult orElse(),
  }) {
    if (connected != null) {
      return connected(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$ConnectedEventImplToJson(
      this,
    );
  }
}

abstract class ConnectedEvent implements SessionEvent {
  const factory ConnectedEvent(
      {required final int seq,
      @JsonKey(name: 'event-id') required final String eventId,
      @JsonKey(name: 'session-id') required final String sessionId,
      @JsonKey(name: 'main-agent-id') required final String mainAgentId,
      @JsonKey(name: 'last-seq') required final int lastSeq,
      required final List<SessionEventAgent> agents,
      required final DateTime timestamp}) = _$ConnectedEventImpl;

  factory ConnectedEvent.fromJson(Map<String, dynamic> json) =
      _$ConnectedEventImpl.fromJson;

  @override
  int get seq;
  @override
  @JsonKey(name: 'event-id')
  String get eventId;
  @JsonKey(name: 'session-id')
  String get sessionId;
  @JsonKey(name: 'main-agent-id')
  String get mainAgentId;
  @JsonKey(name: 'last-seq')
  int get lastSeq;
  List<SessionEventAgent> get agents;
  @override
  DateTime get timestamp;

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConnectedEventImplCopyWith<_$ConnectedEventImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$HistoryEventImplCopyWith<$Res>
    implements $SessionEventCopyWith<$Res> {
  factory _$$HistoryEventImplCopyWith(
          _$HistoryEventImpl value, $Res Function(_$HistoryEventImpl) then) =
      __$$HistoryEventImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int seq,
      @JsonKey(name: 'event-id') String eventId,
      List<Map<String, dynamic>> events,
      DateTime timestamp});
}

/// @nodoc
class __$$HistoryEventImplCopyWithImpl<$Res>
    extends _$SessionEventCopyWithImpl<$Res, _$HistoryEventImpl>
    implements _$$HistoryEventImplCopyWith<$Res> {
  __$$HistoryEventImplCopyWithImpl(
      _$HistoryEventImpl _value, $Res Function(_$HistoryEventImpl) _then)
      : super(_value, _then);

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? seq = null,
    Object? eventId = null,
    Object? events = null,
    Object? timestamp = null,
  }) {
    return _then(_$HistoryEventImpl(
      seq: null == seq
          ? _value.seq
          : seq // ignore: cast_nullable_to_non_nullable
              as int,
      eventId: null == eventId
          ? _value.eventId
          : eventId // ignore: cast_nullable_to_non_nullable
              as String,
      events: null == events
          ? _value._events
          : events // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$HistoryEventImpl implements HistoryEvent {
  const _$HistoryEventImpl(
      {required this.seq,
      @JsonKey(name: 'event-id') required this.eventId,
      required final List<Map<String, dynamic>> events,
      required this.timestamp,
      final String? $type})
      : _events = events,
        $type = $type ?? 'history';

  factory _$HistoryEventImpl.fromJson(Map<String, dynamic> json) =>
      _$$HistoryEventImplFromJson(json);

  @override
  final int seq;
  @override
  @JsonKey(name: 'event-id')
  final String eventId;
  final List<Map<String, dynamic>> _events;
  @override
  List<Map<String, dynamic>> get events {
    if (_events is EqualUnmodifiableListView) return _events;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_events);
  }

  @override
  final DateTime timestamp;

  @JsonKey(name: 'type')
  final String $type;

  @override
  String toString() {
    return 'SessionEvent.history(seq: $seq, eventId: $eventId, events: $events, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HistoryEventImpl &&
            (identical(other.seq, seq) || other.seq == seq) &&
            (identical(other.eventId, eventId) || other.eventId == eventId) &&
            const DeepCollectionEquality().equals(other._events, _events) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, seq, eventId,
      const DeepCollectionEquality().hash(_events), timestamp);

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$HistoryEventImplCopyWith<_$HistoryEventImpl> get copyWith =>
      __$$HistoryEventImplCopyWithImpl<_$HistoryEventImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)
        connected,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events,
            DateTime timestamp)
        history,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)
        message,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)
        status,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)
        toolUse,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)
        toolResult,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)
        permissionRequest,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)
        permissionTimeout,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)
        done,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)
        aborted,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)
        agentSpawned,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)
        agentTerminated,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)
        error,
  }) {
    return history(seq, eventId, events, timestamp);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)?
        connected,
    TResult? Function(int seq, @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events, DateTime timestamp)?
        history,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)?
        message,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)?
        status,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)?
        toolUse,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)?
        toolResult,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)?
        permissionRequest,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)?
        permissionTimeout,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)?
        done,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)?
        aborted,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)?
        agentSpawned,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)?
        agentTerminated,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)?
        error,
  }) {
    return history?.call(seq, eventId, events, timestamp);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)?
        connected,
    TResult Function(int seq, @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events, DateTime timestamp)?
        history,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)?
        message,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)?
        status,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)?
        toolUse,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)?
        toolResult,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)?
        permissionRequest,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)?
        permissionTimeout,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)?
        done,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)?
        aborted,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)?
        agentSpawned,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)?
        agentTerminated,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)?
        error,
    required TResult orElse(),
  }) {
    if (history != null) {
      return history(seq, eventId, events, timestamp);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConnectedEvent value) connected,
    required TResult Function(HistoryEvent value) history,
    required TResult Function(MessageEvent value) message,
    required TResult Function(StatusEvent value) status,
    required TResult Function(ToolUseEvent value) toolUse,
    required TResult Function(ToolResultEvent value) toolResult,
    required TResult Function(PermissionRequestEvent value) permissionRequest,
    required TResult Function(PermissionTimeoutEvent value) permissionTimeout,
    required TResult Function(DoneEvent value) done,
    required TResult Function(AbortedEvent value) aborted,
    required TResult Function(AgentSpawnedEvent value) agentSpawned,
    required TResult Function(AgentTerminatedEvent value) agentTerminated,
    required TResult Function(ErrorEvent value) error,
  }) {
    return history(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConnectedEvent value)? connected,
    TResult? Function(HistoryEvent value)? history,
    TResult? Function(MessageEvent value)? message,
    TResult? Function(StatusEvent value)? status,
    TResult? Function(ToolUseEvent value)? toolUse,
    TResult? Function(ToolResultEvent value)? toolResult,
    TResult? Function(PermissionRequestEvent value)? permissionRequest,
    TResult? Function(PermissionTimeoutEvent value)? permissionTimeout,
    TResult? Function(DoneEvent value)? done,
    TResult? Function(AbortedEvent value)? aborted,
    TResult? Function(AgentSpawnedEvent value)? agentSpawned,
    TResult? Function(AgentTerminatedEvent value)? agentTerminated,
    TResult? Function(ErrorEvent value)? error,
  }) {
    return history?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConnectedEvent value)? connected,
    TResult Function(HistoryEvent value)? history,
    TResult Function(MessageEvent value)? message,
    TResult Function(StatusEvent value)? status,
    TResult Function(ToolUseEvent value)? toolUse,
    TResult Function(ToolResultEvent value)? toolResult,
    TResult Function(PermissionRequestEvent value)? permissionRequest,
    TResult Function(PermissionTimeoutEvent value)? permissionTimeout,
    TResult Function(DoneEvent value)? done,
    TResult Function(AbortedEvent value)? aborted,
    TResult Function(AgentSpawnedEvent value)? agentSpawned,
    TResult Function(AgentTerminatedEvent value)? agentTerminated,
    TResult Function(ErrorEvent value)? error,
    required TResult orElse(),
  }) {
    if (history != null) {
      return history(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$HistoryEventImplToJson(
      this,
    );
  }
}

abstract class HistoryEvent implements SessionEvent {
  const factory HistoryEvent(
      {required final int seq,
      @JsonKey(name: 'event-id') required final String eventId,
      required final List<Map<String, dynamic>> events,
      required final DateTime timestamp}) = _$HistoryEventImpl;

  factory HistoryEvent.fromJson(Map<String, dynamic> json) =
      _$HistoryEventImpl.fromJson;

  @override
  int get seq;
  @override
  @JsonKey(name: 'event-id')
  String get eventId;
  List<Map<String, dynamic>> get events;
  @override
  DateTime get timestamp;

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$HistoryEventImplCopyWith<_$HistoryEventImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$MessageEventImplCopyWith<$Res>
    implements $SessionEventCopyWith<$Res> {
  factory _$$MessageEventImplCopyWith(
          _$MessageEventImpl value, $Res Function(_$MessageEventImpl) then) =
      __$$MessageEventImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int seq,
      @JsonKey(name: 'event-id') String eventId,
      @JsonKey(name: 'agent-id') String agentId,
      @JsonKey(name: 'agent-type') String agentType,
      @JsonKey(name: 'agent-name') String? agentName,
      @JsonKey(name: 'task-name') String? taskName,
      SessionEventMessageData data,
      @JsonKey(name: 'is-partial') bool isPartial,
      DateTime timestamp});

  $SessionEventMessageDataCopyWith<$Res> get data;
}

/// @nodoc
class __$$MessageEventImplCopyWithImpl<$Res>
    extends _$SessionEventCopyWithImpl<$Res, _$MessageEventImpl>
    implements _$$MessageEventImplCopyWith<$Res> {
  __$$MessageEventImplCopyWithImpl(
      _$MessageEventImpl _value, $Res Function(_$MessageEventImpl) _then)
      : super(_value, _then);

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? seq = null,
    Object? eventId = null,
    Object? agentId = null,
    Object? agentType = null,
    Object? agentName = freezed,
    Object? taskName = freezed,
    Object? data = null,
    Object? isPartial = null,
    Object? timestamp = null,
  }) {
    return _then(_$MessageEventImpl(
      seq: null == seq
          ? _value.seq
          : seq // ignore: cast_nullable_to_non_nullable
              as int,
      eventId: null == eventId
          ? _value.eventId
          : eventId // ignore: cast_nullable_to_non_nullable
              as String,
      agentId: null == agentId
          ? _value.agentId
          : agentId // ignore: cast_nullable_to_non_nullable
              as String,
      agentType: null == agentType
          ? _value.agentType
          : agentType // ignore: cast_nullable_to_non_nullable
              as String,
      agentName: freezed == agentName
          ? _value.agentName
          : agentName // ignore: cast_nullable_to_non_nullable
              as String?,
      taskName: freezed == taskName
          ? _value.taskName
          : taskName // ignore: cast_nullable_to_non_nullable
              as String?,
      data: null == data
          ? _value.data
          : data // ignore: cast_nullable_to_non_nullable
              as SessionEventMessageData,
      isPartial: null == isPartial
          ? _value.isPartial
          : isPartial // ignore: cast_nullable_to_non_nullable
              as bool,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SessionEventMessageDataCopyWith<$Res> get data {
    return $SessionEventMessageDataCopyWith<$Res>(_value.data, (value) {
      return _then(_value.copyWith(data: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class _$MessageEventImpl implements MessageEvent {
  const _$MessageEventImpl(
      {required this.seq,
      @JsonKey(name: 'event-id') required this.eventId,
      @JsonKey(name: 'agent-id') required this.agentId,
      @JsonKey(name: 'agent-type') required this.agentType,
      @JsonKey(name: 'agent-name') this.agentName,
      @JsonKey(name: 'task-name') this.taskName,
      required this.data,
      @JsonKey(name: 'is-partial') this.isPartial = false,
      required this.timestamp,
      final String? $type})
      : $type = $type ?? 'message';

  factory _$MessageEventImpl.fromJson(Map<String, dynamic> json) =>
      _$$MessageEventImplFromJson(json);

  @override
  final int seq;
  @override
  @JsonKey(name: 'event-id')
  final String eventId;
  @override
  @JsonKey(name: 'agent-id')
  final String agentId;
  @override
  @JsonKey(name: 'agent-type')
  final String agentType;
  @override
  @JsonKey(name: 'agent-name')
  final String? agentName;
  @override
  @JsonKey(name: 'task-name')
  final String? taskName;
  @override
  final SessionEventMessageData data;
  @override
  @JsonKey(name: 'is-partial')
  final bool isPartial;
  @override
  final DateTime timestamp;

  @JsonKey(name: 'type')
  final String $type;

  @override
  String toString() {
    return 'SessionEvent.message(seq: $seq, eventId: $eventId, agentId: $agentId, agentType: $agentType, agentName: $agentName, taskName: $taskName, data: $data, isPartial: $isPartial, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MessageEventImpl &&
            (identical(other.seq, seq) || other.seq == seq) &&
            (identical(other.eventId, eventId) || other.eventId == eventId) &&
            (identical(other.agentId, agentId) || other.agentId == agentId) &&
            (identical(other.agentType, agentType) ||
                other.agentType == agentType) &&
            (identical(other.agentName, agentName) ||
                other.agentName == agentName) &&
            (identical(other.taskName, taskName) ||
                other.taskName == taskName) &&
            (identical(other.data, data) || other.data == data) &&
            (identical(other.isPartial, isPartial) ||
                other.isPartial == isPartial) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, seq, eventId, agentId, agentType,
      agentName, taskName, data, isPartial, timestamp);

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MessageEventImplCopyWith<_$MessageEventImpl> get copyWith =>
      __$$MessageEventImplCopyWithImpl<_$MessageEventImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)
        connected,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events,
            DateTime timestamp)
        history,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)
        message,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)
        status,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)
        toolUse,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)
        toolResult,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)
        permissionRequest,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)
        permissionTimeout,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)
        done,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)
        aborted,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)
        agentSpawned,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)
        agentTerminated,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)
        error,
  }) {
    return message(seq, eventId, agentId, agentType, agentName, taskName, data,
        isPartial, timestamp);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)?
        connected,
    TResult? Function(int seq, @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events, DateTime timestamp)?
        history,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)?
        message,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)?
        status,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)?
        toolUse,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)?
        toolResult,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)?
        permissionRequest,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)?
        permissionTimeout,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)?
        done,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)?
        aborted,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)?
        agentSpawned,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)?
        agentTerminated,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)?
        error,
  }) {
    return message?.call(seq, eventId, agentId, agentType, agentName, taskName,
        data, isPartial, timestamp);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)?
        connected,
    TResult Function(int seq, @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events, DateTime timestamp)?
        history,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)?
        message,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)?
        status,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)?
        toolUse,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)?
        toolResult,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)?
        permissionRequest,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)?
        permissionTimeout,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)?
        done,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)?
        aborted,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)?
        agentSpawned,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)?
        agentTerminated,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)?
        error,
    required TResult orElse(),
  }) {
    if (message != null) {
      return message(seq, eventId, agentId, agentType, agentName, taskName,
          data, isPartial, timestamp);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConnectedEvent value) connected,
    required TResult Function(HistoryEvent value) history,
    required TResult Function(MessageEvent value) message,
    required TResult Function(StatusEvent value) status,
    required TResult Function(ToolUseEvent value) toolUse,
    required TResult Function(ToolResultEvent value) toolResult,
    required TResult Function(PermissionRequestEvent value) permissionRequest,
    required TResult Function(PermissionTimeoutEvent value) permissionTimeout,
    required TResult Function(DoneEvent value) done,
    required TResult Function(AbortedEvent value) aborted,
    required TResult Function(AgentSpawnedEvent value) agentSpawned,
    required TResult Function(AgentTerminatedEvent value) agentTerminated,
    required TResult Function(ErrorEvent value) error,
  }) {
    return message(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConnectedEvent value)? connected,
    TResult? Function(HistoryEvent value)? history,
    TResult? Function(MessageEvent value)? message,
    TResult? Function(StatusEvent value)? status,
    TResult? Function(ToolUseEvent value)? toolUse,
    TResult? Function(ToolResultEvent value)? toolResult,
    TResult? Function(PermissionRequestEvent value)? permissionRequest,
    TResult? Function(PermissionTimeoutEvent value)? permissionTimeout,
    TResult? Function(DoneEvent value)? done,
    TResult? Function(AbortedEvent value)? aborted,
    TResult? Function(AgentSpawnedEvent value)? agentSpawned,
    TResult? Function(AgentTerminatedEvent value)? agentTerminated,
    TResult? Function(ErrorEvent value)? error,
  }) {
    return message?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConnectedEvent value)? connected,
    TResult Function(HistoryEvent value)? history,
    TResult Function(MessageEvent value)? message,
    TResult Function(StatusEvent value)? status,
    TResult Function(ToolUseEvent value)? toolUse,
    TResult Function(ToolResultEvent value)? toolResult,
    TResult Function(PermissionRequestEvent value)? permissionRequest,
    TResult Function(PermissionTimeoutEvent value)? permissionTimeout,
    TResult Function(DoneEvent value)? done,
    TResult Function(AbortedEvent value)? aborted,
    TResult Function(AgentSpawnedEvent value)? agentSpawned,
    TResult Function(AgentTerminatedEvent value)? agentTerminated,
    TResult Function(ErrorEvent value)? error,
    required TResult orElse(),
  }) {
    if (message != null) {
      return message(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$MessageEventImplToJson(
      this,
    );
  }
}

abstract class MessageEvent implements SessionEvent {
  const factory MessageEvent(
      {required final int seq,
      @JsonKey(name: 'event-id') required final String eventId,
      @JsonKey(name: 'agent-id') required final String agentId,
      @JsonKey(name: 'agent-type') required final String agentType,
      @JsonKey(name: 'agent-name') final String? agentName,
      @JsonKey(name: 'task-name') final String? taskName,
      required final SessionEventMessageData data,
      @JsonKey(name: 'is-partial') final bool isPartial,
      required final DateTime timestamp}) = _$MessageEventImpl;

  factory MessageEvent.fromJson(Map<String, dynamic> json) =
      _$MessageEventImpl.fromJson;

  @override
  int get seq;
  @override
  @JsonKey(name: 'event-id')
  String get eventId;
  @JsonKey(name: 'agent-id')
  String get agentId;
  @JsonKey(name: 'agent-type')
  String get agentType;
  @JsonKey(name: 'agent-name')
  String? get agentName;
  @JsonKey(name: 'task-name')
  String? get taskName;
  SessionEventMessageData get data;
  @JsonKey(name: 'is-partial')
  bool get isPartial;
  @override
  DateTime get timestamp;

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MessageEventImplCopyWith<_$MessageEventImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$StatusEventImplCopyWith<$Res>
    implements $SessionEventCopyWith<$Res> {
  factory _$$StatusEventImplCopyWith(
          _$StatusEventImpl value, $Res Function(_$StatusEventImpl) then) =
      __$$StatusEventImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int seq,
      @JsonKey(name: 'event-id') String eventId,
      @JsonKey(name: 'agent-id') String agentId,
      @JsonKey(name: 'agent-type') String agentType,
      @JsonKey(name: 'agent-name') String? agentName,
      @JsonKey(name: 'task-name') String? taskName,
      AgentStatus status,
      DateTime timestamp});
}

/// @nodoc
class __$$StatusEventImplCopyWithImpl<$Res>
    extends _$SessionEventCopyWithImpl<$Res, _$StatusEventImpl>
    implements _$$StatusEventImplCopyWith<$Res> {
  __$$StatusEventImplCopyWithImpl(
      _$StatusEventImpl _value, $Res Function(_$StatusEventImpl) _then)
      : super(_value, _then);

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? seq = null,
    Object? eventId = null,
    Object? agentId = null,
    Object? agentType = null,
    Object? agentName = freezed,
    Object? taskName = freezed,
    Object? status = null,
    Object? timestamp = null,
  }) {
    return _then(_$StatusEventImpl(
      seq: null == seq
          ? _value.seq
          : seq // ignore: cast_nullable_to_non_nullable
              as int,
      eventId: null == eventId
          ? _value.eventId
          : eventId // ignore: cast_nullable_to_non_nullable
              as String,
      agentId: null == agentId
          ? _value.agentId
          : agentId // ignore: cast_nullable_to_non_nullable
              as String,
      agentType: null == agentType
          ? _value.agentType
          : agentType // ignore: cast_nullable_to_non_nullable
              as String,
      agentName: freezed == agentName
          ? _value.agentName
          : agentName // ignore: cast_nullable_to_non_nullable
              as String?,
      taskName: freezed == taskName
          ? _value.taskName
          : taskName // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as AgentStatus,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$StatusEventImpl implements StatusEvent {
  const _$StatusEventImpl(
      {required this.seq,
      @JsonKey(name: 'event-id') required this.eventId,
      @JsonKey(name: 'agent-id') required this.agentId,
      @JsonKey(name: 'agent-type') required this.agentType,
      @JsonKey(name: 'agent-name') this.agentName,
      @JsonKey(name: 'task-name') this.taskName,
      required this.status,
      required this.timestamp,
      final String? $type})
      : $type = $type ?? 'status';

  factory _$StatusEventImpl.fromJson(Map<String, dynamic> json) =>
      _$$StatusEventImplFromJson(json);

  @override
  final int seq;
  @override
  @JsonKey(name: 'event-id')
  final String eventId;
  @override
  @JsonKey(name: 'agent-id')
  final String agentId;
  @override
  @JsonKey(name: 'agent-type')
  final String agentType;
  @override
  @JsonKey(name: 'agent-name')
  final String? agentName;
  @override
  @JsonKey(name: 'task-name')
  final String? taskName;
  @override
  final AgentStatus status;
  @override
  final DateTime timestamp;

  @JsonKey(name: 'type')
  final String $type;

  @override
  String toString() {
    return 'SessionEvent.status(seq: $seq, eventId: $eventId, agentId: $agentId, agentType: $agentType, agentName: $agentName, taskName: $taskName, status: $status, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StatusEventImpl &&
            (identical(other.seq, seq) || other.seq == seq) &&
            (identical(other.eventId, eventId) || other.eventId == eventId) &&
            (identical(other.agentId, agentId) || other.agentId == agentId) &&
            (identical(other.agentType, agentType) ||
                other.agentType == agentType) &&
            (identical(other.agentName, agentName) ||
                other.agentName == agentName) &&
            (identical(other.taskName, taskName) ||
                other.taskName == taskName) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, seq, eventId, agentId, agentType,
      agentName, taskName, status, timestamp);

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StatusEventImplCopyWith<_$StatusEventImpl> get copyWith =>
      __$$StatusEventImplCopyWithImpl<_$StatusEventImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)
        connected,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events,
            DateTime timestamp)
        history,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)
        message,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)
        status,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)
        toolUse,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)
        toolResult,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)
        permissionRequest,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)
        permissionTimeout,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)
        done,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)
        aborted,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)
        agentSpawned,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)
        agentTerminated,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)
        error,
  }) {
    return status(seq, eventId, agentId, agentType, agentName, taskName,
        this.status, timestamp);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)?
        connected,
    TResult? Function(int seq, @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events, DateTime timestamp)?
        history,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)?
        message,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)?
        status,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)?
        toolUse,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)?
        toolResult,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)?
        permissionRequest,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)?
        permissionTimeout,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)?
        done,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)?
        aborted,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)?
        agentSpawned,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)?
        agentTerminated,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)?
        error,
  }) {
    return status?.call(seq, eventId, agentId, agentType, agentName, taskName,
        this.status, timestamp);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)?
        connected,
    TResult Function(int seq, @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events, DateTime timestamp)?
        history,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)?
        message,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)?
        status,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)?
        toolUse,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)?
        toolResult,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)?
        permissionRequest,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)?
        permissionTimeout,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)?
        done,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)?
        aborted,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)?
        agentSpawned,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)?
        agentTerminated,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)?
        error,
    required TResult orElse(),
  }) {
    if (status != null) {
      return status(seq, eventId, agentId, agentType, agentName, taskName,
          this.status, timestamp);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConnectedEvent value) connected,
    required TResult Function(HistoryEvent value) history,
    required TResult Function(MessageEvent value) message,
    required TResult Function(StatusEvent value) status,
    required TResult Function(ToolUseEvent value) toolUse,
    required TResult Function(ToolResultEvent value) toolResult,
    required TResult Function(PermissionRequestEvent value) permissionRequest,
    required TResult Function(PermissionTimeoutEvent value) permissionTimeout,
    required TResult Function(DoneEvent value) done,
    required TResult Function(AbortedEvent value) aborted,
    required TResult Function(AgentSpawnedEvent value) agentSpawned,
    required TResult Function(AgentTerminatedEvent value) agentTerminated,
    required TResult Function(ErrorEvent value) error,
  }) {
    return status(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConnectedEvent value)? connected,
    TResult? Function(HistoryEvent value)? history,
    TResult? Function(MessageEvent value)? message,
    TResult? Function(StatusEvent value)? status,
    TResult? Function(ToolUseEvent value)? toolUse,
    TResult? Function(ToolResultEvent value)? toolResult,
    TResult? Function(PermissionRequestEvent value)? permissionRequest,
    TResult? Function(PermissionTimeoutEvent value)? permissionTimeout,
    TResult? Function(DoneEvent value)? done,
    TResult? Function(AbortedEvent value)? aborted,
    TResult? Function(AgentSpawnedEvent value)? agentSpawned,
    TResult? Function(AgentTerminatedEvent value)? agentTerminated,
    TResult? Function(ErrorEvent value)? error,
  }) {
    return status?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConnectedEvent value)? connected,
    TResult Function(HistoryEvent value)? history,
    TResult Function(MessageEvent value)? message,
    TResult Function(StatusEvent value)? status,
    TResult Function(ToolUseEvent value)? toolUse,
    TResult Function(ToolResultEvent value)? toolResult,
    TResult Function(PermissionRequestEvent value)? permissionRequest,
    TResult Function(PermissionTimeoutEvent value)? permissionTimeout,
    TResult Function(DoneEvent value)? done,
    TResult Function(AbortedEvent value)? aborted,
    TResult Function(AgentSpawnedEvent value)? agentSpawned,
    TResult Function(AgentTerminatedEvent value)? agentTerminated,
    TResult Function(ErrorEvent value)? error,
    required TResult orElse(),
  }) {
    if (status != null) {
      return status(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$StatusEventImplToJson(
      this,
    );
  }
}

abstract class StatusEvent implements SessionEvent {
  const factory StatusEvent(
      {required final int seq,
      @JsonKey(name: 'event-id') required final String eventId,
      @JsonKey(name: 'agent-id') required final String agentId,
      @JsonKey(name: 'agent-type') required final String agentType,
      @JsonKey(name: 'agent-name') final String? agentName,
      @JsonKey(name: 'task-name') final String? taskName,
      required final AgentStatus status,
      required final DateTime timestamp}) = _$StatusEventImpl;

  factory StatusEvent.fromJson(Map<String, dynamic> json) =
      _$StatusEventImpl.fromJson;

  @override
  int get seq;
  @override
  @JsonKey(name: 'event-id')
  String get eventId;
  @JsonKey(name: 'agent-id')
  String get agentId;
  @JsonKey(name: 'agent-type')
  String get agentType;
  @JsonKey(name: 'agent-name')
  String? get agentName;
  @JsonKey(name: 'task-name')
  String? get taskName;
  AgentStatus get status;
  @override
  DateTime get timestamp;

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StatusEventImplCopyWith<_$StatusEventImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ToolUseEventImplCopyWith<$Res>
    implements $SessionEventCopyWith<$Res> {
  factory _$$ToolUseEventImplCopyWith(
          _$ToolUseEventImpl value, $Res Function(_$ToolUseEventImpl) then) =
      __$$ToolUseEventImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int seq,
      @JsonKey(name: 'event-id') String eventId,
      @JsonKey(name: 'agent-id') String agentId,
      @JsonKey(name: 'agent-type') String agentType,
      @JsonKey(name: 'agent-name') String? agentName,
      @JsonKey(name: 'task-name') String? taskName,
      @JsonKey(name: 'tool-use-id') String toolUseId,
      @JsonKey(name: 'tool-name') String toolName,
      Map<String, dynamic> input,
      DateTime timestamp});
}

/// @nodoc
class __$$ToolUseEventImplCopyWithImpl<$Res>
    extends _$SessionEventCopyWithImpl<$Res, _$ToolUseEventImpl>
    implements _$$ToolUseEventImplCopyWith<$Res> {
  __$$ToolUseEventImplCopyWithImpl(
      _$ToolUseEventImpl _value, $Res Function(_$ToolUseEventImpl) _then)
      : super(_value, _then);

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? seq = null,
    Object? eventId = null,
    Object? agentId = null,
    Object? agentType = null,
    Object? agentName = freezed,
    Object? taskName = freezed,
    Object? toolUseId = null,
    Object? toolName = null,
    Object? input = null,
    Object? timestamp = null,
  }) {
    return _then(_$ToolUseEventImpl(
      seq: null == seq
          ? _value.seq
          : seq // ignore: cast_nullable_to_non_nullable
              as int,
      eventId: null == eventId
          ? _value.eventId
          : eventId // ignore: cast_nullable_to_non_nullable
              as String,
      agentId: null == agentId
          ? _value.agentId
          : agentId // ignore: cast_nullable_to_non_nullable
              as String,
      agentType: null == agentType
          ? _value.agentType
          : agentType // ignore: cast_nullable_to_non_nullable
              as String,
      agentName: freezed == agentName
          ? _value.agentName
          : agentName // ignore: cast_nullable_to_non_nullable
              as String?,
      taskName: freezed == taskName
          ? _value.taskName
          : taskName // ignore: cast_nullable_to_non_nullable
              as String?,
      toolUseId: null == toolUseId
          ? _value.toolUseId
          : toolUseId // ignore: cast_nullable_to_non_nullable
              as String,
      toolName: null == toolName
          ? _value.toolName
          : toolName // ignore: cast_nullable_to_non_nullable
              as String,
      input: null == input
          ? _value._input
          : input // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ToolUseEventImpl implements ToolUseEvent {
  const _$ToolUseEventImpl(
      {required this.seq,
      @JsonKey(name: 'event-id') required this.eventId,
      @JsonKey(name: 'agent-id') required this.agentId,
      @JsonKey(name: 'agent-type') required this.agentType,
      @JsonKey(name: 'agent-name') this.agentName,
      @JsonKey(name: 'task-name') this.taskName,
      @JsonKey(name: 'tool-use-id') required this.toolUseId,
      @JsonKey(name: 'tool-name') required this.toolName,
      required final Map<String, dynamic> input,
      required this.timestamp,
      final String? $type})
      : _input = input,
        $type = $type ?? 'tool-use';

  factory _$ToolUseEventImpl.fromJson(Map<String, dynamic> json) =>
      _$$ToolUseEventImplFromJson(json);

  @override
  final int seq;
  @override
  @JsonKey(name: 'event-id')
  final String eventId;
  @override
  @JsonKey(name: 'agent-id')
  final String agentId;
  @override
  @JsonKey(name: 'agent-type')
  final String agentType;
  @override
  @JsonKey(name: 'agent-name')
  final String? agentName;
  @override
  @JsonKey(name: 'task-name')
  final String? taskName;
  @override
  @JsonKey(name: 'tool-use-id')
  final String toolUseId;
  @override
  @JsonKey(name: 'tool-name')
  final String toolName;
  final Map<String, dynamic> _input;
  @override
  Map<String, dynamic> get input {
    if (_input is EqualUnmodifiableMapView) return _input;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_input);
  }

  @override
  final DateTime timestamp;

  @JsonKey(name: 'type')
  final String $type;

  @override
  String toString() {
    return 'SessionEvent.toolUse(seq: $seq, eventId: $eventId, agentId: $agentId, agentType: $agentType, agentName: $agentName, taskName: $taskName, toolUseId: $toolUseId, toolName: $toolName, input: $input, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ToolUseEventImpl &&
            (identical(other.seq, seq) || other.seq == seq) &&
            (identical(other.eventId, eventId) || other.eventId == eventId) &&
            (identical(other.agentId, agentId) || other.agentId == agentId) &&
            (identical(other.agentType, agentType) ||
                other.agentType == agentType) &&
            (identical(other.agentName, agentName) ||
                other.agentName == agentName) &&
            (identical(other.taskName, taskName) ||
                other.taskName == taskName) &&
            (identical(other.toolUseId, toolUseId) ||
                other.toolUseId == toolUseId) &&
            (identical(other.toolName, toolName) ||
                other.toolName == toolName) &&
            const DeepCollectionEquality().equals(other._input, _input) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      seq,
      eventId,
      agentId,
      agentType,
      agentName,
      taskName,
      toolUseId,
      toolName,
      const DeepCollectionEquality().hash(_input),
      timestamp);

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ToolUseEventImplCopyWith<_$ToolUseEventImpl> get copyWith =>
      __$$ToolUseEventImplCopyWithImpl<_$ToolUseEventImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)
        connected,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events,
            DateTime timestamp)
        history,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)
        message,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)
        status,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)
        toolUse,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)
        toolResult,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)
        permissionRequest,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)
        permissionTimeout,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)
        done,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)
        aborted,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)
        agentSpawned,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)
        agentTerminated,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)
        error,
  }) {
    return toolUse(seq, eventId, agentId, agentType, agentName, taskName,
        toolUseId, toolName, input, timestamp);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)?
        connected,
    TResult? Function(int seq, @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events, DateTime timestamp)?
        history,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)?
        message,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)?
        status,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)?
        toolUse,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)?
        toolResult,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)?
        permissionRequest,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)?
        permissionTimeout,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)?
        done,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)?
        aborted,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)?
        agentSpawned,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)?
        agentTerminated,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)?
        error,
  }) {
    return toolUse?.call(seq, eventId, agentId, agentType, agentName, taskName,
        toolUseId, toolName, input, timestamp);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)?
        connected,
    TResult Function(int seq, @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events, DateTime timestamp)?
        history,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)?
        message,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)?
        status,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)?
        toolUse,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)?
        toolResult,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)?
        permissionRequest,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)?
        permissionTimeout,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)?
        done,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)?
        aborted,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)?
        agentSpawned,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)?
        agentTerminated,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)?
        error,
    required TResult orElse(),
  }) {
    if (toolUse != null) {
      return toolUse(seq, eventId, agentId, agentType, agentName, taskName,
          toolUseId, toolName, input, timestamp);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConnectedEvent value) connected,
    required TResult Function(HistoryEvent value) history,
    required TResult Function(MessageEvent value) message,
    required TResult Function(StatusEvent value) status,
    required TResult Function(ToolUseEvent value) toolUse,
    required TResult Function(ToolResultEvent value) toolResult,
    required TResult Function(PermissionRequestEvent value) permissionRequest,
    required TResult Function(PermissionTimeoutEvent value) permissionTimeout,
    required TResult Function(DoneEvent value) done,
    required TResult Function(AbortedEvent value) aborted,
    required TResult Function(AgentSpawnedEvent value) agentSpawned,
    required TResult Function(AgentTerminatedEvent value) agentTerminated,
    required TResult Function(ErrorEvent value) error,
  }) {
    return toolUse(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConnectedEvent value)? connected,
    TResult? Function(HistoryEvent value)? history,
    TResult? Function(MessageEvent value)? message,
    TResult? Function(StatusEvent value)? status,
    TResult? Function(ToolUseEvent value)? toolUse,
    TResult? Function(ToolResultEvent value)? toolResult,
    TResult? Function(PermissionRequestEvent value)? permissionRequest,
    TResult? Function(PermissionTimeoutEvent value)? permissionTimeout,
    TResult? Function(DoneEvent value)? done,
    TResult? Function(AbortedEvent value)? aborted,
    TResult? Function(AgentSpawnedEvent value)? agentSpawned,
    TResult? Function(AgentTerminatedEvent value)? agentTerminated,
    TResult? Function(ErrorEvent value)? error,
  }) {
    return toolUse?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConnectedEvent value)? connected,
    TResult Function(HistoryEvent value)? history,
    TResult Function(MessageEvent value)? message,
    TResult Function(StatusEvent value)? status,
    TResult Function(ToolUseEvent value)? toolUse,
    TResult Function(ToolResultEvent value)? toolResult,
    TResult Function(PermissionRequestEvent value)? permissionRequest,
    TResult Function(PermissionTimeoutEvent value)? permissionTimeout,
    TResult Function(DoneEvent value)? done,
    TResult Function(AbortedEvent value)? aborted,
    TResult Function(AgentSpawnedEvent value)? agentSpawned,
    TResult Function(AgentTerminatedEvent value)? agentTerminated,
    TResult Function(ErrorEvent value)? error,
    required TResult orElse(),
  }) {
    if (toolUse != null) {
      return toolUse(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$ToolUseEventImplToJson(
      this,
    );
  }
}

abstract class ToolUseEvent implements SessionEvent {
  const factory ToolUseEvent(
      {required final int seq,
      @JsonKey(name: 'event-id') required final String eventId,
      @JsonKey(name: 'agent-id') required final String agentId,
      @JsonKey(name: 'agent-type') required final String agentType,
      @JsonKey(name: 'agent-name') final String? agentName,
      @JsonKey(name: 'task-name') final String? taskName,
      @JsonKey(name: 'tool-use-id') required final String toolUseId,
      @JsonKey(name: 'tool-name') required final String toolName,
      required final Map<String, dynamic> input,
      required final DateTime timestamp}) = _$ToolUseEventImpl;

  factory ToolUseEvent.fromJson(Map<String, dynamic> json) =
      _$ToolUseEventImpl.fromJson;

  @override
  int get seq;
  @override
  @JsonKey(name: 'event-id')
  String get eventId;
  @JsonKey(name: 'agent-id')
  String get agentId;
  @JsonKey(name: 'agent-type')
  String get agentType;
  @JsonKey(name: 'agent-name')
  String? get agentName;
  @JsonKey(name: 'task-name')
  String? get taskName;
  @JsonKey(name: 'tool-use-id')
  String get toolUseId;
  @JsonKey(name: 'tool-name')
  String get toolName;
  Map<String, dynamic> get input;
  @override
  DateTime get timestamp;

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ToolUseEventImplCopyWith<_$ToolUseEventImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ToolResultEventImplCopyWith<$Res>
    implements $SessionEventCopyWith<$Res> {
  factory _$$ToolResultEventImplCopyWith(_$ToolResultEventImpl value,
          $Res Function(_$ToolResultEventImpl) then) =
      __$$ToolResultEventImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int seq,
      @JsonKey(name: 'event-id') String eventId,
      @JsonKey(name: 'agent-id') String agentId,
      @JsonKey(name: 'agent-type') String agentType,
      @JsonKey(name: 'agent-name') String? agentName,
      @JsonKey(name: 'task-name') String? taskName,
      @JsonKey(name: 'tool-use-id') String toolUseId,
      @JsonKey(name: 'tool-name') String toolName,
      dynamic result,
      @JsonKey(name: 'is-error') bool isError,
      DateTime timestamp});
}

/// @nodoc
class __$$ToolResultEventImplCopyWithImpl<$Res>
    extends _$SessionEventCopyWithImpl<$Res, _$ToolResultEventImpl>
    implements _$$ToolResultEventImplCopyWith<$Res> {
  __$$ToolResultEventImplCopyWithImpl(
      _$ToolResultEventImpl _value, $Res Function(_$ToolResultEventImpl) _then)
      : super(_value, _then);

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? seq = null,
    Object? eventId = null,
    Object? agentId = null,
    Object? agentType = null,
    Object? agentName = freezed,
    Object? taskName = freezed,
    Object? toolUseId = null,
    Object? toolName = null,
    Object? result = freezed,
    Object? isError = null,
    Object? timestamp = null,
  }) {
    return _then(_$ToolResultEventImpl(
      seq: null == seq
          ? _value.seq
          : seq // ignore: cast_nullable_to_non_nullable
              as int,
      eventId: null == eventId
          ? _value.eventId
          : eventId // ignore: cast_nullable_to_non_nullable
              as String,
      agentId: null == agentId
          ? _value.agentId
          : agentId // ignore: cast_nullable_to_non_nullable
              as String,
      agentType: null == agentType
          ? _value.agentType
          : agentType // ignore: cast_nullable_to_non_nullable
              as String,
      agentName: freezed == agentName
          ? _value.agentName
          : agentName // ignore: cast_nullable_to_non_nullable
              as String?,
      taskName: freezed == taskName
          ? _value.taskName
          : taskName // ignore: cast_nullable_to_non_nullable
              as String?,
      toolUseId: null == toolUseId
          ? _value.toolUseId
          : toolUseId // ignore: cast_nullable_to_non_nullable
              as String,
      toolName: null == toolName
          ? _value.toolName
          : toolName // ignore: cast_nullable_to_non_nullable
              as String,
      result: freezed == result
          ? _value.result
          : result // ignore: cast_nullable_to_non_nullable
              as dynamic,
      isError: null == isError
          ? _value.isError
          : isError // ignore: cast_nullable_to_non_nullable
              as bool,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ToolResultEventImpl implements ToolResultEvent {
  const _$ToolResultEventImpl(
      {required this.seq,
      @JsonKey(name: 'event-id') required this.eventId,
      @JsonKey(name: 'agent-id') required this.agentId,
      @JsonKey(name: 'agent-type') required this.agentType,
      @JsonKey(name: 'agent-name') this.agentName,
      @JsonKey(name: 'task-name') this.taskName,
      @JsonKey(name: 'tool-use-id') required this.toolUseId,
      @JsonKey(name: 'tool-name') required this.toolName,
      required this.result,
      @JsonKey(name: 'is-error') this.isError = false,
      required this.timestamp,
      final String? $type})
      : $type = $type ?? 'tool-result';

  factory _$ToolResultEventImpl.fromJson(Map<String, dynamic> json) =>
      _$$ToolResultEventImplFromJson(json);

  @override
  final int seq;
  @override
  @JsonKey(name: 'event-id')
  final String eventId;
  @override
  @JsonKey(name: 'agent-id')
  final String agentId;
  @override
  @JsonKey(name: 'agent-type')
  final String agentType;
  @override
  @JsonKey(name: 'agent-name')
  final String? agentName;
  @override
  @JsonKey(name: 'task-name')
  final String? taskName;
  @override
  @JsonKey(name: 'tool-use-id')
  final String toolUseId;
  @override
  @JsonKey(name: 'tool-name')
  final String toolName;
  @override
  final dynamic result;
  @override
  @JsonKey(name: 'is-error')
  final bool isError;
  @override
  final DateTime timestamp;

  @JsonKey(name: 'type')
  final String $type;

  @override
  String toString() {
    return 'SessionEvent.toolResult(seq: $seq, eventId: $eventId, agentId: $agentId, agentType: $agentType, agentName: $agentName, taskName: $taskName, toolUseId: $toolUseId, toolName: $toolName, result: $result, isError: $isError, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ToolResultEventImpl &&
            (identical(other.seq, seq) || other.seq == seq) &&
            (identical(other.eventId, eventId) || other.eventId == eventId) &&
            (identical(other.agentId, agentId) || other.agentId == agentId) &&
            (identical(other.agentType, agentType) ||
                other.agentType == agentType) &&
            (identical(other.agentName, agentName) ||
                other.agentName == agentName) &&
            (identical(other.taskName, taskName) ||
                other.taskName == taskName) &&
            (identical(other.toolUseId, toolUseId) ||
                other.toolUseId == toolUseId) &&
            (identical(other.toolName, toolName) ||
                other.toolName == toolName) &&
            const DeepCollectionEquality().equals(other.result, result) &&
            (identical(other.isError, isError) || other.isError == isError) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      seq,
      eventId,
      agentId,
      agentType,
      agentName,
      taskName,
      toolUseId,
      toolName,
      const DeepCollectionEquality().hash(result),
      isError,
      timestamp);

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ToolResultEventImplCopyWith<_$ToolResultEventImpl> get copyWith =>
      __$$ToolResultEventImplCopyWithImpl<_$ToolResultEventImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)
        connected,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events,
            DateTime timestamp)
        history,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)
        message,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)
        status,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)
        toolUse,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)
        toolResult,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)
        permissionRequest,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)
        permissionTimeout,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)
        done,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)
        aborted,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)
        agentSpawned,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)
        agentTerminated,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)
        error,
  }) {
    return toolResult(seq, eventId, agentId, agentType, agentName, taskName,
        toolUseId, toolName, result, isError, timestamp);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)?
        connected,
    TResult? Function(int seq, @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events, DateTime timestamp)?
        history,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)?
        message,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)?
        status,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)?
        toolUse,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)?
        toolResult,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)?
        permissionRequest,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)?
        permissionTimeout,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)?
        done,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)?
        aborted,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)?
        agentSpawned,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)?
        agentTerminated,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)?
        error,
  }) {
    return toolResult?.call(seq, eventId, agentId, agentType, agentName,
        taskName, toolUseId, toolName, result, isError, timestamp);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)?
        connected,
    TResult Function(int seq, @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events, DateTime timestamp)?
        history,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)?
        message,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)?
        status,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)?
        toolUse,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)?
        toolResult,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)?
        permissionRequest,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)?
        permissionTimeout,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)?
        done,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)?
        aborted,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)?
        agentSpawned,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)?
        agentTerminated,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)?
        error,
    required TResult orElse(),
  }) {
    if (toolResult != null) {
      return toolResult(seq, eventId, agentId, agentType, agentName, taskName,
          toolUseId, toolName, result, isError, timestamp);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConnectedEvent value) connected,
    required TResult Function(HistoryEvent value) history,
    required TResult Function(MessageEvent value) message,
    required TResult Function(StatusEvent value) status,
    required TResult Function(ToolUseEvent value) toolUse,
    required TResult Function(ToolResultEvent value) toolResult,
    required TResult Function(PermissionRequestEvent value) permissionRequest,
    required TResult Function(PermissionTimeoutEvent value) permissionTimeout,
    required TResult Function(DoneEvent value) done,
    required TResult Function(AbortedEvent value) aborted,
    required TResult Function(AgentSpawnedEvent value) agentSpawned,
    required TResult Function(AgentTerminatedEvent value) agentTerminated,
    required TResult Function(ErrorEvent value) error,
  }) {
    return toolResult(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConnectedEvent value)? connected,
    TResult? Function(HistoryEvent value)? history,
    TResult? Function(MessageEvent value)? message,
    TResult? Function(StatusEvent value)? status,
    TResult? Function(ToolUseEvent value)? toolUse,
    TResult? Function(ToolResultEvent value)? toolResult,
    TResult? Function(PermissionRequestEvent value)? permissionRequest,
    TResult? Function(PermissionTimeoutEvent value)? permissionTimeout,
    TResult? Function(DoneEvent value)? done,
    TResult? Function(AbortedEvent value)? aborted,
    TResult? Function(AgentSpawnedEvent value)? agentSpawned,
    TResult? Function(AgentTerminatedEvent value)? agentTerminated,
    TResult? Function(ErrorEvent value)? error,
  }) {
    return toolResult?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConnectedEvent value)? connected,
    TResult Function(HistoryEvent value)? history,
    TResult Function(MessageEvent value)? message,
    TResult Function(StatusEvent value)? status,
    TResult Function(ToolUseEvent value)? toolUse,
    TResult Function(ToolResultEvent value)? toolResult,
    TResult Function(PermissionRequestEvent value)? permissionRequest,
    TResult Function(PermissionTimeoutEvent value)? permissionTimeout,
    TResult Function(DoneEvent value)? done,
    TResult Function(AbortedEvent value)? aborted,
    TResult Function(AgentSpawnedEvent value)? agentSpawned,
    TResult Function(AgentTerminatedEvent value)? agentTerminated,
    TResult Function(ErrorEvent value)? error,
    required TResult orElse(),
  }) {
    if (toolResult != null) {
      return toolResult(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$ToolResultEventImplToJson(
      this,
    );
  }
}

abstract class ToolResultEvent implements SessionEvent {
  const factory ToolResultEvent(
      {required final int seq,
      @JsonKey(name: 'event-id') required final String eventId,
      @JsonKey(name: 'agent-id') required final String agentId,
      @JsonKey(name: 'agent-type') required final String agentType,
      @JsonKey(name: 'agent-name') final String? agentName,
      @JsonKey(name: 'task-name') final String? taskName,
      @JsonKey(name: 'tool-use-id') required final String toolUseId,
      @JsonKey(name: 'tool-name') required final String toolName,
      required final dynamic result,
      @JsonKey(name: 'is-error') final bool isError,
      required final DateTime timestamp}) = _$ToolResultEventImpl;

  factory ToolResultEvent.fromJson(Map<String, dynamic> json) =
      _$ToolResultEventImpl.fromJson;

  @override
  int get seq;
  @override
  @JsonKey(name: 'event-id')
  String get eventId;
  @JsonKey(name: 'agent-id')
  String get agentId;
  @JsonKey(name: 'agent-type')
  String get agentType;
  @JsonKey(name: 'agent-name')
  String? get agentName;
  @JsonKey(name: 'task-name')
  String? get taskName;
  @JsonKey(name: 'tool-use-id')
  String get toolUseId;
  @JsonKey(name: 'tool-name')
  String get toolName;
  dynamic get result;
  @JsonKey(name: 'is-error')
  bool get isError;
  @override
  DateTime get timestamp;

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ToolResultEventImplCopyWith<_$ToolResultEventImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$PermissionRequestEventImplCopyWith<$Res>
    implements $SessionEventCopyWith<$Res> {
  factory _$$PermissionRequestEventImplCopyWith(
          _$PermissionRequestEventImpl value,
          $Res Function(_$PermissionRequestEventImpl) then) =
      __$$PermissionRequestEventImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int seq,
      @JsonKey(name: 'event-id') String eventId,
      @JsonKey(name: 'agent-id') String agentId,
      @JsonKey(name: 'agent-type') String agentType,
      @JsonKey(name: 'agent-name') String? agentName,
      @JsonKey(name: 'task-name') String? taskName,
      @JsonKey(name: 'request-id') String requestId,
      @JsonKey(name: 'tool-name') String toolName,
      @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
      @JsonKey(name: 'permission-suggestions')
      List<String>? permissionSuggestions,
      DateTime timestamp});
}

/// @nodoc
class __$$PermissionRequestEventImplCopyWithImpl<$Res>
    extends _$SessionEventCopyWithImpl<$Res, _$PermissionRequestEventImpl>
    implements _$$PermissionRequestEventImplCopyWith<$Res> {
  __$$PermissionRequestEventImplCopyWithImpl(
      _$PermissionRequestEventImpl _value,
      $Res Function(_$PermissionRequestEventImpl) _then)
      : super(_value, _then);

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? seq = null,
    Object? eventId = null,
    Object? agentId = null,
    Object? agentType = null,
    Object? agentName = freezed,
    Object? taskName = freezed,
    Object? requestId = null,
    Object? toolName = null,
    Object? toolInput = null,
    Object? permissionSuggestions = freezed,
    Object? timestamp = null,
  }) {
    return _then(_$PermissionRequestEventImpl(
      seq: null == seq
          ? _value.seq
          : seq // ignore: cast_nullable_to_non_nullable
              as int,
      eventId: null == eventId
          ? _value.eventId
          : eventId // ignore: cast_nullable_to_non_nullable
              as String,
      agentId: null == agentId
          ? _value.agentId
          : agentId // ignore: cast_nullable_to_non_nullable
              as String,
      agentType: null == agentType
          ? _value.agentType
          : agentType // ignore: cast_nullable_to_non_nullable
              as String,
      agentName: freezed == agentName
          ? _value.agentName
          : agentName // ignore: cast_nullable_to_non_nullable
              as String?,
      taskName: freezed == taskName
          ? _value.taskName
          : taskName // ignore: cast_nullable_to_non_nullable
              as String?,
      requestId: null == requestId
          ? _value.requestId
          : requestId // ignore: cast_nullable_to_non_nullable
              as String,
      toolName: null == toolName
          ? _value.toolName
          : toolName // ignore: cast_nullable_to_non_nullable
              as String,
      toolInput: null == toolInput
          ? _value._toolInput
          : toolInput // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      permissionSuggestions: freezed == permissionSuggestions
          ? _value._permissionSuggestions
          : permissionSuggestions // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PermissionRequestEventImpl implements PermissionRequestEvent {
  const _$PermissionRequestEventImpl(
      {required this.seq,
      @JsonKey(name: 'event-id') required this.eventId,
      @JsonKey(name: 'agent-id') required this.agentId,
      @JsonKey(name: 'agent-type') required this.agentType,
      @JsonKey(name: 'agent-name') this.agentName,
      @JsonKey(name: 'task-name') this.taskName,
      @JsonKey(name: 'request-id') required this.requestId,
      @JsonKey(name: 'tool-name') required this.toolName,
      @JsonKey(name: 'tool-input')
      required final Map<String, dynamic> toolInput,
      @JsonKey(name: 'permission-suggestions')
      final List<String>? permissionSuggestions,
      required this.timestamp,
      final String? $type})
      : _toolInput = toolInput,
        _permissionSuggestions = permissionSuggestions,
        $type = $type ?? 'permission-request';

  factory _$PermissionRequestEventImpl.fromJson(Map<String, dynamic> json) =>
      _$$PermissionRequestEventImplFromJson(json);

  @override
  final int seq;
  @override
  @JsonKey(name: 'event-id')
  final String eventId;
  @override
  @JsonKey(name: 'agent-id')
  final String agentId;
  @override
  @JsonKey(name: 'agent-type')
  final String agentType;
  @override
  @JsonKey(name: 'agent-name')
  final String? agentName;
  @override
  @JsonKey(name: 'task-name')
  final String? taskName;
  @override
  @JsonKey(name: 'request-id')
  final String requestId;
  @override
  @JsonKey(name: 'tool-name')
  final String toolName;
  final Map<String, dynamic> _toolInput;
  @override
  @JsonKey(name: 'tool-input')
  Map<String, dynamic> get toolInput {
    if (_toolInput is EqualUnmodifiableMapView) return _toolInput;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_toolInput);
  }

  final List<String>? _permissionSuggestions;
  @override
  @JsonKey(name: 'permission-suggestions')
  List<String>? get permissionSuggestions {
    final value = _permissionSuggestions;
    if (value == null) return null;
    if (_permissionSuggestions is EqualUnmodifiableListView)
      return _permissionSuggestions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  final DateTime timestamp;

  @JsonKey(name: 'type')
  final String $type;

  @override
  String toString() {
    return 'SessionEvent.permissionRequest(seq: $seq, eventId: $eventId, agentId: $agentId, agentType: $agentType, agentName: $agentName, taskName: $taskName, requestId: $requestId, toolName: $toolName, toolInput: $toolInput, permissionSuggestions: $permissionSuggestions, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PermissionRequestEventImpl &&
            (identical(other.seq, seq) || other.seq == seq) &&
            (identical(other.eventId, eventId) || other.eventId == eventId) &&
            (identical(other.agentId, agentId) || other.agentId == agentId) &&
            (identical(other.agentType, agentType) ||
                other.agentType == agentType) &&
            (identical(other.agentName, agentName) ||
                other.agentName == agentName) &&
            (identical(other.taskName, taskName) ||
                other.taskName == taskName) &&
            (identical(other.requestId, requestId) ||
                other.requestId == requestId) &&
            (identical(other.toolName, toolName) ||
                other.toolName == toolName) &&
            const DeepCollectionEquality()
                .equals(other._toolInput, _toolInput) &&
            const DeepCollectionEquality()
                .equals(other._permissionSuggestions, _permissionSuggestions) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      seq,
      eventId,
      agentId,
      agentType,
      agentName,
      taskName,
      requestId,
      toolName,
      const DeepCollectionEquality().hash(_toolInput),
      const DeepCollectionEquality().hash(_permissionSuggestions),
      timestamp);

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PermissionRequestEventImplCopyWith<_$PermissionRequestEventImpl>
      get copyWith => __$$PermissionRequestEventImplCopyWithImpl<
          _$PermissionRequestEventImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)
        connected,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events,
            DateTime timestamp)
        history,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)
        message,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)
        status,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)
        toolUse,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)
        toolResult,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)
        permissionRequest,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)
        permissionTimeout,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)
        done,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)
        aborted,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)
        agentSpawned,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)
        agentTerminated,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)
        error,
  }) {
    return permissionRequest(
        seq,
        eventId,
        agentId,
        agentType,
        agentName,
        taskName,
        requestId,
        toolName,
        toolInput,
        permissionSuggestions,
        timestamp);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)?
        connected,
    TResult? Function(int seq, @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events, DateTime timestamp)?
        history,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)?
        message,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)?
        status,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)?
        toolUse,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)?
        toolResult,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)?
        permissionRequest,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)?
        permissionTimeout,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)?
        done,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)?
        aborted,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)?
        agentSpawned,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)?
        agentTerminated,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)?
        error,
  }) {
    return permissionRequest?.call(
        seq,
        eventId,
        agentId,
        agentType,
        agentName,
        taskName,
        requestId,
        toolName,
        toolInput,
        permissionSuggestions,
        timestamp);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)?
        connected,
    TResult Function(int seq, @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events, DateTime timestamp)?
        history,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)?
        message,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)?
        status,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)?
        toolUse,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)?
        toolResult,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)?
        permissionRequest,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)?
        permissionTimeout,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)?
        done,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)?
        aborted,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)?
        agentSpawned,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)?
        agentTerminated,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)?
        error,
    required TResult orElse(),
  }) {
    if (permissionRequest != null) {
      return permissionRequest(
          seq,
          eventId,
          agentId,
          agentType,
          agentName,
          taskName,
          requestId,
          toolName,
          toolInput,
          permissionSuggestions,
          timestamp);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConnectedEvent value) connected,
    required TResult Function(HistoryEvent value) history,
    required TResult Function(MessageEvent value) message,
    required TResult Function(StatusEvent value) status,
    required TResult Function(ToolUseEvent value) toolUse,
    required TResult Function(ToolResultEvent value) toolResult,
    required TResult Function(PermissionRequestEvent value) permissionRequest,
    required TResult Function(PermissionTimeoutEvent value) permissionTimeout,
    required TResult Function(DoneEvent value) done,
    required TResult Function(AbortedEvent value) aborted,
    required TResult Function(AgentSpawnedEvent value) agentSpawned,
    required TResult Function(AgentTerminatedEvent value) agentTerminated,
    required TResult Function(ErrorEvent value) error,
  }) {
    return permissionRequest(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConnectedEvent value)? connected,
    TResult? Function(HistoryEvent value)? history,
    TResult? Function(MessageEvent value)? message,
    TResult? Function(StatusEvent value)? status,
    TResult? Function(ToolUseEvent value)? toolUse,
    TResult? Function(ToolResultEvent value)? toolResult,
    TResult? Function(PermissionRequestEvent value)? permissionRequest,
    TResult? Function(PermissionTimeoutEvent value)? permissionTimeout,
    TResult? Function(DoneEvent value)? done,
    TResult? Function(AbortedEvent value)? aborted,
    TResult? Function(AgentSpawnedEvent value)? agentSpawned,
    TResult? Function(AgentTerminatedEvent value)? agentTerminated,
    TResult? Function(ErrorEvent value)? error,
  }) {
    return permissionRequest?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConnectedEvent value)? connected,
    TResult Function(HistoryEvent value)? history,
    TResult Function(MessageEvent value)? message,
    TResult Function(StatusEvent value)? status,
    TResult Function(ToolUseEvent value)? toolUse,
    TResult Function(ToolResultEvent value)? toolResult,
    TResult Function(PermissionRequestEvent value)? permissionRequest,
    TResult Function(PermissionTimeoutEvent value)? permissionTimeout,
    TResult Function(DoneEvent value)? done,
    TResult Function(AbortedEvent value)? aborted,
    TResult Function(AgentSpawnedEvent value)? agentSpawned,
    TResult Function(AgentTerminatedEvent value)? agentTerminated,
    TResult Function(ErrorEvent value)? error,
    required TResult orElse(),
  }) {
    if (permissionRequest != null) {
      return permissionRequest(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$PermissionRequestEventImplToJson(
      this,
    );
  }
}

abstract class PermissionRequestEvent implements SessionEvent {
  const factory PermissionRequestEvent(
      {required final int seq,
      @JsonKey(name: 'event-id') required final String eventId,
      @JsonKey(name: 'agent-id') required final String agentId,
      @JsonKey(name: 'agent-type') required final String agentType,
      @JsonKey(name: 'agent-name') final String? agentName,
      @JsonKey(name: 'task-name') final String? taskName,
      @JsonKey(name: 'request-id') required final String requestId,
      @JsonKey(name: 'tool-name') required final String toolName,
      @JsonKey(name: 'tool-input')
      required final Map<String, dynamic> toolInput,
      @JsonKey(name: 'permission-suggestions')
      final List<String>? permissionSuggestions,
      required final DateTime timestamp}) = _$PermissionRequestEventImpl;

  factory PermissionRequestEvent.fromJson(Map<String, dynamic> json) =
      _$PermissionRequestEventImpl.fromJson;

  @override
  int get seq;
  @override
  @JsonKey(name: 'event-id')
  String get eventId;
  @JsonKey(name: 'agent-id')
  String get agentId;
  @JsonKey(name: 'agent-type')
  String get agentType;
  @JsonKey(name: 'agent-name')
  String? get agentName;
  @JsonKey(name: 'task-name')
  String? get taskName;
  @JsonKey(name: 'request-id')
  String get requestId;
  @JsonKey(name: 'tool-name')
  String get toolName;
  @JsonKey(name: 'tool-input')
  Map<String, dynamic> get toolInput;
  @JsonKey(name: 'permission-suggestions')
  List<String>? get permissionSuggestions;
  @override
  DateTime get timestamp;

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PermissionRequestEventImplCopyWith<_$PermissionRequestEventImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$PermissionTimeoutEventImplCopyWith<$Res>
    implements $SessionEventCopyWith<$Res> {
  factory _$$PermissionTimeoutEventImplCopyWith(
          _$PermissionTimeoutEventImpl value,
          $Res Function(_$PermissionTimeoutEventImpl) then) =
      __$$PermissionTimeoutEventImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int seq,
      @JsonKey(name: 'event-id') String eventId,
      @JsonKey(name: 'agent-id') String agentId,
      @JsonKey(name: 'agent-type') String agentType,
      @JsonKey(name: 'agent-name') String? agentName,
      @JsonKey(name: 'task-name') String? taskName,
      @JsonKey(name: 'request-id') String requestId,
      DateTime timestamp});
}

/// @nodoc
class __$$PermissionTimeoutEventImplCopyWithImpl<$Res>
    extends _$SessionEventCopyWithImpl<$Res, _$PermissionTimeoutEventImpl>
    implements _$$PermissionTimeoutEventImplCopyWith<$Res> {
  __$$PermissionTimeoutEventImplCopyWithImpl(
      _$PermissionTimeoutEventImpl _value,
      $Res Function(_$PermissionTimeoutEventImpl) _then)
      : super(_value, _then);

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? seq = null,
    Object? eventId = null,
    Object? agentId = null,
    Object? agentType = null,
    Object? agentName = freezed,
    Object? taskName = freezed,
    Object? requestId = null,
    Object? timestamp = null,
  }) {
    return _then(_$PermissionTimeoutEventImpl(
      seq: null == seq
          ? _value.seq
          : seq // ignore: cast_nullable_to_non_nullable
              as int,
      eventId: null == eventId
          ? _value.eventId
          : eventId // ignore: cast_nullable_to_non_nullable
              as String,
      agentId: null == agentId
          ? _value.agentId
          : agentId // ignore: cast_nullable_to_non_nullable
              as String,
      agentType: null == agentType
          ? _value.agentType
          : agentType // ignore: cast_nullable_to_non_nullable
              as String,
      agentName: freezed == agentName
          ? _value.agentName
          : agentName // ignore: cast_nullable_to_non_nullable
              as String?,
      taskName: freezed == taskName
          ? _value.taskName
          : taskName // ignore: cast_nullable_to_non_nullable
              as String?,
      requestId: null == requestId
          ? _value.requestId
          : requestId // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PermissionTimeoutEventImpl implements PermissionTimeoutEvent {
  const _$PermissionTimeoutEventImpl(
      {required this.seq,
      @JsonKey(name: 'event-id') required this.eventId,
      @JsonKey(name: 'agent-id') required this.agentId,
      @JsonKey(name: 'agent-type') required this.agentType,
      @JsonKey(name: 'agent-name') this.agentName,
      @JsonKey(name: 'task-name') this.taskName,
      @JsonKey(name: 'request-id') required this.requestId,
      required this.timestamp,
      final String? $type})
      : $type = $type ?? 'permission-timeout';

  factory _$PermissionTimeoutEventImpl.fromJson(Map<String, dynamic> json) =>
      _$$PermissionTimeoutEventImplFromJson(json);

  @override
  final int seq;
  @override
  @JsonKey(name: 'event-id')
  final String eventId;
  @override
  @JsonKey(name: 'agent-id')
  final String agentId;
  @override
  @JsonKey(name: 'agent-type')
  final String agentType;
  @override
  @JsonKey(name: 'agent-name')
  final String? agentName;
  @override
  @JsonKey(name: 'task-name')
  final String? taskName;
  @override
  @JsonKey(name: 'request-id')
  final String requestId;
  @override
  final DateTime timestamp;

  @JsonKey(name: 'type')
  final String $type;

  @override
  String toString() {
    return 'SessionEvent.permissionTimeout(seq: $seq, eventId: $eventId, agentId: $agentId, agentType: $agentType, agentName: $agentName, taskName: $taskName, requestId: $requestId, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PermissionTimeoutEventImpl &&
            (identical(other.seq, seq) || other.seq == seq) &&
            (identical(other.eventId, eventId) || other.eventId == eventId) &&
            (identical(other.agentId, agentId) || other.agentId == agentId) &&
            (identical(other.agentType, agentType) ||
                other.agentType == agentType) &&
            (identical(other.agentName, agentName) ||
                other.agentName == agentName) &&
            (identical(other.taskName, taskName) ||
                other.taskName == taskName) &&
            (identical(other.requestId, requestId) ||
                other.requestId == requestId) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, seq, eventId, agentId, agentType,
      agentName, taskName, requestId, timestamp);

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PermissionTimeoutEventImplCopyWith<_$PermissionTimeoutEventImpl>
      get copyWith => __$$PermissionTimeoutEventImplCopyWithImpl<
          _$PermissionTimeoutEventImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)
        connected,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events,
            DateTime timestamp)
        history,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)
        message,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)
        status,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)
        toolUse,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)
        toolResult,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)
        permissionRequest,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)
        permissionTimeout,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)
        done,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)
        aborted,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)
        agentSpawned,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)
        agentTerminated,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)
        error,
  }) {
    return permissionTimeout(seq, eventId, agentId, agentType, agentName,
        taskName, requestId, timestamp);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)?
        connected,
    TResult? Function(int seq, @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events, DateTime timestamp)?
        history,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)?
        message,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)?
        status,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)?
        toolUse,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)?
        toolResult,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)?
        permissionRequest,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)?
        permissionTimeout,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)?
        done,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)?
        aborted,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)?
        agentSpawned,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)?
        agentTerminated,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)?
        error,
  }) {
    return permissionTimeout?.call(seq, eventId, agentId, agentType, agentName,
        taskName, requestId, timestamp);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)?
        connected,
    TResult Function(int seq, @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events, DateTime timestamp)?
        history,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)?
        message,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)?
        status,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)?
        toolUse,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)?
        toolResult,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)?
        permissionRequest,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)?
        permissionTimeout,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)?
        done,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)?
        aborted,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)?
        agentSpawned,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)?
        agentTerminated,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)?
        error,
    required TResult orElse(),
  }) {
    if (permissionTimeout != null) {
      return permissionTimeout(seq, eventId, agentId, agentType, agentName,
          taskName, requestId, timestamp);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConnectedEvent value) connected,
    required TResult Function(HistoryEvent value) history,
    required TResult Function(MessageEvent value) message,
    required TResult Function(StatusEvent value) status,
    required TResult Function(ToolUseEvent value) toolUse,
    required TResult Function(ToolResultEvent value) toolResult,
    required TResult Function(PermissionRequestEvent value) permissionRequest,
    required TResult Function(PermissionTimeoutEvent value) permissionTimeout,
    required TResult Function(DoneEvent value) done,
    required TResult Function(AbortedEvent value) aborted,
    required TResult Function(AgentSpawnedEvent value) agentSpawned,
    required TResult Function(AgentTerminatedEvent value) agentTerminated,
    required TResult Function(ErrorEvent value) error,
  }) {
    return permissionTimeout(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConnectedEvent value)? connected,
    TResult? Function(HistoryEvent value)? history,
    TResult? Function(MessageEvent value)? message,
    TResult? Function(StatusEvent value)? status,
    TResult? Function(ToolUseEvent value)? toolUse,
    TResult? Function(ToolResultEvent value)? toolResult,
    TResult? Function(PermissionRequestEvent value)? permissionRequest,
    TResult? Function(PermissionTimeoutEvent value)? permissionTimeout,
    TResult? Function(DoneEvent value)? done,
    TResult? Function(AbortedEvent value)? aborted,
    TResult? Function(AgentSpawnedEvent value)? agentSpawned,
    TResult? Function(AgentTerminatedEvent value)? agentTerminated,
    TResult? Function(ErrorEvent value)? error,
  }) {
    return permissionTimeout?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConnectedEvent value)? connected,
    TResult Function(HistoryEvent value)? history,
    TResult Function(MessageEvent value)? message,
    TResult Function(StatusEvent value)? status,
    TResult Function(ToolUseEvent value)? toolUse,
    TResult Function(ToolResultEvent value)? toolResult,
    TResult Function(PermissionRequestEvent value)? permissionRequest,
    TResult Function(PermissionTimeoutEvent value)? permissionTimeout,
    TResult Function(DoneEvent value)? done,
    TResult Function(AbortedEvent value)? aborted,
    TResult Function(AgentSpawnedEvent value)? agentSpawned,
    TResult Function(AgentTerminatedEvent value)? agentTerminated,
    TResult Function(ErrorEvent value)? error,
    required TResult orElse(),
  }) {
    if (permissionTimeout != null) {
      return permissionTimeout(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$PermissionTimeoutEventImplToJson(
      this,
    );
  }
}

abstract class PermissionTimeoutEvent implements SessionEvent {
  const factory PermissionTimeoutEvent(
      {required final int seq,
      @JsonKey(name: 'event-id') required final String eventId,
      @JsonKey(name: 'agent-id') required final String agentId,
      @JsonKey(name: 'agent-type') required final String agentType,
      @JsonKey(name: 'agent-name') final String? agentName,
      @JsonKey(name: 'task-name') final String? taskName,
      @JsonKey(name: 'request-id') required final String requestId,
      required final DateTime timestamp}) = _$PermissionTimeoutEventImpl;

  factory PermissionTimeoutEvent.fromJson(Map<String, dynamic> json) =
      _$PermissionTimeoutEventImpl.fromJson;

  @override
  int get seq;
  @override
  @JsonKey(name: 'event-id')
  String get eventId;
  @JsonKey(name: 'agent-id')
  String get agentId;
  @JsonKey(name: 'agent-type')
  String get agentType;
  @JsonKey(name: 'agent-name')
  String? get agentName;
  @JsonKey(name: 'task-name')
  String? get taskName;
  @JsonKey(name: 'request-id')
  String get requestId;
  @override
  DateTime get timestamp;

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PermissionTimeoutEventImplCopyWith<_$PermissionTimeoutEventImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$DoneEventImplCopyWith<$Res>
    implements $SessionEventCopyWith<$Res> {
  factory _$$DoneEventImplCopyWith(
          _$DoneEventImpl value, $Res Function(_$DoneEventImpl) then) =
      __$$DoneEventImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int seq,
      @JsonKey(name: 'event-id') String eventId,
      @JsonKey(name: 'agent-id') String agentId,
      @JsonKey(name: 'agent-type') String agentType,
      @JsonKey(name: 'agent-name') String? agentName,
      @JsonKey(name: 'task-name') String? taskName,
      String reason,
      DateTime timestamp});
}

/// @nodoc
class __$$DoneEventImplCopyWithImpl<$Res>
    extends _$SessionEventCopyWithImpl<$Res, _$DoneEventImpl>
    implements _$$DoneEventImplCopyWith<$Res> {
  __$$DoneEventImplCopyWithImpl(
      _$DoneEventImpl _value, $Res Function(_$DoneEventImpl) _then)
      : super(_value, _then);

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? seq = null,
    Object? eventId = null,
    Object? agentId = null,
    Object? agentType = null,
    Object? agentName = freezed,
    Object? taskName = freezed,
    Object? reason = null,
    Object? timestamp = null,
  }) {
    return _then(_$DoneEventImpl(
      seq: null == seq
          ? _value.seq
          : seq // ignore: cast_nullable_to_non_nullable
              as int,
      eventId: null == eventId
          ? _value.eventId
          : eventId // ignore: cast_nullable_to_non_nullable
              as String,
      agentId: null == agentId
          ? _value.agentId
          : agentId // ignore: cast_nullable_to_non_nullable
              as String,
      agentType: null == agentType
          ? _value.agentType
          : agentType // ignore: cast_nullable_to_non_nullable
              as String,
      agentName: freezed == agentName
          ? _value.agentName
          : agentName // ignore: cast_nullable_to_non_nullable
              as String?,
      taskName: freezed == taskName
          ? _value.taskName
          : taskName // ignore: cast_nullable_to_non_nullable
              as String?,
      reason: null == reason
          ? _value.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DoneEventImpl implements DoneEvent {
  const _$DoneEventImpl(
      {required this.seq,
      @JsonKey(name: 'event-id') required this.eventId,
      @JsonKey(name: 'agent-id') required this.agentId,
      @JsonKey(name: 'agent-type') required this.agentType,
      @JsonKey(name: 'agent-name') this.agentName,
      @JsonKey(name: 'task-name') this.taskName,
      required this.reason,
      required this.timestamp,
      final String? $type})
      : $type = $type ?? 'done';

  factory _$DoneEventImpl.fromJson(Map<String, dynamic> json) =>
      _$$DoneEventImplFromJson(json);

  @override
  final int seq;
  @override
  @JsonKey(name: 'event-id')
  final String eventId;
  @override
  @JsonKey(name: 'agent-id')
  final String agentId;
  @override
  @JsonKey(name: 'agent-type')
  final String agentType;
  @override
  @JsonKey(name: 'agent-name')
  final String? agentName;
  @override
  @JsonKey(name: 'task-name')
  final String? taskName;
  @override
  final String reason;
  @override
  final DateTime timestamp;

  @JsonKey(name: 'type')
  final String $type;

  @override
  String toString() {
    return 'SessionEvent.done(seq: $seq, eventId: $eventId, agentId: $agentId, agentType: $agentType, agentName: $agentName, taskName: $taskName, reason: $reason, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DoneEventImpl &&
            (identical(other.seq, seq) || other.seq == seq) &&
            (identical(other.eventId, eventId) || other.eventId == eventId) &&
            (identical(other.agentId, agentId) || other.agentId == agentId) &&
            (identical(other.agentType, agentType) ||
                other.agentType == agentType) &&
            (identical(other.agentName, agentName) ||
                other.agentName == agentName) &&
            (identical(other.taskName, taskName) ||
                other.taskName == taskName) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, seq, eventId, agentId, agentType,
      agentName, taskName, reason, timestamp);

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DoneEventImplCopyWith<_$DoneEventImpl> get copyWith =>
      __$$DoneEventImplCopyWithImpl<_$DoneEventImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)
        connected,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events,
            DateTime timestamp)
        history,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)
        message,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)
        status,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)
        toolUse,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)
        toolResult,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)
        permissionRequest,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)
        permissionTimeout,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)
        done,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)
        aborted,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)
        agentSpawned,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)
        agentTerminated,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)
        error,
  }) {
    return done(seq, eventId, agentId, agentType, agentName, taskName, reason,
        timestamp);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)?
        connected,
    TResult? Function(int seq, @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events, DateTime timestamp)?
        history,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)?
        message,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)?
        status,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)?
        toolUse,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)?
        toolResult,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)?
        permissionRequest,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)?
        permissionTimeout,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)?
        done,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)?
        aborted,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)?
        agentSpawned,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)?
        agentTerminated,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)?
        error,
  }) {
    return done?.call(seq, eventId, agentId, agentType, agentName, taskName,
        reason, timestamp);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)?
        connected,
    TResult Function(int seq, @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events, DateTime timestamp)?
        history,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)?
        message,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)?
        status,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)?
        toolUse,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)?
        toolResult,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)?
        permissionRequest,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)?
        permissionTimeout,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)?
        done,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)?
        aborted,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)?
        agentSpawned,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)?
        agentTerminated,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)?
        error,
    required TResult orElse(),
  }) {
    if (done != null) {
      return done(seq, eventId, agentId, agentType, agentName, taskName, reason,
          timestamp);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConnectedEvent value) connected,
    required TResult Function(HistoryEvent value) history,
    required TResult Function(MessageEvent value) message,
    required TResult Function(StatusEvent value) status,
    required TResult Function(ToolUseEvent value) toolUse,
    required TResult Function(ToolResultEvent value) toolResult,
    required TResult Function(PermissionRequestEvent value) permissionRequest,
    required TResult Function(PermissionTimeoutEvent value) permissionTimeout,
    required TResult Function(DoneEvent value) done,
    required TResult Function(AbortedEvent value) aborted,
    required TResult Function(AgentSpawnedEvent value) agentSpawned,
    required TResult Function(AgentTerminatedEvent value) agentTerminated,
    required TResult Function(ErrorEvent value) error,
  }) {
    return done(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConnectedEvent value)? connected,
    TResult? Function(HistoryEvent value)? history,
    TResult? Function(MessageEvent value)? message,
    TResult? Function(StatusEvent value)? status,
    TResult? Function(ToolUseEvent value)? toolUse,
    TResult? Function(ToolResultEvent value)? toolResult,
    TResult? Function(PermissionRequestEvent value)? permissionRequest,
    TResult? Function(PermissionTimeoutEvent value)? permissionTimeout,
    TResult? Function(DoneEvent value)? done,
    TResult? Function(AbortedEvent value)? aborted,
    TResult? Function(AgentSpawnedEvent value)? agentSpawned,
    TResult? Function(AgentTerminatedEvent value)? agentTerminated,
    TResult? Function(ErrorEvent value)? error,
  }) {
    return done?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConnectedEvent value)? connected,
    TResult Function(HistoryEvent value)? history,
    TResult Function(MessageEvent value)? message,
    TResult Function(StatusEvent value)? status,
    TResult Function(ToolUseEvent value)? toolUse,
    TResult Function(ToolResultEvent value)? toolResult,
    TResult Function(PermissionRequestEvent value)? permissionRequest,
    TResult Function(PermissionTimeoutEvent value)? permissionTimeout,
    TResult Function(DoneEvent value)? done,
    TResult Function(AbortedEvent value)? aborted,
    TResult Function(AgentSpawnedEvent value)? agentSpawned,
    TResult Function(AgentTerminatedEvent value)? agentTerminated,
    TResult Function(ErrorEvent value)? error,
    required TResult orElse(),
  }) {
    if (done != null) {
      return done(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$DoneEventImplToJson(
      this,
    );
  }
}

abstract class DoneEvent implements SessionEvent {
  const factory DoneEvent(
      {required final int seq,
      @JsonKey(name: 'event-id') required final String eventId,
      @JsonKey(name: 'agent-id') required final String agentId,
      @JsonKey(name: 'agent-type') required final String agentType,
      @JsonKey(name: 'agent-name') final String? agentName,
      @JsonKey(name: 'task-name') final String? taskName,
      required final String reason,
      required final DateTime timestamp}) = _$DoneEventImpl;

  factory DoneEvent.fromJson(Map<String, dynamic> json) =
      _$DoneEventImpl.fromJson;

  @override
  int get seq;
  @override
  @JsonKey(name: 'event-id')
  String get eventId;
  @JsonKey(name: 'agent-id')
  String get agentId;
  @JsonKey(name: 'agent-type')
  String get agentType;
  @JsonKey(name: 'agent-name')
  String? get agentName;
  @JsonKey(name: 'task-name')
  String? get taskName;
  String get reason;
  @override
  DateTime get timestamp;

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DoneEventImplCopyWith<_$DoneEventImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$AbortedEventImplCopyWith<$Res>
    implements $SessionEventCopyWith<$Res> {
  factory _$$AbortedEventImplCopyWith(
          _$AbortedEventImpl value, $Res Function(_$AbortedEventImpl) then) =
      __$$AbortedEventImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int seq,
      @JsonKey(name: 'event-id') String eventId,
      @JsonKey(name: 'agent-id') String agentId,
      @JsonKey(name: 'agent-type') String agentType,
      @JsonKey(name: 'agent-name') String? agentName,
      @JsonKey(name: 'task-name') String? taskName,
      DateTime timestamp});
}

/// @nodoc
class __$$AbortedEventImplCopyWithImpl<$Res>
    extends _$SessionEventCopyWithImpl<$Res, _$AbortedEventImpl>
    implements _$$AbortedEventImplCopyWith<$Res> {
  __$$AbortedEventImplCopyWithImpl(
      _$AbortedEventImpl _value, $Res Function(_$AbortedEventImpl) _then)
      : super(_value, _then);

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? seq = null,
    Object? eventId = null,
    Object? agentId = null,
    Object? agentType = null,
    Object? agentName = freezed,
    Object? taskName = freezed,
    Object? timestamp = null,
  }) {
    return _then(_$AbortedEventImpl(
      seq: null == seq
          ? _value.seq
          : seq // ignore: cast_nullable_to_non_nullable
              as int,
      eventId: null == eventId
          ? _value.eventId
          : eventId // ignore: cast_nullable_to_non_nullable
              as String,
      agentId: null == agentId
          ? _value.agentId
          : agentId // ignore: cast_nullable_to_non_nullable
              as String,
      agentType: null == agentType
          ? _value.agentType
          : agentType // ignore: cast_nullable_to_non_nullable
              as String,
      agentName: freezed == agentName
          ? _value.agentName
          : agentName // ignore: cast_nullable_to_non_nullable
              as String?,
      taskName: freezed == taskName
          ? _value.taskName
          : taskName // ignore: cast_nullable_to_non_nullable
              as String?,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AbortedEventImpl implements AbortedEvent {
  const _$AbortedEventImpl(
      {required this.seq,
      @JsonKey(name: 'event-id') required this.eventId,
      @JsonKey(name: 'agent-id') required this.agentId,
      @JsonKey(name: 'agent-type') required this.agentType,
      @JsonKey(name: 'agent-name') this.agentName,
      @JsonKey(name: 'task-name') this.taskName,
      required this.timestamp,
      final String? $type})
      : $type = $type ?? 'aborted';

  factory _$AbortedEventImpl.fromJson(Map<String, dynamic> json) =>
      _$$AbortedEventImplFromJson(json);

  @override
  final int seq;
  @override
  @JsonKey(name: 'event-id')
  final String eventId;
  @override
  @JsonKey(name: 'agent-id')
  final String agentId;
  @override
  @JsonKey(name: 'agent-type')
  final String agentType;
  @override
  @JsonKey(name: 'agent-name')
  final String? agentName;
  @override
  @JsonKey(name: 'task-name')
  final String? taskName;
  @override
  final DateTime timestamp;

  @JsonKey(name: 'type')
  final String $type;

  @override
  String toString() {
    return 'SessionEvent.aborted(seq: $seq, eventId: $eventId, agentId: $agentId, agentType: $agentType, agentName: $agentName, taskName: $taskName, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AbortedEventImpl &&
            (identical(other.seq, seq) || other.seq == seq) &&
            (identical(other.eventId, eventId) || other.eventId == eventId) &&
            (identical(other.agentId, agentId) || other.agentId == agentId) &&
            (identical(other.agentType, agentType) ||
                other.agentType == agentType) &&
            (identical(other.agentName, agentName) ||
                other.agentName == agentName) &&
            (identical(other.taskName, taskName) ||
                other.taskName == taskName) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, seq, eventId, agentId, agentType,
      agentName, taskName, timestamp);

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AbortedEventImplCopyWith<_$AbortedEventImpl> get copyWith =>
      __$$AbortedEventImplCopyWithImpl<_$AbortedEventImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)
        connected,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events,
            DateTime timestamp)
        history,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)
        message,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)
        status,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)
        toolUse,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)
        toolResult,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)
        permissionRequest,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)
        permissionTimeout,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)
        done,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)
        aborted,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)
        agentSpawned,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)
        agentTerminated,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)
        error,
  }) {
    return aborted(
        seq, eventId, agentId, agentType, agentName, taskName, timestamp);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)?
        connected,
    TResult? Function(int seq, @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events, DateTime timestamp)?
        history,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)?
        message,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)?
        status,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)?
        toolUse,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)?
        toolResult,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)?
        permissionRequest,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)?
        permissionTimeout,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)?
        done,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)?
        aborted,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)?
        agentSpawned,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)?
        agentTerminated,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)?
        error,
  }) {
    return aborted?.call(
        seq, eventId, agentId, agentType, agentName, taskName, timestamp);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)?
        connected,
    TResult Function(int seq, @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events, DateTime timestamp)?
        history,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)?
        message,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)?
        status,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)?
        toolUse,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)?
        toolResult,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)?
        permissionRequest,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)?
        permissionTimeout,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)?
        done,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)?
        aborted,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)?
        agentSpawned,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)?
        agentTerminated,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)?
        error,
    required TResult orElse(),
  }) {
    if (aborted != null) {
      return aborted(
          seq, eventId, agentId, agentType, agentName, taskName, timestamp);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConnectedEvent value) connected,
    required TResult Function(HistoryEvent value) history,
    required TResult Function(MessageEvent value) message,
    required TResult Function(StatusEvent value) status,
    required TResult Function(ToolUseEvent value) toolUse,
    required TResult Function(ToolResultEvent value) toolResult,
    required TResult Function(PermissionRequestEvent value) permissionRequest,
    required TResult Function(PermissionTimeoutEvent value) permissionTimeout,
    required TResult Function(DoneEvent value) done,
    required TResult Function(AbortedEvent value) aborted,
    required TResult Function(AgentSpawnedEvent value) agentSpawned,
    required TResult Function(AgentTerminatedEvent value) agentTerminated,
    required TResult Function(ErrorEvent value) error,
  }) {
    return aborted(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConnectedEvent value)? connected,
    TResult? Function(HistoryEvent value)? history,
    TResult? Function(MessageEvent value)? message,
    TResult? Function(StatusEvent value)? status,
    TResult? Function(ToolUseEvent value)? toolUse,
    TResult? Function(ToolResultEvent value)? toolResult,
    TResult? Function(PermissionRequestEvent value)? permissionRequest,
    TResult? Function(PermissionTimeoutEvent value)? permissionTimeout,
    TResult? Function(DoneEvent value)? done,
    TResult? Function(AbortedEvent value)? aborted,
    TResult? Function(AgentSpawnedEvent value)? agentSpawned,
    TResult? Function(AgentTerminatedEvent value)? agentTerminated,
    TResult? Function(ErrorEvent value)? error,
  }) {
    return aborted?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConnectedEvent value)? connected,
    TResult Function(HistoryEvent value)? history,
    TResult Function(MessageEvent value)? message,
    TResult Function(StatusEvent value)? status,
    TResult Function(ToolUseEvent value)? toolUse,
    TResult Function(ToolResultEvent value)? toolResult,
    TResult Function(PermissionRequestEvent value)? permissionRequest,
    TResult Function(PermissionTimeoutEvent value)? permissionTimeout,
    TResult Function(DoneEvent value)? done,
    TResult Function(AbortedEvent value)? aborted,
    TResult Function(AgentSpawnedEvent value)? agentSpawned,
    TResult Function(AgentTerminatedEvent value)? agentTerminated,
    TResult Function(ErrorEvent value)? error,
    required TResult orElse(),
  }) {
    if (aborted != null) {
      return aborted(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$AbortedEventImplToJson(
      this,
    );
  }
}

abstract class AbortedEvent implements SessionEvent {
  const factory AbortedEvent(
      {required final int seq,
      @JsonKey(name: 'event-id') required final String eventId,
      @JsonKey(name: 'agent-id') required final String agentId,
      @JsonKey(name: 'agent-type') required final String agentType,
      @JsonKey(name: 'agent-name') final String? agentName,
      @JsonKey(name: 'task-name') final String? taskName,
      required final DateTime timestamp}) = _$AbortedEventImpl;

  factory AbortedEvent.fromJson(Map<String, dynamic> json) =
      _$AbortedEventImpl.fromJson;

  @override
  int get seq;
  @override
  @JsonKey(name: 'event-id')
  String get eventId;
  @JsonKey(name: 'agent-id')
  String get agentId;
  @JsonKey(name: 'agent-type')
  String get agentType;
  @JsonKey(name: 'agent-name')
  String? get agentName;
  @JsonKey(name: 'task-name')
  String? get taskName;
  @override
  DateTime get timestamp;

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AbortedEventImplCopyWith<_$AbortedEventImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$AgentSpawnedEventImplCopyWith<$Res>
    implements $SessionEventCopyWith<$Res> {
  factory _$$AgentSpawnedEventImplCopyWith(_$AgentSpawnedEventImpl value,
          $Res Function(_$AgentSpawnedEventImpl) then) =
      __$$AgentSpawnedEventImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int seq,
      @JsonKey(name: 'event-id') String eventId,
      @JsonKey(name: 'agent-id') String agentId,
      @JsonKey(name: 'agent-type') String agentType,
      @JsonKey(name: 'agent-name') String agentName,
      @JsonKey(name: 'parent-agent-id') String? parentAgentId,
      DateTime timestamp});
}

/// @nodoc
class __$$AgentSpawnedEventImplCopyWithImpl<$Res>
    extends _$SessionEventCopyWithImpl<$Res, _$AgentSpawnedEventImpl>
    implements _$$AgentSpawnedEventImplCopyWith<$Res> {
  __$$AgentSpawnedEventImplCopyWithImpl(_$AgentSpawnedEventImpl _value,
      $Res Function(_$AgentSpawnedEventImpl) _then)
      : super(_value, _then);

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? seq = null,
    Object? eventId = null,
    Object? agentId = null,
    Object? agentType = null,
    Object? agentName = null,
    Object? parentAgentId = freezed,
    Object? timestamp = null,
  }) {
    return _then(_$AgentSpawnedEventImpl(
      seq: null == seq
          ? _value.seq
          : seq // ignore: cast_nullable_to_non_nullable
              as int,
      eventId: null == eventId
          ? _value.eventId
          : eventId // ignore: cast_nullable_to_non_nullable
              as String,
      agentId: null == agentId
          ? _value.agentId
          : agentId // ignore: cast_nullable_to_non_nullable
              as String,
      agentType: null == agentType
          ? _value.agentType
          : agentType // ignore: cast_nullable_to_non_nullable
              as String,
      agentName: null == agentName
          ? _value.agentName
          : agentName // ignore: cast_nullable_to_non_nullable
              as String,
      parentAgentId: freezed == parentAgentId
          ? _value.parentAgentId
          : parentAgentId // ignore: cast_nullable_to_non_nullable
              as String?,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AgentSpawnedEventImpl implements AgentSpawnedEvent {
  const _$AgentSpawnedEventImpl(
      {required this.seq,
      @JsonKey(name: 'event-id') required this.eventId,
      @JsonKey(name: 'agent-id') required this.agentId,
      @JsonKey(name: 'agent-type') required this.agentType,
      @JsonKey(name: 'agent-name') required this.agentName,
      @JsonKey(name: 'parent-agent-id') this.parentAgentId,
      required this.timestamp,
      final String? $type})
      : $type = $type ?? 'agent-spawned';

  factory _$AgentSpawnedEventImpl.fromJson(Map<String, dynamic> json) =>
      _$$AgentSpawnedEventImplFromJson(json);

  @override
  final int seq;
  @override
  @JsonKey(name: 'event-id')
  final String eventId;
  @override
  @JsonKey(name: 'agent-id')
  final String agentId;
  @override
  @JsonKey(name: 'agent-type')
  final String agentType;
  @override
  @JsonKey(name: 'agent-name')
  final String agentName;
  @override
  @JsonKey(name: 'parent-agent-id')
  final String? parentAgentId;
  @override
  final DateTime timestamp;

  @JsonKey(name: 'type')
  final String $type;

  @override
  String toString() {
    return 'SessionEvent.agentSpawned(seq: $seq, eventId: $eventId, agentId: $agentId, agentType: $agentType, agentName: $agentName, parentAgentId: $parentAgentId, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AgentSpawnedEventImpl &&
            (identical(other.seq, seq) || other.seq == seq) &&
            (identical(other.eventId, eventId) || other.eventId == eventId) &&
            (identical(other.agentId, agentId) || other.agentId == agentId) &&
            (identical(other.agentType, agentType) ||
                other.agentType == agentType) &&
            (identical(other.agentName, agentName) ||
                other.agentName == agentName) &&
            (identical(other.parentAgentId, parentAgentId) ||
                other.parentAgentId == parentAgentId) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, seq, eventId, agentId, agentType,
      agentName, parentAgentId, timestamp);

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AgentSpawnedEventImplCopyWith<_$AgentSpawnedEventImpl> get copyWith =>
      __$$AgentSpawnedEventImplCopyWithImpl<_$AgentSpawnedEventImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)
        connected,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events,
            DateTime timestamp)
        history,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)
        message,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)
        status,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)
        toolUse,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)
        toolResult,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)
        permissionRequest,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)
        permissionTimeout,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)
        done,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)
        aborted,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)
        agentSpawned,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)
        agentTerminated,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)
        error,
  }) {
    return agentSpawned(
        seq, eventId, agentId, agentType, agentName, parentAgentId, timestamp);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)?
        connected,
    TResult? Function(int seq, @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events, DateTime timestamp)?
        history,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)?
        message,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)?
        status,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)?
        toolUse,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)?
        toolResult,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)?
        permissionRequest,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)?
        permissionTimeout,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)?
        done,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)?
        aborted,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)?
        agentSpawned,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)?
        agentTerminated,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)?
        error,
  }) {
    return agentSpawned?.call(
        seq, eventId, agentId, agentType, agentName, parentAgentId, timestamp);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)?
        connected,
    TResult Function(int seq, @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events, DateTime timestamp)?
        history,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)?
        message,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)?
        status,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)?
        toolUse,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)?
        toolResult,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)?
        permissionRequest,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)?
        permissionTimeout,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)?
        done,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)?
        aborted,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)?
        agentSpawned,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)?
        agentTerminated,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)?
        error,
    required TResult orElse(),
  }) {
    if (agentSpawned != null) {
      return agentSpawned(seq, eventId, agentId, agentType, agentName,
          parentAgentId, timestamp);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConnectedEvent value) connected,
    required TResult Function(HistoryEvent value) history,
    required TResult Function(MessageEvent value) message,
    required TResult Function(StatusEvent value) status,
    required TResult Function(ToolUseEvent value) toolUse,
    required TResult Function(ToolResultEvent value) toolResult,
    required TResult Function(PermissionRequestEvent value) permissionRequest,
    required TResult Function(PermissionTimeoutEvent value) permissionTimeout,
    required TResult Function(DoneEvent value) done,
    required TResult Function(AbortedEvent value) aborted,
    required TResult Function(AgentSpawnedEvent value) agentSpawned,
    required TResult Function(AgentTerminatedEvent value) agentTerminated,
    required TResult Function(ErrorEvent value) error,
  }) {
    return agentSpawned(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConnectedEvent value)? connected,
    TResult? Function(HistoryEvent value)? history,
    TResult? Function(MessageEvent value)? message,
    TResult? Function(StatusEvent value)? status,
    TResult? Function(ToolUseEvent value)? toolUse,
    TResult? Function(ToolResultEvent value)? toolResult,
    TResult? Function(PermissionRequestEvent value)? permissionRequest,
    TResult? Function(PermissionTimeoutEvent value)? permissionTimeout,
    TResult? Function(DoneEvent value)? done,
    TResult? Function(AbortedEvent value)? aborted,
    TResult? Function(AgentSpawnedEvent value)? agentSpawned,
    TResult? Function(AgentTerminatedEvent value)? agentTerminated,
    TResult? Function(ErrorEvent value)? error,
  }) {
    return agentSpawned?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConnectedEvent value)? connected,
    TResult Function(HistoryEvent value)? history,
    TResult Function(MessageEvent value)? message,
    TResult Function(StatusEvent value)? status,
    TResult Function(ToolUseEvent value)? toolUse,
    TResult Function(ToolResultEvent value)? toolResult,
    TResult Function(PermissionRequestEvent value)? permissionRequest,
    TResult Function(PermissionTimeoutEvent value)? permissionTimeout,
    TResult Function(DoneEvent value)? done,
    TResult Function(AbortedEvent value)? aborted,
    TResult Function(AgentSpawnedEvent value)? agentSpawned,
    TResult Function(AgentTerminatedEvent value)? agentTerminated,
    TResult Function(ErrorEvent value)? error,
    required TResult orElse(),
  }) {
    if (agentSpawned != null) {
      return agentSpawned(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$AgentSpawnedEventImplToJson(
      this,
    );
  }
}

abstract class AgentSpawnedEvent implements SessionEvent {
  const factory AgentSpawnedEvent(
      {required final int seq,
      @JsonKey(name: 'event-id') required final String eventId,
      @JsonKey(name: 'agent-id') required final String agentId,
      @JsonKey(name: 'agent-type') required final String agentType,
      @JsonKey(name: 'agent-name') required final String agentName,
      @JsonKey(name: 'parent-agent-id') final String? parentAgentId,
      required final DateTime timestamp}) = _$AgentSpawnedEventImpl;

  factory AgentSpawnedEvent.fromJson(Map<String, dynamic> json) =
      _$AgentSpawnedEventImpl.fromJson;

  @override
  int get seq;
  @override
  @JsonKey(name: 'event-id')
  String get eventId;
  @JsonKey(name: 'agent-id')
  String get agentId;
  @JsonKey(name: 'agent-type')
  String get agentType;
  @JsonKey(name: 'agent-name')
  String get agentName;
  @JsonKey(name: 'parent-agent-id')
  String? get parentAgentId;
  @override
  DateTime get timestamp;

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AgentSpawnedEventImplCopyWith<_$AgentSpawnedEventImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$AgentTerminatedEventImplCopyWith<$Res>
    implements $SessionEventCopyWith<$Res> {
  factory _$$AgentTerminatedEventImplCopyWith(_$AgentTerminatedEventImpl value,
          $Res Function(_$AgentTerminatedEventImpl) then) =
      __$$AgentTerminatedEventImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int seq,
      @JsonKey(name: 'event-id') String eventId,
      @JsonKey(name: 'agent-id') String agentId,
      @JsonKey(name: 'agent-type') String agentType,
      @JsonKey(name: 'agent-name') String? agentName,
      String? reason,
      DateTime timestamp});
}

/// @nodoc
class __$$AgentTerminatedEventImplCopyWithImpl<$Res>
    extends _$SessionEventCopyWithImpl<$Res, _$AgentTerminatedEventImpl>
    implements _$$AgentTerminatedEventImplCopyWith<$Res> {
  __$$AgentTerminatedEventImplCopyWithImpl(_$AgentTerminatedEventImpl _value,
      $Res Function(_$AgentTerminatedEventImpl) _then)
      : super(_value, _then);

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? seq = null,
    Object? eventId = null,
    Object? agentId = null,
    Object? agentType = null,
    Object? agentName = freezed,
    Object? reason = freezed,
    Object? timestamp = null,
  }) {
    return _then(_$AgentTerminatedEventImpl(
      seq: null == seq
          ? _value.seq
          : seq // ignore: cast_nullable_to_non_nullable
              as int,
      eventId: null == eventId
          ? _value.eventId
          : eventId // ignore: cast_nullable_to_non_nullable
              as String,
      agentId: null == agentId
          ? _value.agentId
          : agentId // ignore: cast_nullable_to_non_nullable
              as String,
      agentType: null == agentType
          ? _value.agentType
          : agentType // ignore: cast_nullable_to_non_nullable
              as String,
      agentName: freezed == agentName
          ? _value.agentName
          : agentName // ignore: cast_nullable_to_non_nullable
              as String?,
      reason: freezed == reason
          ? _value.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String?,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AgentTerminatedEventImpl implements AgentTerminatedEvent {
  const _$AgentTerminatedEventImpl(
      {required this.seq,
      @JsonKey(name: 'event-id') required this.eventId,
      @JsonKey(name: 'agent-id') required this.agentId,
      @JsonKey(name: 'agent-type') required this.agentType,
      @JsonKey(name: 'agent-name') this.agentName,
      this.reason,
      required this.timestamp,
      final String? $type})
      : $type = $type ?? 'agent-terminated';

  factory _$AgentTerminatedEventImpl.fromJson(Map<String, dynamic> json) =>
      _$$AgentTerminatedEventImplFromJson(json);

  @override
  final int seq;
  @override
  @JsonKey(name: 'event-id')
  final String eventId;
  @override
  @JsonKey(name: 'agent-id')
  final String agentId;
  @override
  @JsonKey(name: 'agent-type')
  final String agentType;
  @override
  @JsonKey(name: 'agent-name')
  final String? agentName;
  @override
  final String? reason;
  @override
  final DateTime timestamp;

  @JsonKey(name: 'type')
  final String $type;

  @override
  String toString() {
    return 'SessionEvent.agentTerminated(seq: $seq, eventId: $eventId, agentId: $agentId, agentType: $agentType, agentName: $agentName, reason: $reason, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AgentTerminatedEventImpl &&
            (identical(other.seq, seq) || other.seq == seq) &&
            (identical(other.eventId, eventId) || other.eventId == eventId) &&
            (identical(other.agentId, agentId) || other.agentId == agentId) &&
            (identical(other.agentType, agentType) ||
                other.agentType == agentType) &&
            (identical(other.agentName, agentName) ||
                other.agentName == agentName) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, seq, eventId, agentId, agentType,
      agentName, reason, timestamp);

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AgentTerminatedEventImplCopyWith<_$AgentTerminatedEventImpl>
      get copyWith =>
          __$$AgentTerminatedEventImplCopyWithImpl<_$AgentTerminatedEventImpl>(
              this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)
        connected,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events,
            DateTime timestamp)
        history,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)
        message,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)
        status,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)
        toolUse,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)
        toolResult,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)
        permissionRequest,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)
        permissionTimeout,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)
        done,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)
        aborted,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)
        agentSpawned,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)
        agentTerminated,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)
        error,
  }) {
    return agentTerminated(
        seq, eventId, agentId, agentType, agentName, reason, timestamp);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)?
        connected,
    TResult? Function(int seq, @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events, DateTime timestamp)?
        history,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)?
        message,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)?
        status,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)?
        toolUse,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)?
        toolResult,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)?
        permissionRequest,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)?
        permissionTimeout,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)?
        done,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)?
        aborted,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)?
        agentSpawned,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)?
        agentTerminated,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)?
        error,
  }) {
    return agentTerminated?.call(
        seq, eventId, agentId, agentType, agentName, reason, timestamp);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)?
        connected,
    TResult Function(int seq, @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events, DateTime timestamp)?
        history,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)?
        message,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)?
        status,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)?
        toolUse,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)?
        toolResult,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)?
        permissionRequest,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)?
        permissionTimeout,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)?
        done,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)?
        aborted,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)?
        agentSpawned,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)?
        agentTerminated,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)?
        error,
    required TResult orElse(),
  }) {
    if (agentTerminated != null) {
      return agentTerminated(
          seq, eventId, agentId, agentType, agentName, reason, timestamp);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConnectedEvent value) connected,
    required TResult Function(HistoryEvent value) history,
    required TResult Function(MessageEvent value) message,
    required TResult Function(StatusEvent value) status,
    required TResult Function(ToolUseEvent value) toolUse,
    required TResult Function(ToolResultEvent value) toolResult,
    required TResult Function(PermissionRequestEvent value) permissionRequest,
    required TResult Function(PermissionTimeoutEvent value) permissionTimeout,
    required TResult Function(DoneEvent value) done,
    required TResult Function(AbortedEvent value) aborted,
    required TResult Function(AgentSpawnedEvent value) agentSpawned,
    required TResult Function(AgentTerminatedEvent value) agentTerminated,
    required TResult Function(ErrorEvent value) error,
  }) {
    return agentTerminated(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConnectedEvent value)? connected,
    TResult? Function(HistoryEvent value)? history,
    TResult? Function(MessageEvent value)? message,
    TResult? Function(StatusEvent value)? status,
    TResult? Function(ToolUseEvent value)? toolUse,
    TResult? Function(ToolResultEvent value)? toolResult,
    TResult? Function(PermissionRequestEvent value)? permissionRequest,
    TResult? Function(PermissionTimeoutEvent value)? permissionTimeout,
    TResult? Function(DoneEvent value)? done,
    TResult? Function(AbortedEvent value)? aborted,
    TResult? Function(AgentSpawnedEvent value)? agentSpawned,
    TResult? Function(AgentTerminatedEvent value)? agentTerminated,
    TResult? Function(ErrorEvent value)? error,
  }) {
    return agentTerminated?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConnectedEvent value)? connected,
    TResult Function(HistoryEvent value)? history,
    TResult Function(MessageEvent value)? message,
    TResult Function(StatusEvent value)? status,
    TResult Function(ToolUseEvent value)? toolUse,
    TResult Function(ToolResultEvent value)? toolResult,
    TResult Function(PermissionRequestEvent value)? permissionRequest,
    TResult Function(PermissionTimeoutEvent value)? permissionTimeout,
    TResult Function(DoneEvent value)? done,
    TResult Function(AbortedEvent value)? aborted,
    TResult Function(AgentSpawnedEvent value)? agentSpawned,
    TResult Function(AgentTerminatedEvent value)? agentTerminated,
    TResult Function(ErrorEvent value)? error,
    required TResult orElse(),
  }) {
    if (agentTerminated != null) {
      return agentTerminated(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$AgentTerminatedEventImplToJson(
      this,
    );
  }
}

abstract class AgentTerminatedEvent implements SessionEvent {
  const factory AgentTerminatedEvent(
      {required final int seq,
      @JsonKey(name: 'event-id') required final String eventId,
      @JsonKey(name: 'agent-id') required final String agentId,
      @JsonKey(name: 'agent-type') required final String agentType,
      @JsonKey(name: 'agent-name') final String? agentName,
      final String? reason,
      required final DateTime timestamp}) = _$AgentTerminatedEventImpl;

  factory AgentTerminatedEvent.fromJson(Map<String, dynamic> json) =
      _$AgentTerminatedEventImpl.fromJson;

  @override
  int get seq;
  @override
  @JsonKey(name: 'event-id')
  String get eventId;
  @JsonKey(name: 'agent-id')
  String get agentId;
  @JsonKey(name: 'agent-type')
  String get agentType;
  @JsonKey(name: 'agent-name')
  String? get agentName;
  String? get reason;
  @override
  DateTime get timestamp;

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AgentTerminatedEventImplCopyWith<_$AgentTerminatedEventImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ErrorEventImplCopyWith<$Res>
    implements $SessionEventCopyWith<$Res> {
  factory _$$ErrorEventImplCopyWith(
          _$ErrorEventImpl value, $Res Function(_$ErrorEventImpl) then) =
      __$$ErrorEventImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int seq,
      @JsonKey(name: 'event-id') String eventId,
      @JsonKey(name: 'agent-id') String? agentId,
      @JsonKey(name: 'agent-type') String? agentType,
      @JsonKey(name: 'agent-name') String? agentName,
      @JsonKey(name: 'task-name') String? taskName,
      String code,
      String message,
      DateTime timestamp});
}

/// @nodoc
class __$$ErrorEventImplCopyWithImpl<$Res>
    extends _$SessionEventCopyWithImpl<$Res, _$ErrorEventImpl>
    implements _$$ErrorEventImplCopyWith<$Res> {
  __$$ErrorEventImplCopyWithImpl(
      _$ErrorEventImpl _value, $Res Function(_$ErrorEventImpl) _then)
      : super(_value, _then);

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? seq = null,
    Object? eventId = null,
    Object? agentId = freezed,
    Object? agentType = freezed,
    Object? agentName = freezed,
    Object? taskName = freezed,
    Object? code = null,
    Object? message = null,
    Object? timestamp = null,
  }) {
    return _then(_$ErrorEventImpl(
      seq: null == seq
          ? _value.seq
          : seq // ignore: cast_nullable_to_non_nullable
              as int,
      eventId: null == eventId
          ? _value.eventId
          : eventId // ignore: cast_nullable_to_non_nullable
              as String,
      agentId: freezed == agentId
          ? _value.agentId
          : agentId // ignore: cast_nullable_to_non_nullable
              as String?,
      agentType: freezed == agentType
          ? _value.agentType
          : agentType // ignore: cast_nullable_to_non_nullable
              as String?,
      agentName: freezed == agentName
          ? _value.agentName
          : agentName // ignore: cast_nullable_to_non_nullable
              as String?,
      taskName: freezed == taskName
          ? _value.taskName
          : taskName // ignore: cast_nullable_to_non_nullable
              as String?,
      code: null == code
          ? _value.code
          : code // ignore: cast_nullable_to_non_nullable
              as String,
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ErrorEventImpl implements ErrorEvent {
  const _$ErrorEventImpl(
      {required this.seq,
      @JsonKey(name: 'event-id') required this.eventId,
      @JsonKey(name: 'agent-id') this.agentId,
      @JsonKey(name: 'agent-type') this.agentType,
      @JsonKey(name: 'agent-name') this.agentName,
      @JsonKey(name: 'task-name') this.taskName,
      required this.code,
      required this.message,
      required this.timestamp,
      final String? $type})
      : $type = $type ?? 'error';

  factory _$ErrorEventImpl.fromJson(Map<String, dynamic> json) =>
      _$$ErrorEventImplFromJson(json);

  @override
  final int seq;
  @override
  @JsonKey(name: 'event-id')
  final String eventId;
  @override
  @JsonKey(name: 'agent-id')
  final String? agentId;
  @override
  @JsonKey(name: 'agent-type')
  final String? agentType;
  @override
  @JsonKey(name: 'agent-name')
  final String? agentName;
  @override
  @JsonKey(name: 'task-name')
  final String? taskName;
  @override
  final String code;
  @override
  final String message;
  @override
  final DateTime timestamp;

  @JsonKey(name: 'type')
  final String $type;

  @override
  String toString() {
    return 'SessionEvent.error(seq: $seq, eventId: $eventId, agentId: $agentId, agentType: $agentType, agentName: $agentName, taskName: $taskName, code: $code, message: $message, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ErrorEventImpl &&
            (identical(other.seq, seq) || other.seq == seq) &&
            (identical(other.eventId, eventId) || other.eventId == eventId) &&
            (identical(other.agentId, agentId) || other.agentId == agentId) &&
            (identical(other.agentType, agentType) ||
                other.agentType == agentType) &&
            (identical(other.agentName, agentName) ||
                other.agentName == agentName) &&
            (identical(other.taskName, taskName) ||
                other.taskName == taskName) &&
            (identical(other.code, code) || other.code == code) &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, seq, eventId, agentId, agentType,
      agentName, taskName, code, message, timestamp);

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ErrorEventImplCopyWith<_$ErrorEventImpl> get copyWith =>
      __$$ErrorEventImplCopyWithImpl<_$ErrorEventImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)
        connected,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events,
            DateTime timestamp)
        history,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)
        message,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)
        status,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)
        toolUse,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)
        toolResult,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)
        permissionRequest,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)
        permissionTimeout,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)
        done,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)
        aborted,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)
        agentSpawned,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)
        agentTerminated,
    required TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)
        error,
  }) {
    return error(seq, eventId, agentId, agentType, agentName, taskName, code,
        this.message, timestamp);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)?
        connected,
    TResult? Function(int seq, @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events, DateTime timestamp)?
        history,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)?
        message,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)?
        status,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)?
        toolUse,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)?
        toolResult,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)?
        permissionRequest,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)?
        permissionTimeout,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)?
        done,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)?
        aborted,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)?
        agentSpawned,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)?
        agentTerminated,
    TResult? Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)?
        error,
  }) {
    return error?.call(seq, eventId, agentId, agentType, agentName, taskName,
        code, this.message, timestamp);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'session-id') String sessionId,
            @JsonKey(name: 'main-agent-id') String mainAgentId,
            @JsonKey(name: 'last-seq') int lastSeq,
            List<SessionEventAgent> agents,
            DateTime timestamp)?
        connected,
    TResult Function(int seq, @JsonKey(name: 'event-id') String eventId,
            List<Map<String, dynamic>> events, DateTime timestamp)?
        history,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            SessionEventMessageData data,
            @JsonKey(name: 'is-partial') bool isPartial,
            DateTime timestamp)?
        message,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            AgentStatus status,
            DateTime timestamp)?
        status,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            Map<String, dynamic> input,
            DateTime timestamp)?
        toolUse,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'tool-use-id') String toolUseId,
            @JsonKey(name: 'tool-name') String toolName,
            dynamic result,
            @JsonKey(name: 'is-error') bool isError,
            DateTime timestamp)?
        toolResult,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            @JsonKey(name: 'tool-name') String toolName,
            @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
            @JsonKey(name: 'permission-suggestions')
            List<String>? permissionSuggestions,
            DateTime timestamp)?
        permissionRequest,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            @JsonKey(name: 'request-id') String requestId,
            DateTime timestamp)?
        permissionTimeout,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String reason,
            DateTime timestamp)?
        done,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            DateTime timestamp)?
        aborted,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String agentName,
            @JsonKey(name: 'parent-agent-id') String? parentAgentId,
            DateTime timestamp)?
        agentSpawned,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String agentId,
            @JsonKey(name: 'agent-type') String agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            String? reason,
            DateTime timestamp)?
        agentTerminated,
    TResult Function(
            int seq,
            @JsonKey(name: 'event-id') String eventId,
            @JsonKey(name: 'agent-id') String? agentId,
            @JsonKey(name: 'agent-type') String? agentType,
            @JsonKey(name: 'agent-name') String? agentName,
            @JsonKey(name: 'task-name') String? taskName,
            String code,
            String message,
            DateTime timestamp)?
        error,
    required TResult orElse(),
  }) {
    if (error != null) {
      return error(seq, eventId, agentId, agentType, agentName, taskName, code,
          this.message, timestamp);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConnectedEvent value) connected,
    required TResult Function(HistoryEvent value) history,
    required TResult Function(MessageEvent value) message,
    required TResult Function(StatusEvent value) status,
    required TResult Function(ToolUseEvent value) toolUse,
    required TResult Function(ToolResultEvent value) toolResult,
    required TResult Function(PermissionRequestEvent value) permissionRequest,
    required TResult Function(PermissionTimeoutEvent value) permissionTimeout,
    required TResult Function(DoneEvent value) done,
    required TResult Function(AbortedEvent value) aborted,
    required TResult Function(AgentSpawnedEvent value) agentSpawned,
    required TResult Function(AgentTerminatedEvent value) agentTerminated,
    required TResult Function(ErrorEvent value) error,
  }) {
    return error(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConnectedEvent value)? connected,
    TResult? Function(HistoryEvent value)? history,
    TResult? Function(MessageEvent value)? message,
    TResult? Function(StatusEvent value)? status,
    TResult? Function(ToolUseEvent value)? toolUse,
    TResult? Function(ToolResultEvent value)? toolResult,
    TResult? Function(PermissionRequestEvent value)? permissionRequest,
    TResult? Function(PermissionTimeoutEvent value)? permissionTimeout,
    TResult? Function(DoneEvent value)? done,
    TResult? Function(AbortedEvent value)? aborted,
    TResult? Function(AgentSpawnedEvent value)? agentSpawned,
    TResult? Function(AgentTerminatedEvent value)? agentTerminated,
    TResult? Function(ErrorEvent value)? error,
  }) {
    return error?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConnectedEvent value)? connected,
    TResult Function(HistoryEvent value)? history,
    TResult Function(MessageEvent value)? message,
    TResult Function(StatusEvent value)? status,
    TResult Function(ToolUseEvent value)? toolUse,
    TResult Function(ToolResultEvent value)? toolResult,
    TResult Function(PermissionRequestEvent value)? permissionRequest,
    TResult Function(PermissionTimeoutEvent value)? permissionTimeout,
    TResult Function(DoneEvent value)? done,
    TResult Function(AbortedEvent value)? aborted,
    TResult Function(AgentSpawnedEvent value)? agentSpawned,
    TResult Function(AgentTerminatedEvent value)? agentTerminated,
    TResult Function(ErrorEvent value)? error,
    required TResult orElse(),
  }) {
    if (error != null) {
      return error(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$ErrorEventImplToJson(
      this,
    );
  }
}

abstract class ErrorEvent implements SessionEvent {
  const factory ErrorEvent(
      {required final int seq,
      @JsonKey(name: 'event-id') required final String eventId,
      @JsonKey(name: 'agent-id') final String? agentId,
      @JsonKey(name: 'agent-type') final String? agentType,
      @JsonKey(name: 'agent-name') final String? agentName,
      @JsonKey(name: 'task-name') final String? taskName,
      required final String code,
      required final String message,
      required final DateTime timestamp}) = _$ErrorEventImpl;

  factory ErrorEvent.fromJson(Map<String, dynamic> json) =
      _$ErrorEventImpl.fromJson;

  @override
  int get seq;
  @override
  @JsonKey(name: 'event-id')
  String get eventId;
  @JsonKey(name: 'agent-id')
  String? get agentId;
  @JsonKey(name: 'agent-type')
  String? get agentType;
  @JsonKey(name: 'agent-name')
  String? get agentName;
  @JsonKey(name: 'task-name')
  String? get taskName;
  String get code;
  String get message;
  @override
  DateTime get timestamp;

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ErrorEventImplCopyWith<_$ErrorEventImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SessionEventAgent _$SessionEventAgentFromJson(Map<String, dynamic> json) {
  return _SessionEventAgent.fromJson(json);
}

/// @nodoc
mixin _$SessionEventAgent {
  String get id => throw _privateConstructorUsedError;
  String get type => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  AgentStatus get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'task-name')
  String? get taskName => throw _privateConstructorUsedError;

  /// Serializes this SessionEventAgent to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SessionEventAgent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SessionEventAgentCopyWith<SessionEventAgent> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SessionEventAgentCopyWith<$Res> {
  factory $SessionEventAgentCopyWith(
          SessionEventAgent value, $Res Function(SessionEventAgent) then) =
      _$SessionEventAgentCopyWithImpl<$Res, SessionEventAgent>;
  @useResult
  $Res call(
      {String id,
      String type,
      String name,
      AgentStatus status,
      @JsonKey(name: 'task-name') String? taskName});
}

/// @nodoc
class _$SessionEventAgentCopyWithImpl<$Res, $Val extends SessionEventAgent>
    implements $SessionEventAgentCopyWith<$Res> {
  _$SessionEventAgentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SessionEventAgent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? name = null,
    Object? status = null,
    Object? taskName = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as AgentStatus,
      taskName: freezed == taskName
          ? _value.taskName
          : taskName // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SessionEventAgentImplCopyWith<$Res>
    implements $SessionEventAgentCopyWith<$Res> {
  factory _$$SessionEventAgentImplCopyWith(_$SessionEventAgentImpl value,
          $Res Function(_$SessionEventAgentImpl) then) =
      __$$SessionEventAgentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String type,
      String name,
      AgentStatus status,
      @JsonKey(name: 'task-name') String? taskName});
}

/// @nodoc
class __$$SessionEventAgentImplCopyWithImpl<$Res>
    extends _$SessionEventAgentCopyWithImpl<$Res, _$SessionEventAgentImpl>
    implements _$$SessionEventAgentImplCopyWith<$Res> {
  __$$SessionEventAgentImplCopyWithImpl(_$SessionEventAgentImpl _value,
      $Res Function(_$SessionEventAgentImpl) _then)
      : super(_value, _then);

  /// Create a copy of SessionEventAgent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? name = null,
    Object? status = null,
    Object? taskName = freezed,
  }) {
    return _then(_$SessionEventAgentImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as AgentStatus,
      taskName: freezed == taskName
          ? _value.taskName
          : taskName // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SessionEventAgentImpl implements _SessionEventAgent {
  const _$SessionEventAgentImpl(
      {required this.id,
      required this.type,
      required this.name,
      required this.status,
      @JsonKey(name: 'task-name') this.taskName});

  factory _$SessionEventAgentImpl.fromJson(Map<String, dynamic> json) =>
      _$$SessionEventAgentImplFromJson(json);

  @override
  final String id;
  @override
  final String type;
  @override
  final String name;
  @override
  final AgentStatus status;
  @override
  @JsonKey(name: 'task-name')
  final String? taskName;

  @override
  String toString() {
    return 'SessionEventAgent(id: $id, type: $type, name: $name, status: $status, taskName: $taskName)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SessionEventAgentImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.taskName, taskName) ||
                other.taskName == taskName));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, type, name, status, taskName);

  /// Create a copy of SessionEventAgent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SessionEventAgentImplCopyWith<_$SessionEventAgentImpl> get copyWith =>
      __$$SessionEventAgentImplCopyWithImpl<_$SessionEventAgentImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SessionEventAgentImplToJson(
      this,
    );
  }
}

abstract class _SessionEventAgent implements SessionEventAgent {
  const factory _SessionEventAgent(
          {required final String id,
          required final String type,
          required final String name,
          required final AgentStatus status,
          @JsonKey(name: 'task-name') final String? taskName}) =
      _$SessionEventAgentImpl;

  factory _SessionEventAgent.fromJson(Map<String, dynamic> json) =
      _$SessionEventAgentImpl.fromJson;

  @override
  String get id;
  @override
  String get type;
  @override
  String get name;
  @override
  AgentStatus get status;
  @override
  @JsonKey(name: 'task-name')
  String? get taskName;

  /// Create a copy of SessionEventAgent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SessionEventAgentImplCopyWith<_$SessionEventAgentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SessionEventMessageData _$SessionEventMessageDataFromJson(
    Map<String, dynamic> json) {
  return _SessionEventMessageData.fromJson(json);
}

/// @nodoc
mixin _$SessionEventMessageData {
  String get role => throw _privateConstructorUsedError;
  String get content => throw _privateConstructorUsedError;

  /// Serializes this SessionEventMessageData to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SessionEventMessageData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SessionEventMessageDataCopyWith<SessionEventMessageData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SessionEventMessageDataCopyWith<$Res> {
  factory $SessionEventMessageDataCopyWith(SessionEventMessageData value,
          $Res Function(SessionEventMessageData) then) =
      _$SessionEventMessageDataCopyWithImpl<$Res, SessionEventMessageData>;
  @useResult
  $Res call({String role, String content});
}

/// @nodoc
class _$SessionEventMessageDataCopyWithImpl<$Res,
        $Val extends SessionEventMessageData>
    implements $SessionEventMessageDataCopyWith<$Res> {
  _$SessionEventMessageDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SessionEventMessageData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? role = null,
    Object? content = null,
  }) {
    return _then(_value.copyWith(
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as String,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SessionEventMessageDataImplCopyWith<$Res>
    implements $SessionEventMessageDataCopyWith<$Res> {
  factory _$$SessionEventMessageDataImplCopyWith(
          _$SessionEventMessageDataImpl value,
          $Res Function(_$SessionEventMessageDataImpl) then) =
      __$$SessionEventMessageDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String role, String content});
}

/// @nodoc
class __$$SessionEventMessageDataImplCopyWithImpl<$Res>
    extends _$SessionEventMessageDataCopyWithImpl<$Res,
        _$SessionEventMessageDataImpl>
    implements _$$SessionEventMessageDataImplCopyWith<$Res> {
  __$$SessionEventMessageDataImplCopyWithImpl(
      _$SessionEventMessageDataImpl _value,
      $Res Function(_$SessionEventMessageDataImpl) _then)
      : super(_value, _then);

  /// Create a copy of SessionEventMessageData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? role = null,
    Object? content = null,
  }) {
    return _then(_$SessionEventMessageDataImpl(
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as String,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SessionEventMessageDataImpl implements _SessionEventMessageData {
  const _$SessionEventMessageDataImpl(
      {required this.role, required this.content});

  factory _$SessionEventMessageDataImpl.fromJson(Map<String, dynamic> json) =>
      _$$SessionEventMessageDataImplFromJson(json);

  @override
  final String role;
  @override
  final String content;

  @override
  String toString() {
    return 'SessionEventMessageData(role: $role, content: $content)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SessionEventMessageDataImpl &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.content, content) || other.content == content));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, role, content);

  /// Create a copy of SessionEventMessageData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SessionEventMessageDataImplCopyWith<_$SessionEventMessageDataImpl>
      get copyWith => __$$SessionEventMessageDataImplCopyWithImpl<
          _$SessionEventMessageDataImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SessionEventMessageDataImplToJson(
      this,
    );
  }
}

abstract class _SessionEventMessageData implements SessionEventMessageData {
  const factory _SessionEventMessageData(
      {required final String role,
      required final String content}) = _$SessionEventMessageDataImpl;

  factory _SessionEventMessageData.fromJson(Map<String, dynamic> json) =
      _$SessionEventMessageDataImpl.fromJson;

  @override
  String get role;
  @override
  String get content;

  /// Create a copy of SessionEventMessageData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SessionEventMessageDataImplCopyWith<_$SessionEventMessageDataImpl>
      get copyWith => throw _privateConstructorUsedError;
}
