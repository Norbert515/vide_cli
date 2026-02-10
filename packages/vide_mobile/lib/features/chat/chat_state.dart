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
  final PlanApprovalRequestEvent? pendingPlanApproval;
  final String? error;

  const ChatState({
    this.pendingPermission,
    this.pendingPlanApproval,
    this.error,
  });

  ChatState copyWith({
    PermissionRequestEvent? Function()? pendingPermission,
    PlanApprovalRequestEvent? Function()? pendingPlanApproval,
    String? Function()? error,
  }) {
    return ChatState(
      pendingPermission: pendingPermission != null
          ? pendingPermission()
          : this.pendingPermission,
      pendingPlanApproval: pendingPlanApproval != null
          ? pendingPlanApproval()
          : this.pendingPlanApproval,
      error: error != null ? error() : this.error,
    );
  }
}

/// Thin UI notifier for chat-screen-specific state.
///
/// All conversation data (messages, tools, agents, processing status) is
/// owned by [RemoteVideSession]. This notifier only tracks transient UI
/// concerns: pending permission dialogs, plan approval sheets, and error banners.
@Riverpod(keepAlive: true)
class ChatNotifier extends _$ChatNotifier {
  @override
  ChatState build(String sessionId) {
    return const ChatState();
  }

  void setPendingPermission(PermissionRequestEvent? request) {
    state = state.copyWith(pendingPermission: () => request);
  }

  void setPendingPlanApproval(PlanApprovalRequestEvent? request) {
    state = state.copyWith(pendingPlanApproval: () => request);
  }

  void setError(String? error) {
    state = state.copyWith(error: () => error);
  }

  void reset() {
    state = const ChatState();
  }
}
