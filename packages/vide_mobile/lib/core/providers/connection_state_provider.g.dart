// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection_state_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$webSocketConnectionHash() =>
    r'b7e84f82907be13c4d6737700b7cdf676a1c9bb8';

/// Provider for managing WebSocket connection state.
///
/// Copied from [WebSocketConnection].
@ProviderFor(WebSocketConnection)
final webSocketConnectionProvider =
    NotifierProvider<WebSocketConnection, WebSocketConnectionState>.internal(
  WebSocketConnection.new,
  name: r'webSocketConnectionProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$webSocketConnectionHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$WebSocketConnection = Notifier<WebSocketConnectionState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
