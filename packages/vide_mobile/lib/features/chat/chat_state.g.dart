// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$chatNotifierHash() => r'9f6ec38fd2dfd85b88b93019a3241e690708d3d6';

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

abstract class _$ChatNotifier extends BuildlessNotifier<ChatState> {
  late final String sessionId;

  ChatState build(
    String sessionId,
  );
}

/// Provider for chat state management.
///
/// Kept alive so that optimistic user messages added before navigating
/// to the chat screen survive the route transition (auto-dispose would
/// reset the state between the creation screen disposing and the chat
/// screen subscribing).
///
/// Copied from [ChatNotifier].
@ProviderFor(ChatNotifier)
const chatNotifierProvider = ChatNotifierFamily();

/// Provider for chat state management.
///
/// Kept alive so that optimistic user messages added before navigating
/// to the chat screen survive the route transition (auto-dispose would
/// reset the state between the creation screen disposing and the chat
/// screen subscribing).
///
/// Copied from [ChatNotifier].
class ChatNotifierFamily extends Family<ChatState> {
  /// Provider for chat state management.
  ///
  /// Kept alive so that optimistic user messages added before navigating
  /// to the chat screen survive the route transition (auto-dispose would
  /// reset the state between the creation screen disposing and the chat
  /// screen subscribing).
  ///
  /// Copied from [ChatNotifier].
  const ChatNotifierFamily();

  /// Provider for chat state management.
  ///
  /// Kept alive so that optimistic user messages added before navigating
  /// to the chat screen survive the route transition (auto-dispose would
  /// reset the state between the creation screen disposing and the chat
  /// screen subscribing).
  ///
  /// Copied from [ChatNotifier].
  ChatNotifierProvider call(
    String sessionId,
  ) {
    return ChatNotifierProvider(
      sessionId,
    );
  }

  @override
  ChatNotifierProvider getProviderOverride(
    covariant ChatNotifierProvider provider,
  ) {
    return call(
      provider.sessionId,
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
  String? get name => r'chatNotifierProvider';
}

/// Provider for chat state management.
///
/// Kept alive so that optimistic user messages added before navigating
/// to the chat screen survive the route transition (auto-dispose would
/// reset the state between the creation screen disposing and the chat
/// screen subscribing).
///
/// Copied from [ChatNotifier].
class ChatNotifierProvider
    extends NotifierProviderImpl<ChatNotifier, ChatState> {
  /// Provider for chat state management.
  ///
  /// Kept alive so that optimistic user messages added before navigating
  /// to the chat screen survive the route transition (auto-dispose would
  /// reset the state between the creation screen disposing and the chat
  /// screen subscribing).
  ///
  /// Copied from [ChatNotifier].
  ChatNotifierProvider(
    String sessionId,
  ) : this._internal(
          () => ChatNotifier()..sessionId = sessionId,
          from: chatNotifierProvider,
          name: r'chatNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$chatNotifierHash,
          dependencies: ChatNotifierFamily._dependencies,
          allTransitiveDependencies:
              ChatNotifierFamily._allTransitiveDependencies,
          sessionId: sessionId,
        );

  ChatNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.sessionId,
  }) : super.internal();

  final String sessionId;

  @override
  ChatState runNotifierBuild(
    covariant ChatNotifier notifier,
  ) {
    return notifier.build(
      sessionId,
    );
  }

  @override
  Override overrideWith(ChatNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: ChatNotifierProvider._internal(
        () => create()..sessionId = sessionId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        sessionId: sessionId,
      ),
    );
  }

  @override
  NotifierProviderElement<ChatNotifier, ChatState> createElement() {
    return _ChatNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ChatNotifierProvider && other.sessionId == sessionId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, sessionId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ChatNotifierRef on NotifierProviderRef<ChatState> {
  /// The parameter `sessionId` of this provider.
  String get sessionId;
}

class _ChatNotifierProviderElement
    extends NotifierProviderElement<ChatNotifier, ChatState>
    with ChatNotifierRef {
  _ChatNotifierProviderElement(super.provider);

  @override
  String get sessionId => (origin as ChatNotifierProvider).sessionId;
}

String _$messageInputHash() => r'baac7ef31c581fa0a71f631a8e562037ab5889ca';

/// Provider for the message input text.
///
/// Copied from [MessageInput].
@ProviderFor(MessageInput)
final messageInputProvider =
    AutoDisposeNotifierProvider<MessageInput, String>.internal(
  MessageInput.new,
  name: r'messageInputProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$messageInputHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$MessageInput = AutoDisposeNotifier<String>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
