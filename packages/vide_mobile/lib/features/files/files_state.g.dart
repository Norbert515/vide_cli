// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'files_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$filesNotifierHash() => r'511a056c1495d109a9df55198e03eccb1bca3c6f';

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

abstract class _$FilesNotifier
    extends BuildlessAutoDisposeNotifier<FilesViewState> {
  late final String sessionWorkingDirectory;

  FilesViewState build(
    String sessionWorkingDirectory,
  );
}

/// See also [FilesNotifier].
@ProviderFor(FilesNotifier)
const filesNotifierProvider = FilesNotifierFamily();

/// See also [FilesNotifier].
class FilesNotifierFamily extends Family<FilesViewState> {
  /// See also [FilesNotifier].
  const FilesNotifierFamily();

  /// See also [FilesNotifier].
  FilesNotifierProvider call(
    String sessionWorkingDirectory,
  ) {
    return FilesNotifierProvider(
      sessionWorkingDirectory,
    );
  }

  @override
  FilesNotifierProvider getProviderOverride(
    covariant FilesNotifierProvider provider,
  ) {
    return call(
      provider.sessionWorkingDirectory,
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
  String? get name => r'filesNotifierProvider';
}

/// See also [FilesNotifier].
class FilesNotifierProvider
    extends AutoDisposeNotifierProviderImpl<FilesNotifier, FilesViewState> {
  /// See also [FilesNotifier].
  FilesNotifierProvider(
    String sessionWorkingDirectory,
  ) : this._internal(
          () => FilesNotifier()
            ..sessionWorkingDirectory = sessionWorkingDirectory,
          from: filesNotifierProvider,
          name: r'filesNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$filesNotifierHash,
          dependencies: FilesNotifierFamily._dependencies,
          allTransitiveDependencies:
              FilesNotifierFamily._allTransitiveDependencies,
          sessionWorkingDirectory: sessionWorkingDirectory,
        );

  FilesNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.sessionWorkingDirectory,
  }) : super.internal();

  final String sessionWorkingDirectory;

  @override
  FilesViewState runNotifierBuild(
    covariant FilesNotifier notifier,
  ) {
    return notifier.build(
      sessionWorkingDirectory,
    );
  }

  @override
  Override overrideWith(FilesNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: FilesNotifierProvider._internal(
        () => create()..sessionWorkingDirectory = sessionWorkingDirectory,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        sessionWorkingDirectory: sessionWorkingDirectory,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<FilesNotifier, FilesViewState>
      createElement() {
    return _FilesNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is FilesNotifierProvider &&
        other.sessionWorkingDirectory == sessionWorkingDirectory;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, sessionWorkingDirectory.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin FilesNotifierRef on AutoDisposeNotifierProviderRef<FilesViewState> {
  /// The parameter `sessionWorkingDirectory` of this provider.
  String get sessionWorkingDirectory;
}

class _FilesNotifierProviderElement
    extends AutoDisposeNotifierProviderElement<FilesNotifier, FilesViewState>
    with FilesNotifierRef {
  _FilesNotifierProviderElement(super.provider);

  @override
  String get sessionWorkingDirectory =>
      (origin as FilesNotifierProvider).sessionWorkingDirectory;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
