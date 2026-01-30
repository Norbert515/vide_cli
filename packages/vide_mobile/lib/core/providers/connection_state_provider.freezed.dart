// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'connection_state_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$WebSocketConnectionState {
  WebSocketConnectionStatus get status => throw _privateConstructorUsedError;
  int get retryCount => throw _privateConstructorUsedError;
  int get maxRetries => throw _privateConstructorUsedError;
  int get lastSeq => throw _privateConstructorUsedError;
  String? get errorMessage => throw _privateConstructorUsedError;
  DateTime? get lastConnectedAt => throw _privateConstructorUsedError;
  DateTime? get lastDisconnectedAt => throw _privateConstructorUsedError;

  /// Create a copy of WebSocketConnectionState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WebSocketConnectionStateCopyWith<WebSocketConnectionState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WebSocketConnectionStateCopyWith<$Res> {
  factory $WebSocketConnectionStateCopyWith(WebSocketConnectionState value,
          $Res Function(WebSocketConnectionState) then) =
      _$WebSocketConnectionStateCopyWithImpl<$Res, WebSocketConnectionState>;
  @useResult
  $Res call(
      {WebSocketConnectionStatus status,
      int retryCount,
      int maxRetries,
      int lastSeq,
      String? errorMessage,
      DateTime? lastConnectedAt,
      DateTime? lastDisconnectedAt});
}

