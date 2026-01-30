import 'dart:developer' as developer;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/models/server_connection.dart';
import '../local/settings_storage.dart';
import '../remote/vide_api_client.dart';

part 'connection_repository.g.dart';

/// State for the connection repository.
class ConnectionState {
  final ServerConnection? connection;
  final VideApiClient? client;
  final bool isConnected;

  const ConnectionState({
    this.connection,
    this.client,
    this.isConnected = false,
  });

  ConnectionState copyWith({
    ServerConnection? connection,
    VideApiClient? client,
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
    ref.onDispose(() {
      state.client?.dispose();
    });
    return const ConnectionState();
  }

  /// Tests if a connection to the server is possible.
  Future<bool> testConnection(ServerConnection connection) async {
    _log('Testing connection to ${connection.host}:${connection.port}');

    final client = VideApiClient(
      host: connection.host,
      port: connection.port,
      isSecure: connection.isSecure,
    );

    try {
      final result = await client.healthCheck();
      _log('Connection test result: $result');
      return result;
    } finally {
      client.dispose();
    }
  }

  /// Connects to a server.
  Future<void> connect(ServerConnection connection) async {
    _log('Connecting to ${connection.host}:${connection.port}');

    // Dispose of existing client
    state.client?.dispose();

    final client = VideApiClient(
      host: connection.host,
      port: connection.port,
      isSecure: connection.isSecure,
    );

    // Test the connection
    final isHealthy = await client.healthCheck();
    if (!isHealthy) {
      client.dispose();
      throw VideApiException('Server health check failed');
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
    state.client?.dispose();
    state = const ConnectionState();
  }

  /// Gets the current API client.
  VideApiClient? get client => state.client;

  /// Gets the current connection.
  ServerConnection? get connection => state.connection;

  /// Whether we are connected.
  bool get isConnected => state.isConnected;
}
