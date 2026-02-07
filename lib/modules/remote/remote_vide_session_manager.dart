/// Remote (daemon/WebSocket) implementation of [VideSessionManager].
///
/// Wraps [DaemonConnectionNotifier] to provide session lifecycle operations.
library;

import 'dart:async';

import 'package:vide_client/vide_client.dart'
    show VideAttachment, VideSession, VideSessionInfo, VideSessionManager,
         VideAgent, VideAgentStatus;
import 'package:vide_daemon/vide_daemon.dart' show SessionSummary;

import 'daemon_connection_service.dart';

/// Manages session lifecycle for remote (daemon) sessions.
///
/// Delegates to [DaemonConnectionNotifier] for connection management
/// and session operations. Optimistic session creation is handled
/// internally — callers get a usable [VideSession] immediately.
class RemoteVideSessionManager implements VideSessionManager {
  final DaemonConnectionNotifier _notifier;
  final StreamController<List<VideSessionInfo>> _sessionsController =
      StreamController<List<VideSessionInfo>>.broadcast();
  StreamSubscription<dynamic>? _eventSubscription;

  RemoteVideSessionManager(this._notifier) {
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
  Future<VideSession> resumeSession(String sessionId) async {
    return _notifier.connectToSession(sessionId);
  }

  @override
  Future<List<VideSessionInfo>> listSessions() async {
    final summaries = await _notifier.listSessions();
    final sessions = summaries
        .map((summary) => _summaryToSessionInfo(summary))
        .toList();
    sessions.sort((a, b) {
      final aTime = a.lastActiveAt ?? a.createdAt;
      final bTime = b.lastActiveAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });
    return sessions;
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    await _notifier.stopSession(sessionId);
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
