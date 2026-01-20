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
          expect(team.mainAgent, isNotEmpty,
              reason: 'Team ${team.name} missing main agent');
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

        expect(missingAgents, isEmpty,
            reason: 'Missing agents: $missingAgents');
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
          expect(agent.mcpServers, contains('vide-agent'),
              reason: 'Agent ${agent.name} missing vide-agent MCP server');
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

      test('buildAgentConfiguration includes etiquette', () async {
        final config = await loader.buildAgentConfiguration('main');

        expect(config, isNotNull);
        // Main agent includes etiquette/messaging
        expect(config!.systemPrompt.toLowerCase(), contains('message'));
      });

      test('returns null for non-existent agent', () async {
        final config = await loader.buildAgentConfiguration('non-existent');

        expect(config, isNull);
      });
    });

    group('Team Selection', () {
      test('findBestTeam returns vide for generic tasks', () async {
        final team = await loader.findBestTeam('add a button');

        expect(team, isNotNull);
        // Default should be vide
        expect(team!.name, 'vide');
      });

      test('findBestTeam considers triggers', () async {
        final team = await loader.findBestTeam('production security fix');

        expect(team, isNotNull);
        expect(team!.name, 'enterprise');
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
  });
}
