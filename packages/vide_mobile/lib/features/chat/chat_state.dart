import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vide_client/vide_client.dart';

part 'chat_state.g.dart';

/// Thin UI-only state for the chat screen.
///
/// Messages, tools, agents, and processing status all come from
/// [RemoteVideSession] directly. This state only tracks things that are
/// purely UI concerns with no home in the session model.
class ChatState {
  final List<PermissionRequestEvent> pendingPermissions;
  final PlanApprovalRequestEvent? pendingPlanApproval;
  final AskUserQuestionEvent? pendingAskUserQuestion;
  final String? error;

  const ChatState({
    this.pendingPermissions = const [],
    this.pendingPlanApproval,
    this.pendingAskUserQuestion,
    this.error,
  });

  /// The next permission request to show, or null if the queue is empty.
  PermissionRequestEvent? get currentPermission =>
      pendingPermissions.firstOrNull;

  ChatState copyWith({
    List<PermissionRequestEvent>? pendingPermissions,
    PlanApprovalRequestEvent? Function()? pendingPlanApproval,
    AskUserQuestionEvent? Function()? pendingAskUserQuestion,
    String? Function()? error,
  }) {
    return ChatState(
      pendingPermissions: pendingPermissions ?? this.pendingPermissions,
      pendingPlanApproval: pendingPlanApproval != null
          ? pendingPlanApproval()
          : this.pendingPlanApproval,
      pendingAskUserQuestion: pendingAskUserQuestion != null
          ? pendingAskUserQuestion()
          : this.pendingAskUserQuestion,
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

  void enqueuePermission(PermissionRequestEvent request) {
    state = state.copyWith(
      pendingPermissions: [...state.pendingPermissions, request],
    );
  }

  void dequeuePermission() {
    if (state.pendingPermissions.isEmpty) return;
    state = state.copyWith(
      pendingPermissions: state.pendingPermissions.sublist(1),
    );
  }

  void removePermissionByRequestId(String requestId) {
    state = state.copyWith(
      pendingPermissions: state.pendingPermissions
          .where((r) => r.requestId != requestId)
          .toList(),
    );
  }

  void setPendingPlanApproval(PlanApprovalRequestEvent? request) {
    state = state.copyWith(pendingPlanApproval: () => request);
  }

  void setPendingAskUserQuestion(AskUserQuestionEvent? request) {
    state = state.copyWith(pendingAskUserQuestion: () => request);
  }

  void setError(String? error) {
    state = state.copyWith(error: () => error);
  }

  void reset() {
    state = const ChatState();
  }
}
