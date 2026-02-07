import 'dart:async';

import 'package:riverpod/riverpod.dart';
import 'package:vide_core/vide_core.dart';

import 'vide_session_providers.dart';

final agentNetworksStateNotifierProvider =
    StateNotifierProvider<AgentNetworksStateNotifier, AgentNetworksState>((
      ref,
    ) {
      final sessionManager = ref.watch(videSessionManagerProvider);
      final notifier = AgentNetworksStateNotifier(sessionManager);
      ref.onDispose(notifier.dispose);
      return notifier;
    });

class AgentNetworksState {
  AgentNetworksState({required this.sessions});

  final List<VideSessionInfo> sessions;

  AgentNetworksState copyWith({List<VideSessionInfo>? sessions}) {
    return AgentNetworksState(sessions: sessions ?? this.sessions);
  }

  /// Backward-compatible alias for session count.
  @Deprecated('Use sessions')
  List<VideSessionInfo> get networks => sessions;
}

class AgentNetworksStateNotifier extends StateNotifier<AgentNetworksState> {
  AgentNetworksStateNotifier(this._sessionManager)
    : super(AgentNetworksState(sessions: [])) {
    _subscription = _sessionManager.sessionsStream.listen((sessions) {
      if (mounted) {
        state = state.copyWith(sessions: sessions);
      }
    });
  }

  final VideSessionManager _sessionManager;
  StreamSubscription<List<VideSessionInfo>>? _subscription;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await reload();
  }

  /// Reload sessions from the session manager.
  Future<void> reload() async {
    final sessions = await _sessionManager.listSessions();
    if (mounted) {
      state = state.copyWith(sessions: sessions);
    }
  }

  /// Delete a session by index.
  Future<void> deleteSession(int index) async {
    final session = state.sessions[index];
    await _sessionManager.deleteSession(session.id);

    final updated = [...state.sessions];
    updated.removeAt(index);
    if (mounted) {
      state = state.copyWith(sessions: updated);
    }
  }

  /// Delete a session by ID.
  Future<void> deleteSessionById(String sessionId) async {
    await _sessionManager.deleteSession(sessionId);

    final updated = state.sessions.where((s) => s.id != sessionId).toList();
    if (mounted) {
      state = state.copyWith(sessions: updated);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
