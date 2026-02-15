// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_registry.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$serverRegistryHash() => r'da88a024932d45eaf8b4504198f7ea248ec92bae';

/// Registry for managing multiple server connections.
///
/// Replaces the single-server [ConnectionRepository] with support for
/// multiple named servers, each with independent health status.
///
/// Copied from [ServerRegistry].
@ProviderFor(ServerRegistry)
final serverRegistryProvider =
    NotifierProvider<ServerRegistry, Map<String, ServerEntry>>.internal(
  ServerRegistry.new,
  name: r'serverRegistryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$serverRegistryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ServerRegistry = Notifier<Map<String, ServerEntry>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
