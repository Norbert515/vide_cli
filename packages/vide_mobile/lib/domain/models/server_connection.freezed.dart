// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'server_connection.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ServerConnection _$ServerConnectionFromJson(Map<String, dynamic> json) {
  return _ServerConnection.fromJson(json);
}

/// @nodoc
mixin _$ServerConnection {
  String get host => throw _privateConstructorUsedError;
  int get port => throw _privateConstructorUsedError;
  bool get isSecure => throw _privateConstructorUsedError;
  String? get name => throw _privateConstructorUsedError;

  /// Serializes this ServerConnection to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ServerConnection
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ServerConnectionCopyWith<ServerConnection> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ServerConnectionCopyWith<$Res> {
  factory $ServerConnectionCopyWith(
          ServerConnection value, $Res Function(ServerConnection) then) =
      _$ServerConnectionCopyWithImpl<$Res, ServerConnection>;
  @useResult
  $Res call({String host, int port, bool isSecure, String? name});
}

/// @nodoc
class _$ServerConnectionCopyWithImpl<$Res, $Val extends ServerConnection>
    implements $ServerConnectionCopyWith<$Res> {
  _$ServerConnectionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ServerConnection
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? host = null,
    Object? port = null,
    Object? isSecure = null,
    Object? name = freezed,
  }) {
    return _then(_value.copyWith(
      host: null == host
          ? _value.host
          : host // ignore: cast_nullable_to_non_nullable
              as String,
      port: null == port
          ? _value.port
          : port // ignore: cast_nullable_to_non_nullable
              as int,
      isSecure: null == isSecure
          ? _value.isSecure
          : isSecure // ignore: cast_nullable_to_non_nullable
              as bool,
      name: freezed == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ServerConnectionImplCopyWith<$Res>
    implements $ServerConnectionCopyWith<$Res> {
  factory _$$ServerConnectionImplCopyWith(_$ServerConnectionImpl value,
          $Res Function(_$ServerConnectionImpl) then) =
      __$$ServerConnectionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String host, int port, bool isSecure, String? name});
}

/// @nodoc
class __$$ServerConnectionImplCopyWithImpl<$Res>
    extends _$ServerConnectionCopyWithImpl<$Res, _$ServerConnectionImpl>
    implements _$$ServerConnectionImplCopyWith<$Res> {
  __$$ServerConnectionImplCopyWithImpl(_$ServerConnectionImpl _value,
      $Res Function(_$ServerConnectionImpl) _then)
      : super(_value, _then);

  /// Create a copy of ServerConnection
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? host = null,
    Object? port = null,
    Object? isSecure = null,
    Object? name = freezed,
  }) {
    return _then(_$ServerConnectionImpl(
      host: null == host
          ? _value.host
          : host // ignore: cast_nullable_to_non_nullable
              as String,
      port: null == port
          ? _value.port
          : port // ignore: cast_nullable_to_non_nullable
              as int,
      isSecure: null == isSecure
          ? _value.isSecure
          : isSecure // ignore: cast_nullable_to_non_nullable
              as bool,
      name: freezed == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ServerConnectionImpl implements _ServerConnection {
  const _$ServerConnectionImpl(
      {required this.host,
      required this.port,
      this.isSecure = false,
      this.name});

  factory _$ServerConnectionImpl.fromJson(Map<String, dynamic> json) =>
      _$$ServerConnectionImplFromJson(json);

  @override
  final String host;
  @override
  final int port;
  @override
  @JsonKey()
  final bool isSecure;
  @override
  final String? name;

  @override
  String toString() {
    return 'ServerConnection(host: $host, port: $port, isSecure: $isSecure, name: $name)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ServerConnectionImpl &&
            (identical(other.host, host) || other.host == host) &&
            (identical(other.port, port) || other.port == port) &&
            (identical(other.isSecure, isSecure) ||
                other.isSecure == isSecure) &&
            (identical(other.name, name) || other.name == name));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, host, port, isSecure, name);

  /// Create a copy of ServerConnection
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ServerConnectionImplCopyWith<_$ServerConnectionImpl> get copyWith =>
      __$$ServerConnectionImplCopyWithImpl<_$ServerConnectionImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ServerConnectionImplToJson(
      this,
    );
  }
}

abstract class _ServerConnection implements ServerConnection {
  const factory _ServerConnection(
      {required final String host,
      required final int port,
      final bool isSecure,
      final String? name}) = _$ServerConnectionImpl;

  factory _ServerConnection.fromJson(Map<String, dynamic> json) =
      _$ServerConnectionImpl.fromJson;

  @override
  String get host;
  @override
  int get port;
  @override
  bool get isSecure;
  @override
  String? get name;

  /// Create a copy of ServerConnection
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ServerConnectionImplCopyWith<_$ServerConnectionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
