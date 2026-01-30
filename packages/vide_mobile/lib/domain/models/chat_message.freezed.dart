// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ChatMessage _$ChatMessageFromJson(Map<String, dynamic> json) {
  return _ChatMessage.fromJson(json);
}

/// @nodoc
mixin _$ChatMessage {
  @JsonKey(name: 'event-id')
  String get eventId => throw _privateConstructorUsedError;
  MessageRole get role => throw _privateConstructorUsedError;
  String get content => throw _privateConstructorUsedError;
  @JsonKey(name: 'agent-id')
  String get agentId => throw _privateConstructorUsedError;
  @JsonKey(name: 'agent-type')
  String get agentType => throw _privateConstructorUsedError;
  @JsonKey(name: 'agent-name')
  String? get agentName => throw _privateConstructorUsedError;
  DateTime get timestamp => throw _privateConstructorUsedError;
  @JsonKey(name: 'is-streaming')
  bool get isStreaming => throw _privateConstructorUsedError;

  /// Serializes this ChatMessage to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChatMessageCopyWith<ChatMessage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChatMessageCopyWith<$Res> {
  factory $ChatMessageCopyWith(
          ChatMessage value, $Res Function(ChatMessage) then) =
      _$ChatMessageCopyWithImpl<$Res, ChatMessage>;
  @useResult
  $Res call(
      {@JsonKey(name: 'event-id') String eventId,
      MessageRole role,
      String content,
      @JsonKey(name: 'agent-id') String agentId,
      @JsonKey(name: 'agent-type') String agentType,
      @JsonKey(name: 'agent-name') String? agentName,
      DateTime timestamp,
      @JsonKey(name: 'is-streaming') bool isStreaming});
}

/// @nodoc
class _$ChatMessageCopyWithImpl<$Res, $Val extends ChatMessage>
    implements $ChatMessageCopyWith<$Res> {
  _$ChatMessageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? eventId = null,
    Object? role = null,
    Object? content = null,
    Object? agentId = null,
    Object? agentType = null,
    Object? agentName = freezed,
    Object? timestamp = null,
    Object? isStreaming = null,
  }) {
    return _then(_value.copyWith(
      eventId: null == eventId
          ? _value.eventId
          : eventId // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as MessageRole,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
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
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isStreaming: null == isStreaming
          ? _value.isStreaming
          : isStreaming // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ChatMessageImplCopyWith<$Res>
    implements $ChatMessageCopyWith<$Res> {
  factory _$$ChatMessageImplCopyWith(
          _$ChatMessageImpl value, $Res Function(_$ChatMessageImpl) then) =
      __$$ChatMessageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'event-id') String eventId,
      MessageRole role,
      String content,
      @JsonKey(name: 'agent-id') String agentId,
      @JsonKey(name: 'agent-type') String agentType,
      @JsonKey(name: 'agent-name') String? agentName,
      DateTime timestamp,
      @JsonKey(name: 'is-streaming') bool isStreaming});
}

/// @nodoc
class __$$ChatMessageImplCopyWithImpl<$Res>
    extends _$ChatMessageCopyWithImpl<$Res, _$ChatMessageImpl>
    implements _$$ChatMessageImplCopyWith<$Res> {
  __$$ChatMessageImplCopyWithImpl(
      _$ChatMessageImpl _value, $Res Function(_$ChatMessageImpl) _then)
      : super(_value, _then);

  /// Create a copy of ChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? eventId = null,
    Object? role = null,
    Object? content = null,
    Object? agentId = null,
    Object? agentType = null,
    Object? agentName = freezed,
    Object? timestamp = null,
    Object? isStreaming = null,
  }) {
    return _then(_$ChatMessageImpl(
      eventId: null == eventId
          ? _value.eventId
          : eventId // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as MessageRole,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
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
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isStreaming: null == isStreaming
          ? _value.isStreaming
          : isStreaming // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ChatMessageImpl implements _ChatMessage {
  const _$ChatMessageImpl(
      {@JsonKey(name: 'event-id') required this.eventId,
      required this.role,
      required this.content,
      @JsonKey(name: 'agent-id') required this.agentId,
      @JsonKey(name: 'agent-type') required this.agentType,
      @JsonKey(name: 'agent-name') this.agentName,
      required this.timestamp,
      @JsonKey(name: 'is-streaming') this.isStreaming = false});

  factory _$ChatMessageImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChatMessageImplFromJson(json);

  @override
  @JsonKey(name: 'event-id')
  final String eventId;
  @override
  final MessageRole role;
  @override
  final String content;
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
  final DateTime timestamp;
  @override
  @JsonKey(name: 'is-streaming')
  final bool isStreaming;

  @override
  String toString() {
    return 'ChatMessage(eventId: $eventId, role: $role, content: $content, agentId: $agentId, agentType: $agentType, agentName: $agentName, timestamp: $timestamp, isStreaming: $isStreaming)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChatMessageImpl &&
            (identical(other.eventId, eventId) || other.eventId == eventId) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.agentId, agentId) || other.agentId == agentId) &&
            (identical(other.agentType, agentType) ||
                other.agentType == agentType) &&
            (identical(other.agentName, agentName) ||
                other.agentName == agentName) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.isStreaming, isStreaming) ||
                other.isStreaming == isStreaming));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, eventId, role, content, agentId,
      agentType, agentName, timestamp, isStreaming);

  /// Create a copy of ChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChatMessageImplCopyWith<_$ChatMessageImpl> get copyWith =>
      __$$ChatMessageImplCopyWithImpl<_$ChatMessageImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ChatMessageImplToJson(
      this,
    );
  }
}

abstract class _ChatMessage implements ChatMessage {
  const factory _ChatMessage(
          {@JsonKey(name: 'event-id') required final String eventId,
          required final MessageRole role,
          required final String content,
          @JsonKey(name: 'agent-id') required final String agentId,
          @JsonKey(name: 'agent-type') required final String agentType,
          @JsonKey(name: 'agent-name') final String? agentName,
          required final DateTime timestamp,
          @JsonKey(name: 'is-streaming') final bool isStreaming}) =
      _$ChatMessageImpl;

  factory _ChatMessage.fromJson(Map<String, dynamic> json) =
      _$ChatMessageImpl.fromJson;

  @override
  @JsonKey(name: 'event-id')
  String get eventId;
  @override
  MessageRole get role;
  @override
  String get content;
  @override
  @JsonKey(name: 'agent-id')
  String get agentId;
  @override
  @JsonKey(name: 'agent-type')
  String get agentType;
  @override
  @JsonKey(name: 'agent-name')
  String? get agentName;
  @override
  DateTime get timestamp;
  @override
  @JsonKey(name: 'is-streaming')
  bool get isStreaming;

  /// Create a copy of ChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChatMessageImplCopyWith<_$ChatMessageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
