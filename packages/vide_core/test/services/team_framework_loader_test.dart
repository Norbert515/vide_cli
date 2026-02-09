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
  final tempDir = await Directory.systemTemp.createTemp('vide_test_');
  final defaultsDir = Directory(path.join(tempDir.path, 'defaults'));

  for (final subdir in ['teams', 'agents', 'etiquette', 'behaviors']) {
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
  group('TeamFrameworkLoader', () {
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

    group('Team Loading', () {
      test('vide team has correct structure', () async {
        final team = await loader.getTeam('vide');

        expect(team, isNotNull);
        expect(team!.name, 'vide');
        expect(team.mainAgent, 'main');
        expect(team.agents, contains('researcher'));
        expect(team.agents, contains('implementer'));
        expect(team.agents, contains('tester'));
      });

      test('enterprise team has correct structure', () async {
        final team = await loader.getTeam('enterprise');

        expect(team, isNotNull);
        expect(team!.name, 'enterprise');
        expect(team.mainAgent, 'enterprise-lead');
        expect(team.agents, contains('feature-lead'));
        expect(team.agents, contains('implementer'));
        expect(team.agents, contains('researcher'));
        expect(team.agents, contains('qa-breaker'));
      });

      test('all teams have a main agent', () async {
        final teams = await loader.loadTeams();

        for (final team in teams.values) {
          expect(
            team.mainAgent,
            isNotEmpty,
            reason: 'Team ${team.name} missing main agent',
          );
        }
      });

      test('all agents referenced in teams exist', () async {
        final teams = await loader.loadTeams();
        final agents = await loader.loadAgents();

        final missingAgents = <String, List<String>>{};

        for (final team in teams.values) {
          if (!agents.containsKey(team.mainAgent)) {
            missingAgents.putIfAbsent(team.mainAgent, () => []);
            missingAgents[team.mainAgent]!.add('${team.name}/main-agent');
          }

          for (final agentName in team.agents) {
            if (!agents.containsKey(agentName)) {
              missingAgents.putIfAbsent(agentName, () => []);
              missingAgents[agentName]!.add('${team.name}/agents');
            }
          }
        }

        expect(
          missingAgents,
          isEmpty,
          reason: 'Missing agents: $missingAgents',
        );
      });
    });

    group('Agent Loading', () {
      test('main agent exists and has correct config', () async {
        final agent = await loader.getAgent('main');

        expect(agent, isNotNull);
        expect(agent!.name, 'main');
        expect(agent.model, 'opus');
      });

      test('implementer agent exists', () async {
        final agent = await loader.getAgent('implementer');

        expect(agent, isNotNull);
        expect(agent!.name, 'implementer');
      });

      test('researcher agent exists', () async {
        final agent = await loader.getAgent('researcher');

        expect(agent, isNotNull);
        expect(agent!.name, 'researcher');
      });

      test('tester agent exists', () async {
        final agent = await loader.getAgent('tester');

        expect(agent, isNotNull);
        expect(agent!.name, 'tester');
      });

      test('all agents have vide-agent MCP server', () async {
        final agents = await loader.loadAgents();

        for (final agent in agents.values) {
          expect(
            agent.mcpServers,
            contains('vide-agent'),
            reason: 'Agent ${agent.name} missing vide-agent MCP server',
          );
        }
      });
    });

    group('Agent Configuration Building', () {
      test('buildAgentConfiguration creates complete config', () async {
        final config = await loader.buildAgentConfiguration('main');

        expect(config, isNotNull);
        expect(config!.systemPrompt, isNotEmpty);
        expect(config.model, isNotNull);
      });

      test('buildAgentConfiguration includes etiquette from team', () async {
        final config = await loader.buildAgentConfiguration(
          'main',
          teamName: 'vide',
        );

        expect(config, isNotNull);
        // Etiquette comes from the team, not the agent
        expect(config!.systemPrompt.toLowerCase(), contains('message'));
      });

      test('returns null for non-existent agent', () async {
        final config = await loader.buildAgentConfiguration('non-existent');

        expect(config, isNull);
      });
    });

    group('Team Selection', () {
      test('findBestTeam returns enterprise for generic tasks', () async {
        final team = await loader.findBestTeam('add a button');

        expect(team, isNotNull);
        // Default should be enterprise
        expect(team!.name, 'enterprise');
      });
    });

    group('Behavior Loading', () {
      test('qa-review-cycle behavior loads', () async {
        final behavior = await loader.getBehavior('qa-review-cycle');

        expect(behavior, isNotNull);
        expect(behavior!.name, 'qa-review-cycle');
        expect(behavior.content, contains('qa-breaker'));
      });

      test('behavior includes resolve in agent prompts', () async {
        final config = await loader.buildAgentConfiguration('enterprise-lead');

        expect(config, isNotNull);
        // enterprise-lead includes behaviors/qa-review-cycle
        expect(config!.systemPrompt, contains('QA Review Cycle'));
      });

      test('feature-lead includes qa-review-cycle behavior', () async {
        final config = await loader.buildAgentConfiguration('feature-lead');

        expect(config, isNotNull);
        expect(config!.systemPrompt, contains('QA Review Cycle'));
      });
    });

    group('Source Assets Verification', () {
      test('source assets load correctly', () async {
        final teams = await loader.loadTeams();
        final agents = await loader.loadAgents();

        expect(teams, isNotEmpty);
        expect(agents, isNotEmpty);
        expect(teams.containsKey('vide'), isTrue);
        expect(agents.containsKey('main'), isTrue);
      });
    });

    group('Anti-hallucination messaging', () {
      // Every team that includes etiquette/messaging should inject
      // anti-hallucination content into all its agents' prompts.

      final antiHallucinationPhrases = [
        'NEVER Hallucinate Sub-Agent Responses',
        'End your turn IMMEDIATELY',
        'Do NOT generate your own answer',
        'Do NOT guess or hallucinate',
        'STOP producing output',
        'system-reminder',
      ];

      for (final teamName in ['vide', 'enterprise', 'flutter']) {
        group('team: $teamName', () {
          test('team includes messaging etiquette', () async {
            final team = await loader.getTeam(teamName);

            expect(team, isNotNull);
            expect(
              team!.include,
              contains('etiquette/messaging'),
              reason:
                  'Team $teamName must include etiquette/messaging for '
                  'anti-hallucination rules',
            );
          });

          test('main agent prompt contains anti-hallucination rules',
              () async {
            final team = await loader.getTeam(teamName);
            final config = await loader.buildAgentConfiguration(
              team!.mainAgent,
              teamName: teamName,
            );

            expect(config, isNotNull);
            for (final phrase in antiHallucinationPhrases) {
              expect(
                config!.systemPrompt,
                contains(phrase),
                reason:
                    'Main agent "${team.mainAgent}" in team "$teamName" '
                    'missing anti-hallucination phrase: "$phrase"',
              );
            }
          });

          test('all team agents receive anti-hallucination rules',
              () async {
            final team = await loader.getTeam(teamName);

            for (final agentName in team!.agents) {
              loader.clearCache();
              final config = await loader.buildAgentConfiguration(
                agentName,
                teamName: teamName,
              );

              expect(
                config,
                isNotNull,
                reason: 'Agent $agentName failed to load',
              );
              expect(
                config!.systemPrompt,
                contains('NEVER Hallucinate Sub-Agent Responses'),
                reason:
                    'Agent "$agentName" in team "$teamName" missing '
                    'anti-hallucination section',
              );
            }
          });
        });
      }

      test('messaging etiquette appears before agent content', () async {
        final config = await loader.buildAgentConfiguration(
          'main',
          teamName: 'vide',
        );

        expect(config, isNotNull);
        final prompt = config!.systemPrompt;

        final hallucinationIdx =
            prompt.indexOf('NEVER Hallucinate Sub-Agent Responses');
        final orchestratorIdx = prompt.indexOf('YOU ARE THE ORCHESTRATOR');

        expect(
          hallucinationIdx,
          lessThan(orchestratorIdx),
          reason:
              'Anti-hallucination rules from messaging etiquette should '
              'appear before the agent\'s own content',
        );
      });

      test(
          'messaging etiquette appears before agent content in enterprise',
          () async {
        final config = await loader.buildAgentConfiguration(
          'enterprise-lead',
          teamName: 'enterprise',
        );

        expect(config, isNotNull);
        final prompt = config!.systemPrompt;

        final hallucinationIdx =
            prompt.indexOf('NEVER Hallucinate Sub-Agent Responses');
        final orchestratorIdx =
            prompt.indexOf('ENTERPRISE ORCHESTRATOR');

        expect(
          hallucinationIdx,
          lessThan(orchestratorIdx),
          reason:
              'Anti-hallucination rules from messaging etiquette should '
              'appear before the agent\'s own content',
        );
      });
    });
  });
}
