import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

part 'server_connection.freezed.dart';
part 'server_connection.g.dart';

/// Represents a connection to a Vide server.
@freezed
class ServerConnection with _$ServerConnection {
  const factory ServerConnection({
    required String id,
    required String host,
    required int port,
    @Default(false) bool isSecure,
    String? name,
  }) = _ServerConnection;

  /// Creates a new ServerConnection with an auto-generated UUID.
  static ServerConnection create({
    required String host,
    required int port,
    bool isSecure = false,
    String? name,
  }) {
    return ServerConnection(
      id: const Uuid().v4(),
      host: host,
      port: port,
      isSecure: isSecure,
      name: name,
    );
  }

  factory ServerConnection.fromJson(Map<String, dynamic> json) =>
      _$ServerConnectionFromJson(json);
}

extension ServerConnectionX on ServerConnection {
  /// Returns the WebSocket URL for this connection.
  String get wsUrl {
    final protocol = isSecure ? 'wss' : 'ws';
    return '$protocol://$host:$port';
  }

  /// Returns the HTTP URL for this connection.
  String get httpUrl {
    final protocol = isSecure ? 'https' : 'http';
    return '$protocol://$host:$port';
  }

  /// Returns the display name for this server.
  String get displayName => name ?? '$host:$port';
}