/// @nodoc
class _$WebSocketConnectionStateCopyWithImpl<$Res,
        $Val extends WebSocketConnectionState>
    implements $WebSocketConnectionStateCopyWith<$Res> {
  _$WebSocketConnectionStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WebSocketConnectionState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? retryCount = null,
    Object? maxRetries = null,
    Object? lastSeq = null,
    Object? errorMessage = freezed,
    Object? lastConnectedAt = freezed,
    Object? lastDisconnectedAt = freezed,
  }) {
    return _then(_value.copyWith(
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as WebSocketConnectionStatus,
      retryCount: null == retryCount
          ? _value.retryCount
          : retryCount // ignore: cast_nullable_to_non_nullable
              as int,
      maxRetries: null == maxRetries
          ? _value.maxRetries
          : maxRetries // ignore: cast_nullable_to_non_nullable
              as int,
      lastSeq: null == lastSeq
          ? _value.lastSeq
          : lastSeq // ignore: cast_nullable_to_non_nullable
              as int,
      errorMessage: freezed == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
      lastConnectedAt: freezed == lastConnectedAt
          ? _value.lastConnectedAt
          : lastConnectedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      lastDisconnectedAt: freezed == lastDisconnectedAt
          ? _value.lastDisconnectedAt
          : lastDisconnectedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$WebSocketConnectionStateImplCopyWith<$Res>
    implements $WebSocketConnectionStateCopyWith<$Res> {
  factory _$$WebSocketConnectionStateImplCopyWith(
          _$WebSocketConnectionStateImpl value,
          $Res Function(_$WebSocketConnectionStateImpl) then) =
      __$$WebSocketConnectionStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {WebSocketConnectionStatus status,
      int retryCount,
      int maxRetries,
      int lastSeq,
      String? errorMessage,
      DateTime? lastConnectedAt,
      DateTime? lastDisconnectedAt});
}

/// @nodoc
class __$$WebSocketConnectionStateImplCopyWithImpl<$Res>
    extends _$WebSocketConnectionStateCopyWithImpl<$Res,
        _$WebSocketConnectionStateImpl>
    implements _$$WebSocketConnectionStateImplCopyWith<$Res> {
  __$$WebSocketConnectionStateImplCopyWithImpl(
      _$WebSocketConnectionStateImpl _value,
      $Res Function(_$WebSocketConnectionStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of WebSocketConnectionState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? retryCount = null,
    Object? maxRetries = null,
    Object? lastSeq = null,
    Object? errorMessage = freezed,
    Object? lastConnectedAt = freezed,
    Object? lastDisconnectedAt = freezed,
  }) {
    return _then(_$WebSocketConnectionStateImpl(
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as WebSocketConnectionStatus,
      retryCount: null == retryCount
          ? _value.retryCount
          : retryCount // ignore: cast_nullable_to_non_nullable
              as int,
      maxRetries: null == maxRetries
          ? _value.maxRetries
          : maxRetries // ignore: cast_nullable_to_non_nullable
              as int,
      lastSeq: null == lastSeq
          ? _value.lastSeq
          : lastSeq // ignore: cast_nullable_to_non_nullable
              as int,
      errorMessage: freezed == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
      lastConnectedAt: freezed == lastConnectedAt
          ? _value.lastConnectedAt
          : lastConnectedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      lastDisconnectedAt: freezed == lastDisconnectedAt
          ? _value.lastDisconnectedAt
          : lastDisconnectedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc

class _$WebSocketConnectionStateImpl implements _WebSocketConnectionState {
  const _$WebSocketConnectionStateImpl(
      {this.status = WebSocketConnectionStatus.disconnected,
      this.retryCount = 0,
      this.maxRetries = 5,
      this.lastSeq = 0,
      this.errorMessage,
      this.lastConnectedAt,
      this.lastDisconnectedAt});

  @override
  @JsonKey()
  final WebSocketConnectionStatus status;
  @override
  @JsonKey()
  final int retryCount;
  @override
  @JsonKey()
  final int maxRetries;
  @override
  @JsonKey()
  final int lastSeq;
  @override
  final String? errorMessage;
  @override
  final DateTime? lastConnectedAt;
  @override
  final DateTime? lastDisconnectedAt;

  @override
  String toString() {
    return 'WebSocketConnectionState(status: $status, retryCount: $retryCount, maxRetries: $maxRetries, lastSeq: $lastSeq, errorMessage: $errorMessage, lastConnectedAt: $lastConnectedAt, lastDisconnectedAt: $lastDisconnectedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WebSocketConnectionStateImpl &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.retryCount, retryCount) ||
                other.retryCount == retryCount) &&
            (identical(other.maxRetries, maxRetries) ||
                other.maxRetries == maxRetries) &&
            (identical(other.lastSeq, lastSeq) || other.lastSeq == lastSeq) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage) &&
            (identical(other.lastConnectedAt, lastConnectedAt) ||
                other.lastConnectedAt == lastConnectedAt) &&
            (identical(other.lastDisconnectedAt, lastDisconnectedAt) ||
                other.lastDisconnectedAt == lastDisconnectedAt));
  }

  @override
  int get hashCode => Object.hash(runtimeType, status, retryCount, maxRetries,
      lastSeq, errorMessage, lastConnectedAt, lastDisconnectedAt);

  /// Create a copy of WebSocketConnectionState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WebSocketConnectionStateImplCopyWith<_$WebSocketConnectionStateImpl>
      get copyWith => __$$WebSocketConnectionStateImplCopyWithImpl<
          _$WebSocketConnectionStateImpl>(this, _$identity);
}

abstract class _WebSocketConnectionState implements WebSocketConnectionState {
  const factory _WebSocketConnectionState(
      {final WebSocketConnectionStatus status,
      final int retryCount,
      final int maxRetries,
      final int lastSeq,
      final String? errorMessage,
      final DateTime? lastConnectedAt,
      final DateTime? lastDisconnectedAt}) = _$WebSocketConnectionStateImpl;

  @override
  WebSocketConnectionStatus get status;
  @override
  int get retryCount;
  @override
  int get maxRetries;
  @override
  int get lastSeq;
  @override
  String? get errorMessage;
  @override
  DateTime? get lastConnectedAt;
  @override
  DateTime? get lastDisconnectedAt;

  /// Create a copy of WebSocketConnectionState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WebSocketConnectionStateImplCopyWith<_$WebSocketConnectionStateImpl>
      get copyWith => throw _privateConstructorUsedError;
}
