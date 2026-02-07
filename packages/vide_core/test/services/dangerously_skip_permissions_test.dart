import 'dart:io';

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

    SessionServices createServices({required bool skipPermissions}) {
      return SessionServices(
        configManager: configManager,
        workingDirectory: tempDir.path,
        permissionHandler: PermissionHandler(),
        dangerouslySkipPermissions: skipPermissions,
      );
    }

    test(
      'auto-approves dangerous commands when session skipPermissions is true',
      () async {
        final services = createServices(skipPermissions: true);

        final session = LocalVideSession.create(
          networkId: 'test-network',
          services: services,
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
        }, VidePermissionContext());

        expect(result, isA<VidePermissionAllow>());

        await session.dispose(fireEndTrigger: false);
        services.dispose();
      },
    );

    test(
      'auto-approves dangerous commands when global setting is true',
      () async {
        final services = createServices(skipPermissions: false);

        // Enable via global settings instead of session flag
        configManager.writeGlobalSettings(
          configManager.readGlobalSettings().copyWith(
            dangerouslySkipPermissions: true,
          ),
        );

        final session = LocalVideSession.create(
          networkId: 'test-network',
          services: services,
        );

        final callback = session.createPermissionCallback(
          agentId: 'test-agent',
          agentName: 'Test',
          agentType: 'main',
          cwd: tempDir.path,
        );

        final result = await callback('Bash', {
          'command': 'rm -rf /',
        }, VidePermissionContext());

        expect(result, isA<VidePermissionAllow>());

        await session.dispose(fireEndTrigger: false);
        services.dispose();
      },
    );

    test('auto-approves write operations when flag is set', () async {
      final services = createServices(skipPermissions: true);

      final session = LocalVideSession.create(
        networkId: 'test-network',
        services: services,
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
      }, VidePermissionContext());

      expect(result, isA<VidePermissionAllow>());

      await session.dispose(fireEndTrigger: false);
      services.dispose();
    });

    test('auto-approves edit operations when flag is set', () async {
      final services = createServices(skipPermissions: true);

      final session = LocalVideSession.create(
        networkId: 'test-network',
        services: services,
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
      }, VidePermissionContext());

      expect(result, isA<VidePermissionAllow>());

      await session.dispose(fireEndTrigger: false);
      services.dispose();
    });

    test('does not auto-approve when flag is disabled', () async {
      final services = createServices(skipPermissions: false);

      final session = LocalVideSession.create(
        networkId: 'test-network',
        services: services,
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
      }, VidePermissionContext());

      expect(result, isA<VidePermissionDeny>());

      await session.dispose(fireEndTrigger: false);
      services.dispose();
    });
  });
}
