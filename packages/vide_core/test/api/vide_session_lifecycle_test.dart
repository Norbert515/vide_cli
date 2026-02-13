/// Tests for LocalVideSession lifecycle: creation, disposal, and edge cases.
library;

import 'dart:io';

import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';
import 'package:vide_core/src/services/agent_network_manager.dart';

import '../helpers/mock_vide_config_manager.dart';
import '../helpers/session_test_helper.dart';

void main() {
  group('LocalVideSession lifecycle', () {
    late SessionTestHarness h;

    setUp(() async {
      h = SessionTestHarness();
      await h.setUp();
    });

    tearDown(() => h.dispose());

    test('create() returns a session with correct id', () {
      expect(h.session.id, equals(h.networkId));
    });

    test('state returns agents from the network', () {
      final state = h.session.state;
      expect(state.agents, hasLength(1));
      expect(state.agents.first.id, equals(h.agentId));
      expect(state.agents.first.name, equals('Main Agent'));
      expect(state.agents.first.type, equals('main'));
    });

    test('state.mainAgent returns first agent', () {
      expect(h.session.state.mainAgent, isNotNull);
      expect(h.session.state.mainAgent!.id, equals(h.agentId));
    });

    test('initial status event is emitted on creation for each agent', () async {
      // Events are emitted synchronously during _initialize -> _subscribeToAgent
      // but we collect after creation, so check eventHistory
      final statusEvents = h.session.eventHistory
          .whereType<StatusEvent>()
          .toList();
      expect(statusEvents, hasLength(1));
      expect(statusEvents.first.agentId, equals(h.agentId));
      expect(statusEvents.first.status, equals(VideAgentStatus.idle));
    });

    test('emitInitialUserMessage emits a user MessageEvent', () async {
      final events = h.collectEvents();

      h.session.emitInitialUserMessage('Hello, world!');
      await Future<void>.delayed(Duration.zero);

      final userMessages = events
          .whereType<MessageEvent>()
          .where((e) => e.role == 'user')
          .toList();
      expect(userMessages, hasLength(1));
      expect(userMessages.first.content, equals('Hello, world!'));
      expect(userMessages.first.isPartial, isFalse);
      expect(userMessages.first.agentId, equals(h.agentId));
    });

    test('emitInitialUserMessage with attachments includes them', () async {
      final events = h.collectEvents();

      h.session.emitInitialUserMessage(
        'Check this file',
        attachments: [VideAttachment(type: 'file', filePath: '/tmp/test.dart')],
      );
      await Future<void>.delayed(Duration.zero);

      final msg = events.whereType<MessageEvent>().first;
      expect(msg.attachments, isNotNull);
      expect(msg.attachments, hasLength(1));
      expect(msg.attachments!.first.filePath, equals('/tmp/test.dart'));
    });

    test('dispose completes without error', () async {
      await h.session.dispose(fireEndTrigger: false);
      // Verify it's marked disposed by trying an operation
      expect(
        () => h.session.sendMessage(VideMessage(text: 'after dispose')),
        throwsStateError,
      );
    });

    test('dispose is idempotent (double-dispose does not throw)', () async {
      await h.session.dispose(fireEndTrigger: false);
      // Second dispose should be a no-op
      await h.session.dispose(fireEndTrigger: false);
    });

    test('disposed session throws StateError for all operations', () async {
      await h.session.dispose(fireEndTrigger: false);

      expect(
        () => h.session.sendMessage(VideMessage(text: 'test')),
        throwsStateError,
      );
      expect(
        () => h.session.respondToPermission('x', allow: true),
        throwsStateError,
      );
      expect(
        () => h.session.respondToAskUserQuestion('x', answers: {}),
        throwsStateError,
      );
      expect(
        () => h.session.respondToPlanApproval('x', action: 'accept'),
        throwsStateError,
      );
      expect(() => h.session.abort(), throwsA(isA<StateError>()));
      expect(() => h.session.abortAgent(h.agentId), throwsA(isA<StateError>()));
      expect(
        () async => await h.session.clearConversation(),
        throwsA(isA<StateError>()),
      );
      expect(
        () async => await h.session.setWorktreePath('/tmp'),
        throwsA(isA<StateError>()),
      );
      expect(() => h.session.getConversation(h.agentId), throwsStateError);
      expect(() => h.session.conversationStream(h.agentId), throwsStateError);
      expect(
        () async => await h.session.clearQueuedMessage(h.agentId),
        throwsA(isA<StateError>()),
      );
      expect(
        () async => await h.session.getModel(h.agentId),
        throwsA(isA<StateError>()),
      );
      expect(() => h.session.modelStream(h.agentId), throwsStateError);
    });

    test('state.isProcessing is false when no agents are processing', () {
      expect(h.session.state.isProcessing, isFalse);
    });

    test('state.isProcessing is true when agent is processing', () {
      // _isProcessing() checks agentStatusProvider, not conversation state
      container(h)
          .read(agentStatusProvider(h.agentId).notifier)
          .setStatus(AgentStatus.working);
      expect(h.session.state.isProcessing, isTrue);
    });

    test('stateStream emits on status changes', () async {
      final states = <VideState>[];
      h.session.stateStream.listen(states.add);

      // Trigger a status change
      container(h)
          .read(agentStatusProvider(h.agentId).notifier)
          .setStatus(AgentStatus.working);
      await Future<void>.delayed(Duration.zero);

      expect(states, isNotEmpty);
    });

    test('eventHistory accumulates events', () {
      // Initial status event from creation
      expect(h.session.eventHistory, isNotEmpty);

      h.session.emitInitialUserMessage('Test');
      expect(h.session.eventHistory.length, greaterThan(1));
    });
  });

  group('LocalVideSession with no agents', () {
    test('emitInitialUserMessage is a no-op when no agents exist', () async {
      final tempDir = await Directory.systemTemp.createTemp('no_agents_test_');
      final configManager = MockVideConfigManager(tempDir: tempDir);
      final container = ProviderContainer(
        overrides: [
          videConfigManagerProvider.overrideWithValue(configManager),
          workingDirProvider.overrideWithValue(tempDir.path),
          permissionHandlerProvider.overrideWithValue(PermissionHandler()),
        ],
      );

      // Set up network with NO agents
      final manager = container.read(agentNetworkManagerProvider.notifier);
      manager.state = AgentNetworkState(
        currentNetwork: AgentNetwork(
          id: 'empty-network',
          goal: 'Test',
          agents: [],
          createdAt: DateTime.now(),
        ),
      );

      final session = LocalVideSession.create(
        networkId: 'empty-network',
        container: container,
      );

      final events = <VideEvent>[];
      session.events.listen(events.add);

      // Should not throw, just silently skip
      session.emitInitialUserMessage('Hello');
      await Future<void>.delayed(Duration.zero);

      final userMessages = events
          .whereType<MessageEvent>()
          .where((e) => e.role == 'user')
          .toList();
      expect(userMessages, isEmpty);

      await session.dispose(fireEndTrigger: false);
      container.dispose();
      await configManager.dispose();
    });

    test('sendMessage throws when no agents exist', () async {
      final tempDir = await Directory.systemTemp.createTemp('no_agents_test2_');
      final configManager = MockVideConfigManager(tempDir: tempDir);
      final container = ProviderContainer(
        overrides: [
          videConfigManagerProvider.overrideWithValue(configManager),
          workingDirProvider.overrideWithValue(tempDir.path),
          permissionHandlerProvider.overrideWithValue(PermissionHandler()),
        ],
      );

      final manager = container.read(agentNetworkManagerProvider.notifier);
      manager.state = AgentNetworkState(
        currentNetwork: AgentNetwork(
          id: 'empty-network',
          goal: 'Test',
          agents: [],
          createdAt: DateTime.now(),
        ),
      );

      final session = LocalVideSession.create(
        networkId: 'empty-network',
        container: container,
      );

      expect(
        () => session.sendMessage(VideMessage(text: 'Hello')),
        throwsStateError,
      );

      await session.dispose(fireEndTrigger: false);
      container.dispose();
      await configManager.dispose();
    });
  });
}

/// Helper to access the container from a harness (for brevity in tests)
ProviderContainer container(SessionTestHarness h) => h.container;
