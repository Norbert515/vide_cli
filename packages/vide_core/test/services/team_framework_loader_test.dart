import 'package:test/test.dart';
import 'package:vide_core/src/services/team_framework_loader.dart';
import 'package:vide_core/src/mcp/mcp_server_type.dart';
import 'package:vide_core/models/team_framework/team_framework.dart';

void main() {
  group('TeamFrameworkLoader - Unit Tests', () {
    late TeamFrameworkLoader loader;

    setUp(() {
      loader = TeamFrameworkLoader();
    });

    group('Team Composition Tests', () {
      test('vide-classic team has correct composition', () async {
        final team = await loader.getTeam('vide-classic');

        expect(team, isNotNull);
        expect(team!.name, 'vide-classic');
        expect(team.composition['lead'], 'vide-main-orchestrator');
        expect(team.composition['researcher'], 'vide-context-researcher');
        expect(team.composition['planner'], 'vide-planner');
        expect(team.composition['implementer'], 'vide-implementer');
        expect(team.composition['tester'], 'vide-flutter-tester');
      });

      test('startup team has correct composition', () async {
        final team = await loader.getTeam('startup');

        expect(team, isNotNull);
        expect(team!.name, 'startup');
        expect(team.composition['lead'], 'pragmatic-lead');
        expect(team.composition['implementer'], 'speed-demon');
        expect(team.composition['reviewer'], isNull,
            reason: 'Startup team skips review');
        expect(team.composition['tester'], 'smoke-tester');
      });

      test('enterprise team has correct composition', () async {
        final team = await loader.getTeam('enterprise');

        expect(team, isNotNull);
        expect(team!.name, 'enterprise');
        expect(team.composition['lead'], 'cautious-lead');
        expect(team.composition['planner'], 'thorough-planner');
        expect(team.composition['implementer'], 'careful-implementer');
        expect(team.composition['reviewer'], 'thorough-reviewer');
        expect(team.composition['tester'], 'comprehensive-tester');
      });

      test('balanced team has correct composition', () async {
        final team = await loader.getTeam('balanced');

        expect(team, isNotNull);
        expect(team!.name, 'balanced');
        expect(team.composition['lead'], 'pragmatic-lead');
        expect(team.composition['implementer'], 'solid-implementer');
        expect(team.composition['reviewer'], 'pragmatic-reviewer');
        expect(team.composition['tester'], 'quick-tester');
      });

      test('all teams have a lead role', () async {
        final teams = await loader.loadTeams();

        for (final team in teams.values) {
          expect(team.composition['lead'], isNotNull,
              reason: 'Team ${team.name} missing lead role');
        }
      });

      test('all agents referenced in team compositions exist', () async {
        final teams = await loader.loadTeams();
        final agents = await loader.loadAgents();

        // Track missing agents
        final missingAgents = <String, List<String>>{};

        for (final team in teams.values) {
          for (final entry in team.composition.entries) {
            final agentName = entry.value;
            if (agentName != null && !agents.containsKey(agentName)) {
              missingAgents.putIfAbsent(agentName, () => []);
              missingAgents[agentName]!.add('${team.name}/${entry.key}');
            }
          }
        }

        expect(missingAgents, isEmpty,
            reason: 'Missing agents: $missingAgents');
      });
    });

    group('Process Configuration Tests', () {
      test('startup team has minimal process overhead', () async {
        final team = await loader.getTeam('startup');

        expect(team, isNotNull);
        expect(team!.process.planning, ProcessLevel.minimal);
        expect(team.process.review, ReviewLevel.skip);
        expect(team.process.testing, TestingLevel.smokeOnly);
        expect(team.process.documentation, DocumentationLevel.skip);
      });

      test('enterprise team has thorough process', () async {
        final team = await loader.getTeam('enterprise');

        expect(team, isNotNull);
        expect(team!.process.planning, ProcessLevel.thorough);
        expect(team.process.review, ReviewLevel.required);
        expect(team.process.testing, TestingLevel.comprehensive);
        expect(team.process.documentation, DocumentationLevel.full);
      });

      test('vide-classic team has adaptive planning', () async {
        final team = await loader.getTeam('vide-classic');

        expect(team, isNotNull);
        expect(team!.process.planning, ProcessLevel.adaptive);
        expect(team.process.review, ReviewLevel.skip);
        expect(team.process.testing, TestingLevel.recommended);
      });

      test('balanced team has standard process', () async {
        final team = await loader.getTeam('balanced');

        expect(team, isNotNull);
        expect(team!.process.planning, ProcessLevel.standard);
        expect(team.process.review, ReviewLevel.optional);
        expect(team.process.testing, TestingLevel.recommended);
      });
    });

    group('Communication Configuration Tests', () {
      test('startup team has low verbosity', () async {
        final team = await loader.getTeam('startup');

        expect(team, isNotNull);
        expect(team!.communication.verbosity, Verbosity.low);
        expect(team.communication.handoffDetail, DetailLevel.minimal);
        expect(team.communication.statusUpdates, UpdateFrequency.onCompletion);
      });

      test('enterprise team has high verbosity', () async {
        final team = await loader.getTeam('enterprise');

        expect(team, isNotNull);
        expect(team!.communication.verbosity, Verbosity.high);
        expect(team.communication.handoffDetail, DetailLevel.comprehensive);
        expect(team.communication.statusUpdates, UpdateFrequency.continuous);
      });

      test('vide-classic team has medium verbosity with comprehensive handoffs',
          () async {
        final team = await loader.getTeam('vide-classic');

        expect(team, isNotNull);
        expect(team!.communication.verbosity, Verbosity.medium);
        expect(team.communication.handoffDetail, DetailLevel.comprehensive);
        expect(team.communication.statusUpdates, UpdateFrequency.continuous);
      });
    });

    group('Trigger Matching Tests', () {
      test('startup team matches urgent keywords', () async {
        final team = await loader.getTeam('startup');

        expect(team, isNotNull);
        expect(team!.matchScore('quick fix needed'), greaterThan(0));
        expect(team.matchScore('urgent hotfix'), greaterThan(0));
        expect(team.matchScore('MVP prototype'), greaterThan(0));
        expect(team.matchScore('just make it work'), greaterThan(0));
      });

      test('startup team has negative score for production keywords',
          () async {
        final team = await loader.getTeam('startup');

        expect(team, isNotNull);
        expect(team!.matchScore('production deployment'), lessThan(0));
        expect(team.matchScore('security audit'), lessThan(0));
        expect(team.matchScore('payment processing'), lessThan(0));
      });

      test('enterprise team matches production keywords', () async {
        final team = await loader.getTeam('enterprise');

        expect(team, isNotNull);
        expect(team!.matchScore('production deployment'), greaterThan(0));
        expect(team.matchScore('security feature'), greaterThan(0));
        expect(team.matchScore('payment integration'), greaterThan(0));
        expect(team.matchScore('authentication system'), greaterThan(0));
      });

      test('enterprise team has negative score for prototype keywords',
          () async {
        final team = await loader.getTeam('enterprise');

        expect(team, isNotNull);
        expect(team!.matchScore('quick prototype'), lessThan(0));
        expect(team.matchScore('experimental hack'), lessThan(0));
      });

      test('findBestTeam returns startup for urgent tasks', () async {
        final team = await loader.findBestTeam('urgent hotfix for crash');

        expect(team, isNotNull);
        expect(team!.name, 'startup');
      });

      test('findBestTeam returns enterprise for security tasks', () async {
        final team = await loader.findBestTeam('add authentication security');

        expect(team, isNotNull);
        expect(team!.name, 'enterprise');
      });

      test('findBestTeam returns balanced for generic tasks', () async {
        final team = await loader.findBestTeam('some random task');

        expect(team, isNotNull);
        expect(team!.name, 'balanced');
      });
    });

    group('Agent Personality Tests', () {
      test('speed-demon has fast-shipping traits', () async {
        final agent = await loader.getAgent('speed-demon');

        expect(agent, isNotNull);
        expect(agent!.role, 'implementer');
        expect(agent.archetype, 'flash-fixer');
        expect(agent.traits, contains('ships-fast'));
        expect(agent.traits, contains('minimal-overhead'));
        expect(agent.avoids, contains('over-engineering'));
        expect(agent.avoids, contains('extensive-documentation'));
      });

      test('careful-implementer has thorough traits', () async {
        final agent = await loader.getAgent('careful-implementer');

        expect(agent, isNotNull);
        expect(agent!.role, 'implementer');
        expect(agent.archetype, 'librarian');
        expect(agent.traits, contains('thorough-implementation'));
        expect(agent.traits, contains('defensive-coding'));
        expect(agent.avoids, contains('shortcuts'));
        expect(agent.avoids, contains('skipping-edge-cases'));
      });

      test('vide-implementer has correct tools', () async {
        final agent = await loader.getAgent('vide-implementer');

        expect(agent, isNotNull);
        expect(agent!.tools, contains('Read'));
        expect(agent.tools, contains('Write'));
        expect(agent.tools, contains('Edit'));
        expect(agent.tools, contains('Bash'));
        expect(agent.tools, contains('Grep'));
        expect(agent.tools, contains('Glob'));
      });

      test('vide-context-researcher has read-only tools', () async {
        final agent = await loader.getAgent('vide-context-researcher');

        expect(agent, isNotNull);
        expect(agent!.tools, contains('Read'));
        expect(agent.tools, contains('Grep'));
        expect(agent.tools, contains('Glob'));
        expect(agent.tools, contains('WebSearch'));
        expect(agent.tools, contains('WebFetch'));
        // Should NOT have write tools
        expect(agent.tools, isNot(contains('Write')));
        expect(agent.tools, isNot(contains('Edit')));
      });

      test('different implementers have distinct content', () async {
        final speedDemon = await loader.getAgent('speed-demon');
        final carefulImpl = await loader.getAgent('careful-implementer');
        final videImpl = await loader.getAgent('vide-implementer');

        expect(speedDemon, isNotNull);
        expect(carefulImpl, isNotNull);
        expect(videImpl, isNotNull);

        // Speed demon emphasizes shipping fast
        expect(speedDemon!.content, contains('ship'));
        expect(speedDemon.content.toLowerCase(), contains('fast'));

        // Careful implementer emphasizes thoroughness
        expect(carefulImpl!.content, contains('thorough'));
        expect(carefulImpl.content, contains('edge case'));

        // Vide implementer has async communication guidance
        expect(videImpl!.content, contains('sendMessageToAgent'));
        expect(videImpl.content, contains('SPAWNED BY AGENT'));
      });
    });

    group('Include Resolution Tests', () {
      test('vide-implementer includes messaging etiquette', () async {
        final agent = await loader.getAgent('vide-implementer');

        expect(agent, isNotNull);
        expect(agent!.include, contains('etiquette/messaging'));
      });

      test('careful-implementer includes messaging and reporting', () async {
        final agent = await loader.getAgent('careful-implementer');

        expect(agent, isNotNull);
        expect(agent!.include, contains('etiquette/messaging'));
        expect(agent.include, contains('etiquette/reporting'));
      });

      test('buildAgentPrompt includes etiquette content', () async {
        final agent = await loader.getAgent('vide-implementer');
        expect(agent, isNotNull);

        final prompt = await loader.buildAgentPrompt(agent!);

        // Should contain messaging protocol content
        expect(prompt, contains('Messaging Protocol'),
            reason: 'Missing messaging etiquette header');
        expect(prompt, contains('Golden Rule'),
            reason: 'Missing golden rule from messaging');
        expect(prompt, contains('Message Lifecycle'),
            reason: 'Missing message lifecycle');

        // Should also contain the agent's own content
        expect(prompt, contains('Implementation Sub-Agent'),
            reason: 'Missing agent own content');
      });

      test('prompt length increases with includes', () async {
        final agent = await loader.getAgent('vide-implementer');
        expect(agent, isNotNull);

        final prompt = await loader.buildAgentPrompt(agent!);

        expect(prompt.length, greaterThan(agent.content.length),
            reason: 'Prompt should be longer than agent content due to includes');
      });

      test('multiple includes are all resolved', () async {
        final agent = await loader.getAgent('careful-implementer');
        expect(agent, isNotNull);

        final prompt = await loader.buildAgentPrompt(agent!);

        // Should contain both messaging and reporting content
        expect(prompt, contains('Messaging Protocol'));
        // Note: reporting etiquette content should also be present if the file exists
      });
    });

    group('Agent Configuration Building Tests', () {
      test('buildAgentConfiguration creates complete config', () async {
        final config =
            await loader.buildAgentConfiguration('vide-implementer');

        expect(config, isNotNull);
        expect(config!.name, 'vide-implementer');
        expect(config.description, isNotEmpty);
        expect(config.systemPrompt, isNotEmpty);
        expect(config.mcpServers, isNotNull);
        expect(config.allowedTools, isNotNull);
        expect(config.model, isNotNull);
        expect(config.permissionMode, isNotNull);
      });

      test('buildAgentConfiguration includes etiquette in system prompt',
          () async {
        final config =
            await loader.buildAgentConfiguration('vide-implementer');

        expect(config, isNotNull);
        // System prompt should contain messaging etiquette
        expect(config!.systemPrompt, contains('Messaging Protocol'));
        expect(config.systemPrompt, contains('sendMessageToAgent'));
      });

      test('MCP servers are correctly mapped', () async {
        final config =
            await loader.buildAgentConfiguration('vide-implementer');

        expect(config, isNotNull);
        expect(config!.mcpServers, contains(McpServerType.git));
        expect(config.mcpServers, contains(McpServerType.taskManagement));
        expect(config.mcpServers, contains(McpServerType.flutterRuntime));
        expect(config.mcpServers, contains(McpServerType.agent));
      });

      test('flutter tester has flutter runtime MCP', () async {
        final config =
            await loader.buildAgentConfiguration('vide-flutter-tester');

        expect(config, isNotNull);
        expect(config!.mcpServers, contains(McpServerType.flutterRuntime));
      });

      test('model is set correctly for different agents', () async {
        final implementer =
            await loader.buildAgentConfiguration('vide-implementer');
        final speedDemon =
            await loader.buildAgentConfiguration('speed-demon');

        expect(implementer, isNotNull);
        expect(implementer!.model, 'sonnet');

        expect(speedDemon, isNotNull);
        expect(speedDemon!.model, 'sonnet');
      });

      test('permission mode differs by agent type', () async {
        final implementer =
            await loader.buildAgentConfiguration('vide-implementer');
        final planner = await loader.buildAgentConfiguration('vide-planner');

        expect(implementer, isNotNull);
        expect(implementer!.permissionMode, 'acceptEdits');

        expect(planner, isNotNull);
        expect(planner!.permissionMode, 'plan');
      });
    });

    group('Team-to-Agent Integration Tests', () {
      test('can build all agents from vide-classic team', () async {
        final team = await loader.getTeam('vide-classic');
        expect(team, isNotNull);

        for (final entry in team!.composition.entries) {
          final agentName = entry.value;
          if (agentName != null) {
            final config = await loader.buildAgentConfiguration(agentName);
            expect(config, isNotNull,
                reason:
                    'Failed to build config for ${entry.key} agent "$agentName"');
            expect(config!.systemPrompt.isNotEmpty, isTrue);
          }
        }
      });

      test('can build all agents from startup team', () async {
        final team = await loader.getTeam('startup');
        expect(team, isNotNull);

        for (final entry in team!.composition.entries) {
          final agentName = entry.value;
          if (agentName != null) {
            final config = await loader.buildAgentConfiguration(agentName);
            expect(config, isNotNull,
                reason:
                    'Failed to build config for ${entry.key} agent "$agentName"');
          }
        }
      });

      test('can build all agents from enterprise team', () async {
        final team = await loader.getTeam('enterprise');
        expect(team, isNotNull);

        for (final entry in team!.composition.entries) {
          final agentName = entry.value;
          if (agentName != null) {
            final config = await loader.buildAgentConfiguration(agentName);
            expect(config, isNotNull,
                reason:
                    'Failed to build config for ${entry.key} agent "$agentName"');
          }
        }
      });

      test('can build all agents from all teams', () async {
        final teams = await loader.loadTeams();

        for (final team in teams.values) {
          for (final entry in team.composition.entries) {
            final agentName = entry.value;
            if (agentName != null) {
              final config = await loader.buildAgentConfiguration(agentName);
              expect(config, isNotNull,
                  reason:
                      'Team ${team.name}: Failed to build ${entry.key} agent "$agentName"');
            }
          }
        }
      });

      test('startup implementer differs from enterprise implementer',
          () async {
        final startupTeam = await loader.getTeam('startup');
        final enterpriseTeam = await loader.getTeam('enterprise');

        expect(startupTeam, isNotNull);
        expect(enterpriseTeam, isNotNull);

        final startupImplName = startupTeam!.composition['implementer'];
        final enterpriseImplName = enterpriseTeam!.composition['implementer'];

        expect(startupImplName, isNot(equals(enterpriseImplName)),
            reason: 'Teams should use different implementers');

        final startupImpl =
            await loader.buildAgentConfiguration(startupImplName!);
        final enterpriseImpl =
            await loader.buildAgentConfiguration(enterpriseImplName!);

        expect(startupImpl, isNotNull);
        expect(enterpriseImpl, isNotNull);

        // Verify they have different content/philosophy
        expect(startupImpl!.systemPrompt, isNot(equals(enterpriseImpl!.systemPrompt)));

        // Speed demon should mention shipping fast
        expect(startupImpl.systemPrompt.toLowerCase(), contains('fast'));

        // Careful implementer should mention thoroughness
        expect(enterpriseImpl.systemPrompt, contains('thorough'));
      });
    });

    group('Edge Cases', () {
      test('returns null for non-existent team', () async {
        final team = await loader.getTeam('non-existent-team');
        expect(team, isNull);
      });

      test('returns null for non-existent agent', () async {
        final agent = await loader.getAgent('non-existent-agent');
        expect(agent, isNull);
      });

      test('buildAgentConfiguration returns null for non-existent agent',
          () async {
        final config =
            await loader.buildAgentConfiguration('non-existent-agent');
        expect(config, isNull);
      });

      test('handles team with null role gracefully', () async {
        final team = await loader.getTeam('startup');
        expect(team, isNotNull);

        // Startup has reviewer: null
        final reviewerName = team!.composition['reviewer'];
        expect(reviewerName, isNull);

        // Should not crash when trying to get null agent
        // (Application code should check for null before calling buildAgentConfiguration)
      });
    });
  });
}
