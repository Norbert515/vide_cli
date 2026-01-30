// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tool_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ToolUse _$ToolUseFromJson(Map<String, dynamic> json) {
  return _ToolUse.fromJson(json);
}

/// @nodoc
mixin _$ToolUse {
  @JsonKey(name: 'tool-use-id')
  String get toolUseId => throw _privateConstructorUsedError;
  @JsonKey(name: 'tool-name')
  String get toolName => throw _privateConstructorUsedError;
  Map<String, dynamic> get input => throw _privateConstructorUsedError;
  @JsonKey(name: 'agent-id')
  String get agentId => throw _privateConstructorUsedError;
  @JsonKey(name: 'agent-name')
  String? get agentName => throw _privateConstructorUsedError;
  DateTime get timestamp => throw _privateConstructorUsedError;

  /// Serializes this ToolUse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ToolUse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ToolUseCopyWith<ToolUse> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ToolUseCopyWith<$Res> {
  factory $ToolUseCopyWith(ToolUse value, $Res Function(ToolUse) then) =
      _$ToolUseCopyWithImpl<$Res, ToolUse>;
  @useResult
  $Res call(
      {@JsonKey(name: 'tool-use-id') String toolUseId,
      @JsonKey(name: 'tool-name') String toolName,
      Map<String, dynamic> input,
      @JsonKey(name: 'agent-id') String agentId,
      @JsonKey(name: 'agent-name') String? agentName,
      DateTime timestamp});
}

/// @nodoc
class _$ToolUseCopyWithImpl<$Res, $Val extends ToolUse>
    implements $ToolUseCopyWith<$Res> {
  _$ToolUseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ToolUse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? toolUseId = null,
    Object? toolName = null,
    Object? input = null,
    Object? agentId = null,
    Object? agentName = freezed,
    Object? timestamp = null,
  }) {
    return _then(_value.copyWith(
      toolUseId: null == toolUseId
          ? _value.toolUseId
          : toolUseId // ignore: cast_nullable_to_non_nullable
              as String,
      toolName: null == toolName
          ? _value.toolName
          : toolName // ignore: cast_nullable_to_non_nullable
              as String,
      input: null == input
          ? _value.input
          : input // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      agentId: null == agentId
          ? _value.agentId
          : agentId // ignore: cast_nullable_to_non_nullable
              as String,
      agentName: freezed == agentName
          ? _value.agentName
          : agentName // ignore: cast_nullable_to_non_nullable
              as String?,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ToolUseImplCopyWith<$Res> implements $ToolUseCopyWith<$Res> {
  factory _$$ToolUseImplCopyWith(
          _$ToolUseImpl value, $Res Function(_$ToolUseImpl) then) =
      __$$ToolUseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'tool-use-id') String toolUseId,
      @JsonKey(name: 'tool-name') String toolName,
      Map<String, dynamic> input,
      @JsonKey(name: 'agent-id') String agentId,
      @JsonKey(name: 'agent-name') String? agentName,
      DateTime timestamp});
}

