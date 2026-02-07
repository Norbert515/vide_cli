/// VideCore - The single entry point for the vide_core API.
///
/// This provides a clean, simple interface to create and manage
/// multi-agent sessions without exposing internal implementation details.
library;

import 'dart:io';

import 'package:claude_sdk/claude_sdk.dart';

import 'services/agent_network_persistence_manager.dart';
import 'services/permission_provider.dart' show PermissionHandler;
import 'services/session_services.dart';
import 'services/vide_config_manager.dart';
import 'package:vide_interface/vide_interface.dart';

import 'api/vide_config.dart';
import 'api/vide_session.dart';

/// The main entry point for the vide_core API.
///
/// [VideCore] provides a simple interface to create and manage multi-agent
/// sessions. It handles all the internal wiring and exposes a clean API.
///
/// Example:
/// ```dart
/// // Create VideCore instance
/// final core = VideCore(VideCoreConfig(
///   configDir: '~/.vide',
/// ));
///
/// // Start a new session
/// final session = await core.startSession(VideSessionConfig(
///   workingDirectory: '/path/to/project',
///   initialMessage: 'Help me fix the bug in auth.dart',
/// ));
///
/// // Listen to events
/// session.events.listen((event) {
///   switch (event) {
///     case MessageEvent e:
///       print(e.content);
///     // ... handle other events
///   }
/// });
///
/// // Clean up
/// await session.dispose();
/// core.dispose();
/// ```
class VideCore {
  final VideConfigManager _configManager;
  final PermissionHandler _permissionHandler;
  final bool _dangerouslySkipPermissions;
  bool _disposed = false;

  /// Active sessions by ID.
  final Map<String, VideSession> _activeSessions = {};

  /// Session services by session ID, for sessions we own.
  final Map<String, SessionServices> _ownedServices = {};

  /// Externally-provided SessionServices (for fromSessionServices factory).
  SessionServices? _externalServices;

  VideCore._({
    required VideConfigManager configManager,
    required PermissionHandler permissionHandler,
    bool dangerouslySkipPermissions = false,
    SessionServices? externalServices,
  }) : _configManager = configManager,
       _permissionHandler = permissionHandler,
       _dangerouslySkipPermissions = dangerouslySkipPermissions,
       _externalServices = externalServices;

  /// Create a new VideCore instance.
  ///
  /// The [config] parameter allows customization of the configuration
  /// directory and other settings.
  factory VideCore(VideCoreConfig config) {
    // Determine config directory
    final configDir = config.configDir ?? _defaultConfigDir();

    return VideCore._(
      configManager: VideConfigManager(configRoot: configDir),
      permissionHandler: config.permissionHandler,
    );
  }

  /// Create a VideCore instance from externally-provided SessionServices.
  ///
  /// This is useful for integrating with existing applications (like the TUI)
  /// that manage their own service wiring. The SessionServices will NOT be
  /// disposed when VideCore is disposed.
  ///
  /// [permissionHandler] is required and handles tool permission requests.
  factory VideCore.fromSessionServices(
    SessionServices services, {
    required PermissionHandler permissionHandler,
  }) {
    return VideCore._(
      configManager: services.configManager,
      permissionHandler: permissionHandler,
      dangerouslySkipPermissions: services.dangerouslySkipPermissions,
      externalServices: services,
    );
  }

  /// Start a new session with the given configuration.
  Future<VideSession> startSession(VideSessionConfig config) async {
    _checkNotDisposed();

    final services = _createSessionServices(config.workingDirectory);

    // Create network via AgentNetworkManager
    final manager = services.networkManager;
    final network = await manager.startNew(
      Message.text(config.initialMessage),
      workingDirectory: config.workingDirectory,
      model: config.model,
      permissionMode: config.permissionMode,
      team: config.team,
    );

    // Track owned services
    if (_externalServices == null) {
      _ownedServices[network.id] = services;
    }

    // Create the session
    final session = LocalVideSession.create(
      networkId: network.id,
      services: services,
      initialMessage: config.initialMessage,
    );

    // Bind session to permission handler (enables late binding)
    _permissionHandler.setSession(session);

    _activeSessions[session.id] = session;
    return session;
  }

  /// Start a new session with a Message object.
  ///
  /// This is similar to [startSession] but accepts a [VideMessage] object
  /// instead of a plain string. This allows TUI to include attachments
  /// with the initial message.
  Future<VideSession> startSessionWithMessage(
    VideMessage message, {
    required String workingDirectory,
    String? model,
    String? permissionMode,
    String? team,
  }) async {
    _checkNotDisposed();

    final services = _createSessionServices(workingDirectory);

    // Create network via AgentNetworkManager
    final manager = services.networkManager;
    // Convert VideMessage to claude_sdk Message for internal use
    final claudeAttachments = message.attachments?.map((a) {
      return Attachment(
        type: a.type,
        path: a.filePath,
        content: a.content,
        mimeType: a.mimeType,
      );
    }).toList();
    final claudeMessage = Message(
      text: message.text,
      attachments: claudeAttachments,
    );
    final network = await manager.startNew(
      claudeMessage,
      workingDirectory: workingDirectory,
      model: model,
      permissionMode: permissionMode,
      team: team ?? 'vide',
    );

    // Track owned services
    if (_externalServices == null) {
      _ownedServices[network.id] = services;
    }

    // Create the session
    final session = LocalVideSession.create(
      networkId: network.id,
      services: services,
      initialMessage: message.text,
    );

    // Bind session to permission handler (enables late binding)
    _permissionHandler.setSession(session);

    _activeSessions[session.id] = session;
    return session;
  }

