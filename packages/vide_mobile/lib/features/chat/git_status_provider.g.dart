// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'git_status_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$gitStatusNotifierHash() => r'84919f76a49fdb424f1998b470bbfdb083a21538';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$GitStatusNotifier
    extends BuildlessAutoDisposeNotifier<GitStatusInfo?> {
  late final String workingDirectory;

  GitStatusInfo? build(
    String workingDirectory,
  );
}

/// See also [GitStatusNotifier].
@ProviderFor(GitStatusNotifier)
const gitStatusNotifierProvider = GitStatusNotifierFamily();

/// See also [GitStatusNotifier].
class GitStatusNotifierFamily extends Family<GitStatusInfo?> {
  /// See also [GitStatusNotifier].
  const GitStatusNotifierFamily();

  /// See also [GitStatusNotifier].
  GitStatusNotifierProvider call(
    String workingDirectory,
  ) {
    return GitStatusNotifierProvider(
      workingDirectory,
    );
  }

  @override
  GitStatusNotifierProvider getProviderOverride(
    covariant GitStatusNotifierProvider provider,
  ) {
    return call(
      provider.workingDirectory,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'gitStatusNotifierProvider';
}

/// See also [GitStatusNotifier].
class GitStatusNotifierProvider
    extends AutoDisposeNotifierProviderImpl<GitStatusNotifier, GitStatusInfo?> {
  /// See also [GitStatusNotifier].
  GitStatusNotifierProvider(
    String workingDirectory,
  ) : this._internal(
          () => GitStatusNotifier()..workingDirectory = workingDirectory,
          from: gitStatusNotifierProvider,
          name: r'gitStatusNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$gitStatusNotifierHash,
          dependencies: GitStatusNotifierFamily._dependencies,
          allTransitiveDependencies:
              GitStatusNotifierFamily._allTransitiveDependencies,
          workingDirectory: workingDirectory,
        );

  GitStatusNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.workingDirectory,
  }) : super.internal();

  final String workingDirectory;

  @override
  GitStatusInfo? runNotifierBuild(
    covariant GitStatusNotifier notifier,
  ) {
    return notifier.build(
      workingDirectory,
    );
  }

  @override
  Override overrideWith(GitStatusNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: GitStatusNotifierProvider._internal(
        () => create()..workingDirectory = workingDirectory,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        workingDirectory: workingDirectory,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<GitStatusNotifier, GitStatusInfo?>
      createElement() {
    return _GitStatusNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GitStatusNotifierProvider &&
        other.workingDirectory == workingDirectory;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, workingDirectory.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GitStatusNotifierRef on AutoDisposeNotifierProviderRef<GitStatusInfo?> {
  /// The parameter `workingDirectory` of this provider.
  String get workingDirectory;
}

class _GitStatusNotifierProviderElement
    extends AutoDisposeNotifierProviderElement<GitStatusNotifier,
        GitStatusInfo?> with GitStatusNotifierRef {
  _GitStatusNotifierProviderElement(super.provider);

  @override
  String get workingDirectory =>
      (origin as GitStatusNotifierProvider).workingDirectory;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
