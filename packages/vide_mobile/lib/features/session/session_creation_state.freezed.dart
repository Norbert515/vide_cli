// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_creation_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$SessionCreationState {
  String get initialMessage => throw _privateConstructorUsedError;
  String get workingDirectory => throw _privateConstructorUsedError;
  String get team => throw _privateConstructorUsedError;
  PermissionMode get permissionMode => throw _privateConstructorUsedError;
  bool get isCreating => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;

  /// Create a copy of SessionCreationState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SessionCreationStateCopyWith<SessionCreationState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SessionCreationStateCopyWith<$Res> {
  factory $SessionCreationStateCopyWith(SessionCreationState value,
          $Res Function(SessionCreationState) then) =
      _$SessionCreationStateCopyWithImpl<$Res, SessionCreationState>;
  @useResult
  $Res call(
      {String initialMessage,
      String workingDirectory,
      String team,
      PermissionMode permissionMode,
      bool isCreating,
      String? error});
}

/// @nodoc
class _$SessionCreationStateCopyWithImpl<$Res,
        $Val extends SessionCreationState>
    implements $SessionCreationStateCopyWith<$Res> {
  _$SessionCreationStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SessionCreationState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? initialMessage = null,
    Object? workingDirectory = null,
    Object? team = null,
    Object? permissionMode = null,
    Object? isCreating = null,
    Object? error = freezed,
  }) {
    return _then(_value.copyWith(
      initialMessage: null == initialMessage
          ? _value.initialMessage
          : initialMessage // ignore: cast_nullable_to_non_nullable
              as String,
      workingDirectory: null == workingDirectory
          ? _value.workingDirectory
          : workingDirectory // ignore: cast_nullable_to_non_nullable
              as String,
      team: null == team
          ? _value.team
          : team // ignore: cast_nullable_to_non_nullable
              as String,
      permissionMode: null == permissionMode
          ? _value.permissionMode
          : permissionMode // ignore: cast_nullable_to_non_nullable
              as PermissionMode,
      isCreating: null == isCreating
          ? _value.isCreating
          : isCreating // ignore: cast_nullable_to_non_nullable
              as bool,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SessionCreationStateImplCopyWith<$Res>
    implements $SessionCreationStateCopyWith<$Res> {
  factory _$$SessionCreationStateImplCopyWith(_$SessionCreationStateImpl value,
          $Res Function(_$SessionCreationStateImpl) then) =
      __$$SessionCreationStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String initialMessage,
      String workingDirectory,
      String team,
      PermissionMode permissionMode,
      bool isCreating,
      String? error});
}

/// @nodoc
class __$$SessionCreationStateImplCopyWithImpl<$Res>
    extends _$SessionCreationStateCopyWithImpl<$Res, _$SessionCreationStateImpl>
    implements _$$SessionCreationStateImplCopyWith<$Res> {
  __$$SessionCreationStateImplCopyWithImpl(_$SessionCreationStateImpl _value,
      $Res Function(_$SessionCreationStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of SessionCreationState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? initialMessage = null,
    Object? workingDirectory = null,
    Object? team = null,
    Object? permissionMode = null,
    Object? isCreating = null,
    Object? error = freezed,
  }) {
    return _then(_$SessionCreationStateImpl(
      initialMessage: null == initialMessage
          ? _value.initialMessage
          : initialMessage // ignore: cast_nullable_to_non_nullable
              as String,
      workingDirectory: null == workingDirectory
          ? _value.workingDirectory
          : workingDirectory // ignore: cast_nullable_to_non_nullable
              as String,
      team: null == team
          ? _value.team
          : team // ignore: cast_nullable_to_non_nullable
              as String,
      permissionMode: null == permissionMode
          ? _value.permissionMode
          : permissionMode // ignore: cast_nullable_to_non_nullable
              as PermissionMode,
      isCreating: null == isCreating
          ? _value.isCreating
          : isCreating // ignore: cast_nullable_to_non_nullable
              as bool,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$SessionCreationStateImpl implements _SessionCreationState {
  const _$SessionCreationStateImpl(
      {this.initialMessage = '',
      this.workingDirectory = '',
      this.team = 'vide',
      this.permissionMode = PermissionMode.defaultMode,
      this.isCreating = false,
      this.error});

  @override
  @JsonKey()
  final String initialMessage;
  @override
  @JsonKey()
  final String workingDirectory;
  @override
  @JsonKey()
  final String team;
  @override
  @JsonKey()
  final PermissionMode permissionMode;
  @override
  @JsonKey()
  final bool isCreating;
  @override
  final String? error;

  @override
  String toString() {
    return 'SessionCreationState(initialMessage: $initialMessage, workingDirectory: $workingDirectory, team: $team, permissionMode: $permissionMode, isCreating: $isCreating, error: $error)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SessionCreationStateImpl &&
            (identical(other.initialMessage, initialMessage) ||
                other.initialMessage == initialMessage) &&
            (identical(other.workingDirectory, workingDirectory) ||
                other.workingDirectory == workingDirectory) &&
            (identical(other.team, team) || other.team == team) &&
            (identical(other.permissionMode, permissionMode) ||
                other.permissionMode == permissionMode) &&
            (identical(other.isCreating, isCreating) ||
                other.isCreating == isCreating) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(runtimeType, initialMessage, workingDirectory,
      team, permissionMode, isCreating, error);

  /// Create a copy of SessionCreationState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SessionCreationStateImplCopyWith<_$SessionCreationStateImpl>
      get copyWith =>
          __$$SessionCreationStateImplCopyWithImpl<_$SessionCreationStateImpl>(
              this, _$identity);
}

abstract class _SessionCreationState implements SessionCreationState {
  const factory _SessionCreationState(
      {final String initialMessage,
      final String workingDirectory,
      final String team,
      final PermissionMode permissionMode,
      final bool isCreating,
      final String? error}) = _$SessionCreationStateImpl;

  @override
  String get initialMessage;
  @override
  String get workingDirectory;
  @override
  String get team;
  @override
  PermissionMode get permissionMode;
  @override
  bool get isCreating;
  @override
  String? get error;

  /// Create a copy of SessionCreationState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SessionCreationStateImplCopyWith<_$SessionCreationStateImpl>
      get copyWith => throw _privateConstructorUsedError;
}
