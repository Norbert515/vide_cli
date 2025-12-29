import 'package:test/test.dart';
import 'package:vide_core/models/agent_network.dart';
import 'package:vide_core/services/agent_network_persistence_manager.dart';
import 'package:vide_server/services/network_cache_manager.dart';

/// Mock persistence manager for testing
class MockPersistenceManager implements AgentNetworkPersistenceManager {
  List<AgentNetwork> networks = [];
  int loadCallCount = 0;

  @override
  Future<List<AgentNetwork>> loadNetworks() async {
    loadCallCount++;
    return networks;
  }

  @override
  Future<void> saveNetworks(List<AgentNetwork> networks) async {
    this.networks = networks;
  }

  @override
  Future<void> saveNetwork(AgentNetwork network) async {
    final index = networks.indexWhere((n) => n.id == network.id);
    if (index >= 0) {
      networks[index] = network;
    } else {
      networks.add(network);
    }
  }

  @override
  Future<void> deleteNetwork(String networkId) async {
    networks.removeWhere((n) => n.id == networkId);
  }
}

AgentNetwork _createNetwork(String id) {
  return AgentNetwork(
    id: id,
    goal: 'Test goal',
    agents: [],
    createdAt: DateTime.now(),
  );
}

void main() {
  group('NetworkCacheManager', () {
    late MockPersistenceManager mockPersistence;
    late NetworkCacheManager cacheManager;

    setUp(() {
      mockPersistence = MockPersistenceManager();
      cacheManager = NetworkCacheManager(mockPersistence);
    });

    group('getNetwork', () {
      test('returns null for non-existent network', () async {
        final result = await cacheManager.getNetwork('non-existent');
        expect(result, isNull);
      });

      test('loads from persistence on first cache miss', () async {
        final network = _createNetwork('net-123');
        mockPersistence.networks = [network];

        final result = await cacheManager.getNetwork('net-123');

        expect(result?.id, equals('net-123'));
        expect(mockPersistence.loadCallCount, equals(1));
      });

      test('returns cached network without loading from persistence', () async {
        final network = _createNetwork('net-123');
        cacheManager.cacheNetwork(network);

        final result = await cacheManager.getNetwork('net-123');

        expect(result?.id, equals('net-123'));
        expect(mockPersistence.loadCallCount, equals(0));
      });

      test('loads all networks once and caches them', () async {
        final network1 = _createNetwork('net-1');
        final network2 = _createNetwork('net-2');
        final network3 = _createNetwork('net-3');
        mockPersistence.networks = [network1, network2, network3];

        // First lookup triggers load of all networks
        final result1 = await cacheManager.getNetwork('net-1');
        expect(result1?.id, equals('net-1'));
        expect(mockPersistence.loadCallCount, equals(1));

        // Subsequent lookups use cache - no additional loads
        final result2 = await cacheManager.getNetwork('net-2');
        expect(result2?.id, equals('net-2'));
        expect(mockPersistence.loadCallCount, equals(1));

        final result3 = await cacheManager.getNetwork('net-3');
        expect(result3?.id, equals('net-3'));
        expect(mockPersistence.loadCallCount, equals(1));
      });

      test('returns null for unknown network after full load', () async {
        mockPersistence.networks = [_createNetwork('net-1')];

        // Trigger full load
        await cacheManager.getNetwork('net-1');

        // Unknown network should return null without reloading
        final result = await cacheManager.getNetwork('unknown');
        expect(result, isNull);
        expect(mockPersistence.loadCallCount, equals(1));
      });
    });

    group('cacheNetwork', () {
      test('caches a new network', () async {
        final network = _createNetwork('net-123');

        cacheManager.cacheNetwork(network);

        final result = await cacheManager.getNetwork('net-123');
        expect(result?.id, equals('net-123'));
        expect(mockPersistence.loadCallCount, equals(0));
      });

      test('overwrites existing cached network', () async {
        final network1 = AgentNetwork(
          id: 'net-123',
          goal: 'First goal',
          agents: [],
          createdAt: DateTime(2024, 1, 1),
        );
        final network2 = AgentNetwork(
          id: 'net-123',
          goal: 'Second goal',
          agents: [],
          createdAt: DateTime(2024, 6, 1),
        );

        cacheManager.cacheNetwork(network1);
        cacheManager.cacheNetwork(network2);

        final result = await cacheManager.getNetwork('net-123');
        expect(result?.goal, equals('Second goal'));
      });
    });

    group('cachedNetworkIds', () {
      test('returns empty list when no networks cached', () {
        expect(cacheManager.cachedNetworkIds, isEmpty);
      });

      test('returns list of cached network IDs', () {
        cacheManager.cacheNetwork(_createNetwork('net-1'));
        cacheManager.cacheNetwork(_createNetwork('net-2'));
        cacheManager.cacheNetwork(_createNetwork('net-3'));

        final ids = cacheManager.cachedNetworkIds;

        expect(ids, containsAll(['net-1', 'net-2', 'net-3']));
        expect(ids.length, equals(3));
      });
    });
  });
}
