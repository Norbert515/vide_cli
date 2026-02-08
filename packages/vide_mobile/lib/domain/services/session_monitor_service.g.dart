// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_monitor_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sessionMonitorHash() => r'0a5cd4dfbc7b69290c86a2d7e9d255cee1743b52';

/// Service that eagerly connects to all active session WebSockets
/// to get live metadata (latest message, agent status, agent count).
///
/// Copied from [SessionMonitor].
@ProviderFor(SessionMonitor)
final sessionMonitorProvider =
    NotifierProvider<SessionMonitor, Map<String, SessionLiveMetadata>>.internal(
  SessionMonitor.new,
  name: r'sessionMonitorProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$sessionMonitorHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SessionMonitor = Notifier<Map<String, SessionLiveMetadata>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
