import 'package:vide_core/models/agent_network.dart';
import 'package:vide_core/services/agent_network_persistence_manager.dart';

/// Hybrid caching strategy for agent networks
///
/// Provides O(1) in-memory lookups with persistence backing.
/// On first cache miss, loads and caches all networks from persistence
/// so subsequent lookups are O(1) regardless of which network is requested.
class NetworkCacheManager {
  final Map<String, AgentNetwork> _cache = {};
  final AgentNetworkPersistenceManager _persistence;
  bool _fullyLoaded = false;

  NetworkCacheManager(this._persistence);

  /// Get network by ID (checks cache first, then loads from persistence)
  Future<AgentNetwork?> getNetwork(String networkId) async {
    // Check in-memory cache first
    if (_cache.containsKey(networkId)) {
      return _cache[networkId];
    }

    // If we've already loaded all networks and it's not in cache, it doesn't exist
    if (_fullyLoaded) {
      return null;
    }

    // Load and cache all networks from persistence (only happens once)
    final networks = await _persistence.loadNetworks();
    for (final network in networks) {
      _cache[network.id] = network;
    }
    _fullyLoaded = true;

    return _cache[networkId];
  }

  /// Cache a network (called after creation or updates)
  void cacheNetwork(AgentNetwork network) {
    _cache[network.id] = network;
  }

  /// Get all cached network IDs
  List<String> get cachedNetworkIds => _cache.keys.toList();
}
