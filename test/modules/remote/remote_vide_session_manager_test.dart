import 'dart:io';

import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart'
    show AgentNetwork, AgentNetworkPersistenceManager, VideConfigManager;
import 'package:vide_daemon/vide_daemon.dart'
    show SessionProcessState, SessionSummary;

void main() {
  group('RemoteVideSessionManager', () {
    late Directory tempDir;
    late VideConfigManager configManager;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('vide_session_manager_test_');
      configManager = VideConfigManager(configRoot: tempDir.path);
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    group('AgentNetworkPersistenceManager project scoping', () {
      test('different project paths use different storage locations', () async {
        final managerA = AgentNetworkPersistenceManager(
          configManager: configManager,
          projectPath: '/projects/alpha',
        );
        final managerB = AgentNetworkPersistenceManager(
          configManager: configManager,
          projectPath: '/projects/beta',
        );

        final network = AgentNetwork(
          id: 'net-1',
          goal: 'Build feature X',
          agents: [],
          createdAt: DateTime(2025, 1, 1),
        );

        await managerA.saveNetwork(network);

        final networksFromA = await managerA.loadNetworks();
        final networksFromB = await managerB.loadNetworks();

        expect(networksFromA, hasLength(1));
        expect(networksFromA.first.id, equals('net-1'));
        expect(networksFromB, isEmpty);
      });

      test('same project path shares storage across manager instances',
          () async {
        final manager1 = AgentNetworkPersistenceManager(
          configManager: configManager,
          projectPath: '/projects/shared',
        );
        final manager2 = AgentNetworkPersistenceManager(
          configManager: configManager,
          projectPath: '/projects/shared',
        );

        final network = AgentNetwork(
          id: 'net-shared',
          goal: 'Shared session',
          agents: [],
          createdAt: DateTime(2025, 2, 1),
        );

        await manager1.saveNetwork(network);

        final networksFrom2 = await manager2.loadNetworks();
        expect(networksFrom2, hasLength(1));
        expect(networksFrom2.first.id, equals('net-shared'));
      });

      test('networks are isolated between projects', () async {
        final managerA = AgentNetworkPersistenceManager(
          configManager: configManager,
          projectPath: '/home/user/project-a',
        );
        final managerB = AgentNetworkPersistenceManager(
          configManager: configManager,
          projectPath: '/home/user/project-b',
        );

        final networkA = AgentNetwork(
          id: 'net-a',
          goal: 'Project A work',
          agents: [],
          createdAt: DateTime(2025, 3, 1),
        );
        final networkB = AgentNetwork(
          id: 'net-b',
          goal: 'Project B work',
          agents: [],
          createdAt: DateTime(2025, 3, 2),
        );

        await managerA.saveNetwork(networkA);
        await managerB.saveNetwork(networkB);

        final networksA = await managerA.loadNetworks();
        final networksB = await managerB.loadNetworks();

        expect(networksA, hasLength(1));
        expect(networksA.first.id, equals('net-a'));
        expect(networksB, hasLength(1));
        expect(networksB.first.id, equals('net-b'));
      });

      test('deleting from one project does not affect another', () async {
        final managerA = AgentNetworkPersistenceManager(
          configManager: configManager,
          projectPath: '/projects/alpha',
        );
        final managerB = AgentNetworkPersistenceManager(
          configManager: configManager,
          projectPath: '/projects/beta',
        );

        final networkA = AgentNetwork(
          id: 'shared-id',
          goal: 'Alpha work',
          agents: [],
          createdAt: DateTime(2025, 4, 1),
        );
        final networkB = AgentNetwork(
          id: 'shared-id',
          goal: 'Beta work',
          agents: [],
          createdAt: DateTime(2025, 4, 2),
        );

        await managerA.saveNetwork(networkA);
        await managerB.saveNetwork(networkB);

        await managerA.deleteNetwork('shared-id');

        final networksA = await managerA.loadNetworks();
        final networksB = await managerB.loadNetworks();

        expect(networksA, isEmpty);
        expect(networksB, hasLength(1));
        expect(networksB.first.goal, equals('Beta work'));
      });
    });

    group('session filtering by working directory', () {
      test('filters running sessions by matching working directory', () {
        final summaries = [
          SessionSummary(
            sessionId: 'session-1',
            workingDirectory: '/projects/alpha',
            createdAt: DateTime(2025, 1, 1),
            state: SessionProcessState.ready,
            connectedClients: 1,
            port: 8080,
            goal: 'Alpha task',
          ),
          SessionSummary(
            sessionId: 'session-2',
            workingDirectory: '/projects/beta',
            createdAt: DateTime(2025, 1, 2),
            state: SessionProcessState.ready,
            connectedClients: 0,
            port: 8081,
            goal: 'Beta task',
          ),
          SessionSummary(
            sessionId: 'session-3',
            workingDirectory: '/projects/alpha',
            createdAt: DateTime(2025, 1, 3),
            state: SessionProcessState.ready,
            connectedClients: 1,
            port: 8082,
            goal: 'Another alpha task',
          ),
        ];

        final effectiveWorkingDir = '/projects/alpha';
        final filtered = summaries
            .where(
              (summary) => summary.workingDirectory == effectiveWorkingDir,
            )
            .toList();

        expect(filtered, hasLength(2));
        expect(filtered.map((s) => s.sessionId), contains('session-1'));
        expect(filtered.map((s) => s.sessionId), contains('session-3'));
        expect(
          filtered.map((s) => s.sessionId),
          isNot(contains('session-2')),
        );
      });

      test('returns empty when no sessions match directory', () {
        final summaries = [
          SessionSummary(
            sessionId: 'session-1',
            workingDirectory: '/projects/alpha',
            createdAt: DateTime(2025, 1, 1),
            state: SessionProcessState.ready,
            connectedClients: 1,
            port: 8080,
          ),
        ];

        final filtered = summaries
            .where(
              (summary) =>
                  summary.workingDirectory == '/projects/nonexistent',
            )
            .toList();

        expect(filtered, isEmpty);
      });

      test('exact path match required (no partial matching)', () {
        final summaries = [
          SessionSummary(
            sessionId: 'session-1',
            workingDirectory: '/projects/alpha',
            createdAt: DateTime(2025, 1, 1),
            state: SessionProcessState.ready,
            connectedClients: 1,
            port: 8080,
          ),
          SessionSummary(
            sessionId: 'session-2',
            workingDirectory: '/projects/alpha/subdir',
            createdAt: DateTime(2025, 1, 2),
            state: SessionProcessState.ready,
            connectedClients: 0,
            port: 8081,
          ),
        ];

        final filtered = summaries
            .where(
              (summary) => summary.workingDirectory == '/projects/alpha',
            )
            .toList();

        expect(filtered, hasLength(1));
        expect(filtered.first.sessionId, equals('session-1'));
      });
    });

    group('merged session list deduplication', () {
      test('running sessions take precedence over historical', () async {
        final manager = AgentNetworkPersistenceManager(
          configManager: configManager,
          projectPath: '/projects/alpha',
        );

        // Persist a network that is also currently running.
        final network = AgentNetwork(
          id: 'session-running',
          goal: 'Running task',
          agents: [],
          createdAt: DateTime(2025, 1, 1),
        );
        await manager.saveNetwork(network);

        // Simulate running sessions from daemon.
        final runningSessions = [
          SessionSummary(
            sessionId: 'session-running',
            workingDirectory: '/projects/alpha',
            createdAt: DateTime(2025, 1, 1),
            state: SessionProcessState.ready,
            connectedClients: 1,
            port: 8080,
            goal: 'Running task',
          ),
        ];

        final runningIds =
            runningSessions.map((s) => s.sessionId).toSet();

        // Load historical and filter out running ones.
        final networks = await manager.loadNetworks();
        final historicalOnly =
            networks.where((n) => !runningIds.contains(n.id)).toList();

        expect(historicalOnly, isEmpty);
      });

      test('historical sessions not running are included', () async {
        final manager = AgentNetworkPersistenceManager(
          configManager: configManager,
          projectPath: '/projects/alpha',
        );

        final historicalNetwork = AgentNetwork(
          id: 'session-historical',
          goal: 'Old completed task',
          agents: [],
          createdAt: DateTime(2025, 1, 1),
        );
        await manager.saveNetwork(historicalNetwork);

        // No running sessions match.
        final runningIds = <String>{'session-running-other'};

        final networks = await manager.loadNetworks();
        final historicalOnly =
            networks.where((n) => !runningIds.contains(n.id)).toList();

        expect(historicalOnly, hasLength(1));
        expect(historicalOnly.first.id, equals('session-historical'));
      });

      test('merged list sorts by most recent activity', () {
        final now = DateTime(2025, 6, 1);

        // Create sessions with different timestamps.
        final sessions = [
          _FakeSessionInfo(
            id: 'oldest',
            createdAt: now.subtract(const Duration(days: 3)),
            lastActiveAt: now.subtract(const Duration(days: 3)),
          ),
          _FakeSessionInfo(
            id: 'newest',
            createdAt: now.subtract(const Duration(days: 1)),
            lastActiveAt: now,
          ),
          _FakeSessionInfo(
            id: 'middle',
            createdAt: now.subtract(const Duration(days: 2)),
            lastActiveAt: now.subtract(const Duration(days: 1)),
          ),
        ];

        // Apply the same sort logic as listSessions.
        sessions.sort((a, b) {
          final aTime = a.lastActiveAt ?? a.createdAt;
          final bTime = b.lastActiveAt ?? b.createdAt;
          return bTime.compareTo(aTime);
        });

        expect(sessions[0].id, equals('newest'));
        expect(sessions[1].id, equals('middle'));
        expect(sessions[2].id, equals('oldest'));
      });

      test('sorting uses createdAt when lastActiveAt is null', () {
        final now = DateTime(2025, 6, 1);

        final sessions = [
          _FakeSessionInfo(
            id: 'no-activity',
            createdAt: now.subtract(const Duration(days: 1)),
            lastActiveAt: null,
          ),
          _FakeSessionInfo(
            id: 'with-activity',
            createdAt: now.subtract(const Duration(days: 5)),
            lastActiveAt: now,
          ),
        ];

        sessions.sort((a, b) {
          final aTime = a.lastActiveAt ?? a.createdAt;
          final bTime = b.lastActiveAt ?? b.createdAt;
          return bTime.compareTo(aTime);
        });

        expect(sessions[0].id, equals('with-activity'));
        expect(sessions[1].id, equals('no-activity'));
      });
    });

    group('VideConfigManager project storage isolation', () {
      test('encodes project paths deterministically', () {
        final dirA = configManager.getProjectStorageDir('/projects/alpha');
        final dirB = configManager.getProjectStorageDir('/projects/beta');
        final dirA2 = configManager.getProjectStorageDir('/projects/alpha');

        expect(dirA, isNot(equals(dirB)));
        expect(dirA, equals(dirA2));
      });

      test('project storage directories are created on disk', () {
        final storageDir =
            configManager.getProjectStorageDir('/projects/gamma');
        expect(Directory(storageDir).existsSync(), isTrue);
      });
    });
  });
}

/// Minimal test helper for sorting tests.
class _FakeSessionInfo {
  final String id;
  final DateTime createdAt;
  final DateTime? lastActiveAt;

  _FakeSessionInfo({
    required this.id,
    required this.createdAt,
    this.lastActiveAt,
  });
}
