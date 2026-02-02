/// Providers for VideSession and ConversationStateManager.
///
/// These providers bridge the public vide_core API with the TUI state management.
library;

import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_core/vide_core.dart';

/// Provider for the VideCore instance.
///
/// This is created from the existing ProviderContainer using [VideCore.fromContainer].
final videoCoreProvider = Provider<VideCore>((ref) {
  throw UnimplementedError('videoCoreProvider must be overridden in main.dart');
});

/// Provider for a remote VideSession when connected to a daemon.
///
/// This is set by [SessionPickerPage] when connecting to a remote session.
/// When set, [currentVideSessionProvider] will return this instead of the local session.
final remoteVideSessionProvider = StateProvider<RemoteVideSession?>(
  (ref) => null,
);

/// Provider that triggers rebuilds when the remote session connection state changes.
///
/// This watches the [RemoteVideSession.connectionStateStream] to detect when
/// the WebSocket connects or disconnects. Without this, setting the session
/// provider doesn't trigger rebuilds when internal state changes.
final remoteSessionConnectionProvider = StreamProvider<bool>((ref) {
  final remoteSession = ref.watch(remoteVideSessionProvider);
  if (remoteSession == null) return const Stream.empty();

  return remoteSession.connectionStateStream;
});

/// Provider for the ID of the currently active session.
///
/// This is the primary way to track which session is active.
/// Set this when creating or resuming a session.
/// Set to null when no session is active (e.g., on home page).
final currentSessionIdProvider = StateProvider<String?>((ref) => null);

/// Provider for the current VideSession based on the active session ID.
///
/// Returns null if no session is currently active.
/// In remote mode, returns the [RemoteVideSession] instead.
///
/// This is the unified session accessor - use this to get the current session
/// regardless of whether it's local or remote.
final currentVideSessionProvider = Provider<VideSession?>((ref) {
  // Check if we're in remote mode first
  final remoteSession = ref.watch(remoteVideSessionProvider);
  if (remoteSession != null) {
    // Also watch connection state to rebuild when connected
    ref.watch(remoteSessionConnectionProvider);
    return remoteSession;
  }

  // Local mode - use session ID + VideCore lookup
  final sessionId = ref.watch(currentSessionIdProvider);
  if (sessionId == null) return null;

  final core = ref.watch(videoCoreProvider);
  final session = core.getSessionForNetwork(sessionId);

  // Bind the session to the permission handler for late-binding permission checks
  if (session != null) {
    final permissionHandler = ref.read(permissionHandlerProvider);
    permissionHandler.setSession(session);
  }

  return session;
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
