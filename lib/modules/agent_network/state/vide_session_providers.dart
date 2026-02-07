/// Providers for VideSession and ConversationStateManager.
///
/// These providers bridge the public vide_core API with the TUI state management.
library;

import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_core/vide_core.dart';
import 'package:vide_cli/services/core_providers.dart';

/// Provider for the VideCore instance.
///
/// This is created from the existing ProviderContainer using [VideCore.fromContainer].
final videoCoreProvider = Provider<VideCore>((ref) {
  throw UnimplementedError('videoCoreProvider must be overridden in main.dart');
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
/// connectivity changes.
final sessionConnectionProvider = StreamProvider<bool>((ref) {
  final session = ref.watch(sessionSelectionProvider.select((s) => s.session));
  return session?.connectionStateStream ?? const Stream<bool>.empty();
});

/// Backward-compatible alias while callsites migrate away from the remote-only
/// name.
@Deprecated('Use sessionConnectionProvider')
final remoteSessionConnectionProvider = sessionConnectionProvider;

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

  if (sessionId == null) return activeSession;

  // Local mode - use session ID + VideCore lookup
  final core = ref.watch(videoCoreProvider);
  return core.getSessionForNetwork(sessionId) ?? activeSession;
});

/// Provider for the current session's goal/task name.
///
/// This is reactive - it will update when the goal changes via setTaskName MCP tool.
final currentSessionGoalProvider = Provider<String>((ref) {
  final session = ref.watch(currentVideSessionProvider);
  return session?.goal ?? 'Session';
});

/// Stream provider that emits when the goal changes.
///
/// This allows widgets to reactively rebuild when the task name is updated.
final sessionGoalStreamProvider = StreamProvider<String>((ref) {
  final session = ref.watch(currentVideSessionProvider);
  if (session == null) return Stream.value('Session');

  return session.goalStream;
});

/// Provider that emits the current agents list whenever it changes.
///
/// This is a unified provider that works for both local and remote sessions.
/// It watches the session's [agentsStream] to detect when agents are
/// spawned or terminated, triggering UI rebuilds.
///
/// Usage:
/// ```dart
/// final agents = context.watch(videSessionAgentsProvider);
/// final agentsList = agents.valueOrNull ?? session?.agents ?? [];
/// ```
final videSessionAgentsProvider = StreamProvider<List<VideAgent>>((ref) {
  final session = ref.watch(currentVideSessionProvider);
  if (session == null) return const Stream.empty();

  return session.agentsStream;
});

/// Provider for ConversationStateManager tied to the current session.
///
/// The ConversationStateManager is owned by the VideSession and accumulates
/// all events from the session's creation. This avoids missing events that
/// would occur with late subscription to a broadcast stream.
final conversationStateManagerProvider = Provider<ConversationStateManager?>((
  ref,
) {
  final session = ref.watch(currentVideSessionProvider);
  if (session == null) return null;

  // Use the session's built-in conversation state manager
  return session.conversationState;
});

/// Provider for a specific agent's conversation state.
///
/// Usage:
/// ```dart
/// final agentState = context.watch(agentConversationStateProvider(agentId));
/// ```
final agentConversationStateProvider =
    Provider.family<AgentConversationState?, String>((ref, agentId) {
      final manager = ref.watch(conversationStateManagerProvider);
      if (manager == null) return null;

      return manager.getAgentState(agentId);
    });

/// Provider that triggers rebuilds when conversation state changes.
///
/// This uses a stream to notify when the ConversationStateManager has updates.
/// Widgets can watch this to rebuild when any agent's state changes.
final conversationStateChangedProvider = StreamProvider<void>((ref) {
  final manager = ref.watch(conversationStateManagerProvider);
  if (manager == null) return const Stream.empty();

  return manager.onStateChanged;
});

/// Provider for the current team name.
///
/// Defaults to 'vide' if not set.
/// This should be persisted to settings when changed.
final currentTeamProvider = StateProvider<String>((ref) {
  return 'vide';
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
