/// Remote (daemon/WebSocket) implementation of [VideSessionManager].
///
/// Wraps [DaemonConnectionNotifier] to provide session lifecycle operations.
/// Merges daemon running sessions with persisted historical sessions for
/// a complete session list.
library;

import 'dart:async';

import 'package:vide_client/vide_client.dart'
    show VideAttachment, VideSession, VideSessionInfo, VideSessionManager,
         VideAgent, VideAgentStatus;
import 'package:vide_core/vide_core.dart' show AgentNetworkPersistenceManager;
import 'package:vide_daemon/vide_daemon.dart' show SessionSummary;

import 'daemon_connection_service.dart';

/// Manages session lifecycle for remote (daemon) sessions.
///
/// Delegates to [DaemonConnectionNotifier] for connection management
/// and session operations. Optimistic session creation is handled
/// internally — callers get a usable [VideSession] immediately.
///
/// Session listing merges daemon's running sessions with persisted
/// historical sessions from [AgentNetworkPersistenceManager], so
/// the TUI shows both active and past sessions.
class RemoteVideSessionManager implements VideSessionManager {
  final DaemonConnectionNotifier _notifier;
  final AgentNetworkPersistenceManager _persistenceManager;
  final StreamController<List<VideSessionInfo>> _sessionsController =
      StreamController<List<VideSessionInfo>>.broadcast();
  StreamSubscription<dynamic>? _eventSubscription;

  RemoteVideSessionManager(this._notifier, this._persistenceManager) {
    // Listen to daemon events for reactive session list updates.
    final events = _notifier.connectEvents();
    if (events != null) {
      _eventSubscription = events.listen((event) {
        // Re-emit session list on any session lifecycle event.
        _emitSessionList();
      });
    }
  }

  @override
  Future<VideSession> createSession({
    required String initialMessage,
    required String workingDirectory,
    String? model,
    String? permissionMode,
    String? team,
    List<VideAttachment>? attachments,
  }) async {
    // Use optimistic creation — returns immediately with a pending session.
    // The HTTP call and WebSocket connection happen in the background.
    final session = _notifier.createSessionOptimistic(
      initialMessage: initialMessage,
      workingDirectory: workingDirectory,
      permissionMode: permissionMode ?? 'ask',
      model: model,
      team: team,
    );
    _emitSessionList();
    return session;
  }

  @override
  Future<VideSession> resumeSession(
    String sessionId, {
    String? workingDirectory,
  }) async {
    return _notifier.connectToSession(sessionId);
  }

  @override
  Future<List<VideSessionInfo>> listSessions({
    String? workingDirectory,
  }) async {
    // Get running sessions from the daemon.
    final summaries = await _notifier.listSessions();
    final runningSessions = summaries
        .map((summary) => _summaryToSessionInfo(summary))
        .toList();
    final runningIds = runningSessions.map((s) => s.id).toSet();

    // Get persisted historical sessions from disk.
    final networks = await _persistenceManager.loadNetworks();
    final historicalSessions = networks
        .where((n) => !runningIds.contains(n.id))
        .map((network) {
          return VideSessionInfo(
            id: network.id,
            goal: network.goal,
            createdAt: network.createdAt,
            lastActiveAt: network.lastActiveAt,
            workingDirectory: network.worktreePath,
            team: network.team,
            agents: network.agents.map((agent) {
              return VideAgent(
                id: agent.id,
                name: agent.name,
                type: agent.type,
                status: VideAgentStatus.idle,
                spawnedBy: agent.spawnedBy,
                taskName: agent.taskName,
                createdAt: agent.createdAt,
                totalInputTokens: agent.totalInputTokens,
                totalOutputTokens: agent.totalOutputTokens,
                totalCacheReadInputTokens: agent.totalCacheReadInputTokens,
                totalCacheCreationInputTokens:
                    agent.totalCacheCreationInputTokens,
                totalCostUsd: agent.totalCostUsd,
              );
            }).toList(),
          );
        })
        .toList();

    // Merge: running sessions first, then historical.
    final sessions = [...runningSessions, ...historicalSessions];
    sessions.sort((a, b) {
      final aTime = a.lastActiveAt ?? a.createdAt;
      final bTime = b.lastActiveAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });
    return sessions;
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    // Try to stop if it's a running daemon session.
    try {
      await _notifier.stopSession(sessionId);
    } catch (_) {
      // Session might not be running on the daemon (historical only).
    }

    // Also remove from persistence.
    await _persistenceManager.deleteNetwork(sessionId);
    _emitSessionList();
  }

  @override
  Stream<List<VideSessionInfo>> get sessionsStream => _sessionsController.stream;

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _sessionsController.close();
  }

  void _emitSessionList() {
    if (_sessionsController.isClosed) return;
    listSessions().then((sessions) {
      if (!_sessionsController.isClosed) {
        _sessionsController.add(sessions);
      }
    });
  }

  static VideSessionInfo _summaryToSessionInfo(SessionSummary summary) {
    return VideSessionInfo(
      id: summary.sessionId,
      goal: summary.goal ?? summary.workingDirectory,
      createdAt: summary.createdAt,
      lastActiveAt: summary.lastActiveAt,
      workingDirectory: summary.workingDirectory,
      // Daemon only provides agent count, not full agent details.
      // Construct placeholder agents for the count.
      agents: List.generate(
        summary.agentCount,
        (i) => VideAgent(
          id: 'daemon-agent-$i',
          name: '',
          type: '',
          status: VideAgentStatus.idle,
          createdAt: summary.createdAt,
        ),
      ),
    );
  }
}
