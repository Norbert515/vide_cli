// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'permission_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

PermissionRequest _$PermissionRequestFromJson(Map<String, dynamic> json) {
  return _PermissionRequest.fromJson(json);
}

/// @nodoc
mixin _$PermissionRequest {
  @JsonKey(name: 'request-id')
  String get requestId => throw _privateConstructorUsedError;
  @JsonKey(name: 'tool-name')
  String get toolName => throw _privateConstructorUsedError;
  @JsonKey(name: 'tool-input')
  Map<String, dynamic> get toolInput => throw _privateConstructorUsedError;
  @JsonKey(name: 'agent-id')
  String get agentId => throw _privateConstructorUsedError;
  @JsonKey(name: 'agent-name')
  String? get agentName => throw _privateConstructorUsedError;
  @JsonKey(name: 'permission-suggestions')
  List<String>? get permissionSuggestions => throw _privateConstructorUsedError;
  DateTime get timestamp => throw _privateConstructorUsedError;

  /// Serializes this PermissionRequest to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PermissionRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PermissionRequestCopyWith<PermissionRequest> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PermissionRequestCopyWith<$Res> {
  factory $PermissionRequestCopyWith(
          PermissionRequest value, $Res Function(PermissionRequest) then) =
      _$PermissionRequestCopyWithImpl<$Res, PermissionRequest>;
  @useResult
  $Res call(
      {@JsonKey(name: 'request-id') String requestId,
      @JsonKey(name: 'tool-name') String toolName,
      @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
      @JsonKey(name: 'agent-id') String agentId,
      @JsonKey(name: 'agent-name') String? agentName,
      @JsonKey(name: 'permission-suggestions')
      List<String>? permissionSuggestions,
      DateTime timestamp});
}

/// @nodoc
class _$PermissionRequestCopyWithImpl<$Res, $Val extends PermissionRequest>
    implements $PermissionRequestCopyWith<$Res> {
  _$PermissionRequestCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PermissionRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? requestId = null,
    Object? toolName = null,
    Object? toolInput = null,
    Object? agentId = null,
    Object? agentName = freezed,
    Object? permissionSuggestions = freezed,
    Object? timestamp = null,
  }) {
    return _then(_value.copyWith(
      requestId: null == requestId
          ? _value.requestId
          : requestId // ignore: cast_nullable_to_non_nullable
              as String,
      toolName: null == toolName
          ? _value.toolName
          : toolName // ignore: cast_nullable_to_non_nullable
              as String,
      toolInput: null == toolInput
          ? _value.toolInput
          : toolInput // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      agentId: null == agentId
          ? _value.agentId
          : agentId // ignore: cast_nullable_to_non_nullable
              as String,
      agentName: freezed == agentName
          ? _value.agentName
          : agentName // ignore: cast_nullable_to_non_nullable
              as String?,
      permissionSuggestions: freezed == permissionSuggestions
          ? _value.permissionSuggestions
          : permissionSuggestions // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PermissionRequestImplCopyWith<$Res>
    implements $PermissionRequestCopyWith<$Res> {
  factory _$$PermissionRequestImplCopyWith(_$PermissionRequestImpl value,
          $Res Function(_$PermissionRequestImpl) then) =
      __$$PermissionRequestImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'request-id') String requestId,
      @JsonKey(name: 'tool-name') String toolName,
      @JsonKey(name: 'tool-input') Map<String, dynamic> toolInput,
      @JsonKey(name: 'agent-id') String agentId,
      @JsonKey(name: 'agent-name') String? agentName,
      @JsonKey(name: 'permission-suggestions')
      List<String>? permissionSuggestions,
      DateTime timestamp});
}

