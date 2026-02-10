// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sessions_list_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sessionsListRefreshHash() =>
    r'b2740dfd8c2056dd8d1d1d84aa9859b737711f17';

/// Triggers a refresh of the session list from the daemon.
///
/// The actual session data lives in [sessionListManagerProvider] (keepAlive).
/// This provider just kicks off the fetch; the screen watches the manager
/// directly for live updates.
///
/// Copied from [sessionsListRefresh].
@ProviderFor(sessionsListRefresh)
final sessionsListRefreshProvider = AutoDisposeFutureProvider<void>.internal(
  sessionsListRefresh,
  name: r'sessionsListRefreshProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$sessionsListRefreshHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SessionsListRefreshRef = AutoDisposeFutureProviderRef<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
