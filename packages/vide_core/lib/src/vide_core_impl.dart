/// VideCore - The single entry point for the vide_core API.
///
/// This provides a clean, simple interface to create and manage
/// multi-agent sessions without exposing internal implementation details.
library;

import 'dart:io';

import 'package:claude_sdk/claude_sdk.dart';
import 'package:riverpod/riverpod.dart';

import 'services/agent_network_manager.dart';
import 'services/agent_network_persistence_manager.dart';
import 'services/initial_claude_client.dart';
import 'services/permission_provider.dart'
    show PermissionHandler, permissionHandlerProvider;
import 'services/vide_config_manager.dart';
import 'utils/dangerously_skip_permissions_provider.dart';
import 'utils/working_dir_provider.dart';
import 'package:vide_interface/vide_interface.dart';

import 'api/vide_config.dart';
import 'api/vide_session.dart';

/// The main entry point for the vide_core API.
///
/// [VideCore] provides a simple interface to create and manage multi-agent
/// sessions. It handles all the internal wiring (Riverpod providers, Claude SDK
/// integration, etc.) and exposes a clean API.
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
  final ProviderContainer _container;
  final bool _ownsContainer;
  final PermissionHandler _permissionHandler;
  bool _disposed = false;

  /// Active sessions by ID.
  final Map<String, VideSession> _activeSessions = {};

  VideCore._(
    this._container, {
    bool ownsContainer = true,
    required PermissionHandler permissionHandler,
  }) : _ownsContainer = ownsContainer,
       _permissionHandler = permissionHandler;

  /// Create a new VideCore instance.
  ///
  /// The [config] parameter allows customization of the configuration
  /// directory and other settings.
  factory VideCore(VideCoreConfig config) {
    // Determine config directory
    final configDir = config.configDir ?? _defaultConfigDir();

    // Create ProviderContainer with proper overrides
    final container = ProviderContainer(
      overrides: [
        // Override config manager
        videConfigManagerProvider.overrideWithValue(
          VideConfigManager(configRoot: configDir),
        ),
        // Working directory will be set per-session
        workingDirProvider.overrideWithValue(Directory.current.path),
      ],
    );

    return VideCore._(
      container,
      ownsContainer: true,
      permissionHandler: config.permissionHandler,
    );
  }

  /// Create a VideCore instance from an existing ProviderContainer.
  ///
  /// This is useful for integrating with existing applications that already
  /// have a ProviderContainer with their own overrides.
  ///
  /// The container will NOT be disposed when VideCore is disposed. The caller
  /// is responsible for managing the container lifecycle.
  ///
  /// [permissionHandler] is required and handles tool permission requests.
  ///
  /// Example:
  /// ```dart
  /// final container = ProviderContainer(overrides: [...]);
  /// final handler = PermissionHandler();
  /// final core = VideCore.fromContainer(container, permissionHandler: handler);
  /// // ... use core
  /// core.dispose(); // Does NOT dispose container
  /// container.dispose(); // Caller disposes container
  /// ```
  factory VideCore.fromContainer(
    ProviderContainer container, {
    required PermissionHandler permissionHandler,
  }) {
    return VideCore._(
      container,
      ownsContainer: false,
      permissionHandler: permissionHandler,
    );
  }

  /// Start a new session with the given configuration.
  ///
  /// This creates a new agent network with a main agent and sends
  /// the initial message. Returns a [VideSession] that can be used
  /// to interact with the agents and receive events.
  ///
  /// Example:
  /// ```dart
  /// final session = await core.startSession(VideSessionConfig(
  ///   workingDirectory: '/path/to/project',
  ///   initialMessage: 'What files are in this project?',
  ///   model: 'sonnet',
  /// ));
  /// ```
  Future<VideSession> startSession(VideSessionConfig config) async {
    _checkNotDisposed();

    // Get config from parent container
    final videConfigManager = _container.read(videConfigManagerProvider);
    final skipPermissions = _container.read(dangerouslySkipPermissionsProvider);

    // Use the permission handler passed to VideCore (shared across sessions)
    final permissionHandler = _permissionHandler;

    // Create a completely isolated container for this session.
    // We don't use parent containers because Riverpod's dependency tracking
    // requires all providers in the dependency chain to be overridden when
    // any dependency is overridden, which becomes unwieldy.
    final finalContainer = ProviderContainer(
      overrides: [
        // Copy config from parent
        videConfigManagerProvider.overrideWithValue(videConfigManager),
        // Set the working directory for this session
        workingDirProvider.overrideWithValue(config.workingDirectory),
        // Provide permission handler for late session binding
        permissionHandlerProvider.overrideWithValue(permissionHandler),
        // Copy skip permissions flag from parent
        if (skipPermissions)
          dangerouslySkipPermissionsProvider.overrideWith((ref) => true),
      ],
    );

    // Create network via AgentNetworkManager
    // The initialClaudeClientProvider will be lazily evaluated when first accessed,
    // which will load the main agent configuration from the team framework
    final manager = finalContainer.read(agentNetworkManagerProvider.notifier);
    final network = await manager.startNew(
      Message.text(config.initialMessage),
      workingDirectory: config.workingDirectory,
      model: config.model,
      permissionMode: config.permissionMode,
      team: config.team,
    );

    // Create the session
    final session = LocalVideSession.create(
      networkId: network.id,
      container: finalContainer,
      initialMessage: config.initialMessage,
    );

    // Bind session to permission handler (enables late binding)
    permissionHandler.setSession(session);

    _activeSessions[session.id] = session;
    return session;
  }

  /// Start a new session with a Message object.
  ///
  /// This is similar to [startSession] but accepts a [VideMessage] object
  /// instead of a plain string. This allows TUI to include attachments
  /// with the initial message.
  ///
  /// Example:
  /// ```dart
  /// final session = await core.startSessionWithMessage(
  ///   VideMessage(text: 'Fix the bug', attachments: [VideAttachment.file('error.log')]),
  ///   workingDirectory: '/path/to/project',
  /// );
  /// ```
  Future<VideSession> startSessionWithMessage(
    VideMessage message, {
    required String workingDirectory,
    String? model,
    String? permissionMode,
    String? team,
  }) async {
    _checkNotDisposed();

    // Use the permission handler passed to VideCore (shared across sessions)
    final permissionHandler = _permissionHandler;

    // Determine which container to use:
    // - If we own the container (standalone VideCore), create an isolated container
    // - If we don't own it (fromContainer), use the shared container so providers
    //   like agentNetworkManagerProvider stay in sync with the caller's container
    final ProviderContainer sessionContainer;
    if (_ownsContainer) {
      // Create a completely isolated container for this session.
      // We don't use parent containers because Riverpod's dependency tracking
      // requires all providers in the dependency chain to be overridden when
      // any dependency is overridden, which becomes unwieldy.
      final videConfigManager = _container.read(videConfigManagerProvider);
      final skipPermissions = _container.read(
        dangerouslySkipPermissionsProvider,
      );
      sessionContainer = ProviderContainer(
        overrides: [
          // Copy config from parent
          videConfigManagerProvider.overrideWithValue(videConfigManager),
          // Set the working directory for this session
          workingDirProvider.overrideWithValue(workingDirectory),
          // Provide permission handler for late session binding
          permissionHandlerProvider.overrideWithValue(permissionHandler),
          // Copy skip permissions flag from parent
          if (skipPermissions)
            dangerouslySkipPermissionsProvider.overrideWith((ref) => true),
        ],
      );
    } else {
      // Use shared container - this keeps agentNetworkManagerProvider in sync
      // with the caller's container (important for TUI provider watching)
      sessionContainer = _container;
    }

    // Create network via AgentNetworkManager
    // The initialClaudeClientProvider will be lazily evaluated when first accessed,
    // which will load the main agent configuration from the team framework
    final manager = sessionContainer.read(agentNetworkManagerProvider.notifier);
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

    // Create the session
    final session = LocalVideSession.create(
      networkId: network.id,
      container: sessionContainer,
      initialMessage: message.text,
    );

    // Bind session to permission handler (enables late binding)
    permissionHandler.setSession(session);

    _activeSessions[session.id] = session;
    return session;
  }

  /// Resume an existing session by its ID.
  ///
  /// This loads the session from persistent storage and recreates
  /// the agent network. Returns a [VideSession] for interaction.
  ///
  /// Throws [ArgumentError] if the session is not found.
  ///
  /// Example:
  /// ```dart
  /// final session = await core.resumeSession('session-uuid');
  /// ```
  Future<VideSession> resumeSession(String sessionId) async {
    _checkNotDisposed();

    // Check if session is already active
    if (_activeSessions.containsKey(sessionId)) {
      return _activeSessions[sessionId]!;
    }

    // Load network from persistence
    final persistenceManager = _container.read(
      agentNetworkPersistenceManagerProvider,
    );
    final networks = await persistenceManager.loadNetworks();
    final network = networks.where((n) => n.id == sessionId).firstOrNull;

    if (network == null) {
      throw ArgumentError('Session not found: $sessionId');
    }

    // Determine working directory from network
    final workingDir = network.worktreePath ?? Directory.current.path;

    // Get config from parent container
    final videConfigManager = _container.read(videConfigManagerProvider);
    final skipPermissions = _container.read(dangerouslySkipPermissionsProvider);

    // Use the permission handler passed to VideCore (shared across sessions)
    final permissionHandler = _permissionHandler;

    // Create a completely isolated container for this session.
    // We don't use parent containers because Riverpod's dependency tracking
    // requires all providers in the dependency chain to be overridden when
    // any dependency is overridden, which becomes unwieldy.
    final sessionContainer = ProviderContainer(
      overrides: [
        // Copy config from parent
        videConfigManagerProvider.overrideWithValue(videConfigManager),
        // Set the working directory for this session
        workingDirProvider.overrideWithValue(workingDir),
        // Provide permission handler for late session binding
        permissionHandlerProvider.overrideWithValue(permissionHandler),
        // Copy skip permissions flag from parent
        if (skipPermissions)
          dangerouslySkipPermissionsProvider.overrideWith((ref) => true),
      ],
    );

    // Resume the network
    final manager = sessionContainer.read(agentNetworkManagerProvider.notifier);
    await manager.resume(network);

    // Create the session
    final session = LocalVideSession.create(
      networkId: network.id,
      container: sessionContainer,
    );

    // Bind session to permission handler (enables late binding)
    permissionHandler.setSession(session);

    _activeSessions[session.id] = session;
    return session;
  }

  /// List all available sessions.
  ///
  /// Returns session info for all persisted sessions, including
  /// agent counts and timestamps.
  Future<List<VideSessionInfo>> listSessions() async {
    _checkNotDisposed();

    final persistenceManager = _container.read(
      agentNetworkPersistenceManagerProvider,
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
  /// This is useful when using [fromContainer] with an existing application
  /// that manages networks via the internal [AgentNetworkManager]. It wraps
  /// the current network as a [VideSession] for use with the public API.
  ///
  /// Returns null if no network with [networkId] is currently active.
  ///
  /// Example:
  /// ```dart
  /// // In an app using fromContainer()
  /// final networkState = container.read(agentNetworkManagerProvider);
  /// final currentNetwork = networkState.currentNetwork;
  /// if (currentNetwork != null) {
  ///   final session = core.getSessionForNetwork(currentNetwork.id);
  ///   // Use session.events, session.sendMessage(), etc.
  /// }
  /// ```
  VideSession? getSessionForNetwork(String networkId) {
    _checkNotDisposed();

    // Return existing session if already created
    if (_activeSessions.containsKey(networkId)) {
      return _activeSessions[networkId];
    }

    // Check if network exists in the manager
    final networkState = _container.read(agentNetworkManagerProvider);
    if (networkState.currentNetwork?.id != networkId) {
      return null;
    }

    // Create a session wrapper for this network
    final session = LocalVideSession.create(
      networkId: networkId,
      container: _container,
    );

    // Bind session to permission handler (enables late binding)
    _permissionHandler.setSession(session);

    _activeSessions[networkId] = session;
    return session;
  }

  /// Delete a session by its ID.
  ///
  /// This removes the session from persistent storage. If the session
  /// is currently active, it is disposed first.
  Future<void> deleteSession(String sessionId) async {
    _checkNotDisposed();

    // Dispose if active
    final activeSession = _activeSessions.remove(sessionId);
    if (activeSession != null) {
      await activeSession.dispose();
    }

    // Delete from persistence
    final persistenceManager = _container.read(
      agentNetworkPersistenceManagerProvider,
    );
    await persistenceManager.deleteNetwork(sessionId);
  }

  /// Dispose the VideCore instance and all active sessions.
  ///
  /// After calling dispose, the instance can no longer be used.
  /// If the VideCore was created with [fromContainer], the container
  /// is NOT disposed (caller is responsible for container lifecycle).
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    // Dispose all active sessions
    for (final session in _activeSessions.values) {
      session.dispose();
    }
    _activeSessions.clear();

    // Only dispose the container if we own it
    if (_ownsContainer) {
      _container.dispose();
    }
  }

  void _checkNotDisposed() {
    if (_disposed) {
      throw StateError('VideCore has been disposed');
    }
  }

  static String _defaultConfigDir() {
    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    return '$home/.vide';
  }

  /// The initial Claude client for pre-warming and MCP status.
  ///
  /// This is created lazily on first access. Useful for:
  /// - Pre-warming Claude CLI before user submits first message
  /// - Displaying MCP server status in UI
  ///
  /// Note: The client is reused across sessions when using [fromContainer].
  InitialClaudeClient get initialClient {
    _checkNotDisposed();
    return _container.read(initialClaudeClientProvider);
  }

  /// Current MCP server status, or null if not yet fetched.
  ///
  /// This is a convenience getter that returns [initialClient.mcpStatus].
  McpStatusResponse? get mcpStatus => initialClient.mcpStatus;

  /// Stream of MCP status updates.
  ///
  /// This is a convenience getter that returns [initialClient.mcpStatusStream].
  Stream<McpStatusResponse> get mcpStatusStream =>
      initialClient.mcpStatusStream;
}