  /// Resume an existing session by its ID.
  Future<VideSession> resumeSession(String sessionId) async {
    _checkNotDisposed();

    // Check if session is already active
    if (_activeSessions.containsKey(sessionId)) {
      return _activeSessions[sessionId]!;
    }

    // Load network from persistence
    final persistenceManager = AgentNetworkPersistenceManager(
      configManager: _configManager,
    );
    final networks = await persistenceManager.loadNetworks();
    final network = networks.where((n) => n.id == sessionId).firstOrNull;

    if (network == null) {
      throw ArgumentError('Session not found: $sessionId');
    }

    // Determine working directory from network
    final workingDir = network.worktreePath ?? Directory.current.path;

    final services = _createSessionServices(workingDir);

    // Track owned services
    if (_externalServices == null) {
      _ownedServices[network.id] = services;
    }

    // Resume the network
    final manager = services.networkManager;
    await manager.resume(network);

    // Create the session
    final session = LocalVideSession.create(
      networkId: network.id,
      services: services,
    );

    // Bind session to permission handler (enables late binding)
    _permissionHandler.setSession(session);

    _activeSessions[session.id] = session;
    return session;
  }

  /// List all available sessions.
  Future<List<VideSessionInfo>> listSessions() async {
    _checkNotDisposed();

    final persistenceManager = AgentNetworkPersistenceManager(
      configManager: _configManager,
    );
    final networks = await persistenceManager.loadNetworks();

    return networks.map((network) {
      return VideSessionInfo(
        id: network.id,
        goal: network.goal,
        createdAt: network.createdAt,
        lastActiveAt: network.lastActiveAt,
        workingDirectory: network.worktreePath,
        agents: network.agents.map((agent) {
          return VideAgent(
            id: agent.id,
            name: agent.name,
            type: agent.type,
            status: VideAgentStatus
                .idle, // We don't have live status for inactive sessions
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
  }

  /// Get or create a VideSession for an existing network.
  ///
  /// This is useful when using [fromSessionServices] with an existing
  /// application that manages networks via the internal [AgentNetworkManager].
  VideSession? getSessionForNetwork(String networkId) {
    _checkNotDisposed();

    // Return existing session if already created
    if (_activeSessions.containsKey(networkId)) {
      return _activeSessions[networkId];
    }

    // Must have external services for this path
    final services = _externalServices;
    if (services == null) return null;

    // Check if network exists in the manager
    final networkState = services.networkManager.state;
    if (networkState.currentNetwork?.id != networkId) {
      return null;
    }

    // Create a session wrapper for this network
    final session = LocalVideSession.create(
      networkId: networkId,
      services: services,
    );

    // Bind session to permission handler (enables late binding)
    _permissionHandler.setSession(session);

    _activeSessions[networkId] = session;
    return session;
  }

  /// Delete a session by its ID.
  Future<void> deleteSession(String sessionId) async {
    _checkNotDisposed();

    // Dispose if active
    final activeSession = _activeSessions.remove(sessionId);
    if (activeSession != null) {
      await activeSession.dispose();
    }

    // Dispose owned services
    final services = _ownedServices.remove(sessionId);
    services?.dispose();

    // Delete from persistence
    final persistenceManager = AgentNetworkPersistenceManager(
      configManager: _configManager,
    );
    await persistenceManager.deleteNetwork(sessionId);
  }

  /// Dispose the VideCore instance and all active sessions.
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    // Dispose all active sessions
    for (final session in _activeSessions.values) {
      session.dispose();
    }
    _activeSessions.clear();

    // Dispose all owned services
    for (final services in _ownedServices.values) {
      services.dispose();
    }
    _ownedServices.clear();
  }

  void _checkNotDisposed() {
    if (_disposed) {
      throw StateError('VideCore has been disposed');
    }
  }

  SessionServices _createSessionServices(String workingDirectory) {
    // If we have external services (fromSessionServices), use those
    if (_externalServices != null) {
      return _externalServices!;
    }

    // Create a new SessionServices for this session
    return SessionServices(
      workingDirectory: workingDirectory,
      configManager: _configManager,
      permissionHandler: _permissionHandler,
      dangerouslySkipPermissions: _dangerouslySkipPermissions,
    );
  }

  static String _defaultConfigDir() {
    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    return '$home/.vide';
  }
}
