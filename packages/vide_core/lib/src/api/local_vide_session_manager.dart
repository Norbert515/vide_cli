/// Local (in-process) implementation of [VideSessionManager].
///
/// Operates directly on [ProviderContainer] and [PermissionHandler].
///
/// Supports two modes:
/// - **Shared container** (default): All sessions share one container.
///   Used by the TUI where `agentNetworkManagerProvider` must stay in sync.
/// - **Isolated containers**: Each session gets its own container.
///   Used by the REST server where sessions are independent.
library;

import 'dart:async';
import 'dart:io';

import 'package:claude_sdk/claude_sdk.dart' show Attachment, Message;
import 'package:riverpod/riverpod.dart';
import 'package:vide_interface/vide_interface.dart';

import '../services/agent_network_manager.dart';
import '../services/agent_network_persistence_manager.dart';
import '../services/permission_provider.dart'
    show PermissionHandler, permissionHandlerProvider;
import '../services/vide_config_manager.dart';
import '../utils/dangerously_skip_permissions_provider.dart';
import '../utils/working_dir_provider.dart';
import 'vide_session.dart';

/// Manages session lifecycle for local (in-process) sessions.
///
/// In shared mode (default), uses the provided [ProviderContainer] directly
/// for session creation, keeping `agentNetworkManagerProvider` in sync with
/// TUI state. In isolated mode, creates a fresh container per session so
/// each session has independent providers (used by the REST server).
///
/// Session listing is backed by persistent storage and emits updates
/// via [sessionsStream].
class LocalVideSessionManager implements VideSessionManager {
  final ProviderContainer _container;
  final PermissionHandler _permissionHandler;
  final bool _isolateContainers;
  final StreamController<List<VideSessionInfo>> _sessionsController =
      StreamController<List<VideSessionInfo>>.broadcast();

  /// Active sessions by ID, for disposal on delete.
  final Map<String, VideSession> _activeSessions = {};

  /// Isolated containers by session ID, for disposal.
  final Map<String, ProviderContainer> _sessionContainers = {};

  /// Create a session manager that shares the provided container across
  /// all sessions. Used by the TUI.
  LocalVideSessionManager(this._container, this._permissionHandler)
    : _isolateContainers = false;

  /// Create a session manager that creates an isolated container per session.
  /// Used by the REST server where sessions are independent.
  LocalVideSessionManager.isolated(this._container, this._permissionHandler)
    : _isolateContainers = true;

  ProviderContainer _containerForSession(String workingDirectory) {
    if (!_isolateContainers) return _container;

    final videConfigManager = _container.read(videConfigManagerProvider);
    final skipPermissions = _container.read(dangerouslySkipPermissionsProvider);

    return ProviderContainer(
      overrides: [
        videConfigManagerProvider.overrideWithValue(videConfigManager),
        workingDirProvider.overrideWithValue(workingDirectory),
        permissionHandlerProvider.overrideWithValue(_permissionHandler),
        if (skipPermissions)
          dangerouslySkipPermissionsProvider.overrideWith((ref) => true),
      ],
    );
  }

  @override
  Future<VideSession> createSession({
    String? initialMessage,
    required String workingDirectory,
    String? model,
    String? permissionMode,
    String? team,
    List<VideAttachment>? attachments,
  }) async {
    final sessionContainer = _containerForSession(workingDirectory);
    final manager = sessionContainer.read(agentNetworkManagerProvider.notifier);

    // Build claude message only if initialMessage provided.
    Message? claudeMessage;
    if (initialMessage != null) {
      final claudeAttachments = attachments?.map((a) {
        return Attachment(
          type: a.type,
          path: a.filePath,
          content: a.content,
          mimeType: a.mimeType,
        );
      }).toList();

      claudeMessage = Message(
        text: initialMessage,
        attachments: claudeAttachments,
      );
    }

    final network = await manager.startNew(
      claudeMessage,
      workingDirectory: workingDirectory,
      model: model,
      permissionMode: permissionMode,
      team: team ?? 'enterprise',
    );

    final session = LocalVideSession.create(
      networkId: network.id,
      container: sessionContainer,
    );

    _permissionHandler.setSession(session);
    _activeSessions[session.id] = session;
    if (_isolateContainers) {
      _sessionContainers[session.id] = sessionContainer;
    }

    // Only emit to session list if there's an initial message (active session).
    // Pre-created idle sessions shouldn't appear in the list yet.
    if (initialMessage != null) {
      _emitSessionList();
    }

    return session;
  }

