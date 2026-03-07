/// Providers bridging the public vide_core API with TUI state management.
library;

import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_client/src/remote_vide_session.dart';
import 'package:vide_core/vide_core.dart';

/// Provider for the session manager.
///
/// Uses [RemoteVideSessionManager] backed by the daemon. All session lifecycle
/// operations (create, list, resume, delete) go through this provider.
final videSessionManagerProvider = Provider<VideSessionManager>((ref) {
  // Import is deferred to avoid circular dependency — the provider watches
  // daemonConnectionProvider which lives in the remote module.
  // This provider is overridden with the concrete implementation in main.dart.
  throw UnimplementedError(
    'videSessionManagerProvider must be overridden in main.dart',
  );
});

/// Unified TUI session selection state.
///
/// The session ID is always derived from the live [session] object via
/// [VideSession.id]. This avoids stale-ID bugs where a pending remote session
/// starts with a temporary UUID that later changes when the daemon responds.
class SessionSelectionState {
  final VideSession? session;

  const SessionSelectionState({this.session});

  /// The current session ID, derived from the live session object.
  String? get sessionId => session?.id;
}

/// Controls the current session selection for the TUI.
class SessionSelectionNotifier extends StateNotifier<SessionSelectionState> {
  SessionSelectionNotifier() : super(const SessionSelectionState());

  /// Select a session.
  void selectSession(VideSession session) {
    state = SessionSelectionState(session: session);
  }

  /// Clear selected session state.
  void clear() {
    state = const SessionSelectionState();
  }
}

/// Single source of truth for TUI session selection.
final sessionSelectionProvider =
    StateNotifierProvider<SessionSelectionNotifier, SessionSelectionState>(
      (ref) => SessionSelectionNotifier(),
    );

/// Provider that triggers rebuilds when the selected session connection changes.
///
/// Remote sessions emit connectivity changes via their connectionStateStream.
final sessionConnectionProvider = StreamProvider<bool>((ref) {
  final session = ref.watch(sessionSelectionProvider.select((s) => s.session));
  if (session is RemoteVideSession) {
    return session.connectionStateStream;
  }
  return const Stream<bool>.empty();
});

/// Provider for the current VideSession.
///
/// Returns null if no session is currently active.
///
/// This is the session accessor for the current active session.
final currentVideSessionProvider = Provider<VideSession?>((ref) {
  final session = ref.watch(sessionSelectionProvider).session;
  if (session != null) {
    // Rebuild when transport connectivity changes (remote sessions).
    ref.watch(sessionConnectionProvider);
  }
  return session;
});

/// Stream provider that emits when the goal changes.
///
/// This allows widgets to reactively rebuild when the task name is updated.
final sessionGoalStreamProvider = StreamProvider<String>((ref) {
  final session = ref.watch(currentVideSessionProvider);
  if (session == null) return Stream.value('Session');

  return session.stateStream.map((s) => s.goal).distinct();
});

/// Stream provider that emits when the session's working directory changes.
///
/// In daemon mode, the working directory arrives asynchronously via the
/// WebSocket `connected` event. This stream enables providers like
/// [currentRepoPathProvider] to reactively update when it arrives.
final sessionWorkingDirectoryStreamProvider = StreamProvider<String>((ref) {
  final session = ref.watch(currentVideSessionProvider);
  if (session == null) return const Stream.empty();

  return session.stateStream.map((s) => s.workingDirectory).distinct();
});

/// Provider that emits the current agents list whenever it changes.
///
/// Watches the session's [stateStream] to detect when agents are
/// spawned or terminated, triggering UI rebuilds.
///
/// Usage:
/// ```dart
/// final agents = context.watch(videSessionAgentsProvider);
/// final agentsList = agents.valueOrNull ?? session?.state.agents ?? [];
/// ```
final videSessionAgentsProvider = StreamProvider<List<VideAgent>>((ref) {
  final session = ref.watch(currentVideSessionProvider);
  if (session == null) return const Stream.empty();

  return session.stateStream.map((s) => s.agents);
});

/// Typed selection state for the chat view.
///
/// Determines whether the user is viewing the channel overview or a
/// specific agent's conversation. Defaults to [ChannelOverview]; the
/// sidebar auto-selects the main agent on first load.
final chatViewSelectionProvider =
    StateProvider.family<ChatViewSelection, String>(
  (ref, sessionId) => const ChannelOverview(),
);

/// Convenience accessor: extracts the selected agent ID (or null for channel).
String? selectedAgentId(ChatViewSelection selection) {
  return switch (selection) {
    AgentView(agentId: final id) => id,
    ChannelOverview() => null,
  };
}

/// Provider for the currently displayed model name (e.g. "opus", "sonnet").
///
/// Updated by the active chat view when the model stream emits.
/// Read by the scaffold bottom bar to display the model inline.
final currentModelProvider = StateProvider.family<String?, String>((ref, sessionId) => null);
