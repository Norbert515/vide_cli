import 'package:test/test.dart';
import 'package:vide_core/src/models/team_framework/team_definition.dart';
import 'package:vide_core/src/services/trigger_service.dart';
import 'package:vide_core/src/models/agent_network.dart';
import 'package:vide_core/src/models/agent_metadata.dart';

void main() {
  group('TriggerPoint', () {
    test('has all expected trigger points', () {
      expect(TriggerPoint.values, hasLength(4));
      expect(TriggerPoint.values, contains(TriggerPoint.onSessionStart));
      expect(TriggerPoint.values, contains(TriggerPoint.onSessionEnd));
      expect(TriggerPoint.values, contains(TriggerPoint.onTaskComplete));
      expect(TriggerPoint.values, contains(TriggerPoint.onAllAgentsIdle));
    });
  });

  group('LifecycleTriggerConfig', () {
    test('fromYaml parses enabled and spawn', () {
      final config = LifecycleTriggerConfig.fromYaml({
        'enabled': true,
        'spawn': 'session-synthesizer',
      });

      expect(config.enabled, isTrue);
      expect(config.spawn, equals('session-synthesizer'));
    });

    test('fromYaml defaults enabled to true', () {
      final config = LifecycleTriggerConfig.fromYaml({
        'spawn': 'code-reviewer',
      });

      expect(config.enabled, isTrue);
      expect(config.spawn, equals('code-reviewer'));
    });

    test('fromYaml defaults spawn to empty string', () {
      final config = LifecycleTriggerConfig.fromYaml({'enabled': false});

      expect(config.enabled, isFalse);
      expect(config.spawn, equals(''));
    });
  });

  group('TriggerContext', () {
    late AgentNetwork testNetwork;

    setUp(() {
      testNetwork = AgentNetwork(
        id: 'test-network-id',
        goal: 'Implement authentication',
        agents: [
          AgentMetadata(
            id: 'agent-1',
            name: 'Klaus',
            type: 'main',
            createdAt: DateTime.now(),
            shortDescription: 'Coordinates work',
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
    });

    test('buildContextSection includes session info', () {
      final context = TriggerContext(
        triggerPoint: TriggerPoint.onSessionEnd,
        network: testNetwork,
        teamName: 'enterprise',
      );

      final section = context.buildContextSection();

      expect(section, contains('onSessionEnd'));
      expect(section, contains('test-network-id'));
      expect(section, contains('Implement authentication'));
      expect(section, contains('enterprise'));
    });

    test('buildContextSection includes agent list', () {
      final context = TriggerContext(
        triggerPoint: TriggerPoint.onSessionEnd,
        network: testNetwork,
        teamName: 'enterprise',
      );

      final section = context.buildContextSection();

      expect(section, contains('Klaus'));
      expect(section, contains('main'));
      expect(section, contains('Coordinates work'));
      expect(section, contains('Bert'));
      expect(section, contains('implementer'));
    });

    test('buildContextSection includes task info when provided', () {
      final context = TriggerContext(
        triggerPoint: TriggerPoint.onTaskComplete,
        network: testNetwork,
        teamName: 'enterprise',
        taskName: 'Add JWT authentication',
        filesChanged: ['lib/auth.dart', 'lib/jwt.dart'],
      );

      final section = context.buildContextSection();

      expect(section, contains('Add JWT authentication'));
      expect(section, contains('lib/auth.dart'));
      expect(section, contains('lib/jwt.dart'));
    });
  });

  group('TeamDefinition lifecycle triggers', () {
    test('parses lifecycle-triggers from YAML', () {
      const markdown = '''---
name: test-team
description: Test team with triggers
main-agent: main

agents:
  - implementer
  - session-synthesizer
  - code-reviewer

lifecycle-triggers:
  onSessionEnd:
    enabled: true
    spawn: session-synthesizer
  onTaskComplete:
    enabled: true
    spawn: code-reviewer
  onSessionStart:
    enabled: false
---

# Test Team
''';

      final team = TeamDefinition.fromMarkdown(markdown, 'test.md');

      expect(team.lifecycleTriggers, hasLength(3));

      expect(team.lifecycleTriggers['onSessionEnd']?.enabled, isTrue);
      expect(
        team.lifecycleTriggers['onSessionEnd']?.spawn,
        equals('session-synthesizer'),
      );

      expect(team.lifecycleTriggers['onTaskComplete']?.enabled, isTrue);
      expect(
        team.lifecycleTriggers['onTaskComplete']?.spawn,
        equals('code-reviewer'),
      );

      expect(team.lifecycleTriggers['onSessionStart']?.enabled, isFalse);
    });

    test('handles team without lifecycle-triggers', () {
      const markdown = '''---
name: simple-team
description: Simple team without triggers
main-agent: main

agents:
  - implementer
---

# Simple Team
''';

      final team = TeamDefinition.fromMarkdown(markdown, 'test.md');

      expect(team.lifecycleTriggers, isEmpty);
    });
  });
}
