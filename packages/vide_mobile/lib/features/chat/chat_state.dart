import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vide_client/vide_client.dart';

part 'chat_state.g.dart';

/// Thin UI-only state for the chat screen.
///
/// Messages, tools, agents, and processing status all come from
/// [RemoteVideSession] directly. This state only tracks things that are
/// purely UI concerns with no home in the session model.
class ChatState {
  final PermissionRequestEvent? pendingPermission;
  final String? error;

  const ChatState({
    this.pendingPermission,
    this.error,
  });

  ChatState copyWith({
    PermissionRequestEvent? Function()? pendingPermission,
    String? Function()? error,
  }) {
    return ChatState(
      pendingPermission: pendingPermission != null
          ? pendingPermission()
          : this.pendingPermission,
      error: error != null ? error() : this.error,
    );
  }
}

/// Thin UI notifier for chat-screen-specific state.
///
/// All conversation data (messages, tools, agents, processing status) is
/// owned by [RemoteVideSession]. This notifier only tracks transient UI
/// concerns: pending permission dialogs and error banners.
@Riverpod(keepAlive: true)
class ChatNotifier extends _$ChatNotifier {
  @override
  ChatState build(String sessionId) {
    return const ChatState();
  }

  void setPendingPermission(PermissionRequestEvent? request) {
    state = state.copyWith(pendingPermission: () => request);
  }

  void setError(String? error) {
    state = state.copyWith(error: () => error);
  }

  void reset() {
    state = const ChatState();
  }
}
