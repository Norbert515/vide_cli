import 'dart:async';
import 'dart:developer' as developer;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vide_client/vide_client.dart';

import '../../domain/models/server_connection.dart';
import '../../domain/services/session_list_manager.dart';
import '../local/settings_storage.dart';

part 'server_registry.g.dart';

/// Health status of a server connection.
enum ServerHealthStatus {
  connected,
  connecting,
  disconnected,
  error,
}

/// A server entry in the registry, combining connection config with runtime state.
class ServerEntry {
  final ServerConnection connection;
  final VideClient? client;
  final ServerHealthStatus status;
  final String? errorMessage;

  const ServerEntry({
    required this.connection,
    this.client,
    this.status = ServerHealthStatus.disconnected,
    this.errorMessage,
  });

  ServerEntry copyWith({
    ServerConnection? connection,
    VideClient? client,
    bool clearClient = false,
    ServerHealthStatus? status,
    String? errorMessage,
  }) {
    return ServerEntry(
      connection: connection ?? this.connection,
      client: clearClient ? null : (client ?? this.client),
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }
}

/// Registry for managing multiple server connections.
///
/// Replaces the single-server [ConnectionRepository] with support for
/// multiple named servers, each with independent health status.
@Riverpod(keepAlive: true)
class ServerRegistry extends _$ServerRegistry {
  Timer? _healthCheckTimer;
  Completer<void>? _loadCompleter;
  final Map<String, DaemonConnection> _daemonConnections = {};
  final Map<String, StreamSubscription<DaemonEvent>> _daemonSubscriptions = {};

  void _log(String message) {
    developer.log(message, name: 'ServerRegistry');
  }

  @override
  Map<String, ServerEntry> build() {
    ref.onDispose(() {
      _healthCheckTimer?.cancel();
      for (final sub in _daemonSubscriptions.values) {
        sub.cancel();
      }
      _daemonSubscriptions.clear();
      for (final conn in _daemonConnections.values) {
        conn.dispose();
      }
      _daemonConnections.clear();
    });

    // Load servers on init
    _loadCompleter = Completer<void>();
    _loadServers();

    return const {};
  }

  /// Waits until servers have been loaded from storage.
  Future<void> get loaded => _loadCompleter?.future ?? Future.value();

  Future<void> _loadServers() async {
    final storage = ref.read(settingsStorageProvider.notifier);
    final servers = await storage.getServers();

    final entries = <String, ServerEntry>{};
    for (final server in servers) {
      entries[server.id] = ServerEntry(connection: server);
    }
    state = entries;
    _loadCompleter?.complete();
  }

  /// Adds a new server and persists it.
  Future<void> addServer(ServerConnection server) async {
    final storage = ref.read(settingsStorageProvider.notifier);
    await storage.addServer(server);

    state = {
      ...state,
      server.id: ServerEntry(connection: server),
    };
  }

  /// Removes a server by ID and persists the change.
  Future<void> removeServer(String id) async {
    final storage = ref.read(settingsStorageProvider.notifier);
    await storage.removeServer(id);

    state = Map.fromEntries(state.entries.where((e) => e.key != id));
  }

  /// Updates a server's connection info and persists the change.
  Future<void> updateServer(ServerConnection server) async {
    final storage = ref.read(settingsStorageProvider.notifier);
    await storage.updateServer(server);

    final existing = state[server.id];
    if (existing != null) {
      state = {
        ...state,
        server.id: existing.copyWith(connection: server),
      };
    }
  }

  /// Connects to a specific server by ID.
  Future<void> connectServer(String id) async {
    final entry = state[id];
    if (entry == null) return;

    _log('Connecting to server ${entry.connection.displayName}');

    state = {
      ...state,
      id: entry.copyWith(status: ServerHealthStatus.connecting),
    };

    final client = VideClient(
      host: entry.connection.host,
      port: entry.connection.port,
    );

    final isHealthy = await client.checkHealth();
    if (isHealthy) {
      state = {
        ...state,
        id: entry.copyWith(
          client: client,
          status: ServerHealthStatus.connected,
          errorMessage: null,
        ),
      };
      _log('Connected to ${entry.connection.displayName}');
      _connectDaemonStream(id, client, entry.connection);
      _ensureHealthChecks();
    } else {
      state = {
        ...state,
        id: entry.copyWith(
          status: ServerHealthStatus.error,
          errorMessage: 'Health check failed',
        ),
      };
      _log('Failed to connect to ${entry.connection.displayName}');
    }
  }

