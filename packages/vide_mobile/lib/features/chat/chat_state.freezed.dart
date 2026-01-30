// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$ChatState {
  List<ChatMessage> get messages => throw _privateConstructorUsedError;
  List<ToolUse> get toolUses => throw _privateConstructorUsedError;
  Map<String, ToolResult> get toolResults => throw _privateConstructorUsedError;
  List<Agent> get agents => throw _privateConstructorUsedError;
  PermissionRequest? get pendingPermission =>
      throw _privateConstructorUsedError;
  bool get isLoading => throw _privateConstructorUsedError;
  bool get isAgentWorking => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;

  /// Create a copy of ChatState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChatStateCopyWith<ChatState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChatStateCopyWith<$Res> {
  factory $ChatStateCopyWith(ChatState value, $Res Function(ChatState) then) =
      _$ChatStateCopyWithImpl<$Res, ChatState>;
  @useResult
  $Res call(
      {List<ChatMessage> messages,
      List<ToolUse> toolUses,
      Map<String, ToolResult> toolResults,
      List<Agent> agents,
      PermissionRequest? pendingPermission,
      bool isLoading,
      bool isAgentWorking,
      String? error});

  $PermissionRequestCopyWith<$Res>? get pendingPermission;
}

/// @nodoc
class _$ChatStateCopyWithImpl<$Res, $Val extends ChatState>
    implements $ChatStateCopyWith<$Res> {
  _$ChatStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChatState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? messages = null,
    Object? toolUses = null,
    Object? toolResults = null,
    Object? agents = null,
    Object? pendingPermission = freezed,
    Object? isLoading = null,
    Object? isAgentWorking = null,
    Object? error = freezed,
  }) {
    return _then(_value.copyWith(
      messages: null == messages
          ? _value.messages
          : messages // ignore: cast_nullable_to_non_nullable
              as List<ChatMessage>,
      toolUses: null == toolUses
          ? _value.toolUses
          : toolUses // ignore: cast_nullable_to_non_nullable
              as List<ToolUse>,
      toolResults: null == toolResults
          ? _value.toolResults
          : toolResults // ignore: cast_nullable_to_non_nullable
              as Map<String, ToolResult>,
      agents: null == agents
          ? _value.agents
          : agents // ignore: cast_nullable_to_non_nullable
              as List<Agent>,
      pendingPermission: freezed == pendingPermission
          ? _value.pendingPermission
          : pendingPermission // ignore: cast_nullable_to_non_nullable
              as PermissionRequest?,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      isAgentWorking: null == isAgentWorking
          ? _value.isAgentWorking
          : isAgentWorking // ignore: cast_nullable_to_non_nullable
              as bool,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }

  /// Create a copy of ChatState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PermissionRequestCopyWith<$Res>? get pendingPermission {
    if (_value.pendingPermission == null) {
      return null;
    }

    return $PermissionRequestCopyWith<$Res>(_value.pendingPermission!, (value) {
      return _then(_value.copyWith(pendingPermission: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ChatStateImplCopyWith<$Res>
    implements $ChatStateCopyWith<$Res> {
  factory _$$ChatStateImplCopyWith(
          _$ChatStateImpl value, $Res Function(_$ChatStateImpl) then) =
      __$$ChatStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {List<ChatMessage> messages,
      List<ToolUse> toolUses,
      Map<String, ToolResult> toolResults,
      List<Agent> agents,
      PermissionRequest? pendingPermission,
      bool isLoading,
      bool isAgentWorking,
      String? error});

  @override
  $PermissionRequestCopyWith<$Res>? get pendingPermission;
}

/// @nodoc
class __$$ChatStateImplCopyWithImpl<$Res>
    extends _$ChatStateCopyWithImpl<$Res, _$ChatStateImpl>
    implements _$$ChatStateImplCopyWith<$Res> {
  __$$ChatStateImplCopyWithImpl(
      _$ChatStateImpl _value, $Res Function(_$ChatStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of ChatState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? messages = null,
    Object? toolUses = null,
    Object? toolResults = null,
    Object? agents = null,
    Object? pendingPermission = freezed,
    Object? isLoading = null,
    Object? isAgentWorking = null,
    Object? error = freezed,
  }) {
    return _then(_$ChatStateImpl(
      messages: null == messages
          ? _value._messages
          : messages // ignore: cast_nullable_to_non_nullable
              as List<ChatMessage>,
      toolUses: null == toolUses
          ? _value._toolUses
          : toolUses // ignore: cast_nullable_to_non_nullable
              as List<ToolUse>,
      toolResults: null == toolResults
          ? _value._toolResults
          : toolResults // ignore: cast_nullable_to_non_nullable
              as Map<String, ToolResult>,
      agents: null == agents
          ? _value._agents
          : agents // ignore: cast_nullable_to_non_nullable
              as List<Agent>,
      pendingPermission: freezed == pendingPermission
          ? _value.pendingPermission
          : pendingPermission // ignore: cast_nullable_to_non_nullable
              as PermissionRequest?,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      isAgentWorking: null == isAgentWorking
          ? _value.isAgentWorking
          : isAgentWorking // ignore: cast_nullable_to_non_nullable
              as bool,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$ChatStateImpl implements _ChatState {
  const _$ChatStateImpl(
      {final List<ChatMessage> messages = const [],
      final List<ToolUse> toolUses = const [],
      final Map<String, ToolResult> toolResults = const {},
      final List<Agent> agents = const [],
      this.pendingPermission,
      this.isLoading = false,
      this.isAgentWorking = false,
      this.error})
      : _messages = messages,
        _toolUses = toolUses,
        _toolResults = toolResults,
        _agents = agents;

  final List<ChatMessage> _messages;
  @override
  @JsonKey()
  List<ChatMessage> get messages {
    if (_messages is EqualUnmodifiableListView) return _messages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_messages);
  }

  final List<ToolUse> _toolUses;
  @override
  @JsonKey()
  List<ToolUse> get toolUses {
    if (_toolUses is EqualUnmodifiableListView) return _toolUses;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_toolUses);
  }

  final Map<String, ToolResult> _toolResults;
  @override
  @JsonKey()
  Map<String, ToolResult> get toolResults {
    if (_toolResults is EqualUnmodifiableMapView) return _toolResults;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_toolResults);
  }

  final List<Agent> _agents;
  @override
  @JsonKey()
  List<Agent> get agents {
    if (_agents is EqualUnmodifiableListView) return _agents;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_agents);
  }

  @override
  final PermissionRequest? pendingPermission;
  @override
  @JsonKey()
  final bool isLoading;
  @override
  @JsonKey()
  final bool isAgentWorking;
  @override
  final String? error;

  @override
  String toString() {
    return 'ChatState(messages: $messages, toolUses: $toolUses, toolResults: $toolResults, agents: $agents, pendingPermission: $pendingPermission, isLoading: $isLoading, isAgentWorking: $isAgentWorking, error: $error)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChatStateImpl &&
            const DeepCollectionEquality().equals(other._messages, _messages) &&
            const DeepCollectionEquality().equals(other._toolUses, _toolUses) &&
            const DeepCollectionEquality()
                .equals(other._toolResults, _toolResults) &&
            const DeepCollectionEquality().equals(other._agents, _agents) &&
            (identical(other.pendingPermission, pendingPermission) ||
                other.pendingPermission == pendingPermission) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.isAgentWorking, isAgentWorking) ||
                other.isAgentWorking == isAgentWorking) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_messages),
      const DeepCollectionEquality().hash(_toolUses),
      const DeepCollectionEquality().hash(_toolResults),
      const DeepCollectionEquality().hash(_agents),
      pendingPermission,
      isLoading,
      isAgentWorking,
      error);

  /// Create a copy of ChatState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChatStateImplCopyWith<_$ChatStateImpl> get copyWith =>
      __$$ChatStateImplCopyWithImpl<_$ChatStateImpl>(this, _$identity);
}

abstract class _ChatState implements ChatState {
  const factory _ChatState(
      {final List<ChatMessage> messages,
      final List<ToolUse> toolUses,
      final Map<String, ToolResult> toolResults,
      final List<Agent> agents,
      final PermissionRequest? pendingPermission,
      final bool isLoading,
      final bool isAgentWorking,
      final String? error}) = _$ChatStateImpl;

  @override
  List<ChatMessage> get messages;
  @override
  List<ToolUse> get toolUses;
  @override
  Map<String, ToolResult> get toolResults;
  @override
  List<Agent> get agents;
  @override
  PermissionRequest? get pendingPermission;
  @override
  bool get isLoading;
  @override
  bool get isAgentWorking;
  @override
  String? get error;

  /// Create a copy of ChatState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChatStateImplCopyWith<_$ChatStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
