// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network_monitor_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$networkMonitorHash() => r'27ba39d9970935e56a275b29cc072cea94fc4218';

/// Provider for monitoring network connectivity.
///
/// Copied from [NetworkMonitor].
@ProviderFor(NetworkMonitor)
final networkMonitorProvider =
    NotifierProvider<NetworkMonitor, NetworkStatus>.internal(
  NetworkMonitor.new,
  name: r'networkMonitorProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$networkMonitorHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$NetworkMonitor = Notifier<NetworkStatus>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
