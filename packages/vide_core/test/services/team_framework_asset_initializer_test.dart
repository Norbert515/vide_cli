import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:vide_core/src/generated/bundled_team_framework.dart';
import 'package:vide_core/src/services/team_framework_asset_initializer.dart';
import 'package:vide_core/vide_core.dart';

void main() {
  group('Bundled Team Framework Assets', () {
    test('bundledTeams contains expected teams', () {
      expect(bundledTeams, isNotEmpty);
      expect(bundledTeams.containsKey('vide'), isTrue);
      expect(bundledTeams.containsKey('enterprise'), isTrue);
      expect(bundledTeams.containsKey('flutter'), isTrue);
      expect(bundledTeams.containsKey('parallel'), isTrue);
    });

    test('bundledAgents contains expected agents', () {
      expect(bundledAgents, isNotEmpty);
      expect(bundledAgents.containsKey('main'), isTrue);
      expect(bundledAgents.containsKey('implementer'), isTrue);
      expect(bundledAgents.containsKey('researcher'), isTrue);
      expect(bundledAgents.containsKey('tester'), isTrue);
    });

    test('bundledEtiquette contains expected files', () {
      expect(bundledEtiquette, isNotEmpty);
      expect(bundledEtiquette.containsKey('messaging'), isTrue);
      expect(bundledEtiquette.containsKey('handoff'), isTrue);
      expect(bundledEtiquette.containsKey('reporting'), isTrue);
      expect(bundledEtiquette.containsKey('escalation'), isTrue);
    });

    test('bundledTeamFramework has all categories', () {
      expect(bundledTeamFramework.containsKey('teams'), isTrue);
      expect(bundledTeamFramework.containsKey('agents'), isTrue);
      expect(bundledTeamFramework.containsKey('etiquette'), isTrue);
    });

    test('bundled team content is valid YAML frontmatter', () {
      for (final entry in bundledTeams.entries) {
        expect(
          entry.value.trim().startsWith('---'),
          isTrue,
          reason: 'Team ${entry.key} should start with YAML frontmatter',
        );
        expect(
          entry.value.contains('name:'),
          isTrue,
          reason: 'Team ${entry.key} should have a name field',
        );
      }
    });

    test('bundled agent content is valid YAML frontmatter', () {
      for (final entry in bundledAgents.entries) {
        expect(
          entry.value.trim().startsWith('---'),
          isTrue,
          reason: 'Agent ${entry.key} should start with YAML frontmatter',
        );
        expect(
          entry.value.contains('name:'),
          isTrue,
          reason: 'Agent ${entry.key} should have a name field',
        );
      }
    });

    test('bundled assets match source assets count', () async {
      // This test verifies the generator captured all files
      final sourceAssetsPath = _getSourceAssetsPath();
      if (sourceAssetsPath == null) {
        // Skip if not running from source
        return;
      }

      for (final category in ['teams', 'agents', 'etiquette']) {
        final sourceDir = Directory(path.join(sourceAssetsPath, category));
        if (!sourceDir.existsSync()) continue;

        final sourceFiles = sourceDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.md'))
            .length;

        final bundledCount = bundledTeamFramework[category]?.length ?? 0;

        expect(
          bundledCount,
          sourceFiles,
          reason:
              '$category: bundled has $bundledCount files, source has $sourceFiles',
        );
      }
    });
  });

  group('TeamFrameworkAssetInitializer', () {
    late Directory tempDir;
    late String testVideHome;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('vide_init_test_');
      testVideHome = tempDir.path;
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('initialize creates defaults directory structure', () async {
      final result = await TeamFrameworkAssetInitializer.initialize(
        videHome: testVideHome,
        forceSync: true,
      );

      expect(result, isTrue);

      final defaultsDir = Directory(path.join(testVideHome, 'defaults'));
      expect(defaultsDir.existsSync(), isTrue);

      final teamsDir = Directory(path.join(defaultsDir.path, 'teams'));
      final agentsDir = Directory(path.join(defaultsDir.path, 'agents'));
      final etiquetteDir = Directory(path.join(defaultsDir.path, 'etiquette'));

      expect(teamsDir.existsSync(), isTrue);
      expect(agentsDir.existsSync(), isTrue);
      expect(etiquetteDir.existsSync(), isTrue);
    });

    test('initialize writes all bundled assets', () async {
      await TeamFrameworkAssetInitializer.initialize(
        videHome: testVideHome,
        forceSync: true,
      );

      final defaultsDir = Directory(path.join(testVideHome, 'defaults'));

      // Check teams
      final teamsDir = Directory(path.join(defaultsDir.path, 'teams'));
      final teamFiles = teamsDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.md'))
          .toList();
      expect(teamFiles.length, bundledTeams.length);

      // Check agents
      final agentsDir = Directory(path.join(defaultsDir.path, 'agents'));
      final agentFiles = agentsDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.md'))
          .toList();
      expect(agentFiles.length, bundledAgents.length);

      // Check etiquette
      final etiquetteDir = Directory(path.join(defaultsDir.path, 'etiquette'));
      final etiquetteFiles = etiquetteDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.md'))
          .toList();
      expect(etiquetteFiles.length, bundledEtiquette.length);
    });

    test('initialize skips if defaults already exist (unless forceSync)',
        () async {
      // First initialize
      await TeamFrameworkAssetInitializer.initialize(
        videHome: testVideHome,
        forceSync: true,
      );

      // Modify a file to detect if it gets overwritten
      final markerFile = File(
        path.join(testVideHome, 'defaults', 'teams', 'vide.md'),
      );
      final originalContent = await markerFile.readAsString();
      await markerFile.writeAsString('MODIFIED');

      // Initialize again without forceSync
      await TeamFrameworkAssetInitializer.initialize(
        videHome: testVideHome,
        forceSync: false,
      );

      // File should still be modified (not overwritten)
      final afterContent = await markerFile.readAsString();
      expect(afterContent, 'MODIFIED');

      // Initialize with forceSync
      await TeamFrameworkAssetInitializer.initialize(
        videHome: testVideHome,
        forceSync: true,
      );

      // File should be restored
      final restoredContent = await markerFile.readAsString();
      expect(restoredContent, originalContent);
    });

    test('written assets are loadable by TeamFrameworkLoader', () async {
      await TeamFrameworkAssetInitializer.initialize(
        videHome: testVideHome,
        forceSync: true,
      );

      final loader = TeamFrameworkLoader(videHome: testVideHome);

      // Load and verify teams
      final teams = await loader.loadTeams();
      expect(teams, isNotEmpty);
      expect(teams.containsKey('vide'), isTrue);

      // Load and verify agents
      final agents = await loader.loadAgents();
      expect(agents, isNotEmpty);
      expect(agents.containsKey('main'), isTrue);
      expect(agents.containsKey('implementer'), isTrue);

      // Verify a complete agent config can be built
      final config = await loader.buildAgentConfiguration('main');
      expect(config, isNotNull);
      expect(config!.systemPrompt, isNotEmpty);
    });
  });

  group('End-to-End: Bundled Assets Flow', () {
    late Directory tempDir;
    late String testVideHome;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('vide_e2e_test_');
      testVideHome = tempDir.path;
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('simulates production binary flow (no filesystem assets)', () async {
      // This simulates what happens in a compiled binary:
      // 1. No packages/vide_core/assets exists
      // 2. Must use bundled assets
      // 3. Write to ~/.vide/defaults/
      // 4. TeamFrameworkLoader reads from there

      // Initialize (will use bundled since filesystem assets won't be found
      // from the temp directory perspective)
      await TeamFrameworkAssetInitializer.initialize(
        videHome: testVideHome,
        forceSync: true,
      );

      // Verify files were written
      final videDir = Directory(path.join(testVideHome, 'defaults', 'agents'));
      final files = videDir.listSync().whereType<File>().toList();
      expect(files, isNotEmpty);

      // Verify content matches bundled
      final mainFile = File(path.join(videDir.path, 'main.md'));
      expect(mainFile.existsSync(), isTrue);

      final content = await mainFile.readAsString();
      expect(content, bundledAgents['main']);
    });

    test('full workflow: init -> load -> build config', () async {
      // Step 1: Initialize assets
      final initResult = await TeamFrameworkAssetInitializer.initialize(
        videHome: testVideHome,
        forceSync: true,
      );
      expect(initResult, isTrue);

      // Step 2: Create loader pointing to test home
      final loader = TeamFrameworkLoader(videHome: testVideHome);

      // Step 3: Find best team for a task
      final team = await loader.findBestTeam('add a button to the settings');
      expect(team, isNotNull);

      // Step 4: Build configuration for main agent
      final mainConfig = await loader.buildAgentConfiguration(team!.mainAgent);
      expect(mainConfig, isNotNull);
      expect(mainConfig!.systemPrompt, isNotEmpty);

      // Step 5: Build config for a worker agent
      if (team.agents.isNotEmpty) {
        final workerConfig =
            await loader.buildAgentConfiguration(team.agents.first);
        expect(workerConfig, isNotNull);
      }
    });

    test('verifies all teams reference existing agents', () async {
      await TeamFrameworkAssetInitializer.initialize(
        videHome: testVideHome,
        forceSync: true,
      );

      final loader = TeamFrameworkLoader(videHome: testVideHome);
      final teams = await loader.loadTeams();
      final agents = await loader.loadAgents();

      final missingAgents = <String>[];

      for (final team in teams.values) {
        // Check main agent
        if (!agents.containsKey(team.mainAgent)) {
          missingAgents.add('${team.name}:mainAgent:${team.mainAgent}');
        }

        // Check all referenced agents
        for (final agentName in team.agents) {
          if (!agents.containsKey(agentName)) {
            missingAgents.add('${team.name}:agent:$agentName');
          }
        }
      }

      expect(
        missingAgents,
        isEmpty,
        reason: 'Missing agents: ${missingAgents.join(", ")}',
      );
    });
  });
}

/// Get path to source assets, or null if not available.
String? _getSourceAssetsPath() {
  var current = Directory.current.path;

  // Try from repo root
  if (Directory(path.join(current, 'packages/vide_core/assets')).existsSync()) {
    return path.join(current, 'packages/vide_core/assets/team_framework');
  }

  // Try from vide_core package
  if (Directory(path.join(current, 'assets/team_framework')).existsSync()) {
    return path.join(current, 'assets/team_framework');
  }

  return null;
}
