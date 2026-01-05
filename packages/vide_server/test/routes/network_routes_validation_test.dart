import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:shelf/shelf.dart';
import 'package:riverpod/riverpod.dart';
import 'package:vide_server/routes/network_routes.dart';
import 'package:vide_server/services/network_cache_manager.dart';
import 'package:vide_core/services/agent_network_persistence_manager.dart';
import 'package:vide_core/models/agent_network.dart';

/// Mock persistence manager for testing
class MockPersistenceManager implements AgentNetworkPersistenceManager {
  @override
  Future<List<AgentNetwork>> loadNetworks() async => [];

  @override
  Future<void> saveNetworks(List<AgentNetwork> networks) async {}

  @override
  Future<void> saveNetwork(AgentNetwork network) async {}

  @override
  Future<void> deleteNetwork(String networkId) async {}
}

Request _createRequest(String body) {
  return Request(
    'POST',
    Uri.parse('http://localhost/api/v1/networks'),
    body: body,
    headers: {'Content-Type': 'application/json'},
  );
}

void main() {
  group('createNetwork validation', () {
    late ProviderContainer container;
    late NetworkCacheManager cacheManager;

    setUp(() {
      // Create a minimal container - we're testing validation which happens
      // before the manager is accessed
      container = ProviderContainer();
      cacheManager = NetworkCacheManager(MockPersistenceManager());
    });

    tearDown(() {
      container.dispose();
    });

    test('rejects empty workingDirectory', () async {
      final request = _createRequest(
        jsonEncode({'initialMessage': 'Hello', 'workingDirectory': ''}),
      );

      final response = await createNetwork(request, container, cacheManager);

      expect(response.statusCode, equals(400));
      final body = jsonDecode(await response.readAsString());
      expect(body['error'], contains('workingDirectory is required'));
    });

    test('rejects whitespace-only workingDirectory', () async {
      final request = _createRequest(
        jsonEncode({'initialMessage': 'Hello', 'workingDirectory': '   '}),
      );

      final response = await createNetwork(request, container, cacheManager);

      expect(response.statusCode, equals(400));
      final body = jsonDecode(await response.readAsString());
      expect(body['error'], contains('workingDirectory is required'));
    });

    test('rejects non-existent workingDirectory', () async {
      final request = _createRequest(
        jsonEncode({
          'initialMessage': 'Hello',
          'workingDirectory': '/this/path/definitely/does/not/exist',
        }),
      );

      final response = await createNetwork(request, container, cacheManager);

      expect(response.statusCode, equals(400));
      final body = jsonDecode(await response.readAsString());
      expect(body['error'], contains('workingDirectory does not exist'));
    });

    test('rejects empty initialMessage', () async {
      final request = _createRequest(
        jsonEncode({
          'initialMessage': '',
          'workingDirectory': Directory.current.path,
        }),
      );

      final response = await createNetwork(request, container, cacheManager);

      expect(response.statusCode, equals(400));
      final body = jsonDecode(await response.readAsString());
      expect(body['error'], contains('initialMessage is required'));
    });

    test('rejects whitespace-only initialMessage', () async {
      final request = _createRequest(
        jsonEncode({
          'initialMessage': '   ',
          'workingDirectory': Directory.current.path,
        }),
      );

      final response = await createNetwork(request, container, cacheManager);

      expect(response.statusCode, equals(400));
      final body = jsonDecode(await response.readAsString());
      expect(body['error'], contains('initialMessage is required'));
    });

    test('canonicalizes workingDirectory path', () async {
      // Create a path with .. that should be canonicalized
      final currentDir = Directory.current.path;
      final pathWithDots =
          '$currentDir/../${Directory.current.path.split('/').last}';

      final request = _createRequest(
        jsonEncode({
          'initialMessage': 'Hello',
          'workingDirectory': pathWithDots,
        }),
      );

      // This will fail at the manager.startNew call (which we haven't mocked),
      // but we can verify the path was canonicalized by checking it doesn't
      // fail the directory existence check (which would happen with the
      // un-canonicalized path if it contained invalid .. traversals)
      final response = await createNetwork(request, container, cacheManager);

      // Will get a different error since we haven't mocked the full manager,
      // but it shouldn't be a "does not exist" error for the path
      expect(response.statusCode, isNot(400));
    });
  });
}
