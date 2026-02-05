import 'dart:io';

import 'package:claude_sdk/claude_sdk.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';

import '../helpers/mock_vide_config_manager.dart';

void main() {
  group('dangerouslySkipPermissions', () {
    late Directory tempDir;
    late MockVideConfigManager configManager;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('skip_perm_test_');
      configManager = MockVideConfigManager(tempDir: tempDir);
    });

    tearDown(() async {
      await configManager.dispose();
    });

    ProviderContainer createContainer({required bool skipPermissions}) {
      return ProviderContainer(
        overrides: [
          videConfigManagerProvider.overrideWithValue(configManager),
          workingDirProvider.overrideWithValue(tempDir.path),
          permissionHandlerProvider.overrideWithValue(PermissionHandler()),
          if (skipPermissions)
            dangerouslySkipPermissionsProvider.overrideWith((ref) => true),
        ],
      );
    }

    test(
      'auto-approves dangerous commands when session provider is true',
      () async {
        final container = createContainer(skipPermissions: true);

        final session = VideSession.create(
          networkId: 'test-network',
          container: container,
        );

        final callback = session.createPermissionCallback(
          agentId: 'test-agent',
          agentName: 'Test',
          agentType: 'main',
          cwd: tempDir.path,
        );

        // rm -rf / would normally require user approval — but with skip
        // permissions enabled, it should be auto-approved immediately.
        final result = await callback('Bash', {
          'command': 'rm -rf /',
        }, const ToolPermissionContext());

        expect(result, isA<PermissionResultAllow>());

        await session.dispose(fireEndTrigger: false);
        container.dispose();
      },
    );

    test(
      'auto-approves dangerous commands when global setting is true',
      () async {
        final container = createContainer(skipPermissions: false);

        // Enable via global settings instead of session provider
        configManager.writeGlobalSettings(
          configManager.readGlobalSettings().copyWith(
            dangerouslySkipPermissions: true,
          ),
        );

        final session = VideSession.create(
          networkId: 'test-network',
          container: container,
        );

        final callback = session.createPermissionCallback(
          agentId: 'test-agent',
          agentName: 'Test',
          agentType: 'main',
          cwd: tempDir.path,
        );

        final result = await callback('Bash', {
          'command': 'rm -rf /',
        }, const ToolPermissionContext());

        expect(result, isA<PermissionResultAllow>());

        await session.dispose(fireEndTrigger: false);
        container.dispose();
      },
    );

    test('auto-approves write operations when flag is set', () async {
      final container = createContainer(skipPermissions: true);

      final session = VideSession.create(
        networkId: 'test-network',
        container: container,
      );

      final callback = session.createPermissionCallback(
        agentId: 'test-agent',
        agentName: 'Test',
        agentType: 'main',
        cwd: tempDir.path,
      );

      // Write tool would normally require user approval
      final result = await callback('Write', {
        'file_path': '/etc/passwd',
        'content': 'hacked',
      }, const ToolPermissionContext());

      expect(result, isA<PermissionResultAllow>());

      await session.dispose(fireEndTrigger: false);
      container.dispose();
    });

    test('auto-approves edit operations when flag is set', () async {
      final container = createContainer(skipPermissions: true);

      final session = VideSession.create(
        networkId: 'test-network',
        container: container,
      );

      final callback = session.createPermissionCallback(
        agentId: 'test-agent',
        agentName: 'Test',
        agentType: 'main',
        cwd: tempDir.path,
      );

      final result = await callback('Edit', {
        'file_path': '/some/file.dart',
        'old_string': 'foo',
        'new_string': 'bar',
      }, const ToolPermissionContext());

      expect(result, isA<PermissionResultAllow>());

      await session.dispose(fireEndTrigger: false);
      container.dispose();
    });

    test('does not auto-approve when flag is disabled', () async {
      // Use deny behavior so the callback doesn't hang waiting for user input
      final container = createContainer(skipPermissions: false);

      final session = VideSession.create(
        networkId: 'test-network',
        container: container,
        permissionConfig: const PermissionCheckerConfig(
          askUserBehavior: AskUserBehavior.deny,
          loadSettings: false,
          respectGitignore: false,
        ),
      );

      final callback = session.createPermissionCallback(
        agentId: 'test-agent',
        agentName: 'Test',
        agentType: 'main',
        cwd: tempDir.path,
      );

      // Without skip flag, dangerous command should be denied
      // (using deny behavior instead of ask to avoid hanging)
      final result = await callback('Bash', {
        'command': 'rm -rf /',
      }, const ToolPermissionContext());

      expect(result, isA<PermissionResultDeny>());

      await session.dispose(fireEndTrigger: false);
      container.dispose();
    });
  });
}
