import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';

void main() {
  group('TeamFrameworkLoader - Integration Tests', () {
    late TeamFrameworkLoader loader;

    setUp(() {
      loader = TeamFrameworkLoader();
    });

    group('buildAgentConfiguration', () {
      test('vide-implementer agent loads successfully', () async {
        final config = await loader.buildAgentConfiguration('vide-implementer');

        expect(config, isNotNull);
        expect(config!.name, 'vide-implementer');
        expect(config.description, isNotEmpty);
        expect(config.systemPrompt, isNotEmpty);
      });

      test('vide-main-orchestrator agent loads successfully', () async {
        final config = await loader.buildAgentConfiguration('vide-main-orchestrator');

        expect(config, isNotNull);
        expect(config!.name, 'vide-main-orchestrator');
        expect(config.description, isNotEmpty);
        expect(config.systemPrompt, isNotEmpty);
      });

      test('vide-context-researcher agent loads successfully', () async {
        final config = await loader.buildAgentConfiguration('vide-context-researcher');

        expect(config, isNotNull);
        expect(config!.name, 'vide-context-researcher');
      });

      test('vide-flutter-tester agent loads successfully', () async {
        final config = await loader.buildAgentConfiguration('vide-flutter-tester');

        expect(config, isNotNull);
        expect(config!.name, 'vide-flutter-tester');
      });

      test('vide-planner agent loads successfully', () async {
        final config = await loader.buildAgentConfiguration('vide-planner');

        expect(config, isNotNull);
        expect(config!.name, 'vide-planner');
      });

      test('all vide-* agents load successfully', () async {
        final agents = [
          'vide-main-orchestrator',
          'vide-implementer',
          'vide-context-researcher',
          'vide-flutter-tester',
          'vide-planner',
        ];

        for (final agentName in agents) {
          final config = await loader.buildAgentConfiguration(agentName);
          expect(config, isNotNull, reason: 'Agent $agentName failed to load');
          expect(config!.systemPrompt.isNotEmpty, true,
              reason: 'Agent $agentName has empty system prompt');
        }
      });

      test('returns null for non-existent agent', () async {
        final config = await loader.buildAgentConfiguration('non-existent-agent');
        expect(config, isNull);
      });

      test('includes are resolved correctly in implementer', () async {
        final config = await loader.buildAgentConfiguration('vide-implementer');

        expect(config, isNotNull);
        // Should include etiquette/messaging content
        expect(config!.systemPrompt, contains('sendMessageToAgent'),
            reason: 'Missing messaging etiquette content');
        expect(config.systemPrompt, contains('Implementation'),
            reason: 'Missing implementation-specific content');
      });

      test('includes are resolved correctly in orchestrator', () async {
        final config = await loader.buildAgentConfiguration('vide-main-orchestrator');

        expect(config, isNotNull);
        // Should include messaging and handoff etiquette
        expect(config!.systemPrompt, contains('Async Agent Communication'),
            reason: 'Missing async communication guidance');
        expect(config.systemPrompt, contains('ASSESS'),
            reason: 'Missing assessment guidance');
      });

      test('MCP servers are correctly parsed', () async {
        final config = await loader.buildAgentConfiguration('vide-implementer');

        expect(config, isNotNull);
        expect(config!.mcpServers, isNotNull);
        expect(config.mcpServers, isNotEmpty);
        expect(config.mcpServers, contains(McpServerType.git));
        expect(config.mcpServers, contains(McpServerType.taskManagement));
        expect(config.mcpServers, contains(McpServerType.flutterRuntime));
        expect(config.mcpServers, contains(McpServerType.agent));
      });

      test('MCP servers in orchestrator are correct', () async {
        final config = await loader.buildAgentConfiguration('vide-main-orchestrator');

        expect(config, isNotNull);
        expect(config!.mcpServers, isNotNull);
        expect(config.mcpServers, contains(McpServerType.git));
        expect(config.mcpServers, contains(McpServerType.agent));
        expect(config.mcpServers, contains(McpServerType.taskManagement));
      });

      test('tools are correctly parsed from agent definition', () async {
        final config = await loader.buildAgentConfiguration('vide-implementer');

        expect(config, isNotNull);
        expect(config!.allowedTools, isNotNull);
        expect(config.allowedTools, contains('Read'));
        expect(config.allowedTools, contains('Write'));
        expect(config.allowedTools, contains('Edit'));
      });

      test('model is set correctly', () async {
        final config = await loader.buildAgentConfiguration('vide-implementer');

        expect(config, isNotNull);
        expect(config!.model, 'sonnet');
      });

      test('planner has correct permission mode', () async {
        final config = await loader.buildAgentConfiguration('vide-planner');

        expect(config, isNotNull);
        expect(config!.permissionMode, 'plan');
      });

      test('implementer has acceptEdits permission mode', () async {
        final config = await loader.buildAgentConfiguration('vide-implementer');

        expect(config, isNotNull);
        expect(config!.permissionMode, 'acceptEdits');
      });

      test('system prompt contains complete guidance', () async {
        final config = await loader.buildAgentConfiguration('vide-implementer');

        expect(config, isNotNull);
        final prompt = config!.systemPrompt;

        // Should contain key sections
        expect(prompt, contains('Async Communication'),
            reason: 'Missing async communication model');
        expect(prompt, contains('Verification'),
            reason: 'Missing verification guidance');
        expect(prompt.length, greaterThan(500),
            reason: 'System prompt seems incomplete (too short)');
      });

      test('tools list is not empty for implementer', () async {
        final config = await loader.buildAgentConfiguration('vide-implementer');

        expect(config, isNotNull);
        expect(config!.allowedTools, isNotEmpty);
        expect(config.allowedTools!.length, greaterThan(2));
      });

      test('context researcher has read-only tools', () async {
        final config = await loader.buildAgentConfiguration('vide-context-researcher');

        expect(config, isNotNull);
        expect(config!.allowedTools, isNotNull);
        expect(config.allowedTools, contains('Read'));
        expect(config.allowedTools, contains('Grep'));
        expect(config.allowedTools, contains('Glob'));
        expect(config.allowedTools, contains('WebSearch'));
        expect(config.allowedTools, contains('WebFetch'));
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
        final agent = await loader.getAgent('vide-implementer');
        expect(agent, isNotNull);
        expect(agent!.include.isNotEmpty, true);
      });

      test('resolved include content appears in prompt', () async {
        final agent = await loader.getAgent('vide-implementer');
        expect(agent, isNotNull);

        final prompt = await loader.buildAgentPrompt(agent!);
        expect(prompt.length, greaterThan(agent.content.length),
            reason: 'Prompt should include additional content from includes');
      });
    });

    group('MCP Server parsing', () {
      test('parses vide-git correctly', () async {
        final agents = await loader.loadAgents();
        final implementer = agents['vide-implementer'];

        expect(implementer, isNotNull);
        expect(implementer!.mcpServers, contains('vide-git'));
      });

      test('parses flutter-runtime correctly', () async {
        final agents = await loader.loadAgents();
        final tester = agents['vide-flutter-tester'];

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
  });
}
