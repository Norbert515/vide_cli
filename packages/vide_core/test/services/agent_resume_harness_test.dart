import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';
import 'package:vide_core/src/claude/agent_config_resolver.dart';

/// Create a test directory structure that mimics ~/.vide/defaults/
/// with the bundled team framework assets.
Future<String> _createTestVideHome() async {
  final sourceAssets = _getSourceAssetsPath();
  final tempDir = await Directory.systemTemp.createTemp('vide_harness_test_');
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

void main() {
  group('AgentMetadata.harness serialization', () {
    final testDate = DateTime(2024, 6, 15, 12, 0, 0);

    test('round-trips harness through JSON', () {
      final original = AgentMetadata(
        id: 'agent-codex',
        name: 'Codex Implementer',
        type: 'implementer',
        createdAt: testDate,
        harness: 'codex-cli',
      );

      final json = original.toJson();
      final restored = AgentMetadata.fromJson(json);

      expect(restored.harness, 'codex-cli');
      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.type, original.type);
    });

    test('round-trips null harness through JSON', () {
      final original = AgentMetadata(
        id: 'agent-default',
        name: 'Default Agent',
        type: 'main',
        createdAt: testDate,
      );

      final json = original.toJson();
      final restored = AgentMetadata.fromJson(json);

      expect(restored.harness, isNull);
    });

    test('preserves harness through copyWith', () {
      final original = AgentMetadata(
        id: 'agent-1',
        name: 'Agent',
        type: 'implementer',
        createdAt: testDate,
        harness: 'codex-cli',
      );

      final copied = original.copyWith(name: 'Renamed Agent');

      expect(copied.harness, 'codex-cli');
      expect(copied.name, 'Renamed Agent');
    });

    test('copyWith can change harness', () {
      final original = AgentMetadata(
        id: 'agent-1',
        name: 'Agent',
        type: 'implementer',
        createdAt: testDate,
        harness: 'claude-code',
      );

      final copied = original.copyWith(harness: 'codex-cli');

      expect(copied.harness, 'codex-cli');
    });
  });

  group('AgentConfigResolver harness passthrough', () {
    late TeamFrameworkLoader loader;
    late AgentConfigResolver resolver;
    late String testVideHome;

    setUpAll(() async {
      testVideHome = await _createTestVideHome();
    });

    tearDownAll(() async {
      await Directory(testVideHome).delete(recursive: true);
    });

    setUp(() {
      loader = TeamFrameworkLoader(videHome: testVideHome);
      resolver = AgentConfigResolver(loader);
    });

    test('getConfigurationForType passes harnessOverride through', () async {
      final config = await resolver.getConfigurationForType(
        'implementer',
        teamName: 'extreme',
        harnessOverride: 'codex-cli',
      );

      expect(config.harness, 'codex-cli');
    });

    test(
      'getConfigurationForType uses default harness when no override',
      () async {
        final config = await resolver.getConfigurationForType(
          'implementer',
          teamName: 'extreme',
        );

        // implementer personality defaults to claude-code
        expect(config.harness, 'claude-code');
      },
    );

    test('harnessOverride takes precedence over personality default', () async {
      // The main agent defaults to 'claude-code', override with 'codex-cli'
      final config = await resolver.getConfigurationForType(
        'main',
        teamName: 'extreme',
        harnessOverride: 'codex-cli',
      );

      expect(config.harness, 'codex-cli');
    });

    test('config has correct name regardless of harness', () async {
      final config = await resolver.getConfigurationForType(
        'implementer',
        teamName: 'extreme',
        harnessOverride: 'codex-cli',
      );

      expect(config.name, 'implementer');
      expect(config.systemPrompt, isNotEmpty);
    });
  });
}
