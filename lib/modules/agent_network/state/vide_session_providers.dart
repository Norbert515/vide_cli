/// Providers bridging the public vide_core API with TUI state management.
library;

import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_client/src/remote_vide_session.dart';
import 'package:vide_core/vide_core.dart';

/// Provider for the unified session manager.
///
/// Automatically selects [LocalVideSessionManager] or [RemoteVideSessionManager]
/// based on daemon connection state. All session lifecycle operations (create,
/// list, resume, delete) go through this provider.
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
/// [sessionId] is the selected network/session ID.
/// [session] is an optional already-instantiated session object (local or remote).
class SessionSelectionState {
  final String? sessionId;
  final VideSession? session;

  const SessionSelectionState({this.sessionId, this.session});
}

/// Controls the current session selection for the TUI.
class SessionSelectionNotifier extends StateNotifier<SessionSelectionState> {
  SessionSelectionNotifier() : super(const SessionSelectionState());

  /// Select a session by ID, optionally supplying a live session instance.
  void selectSession(String sessionId, {VideSession? session}) {
    final retainedSession =
        session ?? (state.session?.id == sessionId ? state.session : null);
    state = SessionSelectionState(
      sessionId: sessionId,
      session: retainedSession,
    );
  }

  /// Set the current session object and select its ID.
  void setSession(VideSession session) {
    state = SessionSelectionState(sessionId: session.id, session: session);
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
/// For local sessions this stream is empty. Transport-backed sessions emit
/// connectivity changes via their concrete type's connectionStateStream.
final sessionConnectionProvider = StreamProvider<bool>((ref) {
  final session = ref.watch(sessionSelectionProvider.select((s) => s.session));
  if (session is RemoteVideSession) {
    return session.connectionStateStream;
  }
  return const Stream<bool>.empty();
});

/// Provider for the current VideSession based on the active session ID.
///
/// Returns null if no session is currently active.
///
/// This is the unified session accessor - use this to get the current session
/// regardless of whether it's local or remote.
final currentVideSessionProvider = Provider<VideSession?>((ref) {
  final selection = ref.watch(sessionSelectionProvider);
  final sessionId = selection.sessionId;
  final activeSession = selection.session;

  // Active session override works for both local and remote sessions.
  // Only prefer it when it matches the requested session ID (if any).
  if (activeSession != null &&
      (sessionId == null || activeSession.id == sessionId)) {
    // Rebuild when transport connectivity changes (if any).
    ref.watch(sessionConnectionProvider);
    return activeSession;
  }

  return activeSession;
});

/// Provider for the current session's goal/task name.
///
/// This is reactive - it will update when the goal changes via setTaskName MCP tool.
final currentSessionGoalProvider = Provider<String>((ref) {
  final session = ref.watch(currentVideSessionProvider);
  return session?.state.goal ?? 'Session';
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
/// This is a unified provider that works for both local and remote sessions.
/// It watches the session's [stateStream] to detect when agents are
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


/// Provider for the current team name.
///
/// Defaults to 'enterprise' if not set.
/// This should be persisted to settings when changed.
final currentTeamProvider = StateProvider<String>((ref) {
  return 'enterprise';
});

/// Provider for the current team definition.
///
/// Loads the full TeamDefinition for the currently selected team.
/// Returns null if the team is not found.
final currentTeamDefinitionProvider = FutureProvider<TeamDefinition?>((
  ref,
) async {
  final teamName = ref.watch(currentTeamProvider);
  final loader = ref.watch(teamFrameworkLoaderProvider);
  return await loader.getTeam(teamName);
});

/// Provider for the selected agent ID in the sidebar.
///
/// When null, no agent is selected.
/// Used by AgentSidebar for keyboard navigation and selection.
final selectedAgentIdProvider = StateProvider<String?>((ref) => null);
