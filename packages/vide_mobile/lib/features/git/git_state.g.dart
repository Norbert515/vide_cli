// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'git_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$gitNotifierHash() => r'c5206bf9916a85243767fae31325b27945997cd0';

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

abstract class _$GitNotifier
    extends BuildlessAutoDisposeNotifier<GitViewState> {
  late final String repoPath;

  GitViewState build(
    String repoPath,
  );
}

/// See also [GitNotifier].
@ProviderFor(GitNotifier)
const gitNotifierProvider = GitNotifierFamily();

/// See also [GitNotifier].
class GitNotifierFamily extends Family<GitViewState> {
  /// See also [GitNotifier].
  const GitNotifierFamily();

  /// See also [GitNotifier].
  GitNotifierProvider call(
    String repoPath,
  ) {
    return GitNotifierProvider(
      repoPath,
    );
  }

  @override
  GitNotifierProvider getProviderOverride(
    covariant GitNotifierProvider provider,
  ) {
    return call(
      provider.repoPath,
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
  String? get name => r'gitNotifierProvider';
}

/// See also [GitNotifier].
class GitNotifierProvider
    extends AutoDisposeNotifierProviderImpl<GitNotifier, GitViewState> {
  /// See also [GitNotifier].
  GitNotifierProvider(
    String repoPath,
  ) : this._internal(
          () => GitNotifier()..repoPath = repoPath,
          from: gitNotifierProvider,
          name: r'gitNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$gitNotifierHash,
          dependencies: GitNotifierFamily._dependencies,
          allTransitiveDependencies:
              GitNotifierFamily._allTransitiveDependencies,
          repoPath: repoPath,
        );

  GitNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.repoPath,
  }) : super.internal();

  final String repoPath;

  @override
  GitViewState runNotifierBuild(
    covariant GitNotifier notifier,
  ) {
    return notifier.build(
      repoPath,
    );
  }

  @override
  Override overrideWith(GitNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: GitNotifierProvider._internal(
        () => create()..repoPath = repoPath,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        repoPath: repoPath,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<GitNotifier, GitViewState>
      createElement() {
    return _GitNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GitNotifierProvider && other.repoPath == repoPath;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, repoPath.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GitNotifierRef on AutoDisposeNotifierProviderRef<GitViewState> {
  /// The parameter `repoPath` of this provider.
  String get repoPath;
}

class _GitNotifierProviderElement
    extends AutoDisposeNotifierProviderElement<GitNotifier, GitViewState>
    with GitNotifierRef {
  _GitNotifierProviderElement(super.provider);

  @override
  String get repoPath => (origin as GitNotifierProvider).repoPath;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
