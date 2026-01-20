import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';

void main() {
  group('TeamFrameworkLoader - Integration Tests', () {
    late TeamFrameworkLoader loader;
    late Directory tempDir;
    late String videHome;

    setUpAll(() async {
      // Create a temporary directory for test assets
      tempDir = await Directory.systemTemp.createTemp('vide_test_');
      videHome = tempDir.path;

      // Copy assets from package to temp directory
      final defaultsDir = Directory(path.join(videHome, 'defaults'));
      await defaultsDir.create(recursive: true);

      // Copy from package assets directory
      final categories = ['teams', 'agents', 'etiquette'];
      final assetsPath = 'assets/team_framework';

      for (final category in categories) {
        final targetCategoryDir =
            Directory(path.join(defaultsDir.path, category));
        await targetCategoryDir.create(recursive: true);

        final sourceDir = Directory(path.join(assetsPath, category));
        if (await sourceDir.exists()) {
          final files = sourceDir
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.md'));
          for (final file in files) {
            final targetFile = File(
              path.join(targetCategoryDir.path, path.basename(file.path)),
            );
            await file.copy(targetFile.path);
          }
        }
      }
    });

    tearDownAll(() async {
      // Clean up temp directory
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    setUp(() {
      loader = TeamFrameworkLoader(videHome: videHome);
    });

    group('buildAgentConfiguration', () {
      test('implementer agent loads successfully', () async {
        final config = await loader.buildAgentConfiguration('implementer');

        expect(config, isNotNull);
        expect(config!.name, 'implementer');
        expect(config.description, isNotEmpty);
        expect(config.systemPrompt, isNotEmpty);
      });

      test('main agent loads successfully', () async {
        final config = await loader.buildAgentConfiguration('main');

        expect(config, isNotNull);
        expect(config!.name, 'main');
        expect(config.description, isNotEmpty);
        expect(config.systemPrompt, isNotEmpty);
      });

      test('researcher agent loads successfully', () async {
        final config = await loader.buildAgentConfiguration('researcher');

        expect(config, isNotNull);
        expect(config!.name, 'researcher');
      });

      test('flutter-tester agent loads successfully', () async {
        final config = await loader.buildAgentConfiguration('flutter-tester');

        expect(config, isNotNull);
        expect(config!.name, 'flutter-tester');
      });

      test('tester agent loads successfully', () async {
        final config = await loader.buildAgentConfiguration('tester');

        expect(config, isNotNull);
        expect(config!.name, 'tester');
      });

      test('core agents load successfully', () async {
        final agents = [
          'main',
          'implementer',
          'researcher',
          'tester',
        ];

        for (final agentName in agents) {
          final config = await loader.buildAgentConfiguration(agentName);
          expect(config, isNotNull, reason: 'Agent $agentName failed to load');
          expect(config!.systemPrompt.isNotEmpty, true,
              reason: 'Agent $agentName has empty system prompt');
        }
      });

      test('returns null for non-existent agent', () async {
        final config =
            await loader.buildAgentConfiguration('non-existent-agent');
        expect(config, isNull);
      });

      test('includes are resolved correctly in implementer', () async {
        final config = await loader.buildAgentConfiguration('implementer');

        expect(config, isNotNull);
        // Should include etiquette/messaging content
        expect(config!.systemPrompt, contains('sendMessageToAgent'),
            reason: 'Missing messaging etiquette content');
      });

      test('includes are resolved correctly in main', () async {
        final config = await loader.buildAgentConfiguration('main');

        expect(config, isNotNull);
        // Should include messaging and handoff etiquette
        expect(config!.systemPrompt, contains('ORCHESTRATOR'),
            reason: 'Missing orchestrator guidance');
      });

      test('MCP servers are correctly parsed', () async {
        final config = await loader.buildAgentConfiguration('implementer');

        expect(config, isNotNull);
        expect(config!.mcpServers, isNotNull);
        expect(config.mcpServers, isNotEmpty);
        expect(config.mcpServers, contains(McpServerType.git));
        expect(config.mcpServers, contains(McpServerType.taskManagement));
        expect(config.mcpServers, contains(McpServerType.agent));
      });

      test('MCP servers in main are correct', () async {
        final config = await loader.buildAgentConfiguration('main');

        expect(config, isNotNull);
        expect(config!.mcpServers, isNotNull);
        expect(config.mcpServers, contains(McpServerType.git));
        expect(config.mcpServers, contains(McpServerType.agent));
        expect(config.mcpServers, contains(McpServerType.taskManagement));
      });

      test('tools are correctly parsed from agent definition', () async {
        final config = await loader.buildAgentConfiguration('implementer');

        expect(config, isNotNull);
        expect(config!.allowedTools, isNotNull);
        expect(config.allowedTools, contains('Read'));
        expect(config.allowedTools, contains('Write'));
        expect(config.allowedTools, contains('Edit'));
      });

      test('model is set correctly', () async {
        final config = await loader.buildAgentConfiguration('implementer');

        expect(config, isNotNull);
        expect(config!.model, 'opus');
      });

      test('implementer has acceptEdits permission mode', () async {
        final config = await loader.buildAgentConfiguration('implementer');

        expect(config, isNotNull);
        expect(config!.permissionMode, 'acceptEdits');
      });

      test('system prompt contains complete guidance', () async {
        final config = await loader.buildAgentConfiguration('implementer');

        expect(config, isNotNull);
        final prompt = config!.systemPrompt;

        // Should contain key sections
        expect(prompt, contains('Implementation'),
            reason: 'Missing implementation guidance');
        expect(prompt.length, greaterThan(500),
            reason: 'System prompt seems incomplete (too short)');
      });

      test('tools list is not empty for implementer', () async {
        final config = await loader.buildAgentConfiguration('implementer');

        expect(config, isNotNull);
        expect(config!.allowedTools, isNotEmpty);
        expect(config.allowedTools!.length, greaterThan(2));
      });

      test('researcher has read-only tools', () async {
        final config = await loader.buildAgentConfiguration('researcher');

        expect(config, isNotNull);
        expect(config!.allowedTools, isNotNull);
        expect(config.allowedTools, contains('Read'));
        expect(config.allowedTools, contains('Grep'));
        expect(config.allowedTools, contains('Glob'));
      });
    });

    group('Load all definitions', () {
      test('all agents can be loaded', () async {
        final agents = await loader.loadAgents();
        expect(agents.isNotEmpty, true);
      });

      test('all etiquette protocols can be loaded', () async {
        final etiquette = await loader.loadEtiquette();
        expect(etiquette.isNotEmpty, true);
      });

      test('all teams can be loaded', () async {
        final teams = await loader.loadTeams();
        expect(teams.isNotEmpty, true);
      });
    });

    group('Include resolution', () {
      test('etiquette includes are resolved', () async {
        final agent = await loader.getAgent('implementer');
        expect(agent, isNotNull);
        expect(agent!.include.isNotEmpty, true);
      });

      test('resolved include content appears in prompt', () async {
        final agent = await loader.getAgent('implementer');
        expect(agent, isNotNull);

        final prompt = await loader.buildAgentPrompt(agent!);
        expect(prompt.length, greaterThan(agent.content.length),
            reason: 'Prompt should include additional content from includes');
      });
    });

    group('MCP Server parsing', () {
      test('parses vide-git correctly', () async {
        final agents = await loader.loadAgents();
        final implementer = agents['implementer'];

        expect(implementer, isNotNull);
        expect(implementer!.mcpServers, contains('vide-git'));
      });

      test('parses flutter-runtime correctly for flutter-tester', () async {
        final agents = await loader.loadAgents();
        final tester = agents['flutter-tester'];

        expect(tester, isNotNull);
        expect(tester!.mcpServers, contains('flutter-runtime'));
      });

      test('unknown MCP server names are gracefully skipped', () async {
        // This is just a sanity check that parsing doesn't crash
        final agents = await loader.loadAgents();
        expect(agents.isNotEmpty, true);
      });
    });

    group('Caching behavior', () {
      test('agents are cached after first load', () async {
        final first = await loader.loadAgents();
        final second = await loader.loadAgents();

        expect(identical(first, second), true,
            reason: 'Loader should return cached agents');
      });

      test('clearCache forces reload', () async {
        await loader.loadAgents();
        loader.clearCache();

        // Should load again without error
        final agents = await loader.loadAgents();
        expect(agents.isNotEmpty, true);
      });
    });

    group('Team definitions', () {
      test('vide team exists', () async {
        final team = await loader.getTeam('vide');
        expect(team, isNotNull);
        expect(team!.name, 'vide');
      });

      test('flutter team exists', () async {
        final team = await loader.getTeam('flutter');
        expect(team, isNotNull);
        expect(team!.name, 'flutter');
      });

      test('team has agents defined', () async {
        final team = await loader.getTeam('vide');
        expect(team, isNotNull);
        expect(team!.agents, isNotEmpty);
      });
    });
  });
}
