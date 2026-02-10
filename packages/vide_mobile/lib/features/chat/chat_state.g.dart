// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$chatNotifierHash() => r'52e25e9a7e991186e5be7c12913d067fa0afd7db';

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

/// Thin UI notifier for chat-screen-specific state.
///
/// All conversation data (messages, tools, agents, processing status) is
/// owned by [RemoteVideSession]. This notifier only tracks transient UI
/// concerns: pending permission dialogs, plan approval sheets, and error banners.
///
/// Copied from [ChatNotifier].
@ProviderFor(ChatNotifier)
const chatNotifierProvider = ChatNotifierFamily();

/// Thin UI notifier for chat-screen-specific state.
///
/// All conversation data (messages, tools, agents, processing status) is
/// owned by [RemoteVideSession]. This notifier only tracks transient UI
/// concerns: pending permission dialogs, plan approval sheets, and error banners.
///
/// Copied from [ChatNotifier].
class ChatNotifierFamily extends Family<ChatState> {
  /// Thin UI notifier for chat-screen-specific state.
  ///
  /// All conversation data (messages, tools, agents, processing status) is
  /// owned by [RemoteVideSession]. This notifier only tracks transient UI
  /// concerns: pending permission dialogs, plan approval sheets, and error banners.
  ///
  /// Copied from [ChatNotifier].
  const ChatNotifierFamily();

  /// Thin UI notifier for chat-screen-specific state.
  ///
  /// All conversation data (messages, tools, agents, processing status) is
  /// owned by [RemoteVideSession]. This notifier only tracks transient UI
  /// concerns: pending permission dialogs, plan approval sheets, and error banners.
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

/// Thin UI notifier for chat-screen-specific state.
///
/// All conversation data (messages, tools, agents, processing status) is
/// owned by [RemoteVideSession]. This notifier only tracks transient UI
/// concerns: pending permission dialogs, plan approval sheets, and error banners.
///
/// Copied from [ChatNotifier].
class ChatNotifierProvider
    extends NotifierProviderImpl<ChatNotifier, ChatState> {
  /// Thin UI notifier for chat-screen-specific state.
  ///
  /// All conversation data (messages, tools, agents, processing status) is
  /// owned by [RemoteVideSession]. This notifier only tracks transient UI
  /// concerns: pending permission dialogs, plan approval sheets, and error banners.
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
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
