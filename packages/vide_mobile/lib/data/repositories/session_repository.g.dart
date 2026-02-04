// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sessionRepositoryHash() => r'780b710892aae3be0e94295dbee4b2b105c831de';

/// Repository for managing Vide sessions with reconnection support.
///
/// Copied from [SessionRepository].
@ProviderFor(SessionRepository)
final sessionRepositoryProvider =
    NotifierProvider<SessionRepository, SessionState>.internal(
  SessionRepository.new,
  name: r'sessionRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$sessionRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SessionRepository = Notifier<SessionState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