  /// Disconnects a specific server by ID.
  void disconnectServer(String id) {
    final entry = state[id];
    if (entry == null) return;

    _disconnectDaemonStream(id);

    state = {
      ...state,
      id: entry.copyWith(
        clearClient: true,
        status: ServerHealthStatus.disconnected,
        errorMessage: null,
      ),
    };
  }

  /// Connects to all configured servers in parallel.
  Future<void> connectAll() async {
    await Future.wait(
      state.keys.map((id) => connectServer(id)),
    );
    _startHealthChecks();
  }

  /// Disconnects from all servers.
  void disconnectAll() {
    _healthCheckTimer?.cancel();
    for (final id in _daemonSubscriptions.keys.toList()) {
      _disconnectDaemonStream(id);
    }
    final updated = <String, ServerEntry>{};
    for (final entry in state.entries) {
      updated[entry.key] = entry.value.copyWith(
        clearClient: true,
        status: ServerHealthStatus.disconnected,
        errorMessage: null,
      );
    }
    state = updated;
  }

  /// Gets the VideClient for a specific server.
  VideClient? getClient(String serverId) => state[serverId]?.client;

  /// Gets all connected servers' clients.
  Map<String, VideClient> getConnectedClients() {
    final clients = <String, VideClient>{};
    for (final entry in state.entries) {
      if (entry.value.client != null &&
          entry.value.status == ServerHealthStatus.connected) {
        clients[entry.key] = entry.value.client!;
      }
    }
    return clients;
  }

  /// Gets a list of all server entries.
  List<ServerEntry> get entries => state.values.toList();

  /// Gets a list of connected server entries.
  List<ServerEntry> get connectedEntries => state.values
      .where((e) => e.status == ServerHealthStatus.connected)
      .toList();

  /// Whether any server is connected.
  bool get hasConnectedServer =>
      state.values.any((e) => e.status == ServerHealthStatus.connected);

  /// Whether all servers are connected.
  bool get allConnected =>
      state.isNotEmpty &&
      state.values.every((e) => e.status == ServerHealthStatus.connected);

  void _startHealthChecks() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkHealth(),
    );
  }

  /// Starts health checks if not already running.
  void _ensureHealthChecks() {
    if (_healthCheckTimer == null || !_healthCheckTimer!.isActive) {
      _startHealthChecks();
    }
  }

  Future<void> _checkHealth() async {
    for (final entry in state.entries) {
      if (entry.value.status == ServerHealthStatus.connected &&
          entry.value.client != null) {
        final isHealthy = await entry.value.client!.checkHealth();
        if (!isHealthy) {
          _log('Health check failed for ${entry.value.connection.displayName}');
          state = {
            ...state,
            entry.key: entry.value.copyWith(
              status: ServerHealthStatus.error,
              errorMessage: 'Health check failed',
            ),
          };
        }
      }
    }
  }

  void _connectDaemonStream(
    String serverId,
    VideClient client,
    ServerConnection connection,
  ) {
    _disconnectDaemonStream(serverId);

    _log('Connecting daemon stream for ${connection.displayName}');
    final daemonConn = client.connectToDaemon();
    _daemonConnections[serverId] = daemonConn;

    _daemonSubscriptions[serverId] = daemonConn.events.listen(
      (event) => _handleDaemonEvent(serverId, client, connection, event),
      onError: (error) {
        _log('Daemon stream error for ${connection.displayName}: $error');
      },
      onDone: () {
        _log('Daemon stream closed for ${connection.displayName}');
      },
    );
  }

  void _disconnectDaemonStream(String serverId) {
    _daemonSubscriptions[serverId]?.cancel();
    _daemonSubscriptions.remove(serverId);
    _daemonConnections[serverId]?.dispose();
    _daemonConnections.remove(serverId);
  }

  void _handleDaemonEvent(
    String serverId,
    VideClient client,
    ServerConnection connection,
    DaemonEvent event,
  ) {
    final manager = ref.read(sessionListManagerProvider.notifier);

    switch (event) {
      case DaemonSessionCreatedEvent():
        manager.addSessionFromDaemon(
          event: event,
          client: client,
          serverId: serverId,
          serverName: connection.displayName,
        );
      case DaemonSessionStoppedEvent():
        manager.removeSessionFromDaemon(event.sessionId);
      case DaemonSessionSeenEvent():
        manager.handleSessionSeenEvent(event.sessionId, event.lastSeenAt);
      case DaemonSessionHealthEvent():
      case DaemonStatusEvent():
        break;
    }
  }
}
