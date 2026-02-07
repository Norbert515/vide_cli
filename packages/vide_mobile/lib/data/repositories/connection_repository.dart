import 'dart:developer' as developer;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vide_client/vide_client.dart';

import '../../domain/models/server_connection.dart';
import '../local/settings_storage.dart';

part 'connection_repository.g.dart';

/// State for the connection repository.
class ConnectionState {
  final ServerConnection? connection;
  final VideClient? client;
  final bool isConnected;

  const ConnectionState({
    this.connection,
    this.client,
    this.isConnected = false,
  });

  ConnectionState copyWith({
    ServerConnection? connection,
    VideClient? client,
    bool? isConnected,
  }) {
    return ConnectionState(
      connection: connection ?? this.connection,
      client: client ?? this.client,
      isConnected: isConnected ?? this.isConnected,
    );
  }
}

/// Repository for managing server connections.
@Riverpod(keepAlive: true)
class ConnectionRepository extends _$ConnectionRepository {
  void _log(String message) {
    developer.log(message, name: 'ConnectionRepository');
  }

  @override
  ConnectionState build() {
    return const ConnectionState();
  }

  /// Tests if a connection to the server is possible.
  Future<bool> testConnection(ServerConnection connection) async {
    _log('Testing connection to ${connection.host}:${connection.port}');

    final client = VideClient(
      host: connection.host,
      port: connection.port,
    );

    final result = await client.checkHealth();
    _log('Connection test result: $result');
    return result;
  }

  /// Connects to a server.
  Future<void> connect(ServerConnection connection) async {
    _log('Connecting to ${connection.host}:${connection.port}');

    final client = VideClient(
      host: connection.host,
      port: connection.port,
    );

    // Test the connection
    final isHealthy = await client.checkHealth();
    if (!isHealthy) {
      throw VideClientException('Server health check failed');
    }

    // Save the connection
    final settingsStorage = ref.read(settingsStorageProvider.notifier);
    await settingsStorage.saveConnection(connection);

    state = ConnectionState(
      connection: connection,
      client: client,
      isConnected: true,
    );

    _log('Connected successfully');
  }

  /// Disconnects from the current server.
  void disconnect() {
    _log('Disconnecting');
    state = const ConnectionState();
  }

  /// Gets the current API client.
  VideClient? get client => state.client;

  /// Gets the current connection.
  ServerConnection? get connection => state.connection;

  /// Whether we are connected.
  bool get isConnected => state.isConnected;
}
