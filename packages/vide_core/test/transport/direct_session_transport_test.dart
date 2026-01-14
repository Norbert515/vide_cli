import 'dart:async';

import 'package:claude_sdk/claude_sdk.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';
import 'package:vide_interface/vide_interface.dart' as interface_;

import '../helpers/mock_claude_client.dart';

void main() {
  group('DirectSessionTransport', () {
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

    group('initialization', () {
      test('emits ConnectedEvent on initialize with session info', () async {
        final network = setupBasicNetwork();

        final transport = DirectSessionTransport(
          sessionId: network.id,
          container: container,
        );

        final events = <interface_.SessionEvent>[];
        final subscription = transport.events.listen(events.add);

        await transport.initialize();

        // Allow stream to propagate
        await Future.delayed(Duration.zero);
        await subscription.cancel();
        await transport.close();

        // Should have received ConnectedEvent and initial status event
        expect(events.whereType<interface_.ConnectedEvent>(), hasLength(1));

        final connectedEvent =
            events.whereType<interface_.ConnectedEvent>().first;
        expect(connectedEvent.sessionInfo.sessionId, network.id);
        expect(connectedEvent.sessionInfo.mainAgentId, 'main-agent');
        expect(connectedEvent.sessionInfo.goal, 'Test goal');
        expect(connectedEvent.sessionInfo.agents, hasLength(1));
      });

      test('emits initial AgentStatusEvent on initialize', () async {
        final network = setupBasicNetwork();

        // Set a specific status before initializing
        container
            .read(agentStatusProvider('main-agent').notifier)
            .setStatus(AgentStatus.working);

        final transport = DirectSessionTransport(
          sessionId: network.id,
          container: container,
        );

        final events = <interface_.SessionEvent>[];
        final subscription = transport.events.listen(events.add);

        await transport.initialize();
        await Future.delayed(Duration.zero);
        await subscription.cancel();
        await transport.close();

        final statusEvents = events.whereType<interface_.AgentStatusEvent>();
        expect(statusEvents, isNotEmpty);
        expect(statusEvents.first.status, interface_.AgentStatus.working);
      });

      test('emits ErrorEvent when session not found', () async {
        // Don't set up any network

        final transport = DirectSessionTransport(
          sessionId: 'non-existent',
          container: container,
        );

        final events = <interface_.SessionEvent>[];
        final subscription = transport.events.listen(events.add);

        await transport.initialize();
        await Future.delayed(Duration.zero);
        await subscription.cancel();
        await transport.close();

        final errorEvents = events.whereType<interface_.ErrorEvent>();
        expect(errorEvents, hasLength(1));
        expect(errorEvents.first.code, 'NOT_FOUND');
      });

      test('initialize is idempotent', () async {
        final network = setupBasicNetwork();

        final transport = DirectSessionTransport(
          sessionId: network.id,
          container: container,
        );

        final events = <interface_.SessionEvent>[];
        final subscription = transport.events.listen(events.add);

        // Initialize multiple times
        await transport.initialize();
        await transport.initialize();
        await transport.initialize();

        await Future.delayed(Duration.zero);
        await subscription.cancel();
        await transport.close();

        // Should only have one ConnectedEvent
        expect(events.whereType<interface_.ConnectedEvent>(), hasLength(1));
      });
    });

    group('connection state', () {
      test('currentState is connected after creation', () {
        final transport = DirectSessionTransport(
          sessionId: 'test',
          container: container,
        );

        expect(transport.currentState, interface_.ConnectionState.connected);
      });

      test('currentState is disconnected after close', () async {
        final network = setupBasicNetwork();

        final transport = DirectSessionTransport(
          sessionId: network.id,
          container: container,
        );

        await transport.initialize();
        await transport.close();

        expect(transport.currentState, interface_.ConnectionState.disconnected);
      });

      test('connectionState stream emits disconnected on close', () async {
        final network = setupBasicNetwork();

        final transport = DirectSessionTransport(
          sessionId: network.id,
          container: container,
        );

        await transport.initialize();

        final states = <interface_.ConnectionState>[];
        final subscription = transport.connectionState.listen(states.add);

        await transport.close();

        expect(states, contains(interface_.ConnectionState.disconnected));
        await subscription.cancel();
      });
    });

    group('message events', () {
      test('emits MessageEvent when user sends message', () async {
        final network = setupBasicNetwork();
        final client = clientFactory.getClient('main-agent');

        final transport = DirectSessionTransport(
          sessionId: network.id,
          container: container,
        );

        final events = <interface_.SessionEvent>[];
        final subscription = transport.events.listen(events.add);

        await transport.initialize();

        // Simulate user sending a message through the client
        client.sendMessage(Message.text('Hello'));

        await Future.delayed(Duration.zero);
        await subscription.cancel();
        await transport.close();

        final messageEvents = events.whereType<interface_.MessageEvent>();
        expect(messageEvents, isNotEmpty);

        // The user message should be captured
        final userMessages =
            messageEvents.where((e) => e.role == 'user').toList();
        expect(userMessages, isNotEmpty);
        expect(userMessages.first.content, 'Hello');
        expect(userMessages.first.isPartial, isTrue);
      });

      test('emits MessageEvent when assistant responds', () async {
        final network = setupBasicNetwork();
        final client = clientFactory.getClient('main-agent');

        final transport = DirectSessionTransport(
          sessionId: network.id,
          container: container,
        );

        final events = <interface_.SessionEvent>[];
        final subscription = transport.events.listen(events.add);

        await transport.initialize();

        // Simulate assistant response
        client.simulateTextResponse('I can help with that');

        await Future.delayed(Duration.zero);
        await subscription.cancel();
        await transport.close();

        final messageEvents = events.whereType<interface_.MessageEvent>();
        final assistantMessages =
            messageEvents.where((e) => e.role == 'assistant').toList();
        expect(assistantMessages, isNotEmpty);
        expect(assistantMessages.first.content, contains('I can help'));
      });

      test('emits TurnCompleteEvent when turn completes', () async {
        final network = setupBasicNetwork();
        final client = clientFactory.getClient('main-agent');

        final transport = DirectSessionTransport(
          sessionId: network.id,
          container: container,
        );

        final events = <interface_.SessionEvent>[];
        final subscription = transport.events.listen(events.add);

        await transport.initialize();

        // Simulate turn completion
        client.simulateTurnComplete();

        await Future.delayed(Duration.zero);
        await subscription.cancel();
        await transport.close();

        final turnCompleteEvents =
            events.whereType<interface_.TurnCompleteEvent>();
        expect(turnCompleteEvents, hasLength(1));
        expect(turnCompleteEvents.first.agentId, 'main-agent');
      });
    });

    group('status events', () {
      test('emits AgentStatusEvent when status changes', () async {
        final network = setupBasicNetwork();

        final transport = DirectSessionTransport(
          sessionId: network.id,
          container: container,
        );

        final events = <interface_.SessionEvent>[];
        final subscription = transport.events.listen(events.add);

        await transport.initialize();

        // Clear existing events
        events.clear();

        // Change agent status
        container
            .read(agentStatusProvider('main-agent').notifier)
            .setStatus(AgentStatus.waitingForAgent);

        await Future.delayed(Duration.zero);
        await subscription.cancel();
        await transport.close();

        final statusEvents = events.whereType<interface_.AgentStatusEvent>();
        expect(statusEvents, isNotEmpty);
        expect(statusEvents.first.status, interface_.AgentStatus.waitingForAgent);
      });
    });

    group('send messages', () {
      test('SendUserMessage forwards to main agent', () async {
        final network = setupBasicNetwork();
        final client = clientFactory.getClient('main-agent');

        final transport = DirectSessionTransport(
          sessionId: network.id,
          container: container,
        );

        await transport.initialize();

        transport.send(interface_.SendUserMessage(content: 'Test message'));

        await Future.delayed(Duration.zero);
        await transport.close();

        expect(client.sentMessages, hasLength(1));
        expect(client.sentMessages.first.text, 'Test message');
      });

      test('AbortRequest aborts all agents', () async {
        final network = setupBasicNetwork();
        final client = clientFactory.getClient('main-agent');

        final transport = DirectSessionTransport(
          sessionId: network.id,
          container: container,
        );

        final events = <interface_.SessionEvent>[];
        final subscription = transport.events.listen(events.add);

        await transport.initialize();

        transport.send(interface_.AbortRequest());

        await Future.delayed(Duration.zero);
        await subscription.cancel();
        await transport.close();

        expect(client.isAborted, isTrue);

        final abortedEvents = events.whereType<interface_.AbortedEvent>();
        expect(abortedEvents, hasLength(1));
      });

      test('send emits error when session not found', () async {
        // Setup and close transport without initializing network properly
        final transport = DirectSessionTransport(
          sessionId: 'non-existent',
          container: container,
        );

        final events = <interface_.SessionEvent>[];
        final subscription = transport.events.listen(events.add);

        transport.send(interface_.SendUserMessage(content: 'Test'));

        await Future.delayed(Duration.zero);
        await subscription.cancel();
        await transport.close();

        final errorEvents = events.whereType<interface_.ErrorEvent>();
        expect(errorEvents, isNotEmpty);
      });
    });

    group('close', () {
      test('close cleans up subscriptions and closes streams', () async {
        final network = setupBasicNetwork();

        final transport = DirectSessionTransport(
          sessionId: network.id,
          container: container,
        );

        await transport.initialize();
        await transport.close();

        // Verify state is disconnected
        expect(transport.currentState, interface_.ConnectionState.disconnected);

        // Verify no more events are emitted after close
        final eventsAfterClose = <interface_.SessionEvent>[];
        final subscription = transport.events.listen(
          eventsAfterClose.add,
          onDone: () {},
          onError: (e) {},
        );

        await Future.delayed(Duration.zero);
        await subscription.cancel();

        // No new events should be emitted
        expect(eventsAfterClose, isEmpty);
      });
    });
  });
}

/// Extension to allow setting the current network for testing.
extension AgentNetworkManagerTestExtension on AgentNetworkManager {
  void setCurrentNetworkForTest(AgentNetwork network) {
    // Access the state directly to set the network
    state = state.copyWith(currentNetwork: network);
  }
}