/// @nodoc
class __$$ToolUseImplCopyWithImpl<$Res>
    extends _$ToolUseCopyWithImpl<$Res, _$ToolUseImpl>
    implements _$$ToolUseImplCopyWith<$Res> {
  __$$ToolUseImplCopyWithImpl(
      _$ToolUseImpl _value, $Res Function(_$ToolUseImpl) _then)
      : super(_value, _then);

  /// Create a copy of ToolUse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? toolUseId = null,
    Object? toolName = null,
    Object? input = null,
    Object? agentId = null,
    Object? agentName = freezed,
    Object? timestamp = null,
  }) {
    return _then(_$ToolUseImpl(
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
      agentId: null == agentId
          ? _value.agentId
          : agentId // ignore: cast_nullable_to_non_nullable
              as String,
      agentName: freezed == agentName
          ? _value.agentName
          : agentName // ignore: cast_nullable_to_non_nullable
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
class _$ToolUseImpl implements _ToolUse {
  const _$ToolUseImpl(
      {@JsonKey(name: 'tool-use-id') required this.toolUseId,
      @JsonKey(name: 'tool-name') required this.toolName,
      required final Map<String, dynamic> input,
      @JsonKey(name: 'agent-id') required this.agentId,
      @JsonKey(name: 'agent-name') this.agentName,
      required this.timestamp})
      : _input = input;

  factory _$ToolUseImpl.fromJson(Map<String, dynamic> json) =>
      _$$ToolUseImplFromJson(json);

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
  @JsonKey(name: 'agent-id')
  final String agentId;
  @override
  @JsonKey(name: 'agent-name')
  final String? agentName;
  @override
  final DateTime timestamp;

  @override
  String toString() {
    return 'ToolUse(toolUseId: $toolUseId, toolName: $toolName, input: $input, agentId: $agentId, agentName: $agentName, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ToolUseImpl &&
            (identical(other.toolUseId, toolUseId) ||
                other.toolUseId == toolUseId) &&
            (identical(other.toolName, toolName) ||
                other.toolName == toolName) &&
            const DeepCollectionEquality().equals(other._input, _input) &&
            (identical(other.agentId, agentId) || other.agentId == agentId) &&
            (identical(other.agentName, agentName) ||
                other.agentName == agentName) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      toolUseId,
      toolName,
      const DeepCollectionEquality().hash(_input),
      agentId,
      agentName,
      timestamp);

  /// Create a copy of ToolUse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ToolUseImplCopyWith<_$ToolUseImpl> get copyWith =>
      __$$ToolUseImplCopyWithImpl<_$ToolUseImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ToolUseImplToJson(
      this,
    );
  }
}

abstract class _ToolUse implements ToolUse {
  const factory _ToolUse(
      {@JsonKey(name: 'tool-use-id') required final String toolUseId,
      @JsonKey(name: 'tool-name') required final String toolName,
      required final Map<String, dynamic> input,
      @JsonKey(name: 'agent-id') required final String agentId,
      @JsonKey(name: 'agent-name') final String? agentName,
      required final DateTime timestamp}) = _$ToolUseImpl;

  factory _ToolUse.fromJson(Map<String, dynamic> json) = _$ToolUseImpl.fromJson;

  @override
  @JsonKey(name: 'tool-use-id')
  String get toolUseId;
  @override
  @JsonKey(name: 'tool-name')
  String get toolName;
  @override
  Map<String, dynamic> get input;
  @override
  @JsonKey(name: 'agent-id')
  String get agentId;
  @override
  @JsonKey(name: 'agent-name')
  String? get agentName;
  @override
  DateTime get timestamp;

  /// Create a copy of ToolUse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ToolUseImplCopyWith<_$ToolUseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ToolResult _$ToolResultFromJson(Map<String, dynamic> json) {
  return _ToolResult.fromJson(json);
}

/// @nodoc
mixin _$ToolResult {
  @JsonKey(name: 'tool-use-id')
  String get toolUseId => throw _privateConstructorUsedError;
  @JsonKey(name: 'tool-name')
  String get toolName => throw _privateConstructorUsedError;
  dynamic get result => throw _privateConstructorUsedError;
  @JsonKey(name: 'is-error')
  bool get isError => throw _privateConstructorUsedError;
  DateTime get timestamp => throw _privateConstructorUsedError;

  /// Serializes this ToolResult to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ToolResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ToolResultCopyWith<ToolResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ToolResultCopyWith<$Res> {
  factory $ToolResultCopyWith(
          ToolResult value, $Res Function(ToolResult) then) =
      _$ToolResultCopyWithImpl<$Res, ToolResult>;
  @useResult
  $Res call(
      {@JsonKey(name: 'tool-use-id') String toolUseId,
      @JsonKey(name: 'tool-name') String toolName,
      dynamic result,
      @JsonKey(name: 'is-error') bool isError,
      DateTime timestamp});
}

/// @nodoc
class _$ToolResultCopyWithImpl<$Res, $Val extends ToolResult>
    implements $ToolResultCopyWith<$Res> {
  _$ToolResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ToolResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? toolUseId = null,
    Object? toolName = null,
    Object? result = freezed,
    Object? isError = null,
    Object? timestamp = null,
  }) {
    return _then(_value.copyWith(
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
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ToolResultImplCopyWith<$Res>
    implements $ToolResultCopyWith<$Res> {
  factory _$$ToolResultImplCopyWith(
          _$ToolResultImpl value, $Res Function(_$ToolResultImpl) then) =
      __$$ToolResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'tool-use-id') String toolUseId,
      @JsonKey(name: 'tool-name') String toolName,
      dynamic result,
      @JsonKey(name: 'is-error') bool isError,
      DateTime timestamp});
}

/// @nodoc
class __$$ToolResultImplCopyWithImpl<$Res>
    extends _$ToolResultCopyWithImpl<$Res, _$ToolResultImpl>
    implements _$$ToolResultImplCopyWith<$Res> {
  __$$ToolResultImplCopyWithImpl(
      _$ToolResultImpl _value, $Res Function(_$ToolResultImpl) _then)
      : super(_value, _then);

  /// Create a copy of ToolResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? toolUseId = null,
    Object? toolName = null,
    Object? result = freezed,
    Object? isError = null,
    Object? timestamp = null,
  }) {
    return _then(_$ToolResultImpl(
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
class _$ToolResultImpl implements _ToolResult {
  const _$ToolResultImpl(
      {@JsonKey(name: 'tool-use-id') required this.toolUseId,
      @JsonKey(name: 'tool-name') required this.toolName,
      required this.result,
      @JsonKey(name: 'is-error') required this.isError,
      required this.timestamp});

  factory _$ToolResultImpl.fromJson(Map<String, dynamic> json) =>
      _$$ToolResultImplFromJson(json);

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

  @override
  String toString() {
    return 'ToolResult(toolUseId: $toolUseId, toolName: $toolName, result: $result, isError: $isError, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ToolResultImpl &&
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
  int get hashCode => Object.hash(runtimeType, toolUseId, toolName,
      const DeepCollectionEquality().hash(result), isError, timestamp);

  /// Create a copy of ToolResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ToolResultImplCopyWith<_$ToolResultImpl> get copyWith =>
      __$$ToolResultImplCopyWithImpl<_$ToolResultImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ToolResultImplToJson(
      this,
    );
  }
}

abstract class _ToolResult implements ToolResult {
  const factory _ToolResult(
      {@JsonKey(name: 'tool-use-id') required final String toolUseId,
      @JsonKey(name: 'tool-name') required final String toolName,
      required final dynamic result,
      @JsonKey(name: 'is-error') required final bool isError,
      required final DateTime timestamp}) = _$ToolResultImpl;

  factory _ToolResult.fromJson(Map<String, dynamic> json) =
      _$ToolResultImpl.fromJson;

  @override
  @JsonKey(name: 'tool-use-id')
  String get toolUseId;
  @override
  @JsonKey(name: 'tool-name')
  String get toolName;
  @override
  dynamic get result;
  @override
  @JsonKey(name: 'is-error')
  bool get isError;
  @override
  DateTime get timestamp;

  /// Create a copy of ToolResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ToolResultImplCopyWith<_$ToolResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
