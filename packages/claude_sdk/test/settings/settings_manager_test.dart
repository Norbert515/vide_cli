import 'dart:convert';
import 'dart:io';

import 'package:claude_sdk/src/settings/settings_manager.dart';
import 'package:claude_sdk/src/settings/claude_settings.dart';
import 'package:claude_sdk/src/settings/permissions_config.dart';
import 'package:claude_sdk/src/settings/mcp_config.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late String projectRoot;
  late String userHome;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('settings_test_');
    projectRoot = '${tempDir.path}/project';
    userHome = '${tempDir.path}/home';

    // Create directory structure
    await Directory('$projectRoot/.claude').create(recursive: true);
    await Directory('$userHome/.claude').create(recursive: true);
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  group('ClaudeSettingsManager', () {
    group('readSettings', () {
      test('returns empty settings when file does not exist', () async {
        final manager = ClaudeSettingsManager(
          projectRoot: projectRoot,
          userHome: userHome,
        );

        final settings = await manager.readSettings(SettingsScope.local);

        expect(settings.permissions, isNull);
        expect(settings.enabledMcpjsonServers, isNull);
      });

      test('reads settings from local scope', () async {
        final settingsFile = File('$projectRoot/.claude/settings.local.json');
        await settingsFile.writeAsString(
          jsonEncode({
            'enabledMcpjsonServers': ['server1', 'server2'],
            'permissions': {
              'allow': ['Bash(npm:*)'],
            },
          }),
        );

        final manager = ClaudeSettingsManager(
          projectRoot: projectRoot,
          userHome: userHome,
        );

        final settings = await manager.readSettings(SettingsScope.local);

        expect(settings.enabledMcpjsonServers, ['server1', 'server2']);
        expect(settings.permissions?.allow, ['Bash(npm:*)']);
      });

      test('reads settings from project scope', () async {
        final settingsFile = File('$projectRoot/.claude/settings.json');
        await settingsFile.writeAsString(
          jsonEncode({'model': 'claude-sonnet-4'}),
        );

        final manager = ClaudeSettingsManager(
          projectRoot: projectRoot,
          userHome: userHome,
        );

        final settings = await manager.readSettings(SettingsScope.project);

        expect(settings.model, 'claude-sonnet-4');
      });

      test('reads settings from user scope', () async {
        final settingsFile = File('$userHome/.claude/settings.json');
        await settingsFile.writeAsString(jsonEncode({'language': 'en'}));

        final manager = ClaudeSettingsManager(
          projectRoot: projectRoot,
          userHome: userHome,
        );

        final settings = await manager.readSettings(SettingsScope.user);

        expect(settings.language, 'en');
      });
    });

    group('readMergedSettings', () {
      test('merges settings from all scopes', () async {
        // User settings (lowest priority)
        await File(
          '$userHome/.claude/settings.json',
        ).writeAsString(jsonEncode({'language': 'en', 'model': 'user-model'}));

        // Project settings
        await File(
          '$projectRoot/.claude/settings.json',
        ).writeAsString(jsonEncode({'model': 'project-model'}));

        // Local settings (highest priority)
        await File('$projectRoot/.claude/settings.local.json').writeAsString(
          jsonEncode({
            'enabledMcpjsonServers': ['test-server'],
          }),
        );

        final manager = ClaudeSettingsManager(
          projectRoot: projectRoot,
          userHome: userHome,
        );

        final settings = await manager.readMergedSettings();

        // User setting not overridden
        expect(settings.language, 'en');
        // Project overrides user
        expect(settings.model, 'project-model');
        // Local setting
        expect(settings.enabledMcpjsonServers, ['test-server']);
      });

      test('local settings override project settings', () async {
        await File(
          '$projectRoot/.claude/settings.json',
        ).writeAsString(jsonEncode({'model': 'project-model'}));

        await File(
          '$projectRoot/.claude/settings.local.json',
        ).writeAsString(jsonEncode({'model': 'local-model'}));

        final manager = ClaudeSettingsManager(
          projectRoot: projectRoot,
          userHome: userHome,
        );

        final settings = await manager.readMergedSettings();

        expect(settings.model, 'local-model');
      });
    });

    group('writeSettings', () {
      test('writes settings to local scope', () async {
        final manager = ClaudeSettingsManager(
          projectRoot: projectRoot,
          userHome: userHome,
        );

        await manager.writeSettings(
          const ClaudeSettings(enabledMcpjsonServers: ['my-server']),
          SettingsScope.local,
        );

        final file = File('$projectRoot/.claude/settings.local.json');
        expect(await file.exists(), isTrue);

        final content = jsonDecode(await file.readAsString());
        expect(content['enabledMcpjsonServers'], ['my-server']);
      });

      test('creates parent directory if needed', () async {
        final newProjectRoot = '${tempDir.path}/new-project';
        final manager = ClaudeSettingsManager(
          projectRoot: newProjectRoot,
          userHome: userHome,
        );

        await manager.writeSettings(
          const ClaudeSettings(model: 'test'),
          SettingsScope.local,
        );

        final file = File('$newProjectRoot/.claude/settings.local.json');
        expect(await file.exists(), isTrue);
      });
    });

    group('updateSettings', () {
      test('updates existing settings', () async {
        await File('$projectRoot/.claude/settings.local.json').writeAsString(
          jsonEncode({
            'enabledMcpjsonServers': ['server1'],
            'model': 'original-model',
          }),
        );

        final manager = ClaudeSettingsManager(
          projectRoot: projectRoot,
          userHome: userHome,
        );

        await manager.updateSettings(SettingsScope.local, (current) {
          return current.copyWith(model: 'updated-model');
        });

        final settings = await manager.readSettings(SettingsScope.local);
        expect(settings.model, 'updated-model');
        expect(settings.enabledMcpjsonServers, ['server1']); // Preserved
      });
    });

    group('MCP server management', () {
      test('isMcpServerEnabled returns true for enabled server', () async {
        await File('$projectRoot/.claude/settings.local.json').writeAsString(
          jsonEncode({
            'enabledMcpjsonServers': ['my-server'],
          }),
        );

        final manager = ClaudeSettingsManager(
          projectRoot: projectRoot,
          userHome: userHome,
        );

        expect(manager.isMcpServerEnabled('my-server'), isTrue);
        expect(manager.isMcpServerEnabled('other-server'), isFalse);
      });

      test(
        'isMcpServerEnabled returns true when enableAllProjectMcpServers is true',
        () async {
          await File(
            '$projectRoot/.claude/settings.local.json',
          ).writeAsString(jsonEncode({'enableAllProjectMcpServers': true}));

          final manager = ClaudeSettingsManager(
            projectRoot: projectRoot,
            userHome: userHome,
          );

          expect(manager.isMcpServerEnabled('any-server'), isTrue);
        },
      );

      test('isMcpServerEnabled returns false for disabled server', () async {
        await File('$projectRoot/.claude/settings.local.json').writeAsString(
          jsonEncode({
            'enableAllProjectMcpServers': true,
            'disabledMcpjsonServers': ['blocked-server'],
          }),
        );

        final manager = ClaudeSettingsManager(
          projectRoot: projectRoot,
          userHome: userHome,
        );

        expect(manager.isMcpServerEnabled('blocked-server'), isFalse);
        expect(manager.isMcpServerEnabled('other-server'), isTrue);
      });

      test('enableMcpServer adds server to enabledMcpjsonServers', () async {
        final manager = ClaudeSettingsManager(
          projectRoot: projectRoot,
          userHome: userHome,
        );

        await manager.enableMcpServer('new-server');

        final settings = await manager.readSettings(SettingsScope.local);
        expect(settings.enabledMcpjsonServers, contains('new-server'));
      });

      test('enableMcpServers adds multiple servers', () async {
        final manager = ClaudeSettingsManager(
          projectRoot: projectRoot,
          userHome: userHome,
        );

        await manager.enableMcpServers(['server1', 'server2']);

        final settings = await manager.readSettings(SettingsScope.local);
        expect(
          settings.enabledMcpjsonServers,
          containsAll(['server1', 'server2']),
        );
      });

      test(
        'disableMcpServer removes server from enabledMcpjsonServers',
        () async {
          await File('$projectRoot/.claude/settings.local.json').writeAsString(
            jsonEncode({
              'enabledMcpjsonServers': ['server1', 'server2'],
            }),
          );

          final manager = ClaudeSettingsManager(
            projectRoot: projectRoot,
            userHome: userHome,
          );

          await manager.disableMcpServer('server1');

          final settings = await manager.readSettings(SettingsScope.local);
          expect(settings.enabledMcpjsonServers, ['server2']);
        },
      );
    });

    group('permission management', () {
      test('addToAllowList adds pattern to allow list', () async {
        final manager = ClaudeSettingsManager(
          projectRoot: projectRoot,
          userHome: userHome,
        );

        await manager.addToAllowList('Bash(npm:*)');

        final settings = await manager.readSettings(SettingsScope.local);
        expect(settings.permissions?.allow, contains('Bash(npm:*)'));
      });

      test('addToDenyList adds pattern to deny list', () async {
        final manager = ClaudeSettingsManager(
          projectRoot: projectRoot,
          userHome: userHome,
        );

        await manager.addToDenyList('WebFetch');

        final settings = await manager.readSettings(SettingsScope.local);
        expect(settings.permissions?.deny, contains('WebFetch'));
      });
    });

    group('MCP JSON parsing', () {
      test('readMcpJson parses .mcp.json file', () async {
        await File('$projectRoot/.mcp.json').writeAsString(
          jsonEncode({
            'mcpServers': {
              'test-server': {
                'command': 'node',
                'args': ['server.js'],
                'env': {'DEBUG': 'true'},
              },
            },
          }),
        );

        final manager = ClaudeSettingsManager(
          projectRoot: projectRoot,
          userHome: userHome,
        );

        final mcpJson = await manager.readMcpJson();

        expect(mcpJson.serverNames, {'test-server'});
        expect(mcpJson.hasServer('test-server'), isTrue);

        final server = mcpJson.getServer('test-server');
        expect(server?.command, 'node');
        expect(server?.args, ['server.js']);
        expect(server?.env?['DEBUG'], 'true');
      });

      test(
        'areAllMcpServersApprovedSync returns true when all approved',
        () async {
          await File('$projectRoot/.mcp.json').writeAsString(
            jsonEncode({
              'mcpServers': {
                'server1': {'command': 'node'},
                'server2': {'command': 'python'},
              },
            }),
          );

          await File('$projectRoot/.claude/settings.local.json').writeAsString(
            jsonEncode({
              'enabledMcpjsonServers': ['server1', 'server2'],
            }),
          );

          final manager = ClaudeSettingsManager(
            projectRoot: projectRoot,
            userHome: userHome,
          );

          expect(manager.areAllMcpServersApprovedSync(), isTrue);
        },
      );

      test(
        'areAllMcpServersApprovedSync returns false when some unapproved',
        () async {
          await File('$projectRoot/.mcp.json').writeAsString(
            jsonEncode({
              'mcpServers': {
                'server1': {'command': 'node'},
                'server2': {'command': 'python'},
              },
            }),
          );

          await File('$projectRoot/.claude/settings.local.json').writeAsString(
            jsonEncode({
              'enabledMcpjsonServers': ['server1'],
            }),
          );

          final manager = ClaudeSettingsManager(
            projectRoot: projectRoot,
            userHome: userHome,
          );

          expect(manager.areAllMcpServersApprovedSync(), isFalse);
        },
      );

      test('getUnapprovedMcpServers returns unapproved servers', () async {
        await File('$projectRoot/.mcp.json').writeAsString(
          jsonEncode({
            'mcpServers': {
              'server1': {'command': 'node'},
              'server2': {'command': 'python'},
              'server3': {'command': 'deno'},
            },
          }),
        );

        await File('$projectRoot/.claude/settings.local.json').writeAsString(
          jsonEncode({
            'enabledMcpjsonServers': ['server1'],
          }),
        );

        final manager = ClaudeSettingsManager(
          projectRoot: projectRoot,
          userHome: userHome,
        );

        final unapproved = await manager.getUnapprovedMcpServers();
        expect(unapproved, containsAll(['server2', 'server3']));
        expect(unapproved, isNot(contains('server1')));
      });
    });
  });

  group('ClaudeSettings', () {
    test('fromJson parses all fields', () {
      final json = {
        'permissions': {
          'allow': ['Bash(npm:*)'],
          'deny': ['WebFetch'],
        },
        'enableAllProjectMcpServers': true,
        'enabledMcpjsonServers': ['server1'],
        'model': 'claude-sonnet-4',
        'language': 'en',
        'respectGitignore': false,
      };

      final settings = ClaudeSettings.fromJson(json);

      expect(settings.permissions?.allow, ['Bash(npm:*)']);
      expect(settings.permissions?.deny, ['WebFetch']);
      expect(settings.enableAllProjectMcpServers, isTrue);
      expect(settings.enabledMcpjsonServers, ['server1']);
      expect(settings.model, 'claude-sonnet-4');
      expect(settings.language, 'en');
      expect(settings.respectGitignore, isFalse);
    });

    test('toJson excludes null fields', () {
      const settings = ClaudeSettings(model: 'claude-sonnet-4');

      final json = settings.toJson();

      expect(json.containsKey('model'), isTrue);
      expect(json.containsKey('permissions'), isFalse);
      expect(json.containsKey('enabledMcpjsonServers'), isFalse);
    });

    test('merge combines settings with other taking precedence', () {
      const base = ClaudeSettings(model: 'base-model', language: 'en');

      const other = ClaudeSettings(model: 'other-model');

      final merged = base.merge(other);

      expect(merged.model, 'other-model');
      expect(merged.language, 'en');
    });

    test('copyWith creates new instance with updated values', () {
      const settings = ClaudeSettings(model: 'original', language: 'en');

      final updated = settings.copyWith(model: 'updated');

      expect(updated.model, 'updated');
      expect(updated.language, 'en');
      expect(settings.model, 'original'); // Original unchanged
    });
  });

  group('PermissionsConfig', () {
    test('isAllowed checks allow list', () {
      const config = PermissionsConfig(allow: ['Bash(npm:*)']);

      expect(config.isAllowed('Bash(npm:*)'), isTrue);
      expect(config.isAllowed('other'), isFalse);
    });

    test('isDenied checks deny list', () {
      const config = PermissionsConfig(deny: ['WebFetch']);

      expect(config.isDenied('WebFetch'), isTrue);
      expect(config.isDenied('other'), isFalse);
    });
  });

  group('McpJsonConfig', () {
    test('serverNames returns all server names', () {
      final config = McpJsonConfig(
        mcpServers: {
          'server1': const McpServerDefinition(command: 'node'),
          'server2': const McpServerDefinition(command: 'python'),
        },
      );

      expect(config.serverNames, {'server1', 'server2'});
    });

    test('hasServer checks if server exists', () {
      final config = McpJsonConfig(
        mcpServers: {'server1': const McpServerDefinition(command: 'node')},
      );

      expect(config.hasServer('server1'), isTrue);
      expect(config.hasServer('server2'), isFalse);
    });
  });
}
