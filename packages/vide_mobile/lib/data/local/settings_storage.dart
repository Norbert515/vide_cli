import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers/app_providers.dart';
import '../../domain/models/server_connection.dart';

part 'settings_storage.g.dart';

/// Keys for settings storage.
class SettingsKeys {
  static const serverConnection = 'server_connection';
  static const lastWorkingDir = 'last_working_dir';
  static const recentConnections = 'recent_connections';
}

/// Wrapper for SharedPreferences to persist app settings.
@Riverpod(keepAlive: true)
class SettingsStorage extends _$SettingsStorage {
  late SharedPreferences _prefs;

  @override
  Future<void> build() async {
    _prefs = await ref.watch(sharedPreferencesProvider.future);
  }

  /// Gets the last used server connection.
  Future<ServerConnection?> getLastConnection() async {
    await future;
    final json = _prefs.getString(SettingsKeys.serverConnection);
    if (json == null) return null;
    try {
      return ServerConnection.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  /// Saves the current server connection.
  Future<void> saveConnection(ServerConnection connection) async {
    await future;
    await _prefs.setString(
      SettingsKeys.serverConnection,
      jsonEncode(connection.toJson()),
    );
    await _addToRecentConnections(connection);
  }

  /// Gets the last working directory path.
  Future<String?> getLastWorkingDirectory() async {
    await future;
    return _prefs.getString(SettingsKeys.lastWorkingDir);
  }

  /// Saves the working directory path.
  Future<void> saveWorkingDirectory(String path) async {
    await future;
    await _prefs.setString(SettingsKeys.lastWorkingDir, path);
  }

  /// Gets the list of recent server connections.
  Future<List<ServerConnection>> getRecentConnections() async {
    await future;
    final json = _prefs.getString(SettingsKeys.recentConnections);
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list
          .map((e) => ServerConnection.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Adds a connection to recent connections list.
  Future<void> _addToRecentConnections(ServerConnection connection) async {
    final recent = await getRecentConnections();

    // Remove existing entry with same host:port
    recent.removeWhere(
      (c) => c.host == connection.host && c.port == connection.port,
    );

    // Add to beginning of list
    recent.insert(0, connection);

    // Keep only last 10 connections
    final trimmed = recent.take(10).toList();

    await _prefs.setString(
      SettingsKeys.recentConnections,
      jsonEncode(trimmed.map((c) => c.toJson()).toList()),
    );
  }

  /// Clears all stored settings.
  Future<void> clear() async {
    await future;
    await _prefs.remove(SettingsKeys.serverConnection);
    await _prefs.remove(SettingsKeys.lastWorkingDir);
    await _prefs.remove(SettingsKeys.recentConnections);
  }
}
