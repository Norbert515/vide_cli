import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';

/// Get path to the source assets directory for testing.
String _getSourceAssetsPath() {
  var current = Directory.current.path;

  if (Directory(path.join(current, 'packages/vide_core/assets')).existsSync()) {
    return path.join(current, 'packages/vide_core/assets/team_framework');
  }

  if (Directory(path.join(current, 'assets/team_framework')).existsSync()) {
    return path.join(current, 'assets/team_framework');
  }

  throw StateError('Could not locate source assets directory from: $current');
}

/// Create a test directory structure that mimics ~/.vide/defaults/
Future<String> _createTestVideHome() async {
  final sourceAssets = _getSourceAssetsPath();
  final tempDir = await Directory.systemTemp.createTemp('vide_trigger_test_');
  final defaultsDir = Directory(path.join(tempDir.path, 'defaults'));

  for (final subdir in ['teams', 'agents', 'etiquette']) {
    final targetDir = Directory(path.join(defaultsDir.path, subdir));
    await targetDir.create(recursive: true);

    final sourceDir = Directory(path.join(sourceAssets, subdir));
    if (await sourceDir.exists()) {
      for (final file in sourceDir.listSync().whereType<File>()) {
        await file.copy(path.join(targetDir.path, path.basename(file.path)));
      }
    }
  }

  return tempDir.path;
}

