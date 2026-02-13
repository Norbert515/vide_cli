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
/// For local sessions this stream is empty. Transport-backed sessions emit
/// connectivity changes via their concrete type's connectionStateStream.
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
/// This is the unified session accessor - use this to get the current session
/// regardless of whether it's local or remote.
final currentVideSessionProvider = Provider<VideSession?>((ref) {
  final session = ref.watch(sessionSelectionProvider).session;
  if (session != null) {
    // Rebuild when transport connectivity changes (remote sessions).
    ref.watch(sessionConnectionProvider);
  }
  return session;
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

/// Holds a pre-created idle session for instant first-message response.
///
/// When the TUI starts, a session is created without an initial message
/// (CLI process starts, MCP servers connect). When the user submits their
/// first message, this session is consumed and the message is sent to
/// the already-running session, eliminating startup delay.
///
/// Set to null after the session is consumed or when team changes.
final pendingSessionProvider = StateProvider<VideSession?>((ref) => null);

/// Provider for the selected agent ID in the sidebar.
///
/// When null, no agent is selected.
/// Used by AgentSidebar for keyboard navigation and selection.
final selectedAgentIdProvider = StateProvider<String?>((ref) => null);
