// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sharedPreferencesHash() => r'd22b545aefe95500327f9dce52c645d746349271';

/// See also [sharedPreferences].
@ProviderFor(sharedPreferences)
final sharedPreferencesProvider = FutureProvider<SharedPreferences>.internal(
  sharedPreferences,
  name: r'sharedPreferencesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$sharedPreferencesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SharedPreferencesRef = FutureProviderRef<SharedPreferences>;
String _$connectivityHash() => r'9cb176853e1e6817de35f5d6315b626af51de97a';

/// See also [connectivity].
@ProviderFor(connectivity)
final connectivityProvider =
    AutoDisposeStreamProvider<ConnectivityResult>.internal(
  connectivity,
  name: r'connectivityProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$connectivityHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ConnectivityRef = AutoDisposeStreamProviderRef<ConnectivityResult>;
String _$currentConnectivityHash() =>
    r'2b8cab0f068de53f5ace1cc48087cb0d32e9a10d';

/// See also [currentConnectivity].
@ProviderFor(currentConnectivity)
final currentConnectivityProvider =
    AutoDisposeFutureProvider<ConnectivityResult>.internal(
  currentConnectivity,
  name: r'currentConnectivityProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentConnectivityHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentConnectivityRef
    = AutoDisposeFutureProviderRef<ConnectivityResult>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