void main() {
  group('Trigger Integration Tests', () {
    late TeamFrameworkLoader loader;
    late String testVideHome;

    setUpAll(() async {
      testVideHome = await _createTestVideHome();
    });

    tearDownAll(() async {
      await Directory(testVideHome).delete(recursive: true);
    });

    setUp(() {
      loader = TeamFrameworkLoader(videHome: testVideHome);
    });

    group('Enterprise Team Lifecycle Triggers', () {
      test('enterprise team has lifecycle triggers configured', () async {
        final team = await loader.getTeam('enterprise');

        expect(team, isNotNull);
        expect(team!.lifecycleTriggers, isNotEmpty);

        // Check onSessionEnd trigger
        final sessionEndTrigger = team.lifecycleTriggers['onSessionEnd'];
        expect(
          sessionEndTrigger,
          isNotNull,
          reason: 'onSessionEnd trigger should be configured',
        );
        expect(sessionEndTrigger!.enabled, isTrue);
        expect(sessionEndTrigger.spawn, equals('session-synthesizer'));

        // Check onTaskComplete trigger
        final taskCompleteTrigger = team.lifecycleTriggers['onTaskComplete'];
        expect(
          taskCompleteTrigger,
          isNotNull,
          reason: 'onTaskComplete trigger should be configured',
        );
        expect(taskCompleteTrigger!.enabled, isTrue);
        expect(taskCompleteTrigger.spawn, equals('code-reviewer'));
      });

      test('session-synthesizer agent exists and can be loaded', () async {
        final agent = await loader.getAgent('session-synthesizer');

        expect(
          agent,
          isNotNull,
          reason: 'session-synthesizer agent should exist',
        );
        expect(agent!.name, equals('session-synthesizer'));
        expect(agent.displayName, equals('Sage'));
        expect(agent.mcpServers, contains('vide-knowledge'));
        expect(agent.mcpServers, contains('vide-agent'));
      });

      test('code-reviewer agent exists and can be loaded', () async {
        final agent = await loader.getAgent('code-reviewer');

        expect(agent, isNotNull, reason: 'code-reviewer agent should exist');
        expect(agent!.name, equals('code-reviewer'));
        expect(agent.displayName, equals('Tim'));
        expect(agent.mcpServers, contains('vide-agent'));
      });

      test('buildAgentConfiguration works for triggered agents', () async {
        final synthConfig = await loader.buildAgentConfiguration(
          'session-synthesizer',
          teamName: 'enterprise',
        );

        expect(synthConfig, isNotNull);
        expect(synthConfig!.name, equals('session-synthesizer'));
        expect(synthConfig.systemPrompt, contains('Session Synthesizer'));

        final reviewerConfig = await loader.buildAgentConfiguration(
          'code-reviewer',
          teamName: 'enterprise',
        );

        expect(reviewerConfig, isNotNull);
        expect(reviewerConfig!.name, equals('code-reviewer'));
        expect(reviewerConfig.systemPrompt, contains('Code Reviewer'));
      });
    });

    group('Vide Team (no triggers)', () {
      test('vide team has no lifecycle triggers', () async {
        final team = await loader.getTeam('vide');

        expect(team, isNotNull);
        expect(
          team!.lifecycleTriggers,
          isEmpty,
          reason: 'vide team should not have lifecycle triggers',
        );
      });
    });

    group('TriggerContext', () {
      test('buildContextSection generates valid markdown', () {
        final network = AgentNetwork(
          id: 'test-network-123',
          goal: 'Implement authentication',
          agents: [
            AgentMetadata(
              id: 'agent-1',
              name: 'Elena',
              type: 'enterprise-lead',
              createdAt: DateTime.now(),
              shortDescription: 'Organizes teams',
            ),
            AgentMetadata(
              id: 'agent-2',
              name: 'Bert',
              type: 'implementer',
              createdAt: DateTime.now(),
              shortDescription: 'Writes code',
            ),
          ],
          createdAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        );

        final context = TriggerContext(
          triggerPoint: TriggerPoint.onTaskComplete,
          network: network,
          teamName: 'enterprise',
          taskName: 'Add JWT auth',
          filesChanged: ['lib/auth.dart', 'lib/jwt.dart'],
        );

        final section = context.buildContextSection();

        // Verify structure
        expect(section, contains('## Trigger Context'));
        expect(section, contains('onTaskComplete'));
        expect(section, contains('test-network-123'));
        expect(section, contains('Implement authentication'));
        expect(section, contains('enterprise'));

        // Verify agents listed
        expect(section, contains('Elena'));
        expect(section, contains('enterprise-lead'));
        expect(section, contains('Organizes teams'));
        expect(section, contains('Bert'));
        expect(section, contains('implementer'));

        // Verify task info
        expect(section, contains('Add JWT auth'));
        expect(section, contains('lib/auth.dart'));
        expect(section, contains('lib/jwt.dart'));
      });

      test('buildContextSection handles missing optional fields', () {
        final network = AgentNetwork(
          id: 'test-network',
          goal: 'Test goal',
          agents: [
            AgentMetadata(
              id: 'agent-1',
              name: 'Test',
              type: 'main',
              createdAt: DateTime.now(),
            ),
          ],
          createdAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        );

        final context = TriggerContext(
          triggerPoint: TriggerPoint.onSessionEnd,
          network: network,
          teamName: 'vide',
          // No taskName or filesChanged
        );

        final section = context.buildContextSection();

        expect(section, contains('onSessionEnd'));
        expect(section, contains('Test'));
        expect(
          section,
          isNot(contains('### Task')),
        ); // Task section should be absent
      });
    });

    group('Trigger Point Names', () {
      test('trigger point names match YAML keys', () {
        // These names must match exactly what's in the YAML
        expect(TriggerPoint.onSessionStart.name, equals('onSessionStart'));
        expect(TriggerPoint.onSessionEnd.name, equals('onSessionEnd'));
        expect(TriggerPoint.onTaskComplete.name, equals('onTaskComplete'));
        expect(TriggerPoint.onAllAgentsIdle.name, equals('onAllAgentsIdle'));
      });

      test('enterprise team trigger keys match TriggerPoint names', () async {
        final team = await loader.getTeam('enterprise');

        // The keys in lifecycleTriggers should match TriggerPoint enum names
        for (final key in team!.lifecycleTriggers.keys) {
          final matchesTriggerPoint = TriggerPoint.values.any(
            (tp) => tp.name == key,
          );
          expect(
            matchesTriggerPoint,
            isTrue,
            reason: 'Trigger key "$key" should match a TriggerPoint enum value',
          );
        }
      });
    });

    group('End-to-End Trigger Flow Simulation', () {
      test('simulate onSessionEnd trigger for enterprise team', () async {
        // 1. Load the team
        final team = await loader.getTeam('enterprise');
        expect(team, isNotNull);

        // 2. Check trigger config
        final triggerConfig = team!.lifecycleTriggers['onSessionEnd'];
        expect(triggerConfig, isNotNull);
        expect(triggerConfig!.enabled, isTrue);
        expect(triggerConfig.spawn, equals('session-synthesizer'));

        // 3. Load the agent to be spawned
        final agentPersonality = await loader.getAgent(triggerConfig.spawn);
        expect(agentPersonality, isNotNull);
        expect(agentPersonality!.displayName, equals('Sage'));

        // 4. Build the agent configuration
        final config = await loader.buildAgentConfiguration(
          triggerConfig.spawn,
          teamName: 'enterprise',
        );
        expect(config, isNotNull);

        // 5. Create trigger context
        final network = AgentNetwork(
          id: 'session-123',
          goal: 'Build feature X',
          agents: [
            AgentMetadata(
              id: 'main-1',
              name: 'Elena',
              type: 'enterprise-lead',
              createdAt: DateTime.now(),
              shortDescription: 'Organizes teams',
            ),
          ],
          createdAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
          team: 'enterprise',
        );

        final context = TriggerContext(
          triggerPoint: TriggerPoint.onSessionEnd,
          network: network,
          teamName: 'enterprise',
        );

        // 6. Verify context generation
        final contextSection = context.buildContextSection();
        expect(contextSection, contains('onSessionEnd'));
        expect(contextSection, contains('session-123'));
        expect(contextSection, contains('Build feature X'));

        // This would be the prompt sent to the triggered agent
        print('--- Simulated Trigger Prompt ---');
        print(
          'Agent to spawn: ${agentPersonality.displayName} (${agentPersonality.name})',
        );
        print('Trigger: onSessionEnd');
        print('Context:\n$contextSection');
        print('--- End ---');
      });

      test('simulate onTaskComplete trigger for enterprise team', () async {
        // 1. Load the team
        final team = await loader.getTeam('enterprise');
        expect(team, isNotNull);

        // 2. Check trigger config
        final triggerConfig = team!.lifecycleTriggers['onTaskComplete'];
        expect(triggerConfig, isNotNull);
        expect(triggerConfig!.enabled, isTrue);
        expect(triggerConfig.spawn, equals('code-reviewer'));

        // 3. Load the agent to be spawned
        final agentPersonality = await loader.getAgent(triggerConfig.spawn);
        expect(agentPersonality, isNotNull);
        expect(agentPersonality!.displayName, equals('Tim'));

        // 4. Create trigger context with files changed
        final network = AgentNetwork(
          id: 'session-456',
          goal: 'Add authentication',
          agents: [
            AgentMetadata(
              id: 'main-1',
              name: 'Elena',
              type: 'enterprise-lead',
              createdAt: DateTime.now(),
            ),
            AgentMetadata(
              id: 'impl-1',
              name: 'Bert',
              type: 'implementer',
              createdAt: DateTime.now(),
              shortDescription: 'Writes code',
            ),
          ],
          createdAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
          team: 'enterprise',
        );

        final context = TriggerContext(
          triggerPoint: TriggerPoint.onTaskComplete,
          network: network,
          teamName: 'enterprise',
          taskName: 'Implement JWT authentication',
          filesChanged: [
            'lib/auth/jwt_service.dart',
            'lib/auth/auth_middleware.dart',
            'test/auth/jwt_service_test.dart',
          ],
        );

        // 5. Verify context generation
        final contextSection = context.buildContextSection();
        expect(contextSection, contains('onTaskComplete'));
        expect(contextSection, contains('Implement JWT authentication'));
        expect(contextSection, contains('lib/auth/jwt_service.dart'));
        expect(contextSection, contains('lib/auth/auth_middleware.dart'));

        print('--- Simulated Trigger Prompt ---');
        print(
          'Agent to spawn: ${agentPersonality.displayName} (${agentPersonality.name})',
        );
        print('Trigger: onTaskComplete');
        print('Context:\n$contextSection');
        print('--- End ---');
      });
    });
  });
}
