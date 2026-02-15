// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_list_manager.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sessionListManagerHash() =>
    r'45f05ffa4ce160e13011de3e417462f5023a5be8';

/// Manages RemoteVideSession instances for all sessions on the list screen.
///
/// Single source of truth for the session list: fetches from daemon,
/// connects via RemoteVideSession, and tracks live activity.
///
/// Copied from [SessionListManager].
@ProviderFor(SessionListManager)
final sessionListManagerProvider = NotifierProvider<SessionListManager,
    Map<String, SessionListEntry>>.internal(
  SessionListManager.new,
  name: r'sessionListManagerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$sessionListManagerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SessionListManager = Notifier<Map<String, SessionListEntry>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
