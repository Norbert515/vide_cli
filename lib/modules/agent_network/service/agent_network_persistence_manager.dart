import 'dart:convert';
import 'dart:io';

import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_cli/modules/agent_network/models/agent_network.dart';
import 'package:vide_cli/services/vide_config_manager.dart';
import 'package:path/path.dart' as path;

final agentNetworkPersistenceManagerProvider =
    Provider<AgentNetworkPersistenceManager>((ref) {
  return AgentNetworkPersistenceManager();
});

/// Manages persistence of agent networks to JSON files.
///
/// Data is stored in a global config directory to avoid conflicts
/// with version control systems.
class AgentNetworkPersistenceManager {
  AgentNetworkPersistenceManager({String? projectPath})
      : _projectPath = projectPath ?? Directory.current.path {
    final configManager = VideConfigManager();
    _storageDir = configManager.getProjectStorageDir(_projectPath);
  }

  final String _projectPath;
  late final String _storageDir;

  String get _networksFilePath => path.join(_storageDir, 'agent_networks.json');

  /// Ensures the storage directory exists
  Future<void> _ensureDirectoryExists() async {
    final dir = Directory(_storageDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  /// Save agent networks to JSON file
  Future<void> saveNetworks(List<AgentNetwork> networks) async {
    await _ensureDirectoryExists();
    final file = File(_networksFilePath);
    final json = jsonEncode({
      'networks': networks.map((n) => n.toJson()).toList(),
    });
    await file.writeAsString(json);
  }

  /// Load agent networks from JSON file
  Future<List<AgentNetwork>> loadNetworks() async {
    final file = File(_networksFilePath);
    if (!await file.exists()) {
      return [];
    }

    try {
      final contents = await file.readAsString();
      final json = jsonDecode(contents) as Map<String, dynamic>;
      final networksJson = json['networks'] as List<dynamic>;
      return networksJson
          .map((n) => AgentNetwork.fromJson(n as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // If there's an error reading the file, return empty list
      // This prevents crashes on corrupted files
      return [];
    }
  }

  /// Save a single network (adds or updates)
  Future<void> saveNetwork(AgentNetwork network) async {
    final networks = await loadNetworks();
    final existingIndex = networks.indexWhere((n) => n.id == network.id);

    if (existingIndex >= 0) {
      networks[existingIndex] = network;
    } else {
      networks.add(network);
    }

    await saveNetworks(networks);
  }

  /// Delete a network by ID
  Future<void> deleteNetwork(String networkId) async {
    final networks = await loadNetworks();
    networks.removeWhere((n) => n.id == networkId);
    await saveNetworks(networks);
  }
}
