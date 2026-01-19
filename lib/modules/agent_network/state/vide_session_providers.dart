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

/// Provider for the current VideSession based on the active network.
///
/// Returns null if no network is currently active.
final currentVideSessionProvider = Provider<VideSession?>((ref) {
  final core = ref.watch(videoCoreProvider);
  final networkState = ref.watch(agentNetworkManagerProvider);
  final currentNetwork = networkState.currentNetwork;

  if (currentNetwork == null) return null;

  return core.getSessionForNetwork(currentNetwork.id);
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
/// Defaults to 'vide-classic' if not set.
/// This should be persisted to settings when changed.
final currentTeamProvider = StateProvider<String>((ref) {
  return 'vide-classic';
});

/// Provider for the current team definition.
///
/// Loads the full TeamDefinition for the currently selected team.
/// Returns null if the team is not found.
final currentTeamDefinitionProvider = FutureProvider<TeamDefinition?>((ref) async {
  final teamName = ref.watch(currentTeamProvider);
  final loader = ref.watch(teamFrameworkLoaderProvider);
  return await loader.getTeam(teamName);
});

/// Provider for the selected agent ID in the sidebar.
///
/// When null, no agent is selected.
/// Used by AgentSidebar for keyboard navigation and selection.
final selectedAgentIdProvider = StateProvider<String?>((ref) => null);

/// State for the embedded server.
class EmbeddedServerState {
  final VideEmbeddedServer? server;
  final bool isStarting;
  final String? error;

  const EmbeddedServerState({
    this.server,
    this.isStarting = false,
    this.error,
  });

  bool get isRunning => server != null;
  String? get url => server != null ? 'http://localhost:${server!.port}' : null;
  String? get wsUrl => server != null ? 'ws://localhost:${server!.port}/ws' : null;

  EmbeddedServerState copyWith({
    VideEmbeddedServer? server,
    bool? isStarting,
    String? error,
    bool clearServer = false,
    bool clearError = false,
  }) {
    return EmbeddedServerState(
      server: clearServer ? null : (server ?? this.server),
      isStarting: isStarting ?? this.isStarting,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier for managing the embedded server lifecycle.
class EmbeddedServerNotifier extends StateNotifier<EmbeddedServerState> {
  final Ref _ref;

  EmbeddedServerNotifier(this._ref) : super(const EmbeddedServerState());

  /// Start the embedded server on the given port.
  Future<void> start({int port = 8080}) async {
    if (state.isRunning || state.isStarting) return;

    final session = _ref.read(currentVideSessionProvider);
    if (session == null) {
      state = state.copyWith(error: 'No active session');
      return;
    }

    state = state.copyWith(isStarting: true, clearError: true);

    try {
      final server = await VideEmbeddedServer.start(
        session: session,
        port: port,
      );
      state = EmbeddedServerState(server: server);
    } catch (e) {
      state = state.copyWith(isStarting: false, error: e.toString());
    }
  }

  /// Stop the embedded server.
  Future<void> stop() async {
    final server = state.server;
    if (server == null) return;

    await server.stop();
    state = const EmbeddedServerState();
  }

  @override
  void dispose() {
    state.server?.stop();
    super.dispose();
  }
}

/// Provider for managing the embedded server state.
final embeddedServerProvider =
    StateNotifierProvider<EmbeddedServerNotifier, EmbeddedServerState>((ref) {
  return EmbeddedServerNotifier(ref);
});
