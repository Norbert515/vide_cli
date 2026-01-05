import 'dart:io';
import 'dart:convert';
import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';

void main() {
  group('Permission Persistence - LocalSettingsManager.addToAllowList', () {
    late Directory tempDir;
    late LocalSettingsManager settingsManager;

    setUp(() async {
      // Create a temp directory for test
      tempDir = await Directory.systemTemp.createTemp('permission_test_');
      settingsManager = LocalSettingsManager(
        projectRoot: tempDir.path,
        parrottRoot: tempDir.path,
      );
    });

    tearDown(() async {
      // Clean up temp directory
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'addToAllowList creates .claude/settings.local.json if not exists',
      () async {
        // Arrange
        final pattern = 'Read(/some/path/**)';

        // Act
        await settingsManager.addToAllowList(pattern);

        // Assert
        final settingsFile = File(
          '${tempDir.path}/.claude/settings.local.json',
        );
        expect(
          await settingsFile.exists(),
          isTrue,
          reason: 'Settings file should be created',
        );

        final content = await settingsFile.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        final permissions = json['permissions'] as Map<String, dynamic>;
        final allow = permissions['allow'] as List;

        expect(
          allow,
          contains(pattern),
          reason: 'Allow list should contain the added pattern',
        );
      },
    );

    test('addToAllowList adds pattern to existing allow list', () async {
      // Arrange - create initial settings
      final claudeDir = Directory('${tempDir.path}/.claude');
      await claudeDir.create(recursive: true);
      final settingsFile = File('${claudeDir.path}/settings.local.json');
      await settingsFile.writeAsString(
        jsonEncode({
          'permissions': {
            'allow': ['ExistingPattern'],
            'deny': [],
            'ask': [],
          },
        }),
      );

      final newPattern = 'WebFetch(domain:example.com)';

      // Act
      await settingsManager.addToAllowList(newPattern);

      // Assert
      final content = await settingsFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final permissions = json['permissions'] as Map<String, dynamic>;
      final allow = permissions['allow'] as List;

      expect(
        allow,
        contains('ExistingPattern'),
        reason: 'Existing pattern should be preserved',
      );
      expect(
        allow,
        contains(newPattern),
        reason: 'New pattern should be added',
      );
      expect(allow.length, equals(2));
    });

    test('addToAllowList does not duplicate existing patterns', () async {
      // Arrange - create initial settings with pattern
      final claudeDir = Directory('${tempDir.path}/.claude');
      await claudeDir.create(recursive: true);
      final settingsFile = File('${claudeDir.path}/settings.local.json');
      final existingPattern = 'Bash(dart test:*)';
      await settingsFile.writeAsString(
        jsonEncode({
          'permissions': {
            'allow': [existingPattern],
            'deny': [],
            'ask': [],
          },
        }),
      );

      // Act - add the same pattern again
      await settingsManager.addToAllowList(existingPattern);

      // Assert
      final content = await settingsFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final permissions = json['permissions'] as Map<String, dynamic>;
      final allow = permissions['allow'] as List;

      expect(
        allow.where((p) => p == existingPattern).length,
        equals(1),
        reason: 'Pattern should not be duplicated',
      );
    });

    test('addToAllowList preserves hooks', () async {
      // Arrange - create initial settings with hooks
      final claudeDir = Directory('${tempDir.path}/.claude');
      await claudeDir.create(recursive: true);
      final settingsFile = File('${claudeDir.path}/settings.local.json');
      await settingsFile.writeAsString(
        jsonEncode({
          'permissions': {'allow': [], 'deny': [], 'ask': []},
          'hooks': {
            'PreToolUse': [
              {
                'matcher': 'Write|Edit',
                'hooks': [
                  {'type': 'command', 'command': 'echo test', 'timeout': 1000},
                ],
              },
            ],
          },
        }),
      );

      final newPattern = 'Read(/new/path/**)';

      // Act
      await settingsManager.addToAllowList(newPattern);

      // Assert
      final content = await settingsFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;

      // Check hooks are preserved
      expect(
        json.containsKey('hooks'),
        isTrue,
        reason: 'Hooks should be preserved',
      );
      final hooks = json['hooks'] as Map<String, dynamic>;
      expect(hooks.containsKey('PreToolUse'), isTrue);

      // Check pattern was added
      final permissions = json['permissions'] as Map<String, dynamic>;
      final allow = permissions['allow'] as List;
      expect(allow, contains(newPattern));
    });

    test(
      'Permission dialog "Allow and remember" should persist non-write operations',
      () async {
        // This test documents the expected behavior:
        // When a user clicks "Allow and remember" for non-write operations (like Read, WebFetch, Bash),
        // the pattern should be added to the persistent allow list via addToAllowList.
        //
        // Write operations (Write, Edit, MultiEdit) are handled differently - they go to session cache only.
        //
        // See: lib/modules/agent_network/network_execution_page.dart lines 209-229

        final nonWritePattern = 'WebFetch(domain:api.example.com)';

        // Act - simulate what happens when "Allow and remember" is clicked for a non-write operation
        await settingsManager.addToAllowList(nonWritePattern);

        // Assert - pattern should be persisted
        final settings = await settingsManager.readSettings();
        expect(
          settings.permissions.allow,
          contains(nonWritePattern),
          reason:
              'Non-write operations with "Allow and remember" should be persisted',
        );
      },
    );
  });
}
