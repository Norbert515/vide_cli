import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';

import '../helpers/mock_claude_client.dart';

void main() {
  group('EmbeddedServer', () {
    late ProviderContainer container;
    late MockClaudeClientFactory clientFactory;

    setUp(() {
      clientFactory = MockClaudeClientFactory();
      container = ProviderContainer(
        overrides: [
          workingDirProvider.overrideWithValue('/test/working/dir'),
        ],
      );
    });

    tearDown(() {
      clientFactory.clear();
      container.dispose();
    });

    /// Helper to set up a basic network with one agent.
    AgentNetwork setupBasicNetwork({String? networkId, String? agentId}) {
      final id = networkId ?? 'test-network';
      final mainAgentId = agentId ?? 'main-agent';

      final network = AgentNetwork(
        id: id,
        goal: 'Test goal',
        agents: [
          AgentMetadata(
            id: mainAgentId,
            name: 'Main',
            type: 'main',
            createdAt: DateTime.now(),
          ),
        ],
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      );

      // Set up the network in the manager
      container
          .read(agentNetworkManagerProvider.notifier)
          .setCurrentNetworkForTest(network);

      // Add mock client
      final client = clientFactory.getClient(mainAgentId);
      container.read(claudeManagerProvider.notifier).addAgent(mainAgentId, client);

      return network;
    }

    group('start/stop', () {
      test('start returns ServerInfo with address and port', () async {
        final network = setupBasicNetwork();

        final server = EmbeddedServer(
          container: container,
          sessionId: network.id,
        );

        final serverInfo = await server.start();

        expect(serverInfo.address, isNotEmpty);
        expect(serverInfo.port, greaterThan(0));

        await server.stop();
      });

      test('start with specific port uses that port', () async {
        final network = setupBasicNetwork();

        final server = EmbeddedServer(
          container: container,
          sessionId: network.id,
        );

        // Find an available port first
        final tempServer = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final port = tempServer.port;
        await tempServer.close();

        final serverInfo = await server.start(port: port);

        expect(serverInfo.port, port);

        await server.stop();
      });

      test('start throws if already running', () async {
        final network = setupBasicNetwork();

        final server = EmbeddedServer(
          container: container,
          sessionId: network.id,
        );

        await server.start();

        expect(
          () => server.start(),
          throwsStateError,
        );

        await server.stop();
      });

      test('isRunning reflects server state', () async {
        final network = setupBasicNetwork();

        final server = EmbeddedServer(
          container: container,
          sessionId: network.id,
        );

        expect(server.isRunning, isFalse);

        await server.start();
        expect(server.isRunning, isTrue);

        await server.stop();
        expect(server.isRunning, isFalse);
      });

      test('stop is idempotent', () async {
        final network = setupBasicNetwork();

        final server = EmbeddedServer(
          container: container,
          sessionId: network.id,
        );

        await server.start();
        await server.stop();
        await server.stop(); // Should not throw
        await server.stop();
      });
    });

    group('health endpoint', () {
      test('GET /health returns ok status', () async {
        final network = setupBasicNetwork();

        final server = EmbeddedServer(
          container: container,
          sessionId: network.id,
        );

        final serverInfo = await server.start();

        final client = HttpClient();
        final request = await client.get(
          serverInfo.address,
          serverInfo.port,
          '/health',
        );
        final response = await request.close();

        expect(response.statusCode, 200);

        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body);
        expect(json['status'], 'ok');

        client.close();
        await server.stop();
      });
    });

    group('WebSocket connection', () {
      test('connecting to /ws triggers joinRequest', () async {
        final network = setupBasicNetwork();

        final server = EmbeddedServer(
          container: container,
          sessionId: network.id,
        );

        final serverInfo = await server.start();

        // Listen for join requests
        final joinRequests = <JoinRequest>[];
        final joinSub = server.joinRequests.listen(joinRequests.add);

        // Connect WebSocket
        final ws = await WebSocket.connect(
          'ws://${serverInfo.address}:${serverInfo.port}/ws',
        );

        // Wait for join request to be emitted
        await Future.delayed(const Duration(milliseconds: 50));

        expect(joinRequests, hasLength(1));
        expect(joinRequests.first.remoteAddress, isNotEmpty);

        // Clean up
        await ws.close();
        await joinSub.cancel();
        await server.stop();
      });

      test('approving join request adds client to clients list', () async {
        final network = setupBasicNetwork();

        final server = EmbeddedServer(
          container: container,
          sessionId: network.id,
        );

        final serverInfo = await server.start();

        // Listen for join requests and approve them
        final joinSub = server.joinRequests.listen((request) {
          server.respondToJoinRequest(request.id, JoinResponse.allow);
        });

        // Connect WebSocket
        final ws = await WebSocket.connect(
          'ws://${serverInfo.address}:${serverInfo.port}/ws',
        );

        // Wait for connection to be established
        await Future.delayed(const Duration(milliseconds: 100));

        expect(server.clients, hasLength(1));
        expect(server.clients.first.permission, ClientPermission.interact);

        // Clean up
        await ws.close();
        await joinSub.cancel();
        await server.stop();
      });

      test('denying join request closes connection', () async {
        final network = setupBasicNetwork();

        final server = EmbeddedServer(
          container: container,
          sessionId: network.id,
        );

        final serverInfo = await server.start();

        // Listen for join requests and deny them
        final joinSub = server.joinRequests.listen((request) {
          server.respondToJoinRequest(request.id, JoinResponse.deny);
        });

        // Connect WebSocket
        final ws = await WebSocket.connect(
          'ws://${serverInfo.address}:${serverInfo.port}/ws',
        );

        // Wait for denial and read the error message
        final messages = <dynamic>[];
        final messageSub = ws.listen(messages.add);

        await Future.delayed(const Duration(milliseconds: 100));

        // WebSocket should receive error and be closed
        expect(server.clients, isEmpty);

        if (messages.isNotEmpty) {
          final firstMessage = jsonDecode(messages.first as String);
          expect(firstMessage['type'], 'error');
          expect(firstMessage['code'], 'ACCESS_DENIED');
        }

        // Clean up
        await messageSub.cancel();
        await ws.close();
        await joinSub.cancel();
        await server.stop();
      });

      test('read-only client cannot send messages', () async {
        final network = setupBasicNetwork();

        final server = EmbeddedServer(
          container: container,
          sessionId: network.id,
        );

        final serverInfo = await server.start();

        // Listen for join requests and approve as read-only
        final joinSub = server.joinRequests.listen((request) {
          server.respondToJoinRequest(request.id, JoinResponse.allowReadOnly);
        });

        // Connect WebSocket
        final ws = await WebSocket.connect(
          'ws://${serverInfo.address}:${serverInfo.port}/ws',
        );

        // Wait for connection
        await Future.delayed(const Duration(milliseconds: 100));

        // Collect messages
        final messages = <dynamic>[];
        final messageSub = ws.listen(messages.add);

        // Try to send a message
        ws.add(jsonEncode({
          'type': 'send-user-message',
          'content': 'Hello',
        }));

        await Future.delayed(const Duration(milliseconds: 100));

        // Should receive permission denied error
        final errorMessages = messages
            .map((m) => jsonDecode(m as String) as Map<String, dynamic>)
            .where((m) => m['type'] == 'error' && m['code'] == 'PERMISSION_DENIED')
            .toList();

        expect(errorMessages, isNotEmpty);

        // Clean up
        await messageSub.cancel();
        await ws.close();
        await joinSub.cancel();
        await server.stop();
      });
    });

    group('event broadcasting', () {
      test('events are broadcast to connected clients', () async {
        final network = setupBasicNetwork();
        final client = clientFactory.getClient('main-agent');

        final server = EmbeddedServer(
          container: container,
          sessionId: network.id,
        );

        final serverInfo = await server.start();

        // Listen for join requests and approve them
        final joinSub = server.joinRequests.listen((request) {
          server.respondToJoinRequest(request.id, JoinResponse.allow);
        });

        // Connect WebSocket
        final ws = await WebSocket.connect(
          'ws://${serverInfo.address}:${serverInfo.port}/ws',
        );

        // Collect messages
        final messages = <Map<String, dynamic>>[];
        final messageSub = ws.listen((m) {
          messages.add(jsonDecode(m as String) as Map<String, dynamic>);
        });

        // Wait for connection
        await Future.delayed(const Duration(milliseconds: 100));

        // Trigger an event by simulating assistant response
        client.simulateTextResponse('Hello from assistant');

        await Future.delayed(const Duration(milliseconds: 100));

        // Should have received events including message
        final messageEvents = messages.where((m) => m['type'] == 'message').toList();
        expect(messageEvents, isNotEmpty);

        // Clean up
        await messageSub.cancel();
        await ws.close();
        await joinSub.cancel();
        await server.stop();
      });
    });

    group('client disconnect', () {
      test('disconnecting client removes from clients list', () async {
        final network = setupBasicNetwork();

        final server = EmbeddedServer(
          container: container,
          sessionId: network.id,
        );

        final serverInfo = await server.start();

        // Listen for join requests and approve them
        final joinSub = server.joinRequests.listen((request) {
          server.respondToJoinRequest(request.id, JoinResponse.allow);
        });

        // Connect WebSocket
        final ws = await WebSocket.connect(
          'ws://${serverInfo.address}:${serverInfo.port}/ws',
        );

        await Future.delayed(const Duration(milliseconds: 100));
        expect(server.clients, hasLength(1));

        // Disconnect
        await ws.close();
        await Future.delayed(const Duration(milliseconds: 100));

        expect(server.clients, isEmpty);

        // Clean up
        await joinSub.cancel();
        await server.stop();
      });
    });
  });
}

/// Extension to allow setting the current network for testing.
extension AgentNetworkManagerTestExtension on AgentNetworkManager {
  void setCurrentNetworkForTest(AgentNetwork network) {
    state = state.copyWith(currentNetwork: network);
  }
}
