/// VideCore - The single entry point for the vide_core API.
///
/// This provides a clean, simple interface to create and manage
/// multi-agent sessions without exposing internal implementation details.
library;

import 'dart:io';

import 'package:claude_sdk/claude_sdk.dart';
import 'package:riverpod/riverpod.dart';
import 'package:uuid/uuid.dart';

import '../agents/main_agent_config.dart';
import '../services/agent_network_manager.dart';
import '../services/agent_network_persistence_manager.dart';
import '../services/claude_client_factory.dart';
import '../services/initial_claude_client.dart';
import '../services/vide_config_manager.dart';
import '../utils/working_dir_provider.dart';
import 'vide_agent.dart';
import 'vide_config.dart';
import 'vide_session.dart';

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
  bool _disposed = false;

  /// Active sessions by ID.
  final Map<String, VideSession> _activeSessions = {};

  VideCore._(this._container);

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

    return VideCore._(container);
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

    // Create the initial client (this mirrors what initialClaudeClientProvider does)
    final agentId = const Uuid().v4();
    final mainAgentConfig = MainAgentConfig.create();

    // We need to create the container first, then create the client using
    // a factory that uses that container's ref
    final sessionContainer = ProviderContainer(
      parent: _container,
      overrides: [
        workingDirProvider.overrideWithValue(config.workingDirectory),
      ],
    );

    final factory = ClaudeClientFactoryImpl(
      getWorkingDirectory: () => config.workingDirectory,
      ref: sessionContainer.read(_providerContainerRefProvider),
    );

    final client = factory.createSync(
      agentId: agentId,
      config: mainAgentConfig,
      networkId: null, // Will be set after network is created
      agentType: 'main',
    );

    // Create InitialClaudeClient wrapper and override the provider
    final initialClient = InitialClaudeClient(
      client: client,
      agentId: agentId,
      workingDirectory: config.workingDirectory,
    );

    // Create a new container with the initialClaudeClientProvider override
    final finalContainer = ProviderContainer(
      parent: _container,
      overrides: [
        workingDirProvider.overrideWithValue(config.workingDirectory),
        initialClaudeClientProvider.overrideWithValue(initialClient),
      ],
    );

    // Create network via AgentNetworkManager
    // This will use our overridden initialClaudeClientProvider
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

    // Dispose the intermediate container (not the final one)
    sessionContainer.dispose();

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
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    // Dispose all active sessions
    for (final session in _activeSessions.values) {
      session.dispose();
    }
    _activeSessions.clear();

    // Dispose the container
    _container.dispose();
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
}

/// Internal provider to get a Ref from the container.
///
/// This is a workaround to access Ref in ClaudeClientFactoryImpl.
final _providerContainerRefProvider = Provider<Ref>((ref) => ref);
