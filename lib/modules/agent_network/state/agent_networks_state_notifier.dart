import 'package:vide_core/vide_core.dart';
import 'package:riverpod/riverpod.dart';

final agentNetworksStateNotifierProvider =
    StateNotifierProvider<AgentNetworksStateNotifier, AgentNetworksState>((
      ref,
    ) {
      return AgentNetworksStateNotifier(
        ref.read(agentNetworkPersistenceManagerProvider),
      );
    });

class AgentNetworksState {
  AgentNetworksState({required this.networks});

  final List<AgentNetwork> networks;

  AgentNetworksState copyWith({List<AgentNetwork>? networks}) {
    return AgentNetworksState(networks: networks ?? this.networks);
  }
}

class AgentNetworksStateNotifier extends StateNotifier<AgentNetworksState> {
  AgentNetworksStateNotifier(this._persistenceManager)
    : super(AgentNetworksState(networks: []));

  final AgentNetworkPersistenceManager _persistenceManager;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final networks = await _persistenceManager.loadNetworks();
    // Sort by last active, most recent first
    networks.sort((a, b) {
      final aTime = a.lastActiveAt ?? a.createdAt;
      final bTime = b.lastActiveAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });
    state = state.copyWith(networks: networks);
  }

  /// Reload networks from persistence
  Future<void> reload() async {
    final networks = await _persistenceManager.loadNetworks();
    networks.sort((a, b) {
      final aTime = a.lastActiveAt ?? a.createdAt;
      final bTime = b.lastActiveAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });
    state = state.copyWith(networks: networks);
  }

  /// Add or update a network in the list
  void upsertNetwork(AgentNetwork network) {
    final networks = [...state.networks];
    final existingIndex = networks.indexWhere((n) => n.id == network.id);

    if (existingIndex >= 0) {
      networks[existingIndex] = network;
    } else {
      networks.insert(0, network); // Add at the beginning (most recent)
    }

    state = state.copyWith(networks: networks);
  }

  /// Delete a network by index
  Future<void> deleteNetwork(int index) async {
    final network = state.networks[index];
    await _persistenceManager.deleteNetwork(network.id);

    final updatedNetworks = [...state.networks];
    updatedNetworks.removeAt(index);
    state = state.copyWith(networks: updatedNetworks);
  }

  /// Delete a network by ID
  Future<void> deleteNetworkById(String networkId) async {
    await _persistenceManager.deleteNetwork(networkId);

    final updatedNetworks = state.networks
        .where((n) => n.id != networkId)
        .toList();
    state = state.copyWith(networks: updatedNetworks);
  }
}
