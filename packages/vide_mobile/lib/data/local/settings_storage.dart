import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/app_providers.dart';
import '../../domain/models/server_connection.dart';

part 'settings_storage.g.dart';

/// Keys for settings storage.
class SettingsKeys {
  static const serverConnection = 'server_connection';
  static const lastWorkingDir = 'last_working_dir';
  static const recentConnections = 'recent_connections';
  static const recentWorkingDirectories = 'recent_working_directories';
  static const lastTeam = 'last_team';
  static const themeMode = 'theme_mode';
  static const configuredServers = 'configured_servers';
  static const pathServerMap = 'path_server_map';
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
      return ServerConnection.fromJson(
          jsonDecode(json) as Map<String, dynamic>);
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

  /// Gets the list of recent working directories.
  Future<List<String>> getRecentWorkingDirectories() async {
    await future;
    final json = _prefs.getString(SettingsKeys.recentWorkingDirectories);
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list.cast<String>();
    } catch (e) {
      return [];
    }
  }

  /// Adds a directory to the recent list. Deduplicates, max 10, most recent first.
  Future<void> addRecentWorkingDirectory(String path) async {
    await future;
    final recent = await getRecentWorkingDirectories();
    recent.remove(path);
    recent.insert(0, path);
    final trimmed = recent.take(10).toList();
    await _prefs.setString(
      SettingsKeys.recentWorkingDirectories,
      jsonEncode(trimmed),
    );
  }

  /// Gets the last used team name.
  Future<String?> getLastTeam() async {
    await future;
    return _prefs.getString(SettingsKeys.lastTeam);
  }

  /// Saves the last used team name.
  Future<void> saveLastTeam(String team) async {
    await future;
    await _prefs.setString(SettingsKeys.lastTeam, team);
  }

  /// Gets the stored theme mode.
  Future<ThemeMode> getThemeMode() async {
    await future;
    final value = _prefs.getString(SettingsKeys.themeMode);
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  /// Saves the theme mode.
  Future<void> saveThemeMode(ThemeMode mode) async {
    await future;
    await _prefs.setString(SettingsKeys.themeMode, mode.name);
  }

  /// Gets all configured servers.
  Future<List<ServerConnection>> getServers() async {
    await future;
    // Migration: if old single-server key exists, migrate it
    final oldJson = _prefs.getString(SettingsKeys.serverConnection);
    final serversJson = _prefs.getString(SettingsKeys.configuredServers);

    if (serversJson == null && oldJson != null) {
      // Migrate old single server to new format
      try {
        final oldData = jsonDecode(oldJson) as Map<String, dynamic>;
        // Old connections don't have an ID, create one with an ID
        final migrated = ServerConnection(
          id: const Uuid().v4(),
          host: oldData['host'] as String,
          port: oldData['port'] as int,
          isSecure: oldData['isSecure'] as bool? ?? false,
          name: oldData['name'] as String?,
        );
        final list = [migrated];
        await _prefs.setString(
          SettingsKeys.configuredServers,
          jsonEncode(list.map((s) => s.toJson()).toList()),
        );
        // Clean up old key
        await _prefs.remove(SettingsKeys.serverConnection);
        return list;
      } catch (e) {
        return [];
      }
    }

    if (serversJson == null) return [];
    try {
      final list = jsonDecode(serversJson) as List<dynamic>;
      return list
          .map((e) => ServerConnection.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Adds a server to the configured list.
  Future<void> addServer(ServerConnection server) async {
    await future;
    final servers = await getServers();
    servers.add(server);
    await _saveServers(servers);
  }

  /// Removes a server by its ID.
  Future<void> removeServer(String id) async {
    await future;
    final servers = await getServers();
    servers.removeWhere((s) => s.id == id);
    await _saveServers(servers);
  }

  /// Updates an existing server (matched by ID).
  Future<void> updateServer(ServerConnection server) async {
    await future;
    final servers = await getServers();
    final index = servers.indexWhere((s) => s.id == server.id);
    if (index != -1) {
      servers[index] = server;
      await _saveServers(servers);
    }
  }

  Future<void> _saveServers(List<ServerConnection> servers) async {
    await _prefs.setString(
      SettingsKeys.configuredServers,
      jsonEncode(servers.map((s) => s.toJson()).toList()),
    );
  }

  /// Gets the cached server ID for a working directory path.
  Future<String?> getServerForPath(String path) async {
    await future;
    final json = _prefs.getString(SettingsKeys.pathServerMap);
    if (json == null) return null;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return map[path] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Caches the server ID used for a working directory path.
  Future<void> saveServerForPath(String path, String serverId) async {
    await future;
    final json = _prefs.getString(SettingsKeys.pathServerMap);
    Map<String, dynamic> map;
    try {
      map = json != null
          ? jsonDecode(json) as Map<String, dynamic>
          : <String, dynamic>{};
    } catch (e) {
      map = <String, dynamic>{};
    }
    map[path] = serverId;
    await _prefs.setString(SettingsKeys.pathServerMap, jsonEncode(map));
  }

  /// Clears all stored settings.
  Future<void> clear() async {
    await future;
    await _prefs.remove(SettingsKeys.serverConnection);
    await _prefs.remove(SettingsKeys.lastWorkingDir);
    await _prefs.remove(SettingsKeys.recentConnections);
    await _prefs.remove(SettingsKeys.recentWorkingDirectories);
    await _prefs.remove(SettingsKeys.lastTeam);
    await _prefs.remove(SettingsKeys.themeMode);
    await _prefs.remove(SettingsKeys.configuredServers);
    await _prefs.remove(SettingsKeys.pathServerMap);
  }
}
