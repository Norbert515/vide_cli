// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$connectionRepositoryHash() =>
    r'51a9f593882dbcc79da78eded6be8e5eaa75a0ad';

/// Repository for managing server connections.
///
/// Copied from [ConnectionRepository].
@ProviderFor(ConnectionRepository)
final connectionRepositoryProvider =
    NotifierProvider<ConnectionRepository, ConnectionState>.internal(
  ConnectionRepository.new,
  name: r'connectionRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$connectionRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ConnectionRepository = Notifier<ConnectionState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
