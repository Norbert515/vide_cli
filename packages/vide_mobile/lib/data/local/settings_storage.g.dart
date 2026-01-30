// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_storage.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$settingsStorageHash() => r'65a1aa29de9c0a225d1c282dc988abed32c50184';

/// Wrapper for SharedPreferences to persist app settings.
///
/// Copied from [SettingsStorage].
@ProviderFor(SettingsStorage)
final settingsStorageProvider =
    AsyncNotifierProvider<SettingsStorage, void>.internal(
  SettingsStorage.new,
  name: r'settingsStorageProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$settingsStorageHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SettingsStorage = AsyncNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