  /// Get a persistence manager scoped to the given working directory.
  ///
  /// When [workingDirectory] is provided, creates a temporary container
  /// to get a persistence manager scoped to that project. Otherwise
  /// uses the root container (which is scoped by its own workingDirProvider).
  AgentNetworkPersistenceManager _persistenceManagerFor(
    String? workingDirectory,
  ) {
    if (workingDirectory == null || !_isolateContainers) {
      return _container.read(agentNetworkPersistenceManagerProvider);
    }

    // In isolated mode with explicit working directory, create a scoped
    // persistence manager directly (avoids creating a full container).
    return AgentNetworkPersistenceManager(
      configManager: _container.read(videConfigManagerProvider),
      projectPath: workingDirectory,
    );
  }

  @override
  Future<VideSession> resumeSession(
    String sessionId, {
    String? workingDirectory,
  }) async {
    // Return existing active session if available.
    if (_activeSessions.containsKey(sessionId)) {
      return _activeSessions[sessionId]!;
    }

    final persistenceManager = _persistenceManagerFor(workingDirectory);
    final networks = await persistenceManager.loadNetworks();
    final network = networks.where((n) => n.id == sessionId).firstOrNull;

    if (network == null) {
      throw ArgumentError('Session not found: $sessionId');
    }

    // Use the network's stored working directory, falling back to the
    // explicitly provided one, then to the current process directory.
    final workingDir =
        network.worktreePath ?? workingDirectory ?? Directory.current.path;
    final sessionContainer = _containerForSession(workingDir);
    final manager = sessionContainer.read(agentNetworkManagerProvider.notifier);
    await manager.resume(network);

    final session = LocalVideSession.create(
      networkId: network.id,
      container: sessionContainer,
    );

    _permissionHandler.setSession(session);
    _activeSessions[session.id] = session;
    if (_isolateContainers) {
      _sessionContainers[session.id] = sessionContainer;
    }

    return session;
  }

  @override
  Future<List<VideSessionInfo>> listSessions({String? workingDirectory}) async {
    final persistenceManager = _persistenceManagerFor(workingDirectory);
    final networks = await persistenceManager.loadNetworks();

    final sessions = networks.map((network) {
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
            totalCacheCreationInputTokens: agent.totalCacheCreationInputTokens,
            totalCostUsd: agent.totalCostUsd,
          );
        }).toList(),
      );
    }).toList();

    sessions.sort((a, b) {
      final aTime = a.lastActiveAt ?? a.createdAt;
      final bTime = b.lastActiveAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });

    return sessions;
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    // Dispose if active.
    final activeSession = _activeSessions.remove(sessionId);
    if (activeSession != null) {
      await activeSession.dispose();
    }

    // Use the session's container for persistence (it has the correct project
    // path), falling back to the root container for non-isolated mode.
    final sessionContainer = _sessionContainers.remove(sessionId);
    final persistenceManager = (sessionContainer ?? _container).read(
      agentNetworkPersistenceManagerProvider,
    );
    await persistenceManager.deleteNetwork(sessionId);

    // Dispose the isolated container after using its persistence manager.
    sessionContainer?.dispose();

    _emitSessionList();
  }

  @override
  Stream<List<VideSessionInfo>> get sessionsStream =>
      _sessionsController.stream;

  @override
  void dispose() {
    // Dispose all active sessions.
    for (final session in _activeSessions.values) {
      session.dispose();
    }
    _activeSessions.clear();

    // Dispose isolated containers.
    for (final container in _sessionContainers.values) {
      container.dispose();
    }
    _sessionContainers.clear();

    _sessionsController.close();
  }

  void _emitSessionList() {
    if (_sessionsController.isClosed) return;
    listSessions().then(
      (sessions) {
        if (!_sessionsController.isClosed) {
          _sessionsController.add(sessions);
        }
      },
      onError: (Object e) {
        print('[LocalVideSessionManager] Error listing sessions: $e');
      },
    );
  }
}
