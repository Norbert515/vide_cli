// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Session _$SessionFromJson(Map<String, dynamic> json) {
  return _Session.fromJson(json);
}

/// @nodoc
mixin _$Session {
  @JsonKey(name: 'session-id')
  String get sessionId => throw _privateConstructorUsedError;
  @JsonKey(name: 'main-agent-id')
  String get mainAgentId => throw _privateConstructorUsedError;
  @JsonKey(name: 'created-at')
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'working-directory')
  String get workingDirectory => throw _privateConstructorUsedError;
  String? get model => throw _privateConstructorUsedError;

  /// Serializes this Session to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Session
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SessionCopyWith<Session> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SessionCopyWith<$Res> {
  factory $SessionCopyWith(Session value, $Res Function(Session) then) =
      _$SessionCopyWithImpl<$Res, Session>;
  @useResult
  $Res call(
      {@JsonKey(name: 'session-id') String sessionId,
      @JsonKey(name: 'main-agent-id') String mainAgentId,
      @JsonKey(name: 'created-at') DateTime createdAt,
      @JsonKey(name: 'working-directory') String workingDirectory,
      String? model});
}

/// @nodoc
class _$SessionCopyWithImpl<$Res, $Val extends Session>
    implements $SessionCopyWith<$Res> {
  _$SessionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Session
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sessionId = null,
    Object? mainAgentId = null,
    Object? createdAt = null,
    Object? workingDirectory = null,
    Object? model = freezed,
  }) {
    return _then(_value.copyWith(
      sessionId: null == sessionId
          ? _value.sessionId
          : sessionId // ignore: cast_nullable_to_non_nullable
              as String,
      mainAgentId: null == mainAgentId
          ? _value.mainAgentId
          : mainAgentId // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      workingDirectory: null == workingDirectory
          ? _value.workingDirectory
          : workingDirectory // ignore: cast_nullable_to_non_nullable
              as String,
      model: freezed == model
          ? _value.model
          : model // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SessionImplCopyWith<$Res> implements $SessionCopyWith<$Res> {
  factory _$$SessionImplCopyWith(
          _$SessionImpl value, $Res Function(_$SessionImpl) then) =
      __$$SessionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'session-id') String sessionId,
      @JsonKey(name: 'main-agent-id') String mainAgentId,
      @JsonKey(name: 'created-at') DateTime createdAt,
      @JsonKey(name: 'working-directory') String workingDirectory,
      String? model});
}

/// @nodoc
class __$$SessionImplCopyWithImpl<$Res>
    extends _$SessionCopyWithImpl<$Res, _$SessionImpl>
    implements _$$SessionImplCopyWith<$Res> {
  __$$SessionImplCopyWithImpl(
      _$SessionImpl _value, $Res Function(_$SessionImpl) _then)
      : super(_value, _then);

  /// Create a copy of Session
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sessionId = null,
    Object? mainAgentId = null,
    Object? createdAt = null,
    Object? workingDirectory = null,
    Object? model = freezed,
  }) {
    return _then(_$SessionImpl(
      sessionId: null == sessionId
          ? _value.sessionId
          : sessionId // ignore: cast_nullable_to_non_nullable
              as String,
      mainAgentId: null == mainAgentId
          ? _value.mainAgentId
          : mainAgentId // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      workingDirectory: null == workingDirectory
          ? _value.workingDirectory
          : workingDirectory // ignore: cast_nullable_to_non_nullable
              as String,
      model: freezed == model
          ? _value.model
          : model // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SessionImpl implements _Session {
  const _$SessionImpl(
      {@JsonKey(name: 'session-id') required this.sessionId,
      @JsonKey(name: 'main-agent-id') required this.mainAgentId,
      @JsonKey(name: 'created-at') required this.createdAt,
      @JsonKey(name: 'working-directory') required this.workingDirectory,
      this.model});

  factory _$SessionImpl.fromJson(Map<String, dynamic> json) =>
      _$$SessionImplFromJson(json);

  @override
  @JsonKey(name: 'session-id')
  final String sessionId;
  @override
  @JsonKey(name: 'main-agent-id')
  final String mainAgentId;
  @override
  @JsonKey(name: 'created-at')
  final DateTime createdAt;
  @override
  @JsonKey(name: 'working-directory')
  final String workingDirectory;
  @override
  final String? model;

  @override
  String toString() {
    return 'Session(sessionId: $sessionId, mainAgentId: $mainAgentId, createdAt: $createdAt, workingDirectory: $workingDirectory, model: $model)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SessionImpl &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.mainAgentId, mainAgentId) ||
                other.mainAgentId == mainAgentId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.workingDirectory, workingDirectory) ||
                other.workingDirectory == workingDirectory) &&
            (identical(other.model, model) || other.model == model));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, sessionId, mainAgentId, createdAt, workingDirectory, model);

  /// Create a copy of Session
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SessionImplCopyWith<_$SessionImpl> get copyWith =>
      __$$SessionImplCopyWithImpl<_$SessionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SessionImplToJson(
      this,
    );
  }
}

abstract class _Session implements Session {
  const factory _Session(
      {@JsonKey(name: 'session-id') required final String sessionId,
      @JsonKey(name: 'main-agent-id') required final String mainAgentId,
      @JsonKey(name: 'created-at') required final DateTime createdAt,
      @JsonKey(name: 'working-directory')
      required final String workingDirectory,
      final String? model}) = _$SessionImpl;

  factory _Session.fromJson(Map<String, dynamic> json) = _$SessionImpl.fromJson;

  @override
  @JsonKey(name: 'session-id')
  String get sessionId;
  @override
  @JsonKey(name: 'main-agent-id')
  String get mainAgentId;
  @override
  @JsonKey(name: 'created-at')
  DateTime get createdAt;
  @override
  @JsonKey(name: 'working-directory')
  String get workingDirectory;
  @override
  String? get model;

  /// Create a copy of Session
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SessionImplCopyWith<_$SessionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
