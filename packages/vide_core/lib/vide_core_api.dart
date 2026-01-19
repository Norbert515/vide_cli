/// VideCore - The single entry point for the vide_core API.
///
/// This provides a clean, simple interface to create and manage
/// multi-agent sessions without exposing internal implementation details.
library;

import 'dart:io';

import 'package:claude_sdk/claude_sdk.dart';
import 'package:riverpod/riverpod.dart';

import 'src/services/agent_network_manager.dart';
import 'src/services/agent_network_persistence_manager.dart';
import 'src/services/initial_claude_client.dart';
import 'src/services/vide_config_manager.dart';
import 'src/utils/working_dir_provider.dart';
import 'src/api/vide_agent.dart';
import 'src/api/vide_config.dart';
import 'src/api/vide_session.dart';

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
  bool _disposed = false;

  /// Active sessions by ID.
  final Map<String, VideSession> _activeSessions = {};

  VideCore._(this._container, {bool ownsContainer = true})
      : _ownsContainer = ownsContainer;

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

    return VideCore._(container, ownsContainer: true);
  }

  /// Create a VideCore instance from an existing ProviderContainer.
  ///
  /// This is useful for integrating with existing applications that already
  /// have a ProviderContainer with their own overrides (e.g., for permissions).
  ///
  /// The container will NOT be disposed when VideCore is disposed. The caller
  /// is responsible for managing the container lifecycle.
  ///
  /// Example:
  /// ```dart
  /// final container = ProviderContainer(overrides: [...]);
  /// final core = VideCore.fromContainer(container);
  /// // ... use core
  /// core.dispose(); // Does NOT dispose container
  /// container.dispose(); // Caller disposes container
  /// ```
  factory VideCore.fromContainer(ProviderContainer container) {
    return VideCore._(container, ownsContainer: false);
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

    // Create a new container for this session
    final finalContainer = ProviderContainer(
      parent: _container,
      overrides: [
        workingDirProvider.overrideWithValue(config.workingDirectory),
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
    );

    // Create and return the session
    final session = VideSession.create(
      networkId: network.id,
      container: finalContainer,
    );

    _activeSessions[session.id] = session;
    return session;
  }

  /// Start a new session with a Message object.
  ///
  /// This is similar to [startSession] but accepts a [Message] object
  /// instead of a plain string. This allows TUI to include attachments
  /// with the initial message.
  ///
  /// Example:
  /// ```dart
  /// final session = await core.startSessionWithMessage(
  ///   Message(text: 'Fix the bug', attachments: [Attachment.file('error.log')]),
  ///   workingDirectory: '/path/to/project',
  /// );
  /// ```
  Future<VideSession> startSessionWithMessage(
    Message message, {
    required String workingDirectory,
    String? model,
    String? permissionMode,
  }) async {
    _checkNotDisposed();

    // Create a new container for this session
    final finalContainer = ProviderContainer(
      parent: _container,
      overrides: [
        workingDirProvider.overrideWithValue(workingDirectory),
      ],
    );

    // Create network via AgentNetworkManager
    // The initialClaudeClientProvider will be lazily evaluated when first accessed,
    // which will load the main agent configuration from the team framework
    final manager = finalContainer.read(agentNetworkManagerProvider.notifier);
    final network = await manager.startNew(
      message,
      workingDirectory: workingDirectory,
      model: model,
      permissionMode: permissionMode,
    );

    // Create and return the session
    final session = VideSession.create(
      networkId: network.id,
      container: finalContainer,
    );

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
    final persistenceManager = _container.read(agentNetworkPersistenceManagerProvider);
    final networks = await persistenceManager.loadNetworks();
    final network = networks.where((n) => n.id == sessionId).firstOrNull;

    if (network == null) {
      throw ArgumentError('Session not found: $sessionId');
    }

    // Determine working directory from network
    final workingDir = network.worktreePath ?? Directory.current.path;

    // Create a new container for this session
    final sessionContainer = ProviderContainer(
      parent: _container,
      overrides: [
        workingDirProvider.overrideWithValue(workingDir),
      ],
    );

    // Resume the network
    final manager = sessionContainer.read(agentNetworkManagerProvider.notifier);
    await manager.resume(network);

    // Create and return the session
    final session = VideSession.create(
      networkId: network.id,
      container: sessionContainer,
    );

    _activeSessions[session.id] = session;
    return session;
  }

  /// List all available sessions.
  ///
  /// Returns session info for all persisted sessions, including
  /// agent counts and timestamps.
  Future<List<VideSessionInfo>> listSessions() async {
    _checkNotDisposed();

    final persistenceManager = _container.read(agentNetworkPersistenceManagerProvider);
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
            status: VideAgentStatus.idle, // We don't have live status for inactive sessions
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
    final session = VideSession.create(
      networkId: networkId,
      container: _container,
    );

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
    final persistenceManager = _container.read(agentNetworkPersistenceManagerProvider);
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
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
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
  Stream<McpStatusResponse> get mcpStatusStream => initialClient.mcpStatusStream;
}