/// @nodoc
class __$$PermissionRequestImplCopyWithImpl<$Res>
    extends _$PermissionRequestCopyWithImpl<$Res, _$PermissionRequestImpl>
    implements _$$PermissionRequestImplCopyWith<$Res> {
  __$$PermissionRequestImplCopyWithImpl(_$PermissionRequestImpl _value,
      $Res Function(_$PermissionRequestImpl) _then)
      : super(_value, _then);

  /// Create a copy of PermissionRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? requestId = null,
    Object? toolName = null,
    Object? toolInput = null,
    Object? agentId = null,
    Object? agentName = freezed,
    Object? permissionSuggestions = freezed,
    Object? timestamp = null,
  }) {
    return _then(_$PermissionRequestImpl(
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
      agentId: null == agentId
          ? _value.agentId
          : agentId // ignore: cast_nullable_to_non_nullable
              as String,
      agentName: freezed == agentName
          ? _value.agentName
          : agentName // ignore: cast_nullable_to_non_nullable
              as String?,
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
class _$PermissionRequestImpl implements _PermissionRequest {
  const _$PermissionRequestImpl(
      {@JsonKey(name: 'request-id') required this.requestId,
      @JsonKey(name: 'tool-name') required this.toolName,
      @JsonKey(name: 'tool-input')
      required final Map<String, dynamic> toolInput,
      @JsonKey(name: 'agent-id') required this.agentId,
      @JsonKey(name: 'agent-name') this.agentName,
      @JsonKey(name: 'permission-suggestions')
      final List<String>? permissionSuggestions,
      required this.timestamp})
      : _toolInput = toolInput,
        _permissionSuggestions = permissionSuggestions;

  factory _$PermissionRequestImpl.fromJson(Map<String, dynamic> json) =>
      _$$PermissionRequestImplFromJson(json);

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

  @override
  @JsonKey(name: 'agent-id')
  final String agentId;
  @override
  @JsonKey(name: 'agent-name')
  final String? agentName;
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

  @override
  String toString() {
    return 'PermissionRequest(requestId: $requestId, toolName: $toolName, toolInput: $toolInput, agentId: $agentId, agentName: $agentName, permissionSuggestions: $permissionSuggestions, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PermissionRequestImpl &&
            (identical(other.requestId, requestId) ||
                other.requestId == requestId) &&
            (identical(other.toolName, toolName) ||
                other.toolName == toolName) &&
            const DeepCollectionEquality()
                .equals(other._toolInput, _toolInput) &&
            (identical(other.agentId, agentId) || other.agentId == agentId) &&
            (identical(other.agentName, agentName) ||
                other.agentName == agentName) &&
            const DeepCollectionEquality()
                .equals(other._permissionSuggestions, _permissionSuggestions) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      requestId,
      toolName,
      const DeepCollectionEquality().hash(_toolInput),
      agentId,
      agentName,
      const DeepCollectionEquality().hash(_permissionSuggestions),
      timestamp);

  /// Create a copy of PermissionRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PermissionRequestImplCopyWith<_$PermissionRequestImpl> get copyWith =>
      __$$PermissionRequestImplCopyWithImpl<_$PermissionRequestImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PermissionRequestImplToJson(
      this,
    );
  }
}

abstract class _PermissionRequest implements PermissionRequest {
  const factory _PermissionRequest(
      {@JsonKey(name: 'request-id') required final String requestId,
      @JsonKey(name: 'tool-name') required final String toolName,
      @JsonKey(name: 'tool-input')
      required final Map<String, dynamic> toolInput,
      @JsonKey(name: 'agent-id') required final String agentId,
      @JsonKey(name: 'agent-name') final String? agentName,
      @JsonKey(name: 'permission-suggestions')
      final List<String>? permissionSuggestions,
      required final DateTime timestamp}) = _$PermissionRequestImpl;

  factory _PermissionRequest.fromJson(Map<String, dynamic> json) =
      _$PermissionRequestImpl.fromJson;

  @override
  @JsonKey(name: 'request-id')
  String get requestId;
  @override
  @JsonKey(name: 'tool-name')
  String get toolName;
  @override
  @JsonKey(name: 'tool-input')
  Map<String, dynamic> get toolInput;
  @override
  @JsonKey(name: 'agent-id')
  String get agentId;
  @override
  @JsonKey(name: 'agent-name')
  String? get agentName;
  @override
  @JsonKey(name: 'permission-suggestions')
  List<String>? get permissionSuggestions;
  @override
  DateTime get timestamp;

  /// Create a copy of PermissionRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PermissionRequestImplCopyWith<_$PermissionRequestImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
