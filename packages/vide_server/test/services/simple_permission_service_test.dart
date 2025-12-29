import 'package:test/test.dart';
import 'package:claude_sdk/claude_sdk.dart';
import 'package:vide_server/services/simple_permission_service.dart';

void main() {
  late CanUseToolCallback callback;

  setUp(() {
    callback = createSimplePermissionCallback('/project');
  });

  group('SimplePermissionService', () {
    group('safe operations', () {
      test('Read operations are auto-approved', () async {
        final result = await callback('Read', {
          'file_path': '/path/to/file.dart',
        }, const ToolPermissionContext());

        expect(result, isA<PermissionResultAllow>());
      });

      test('Grep operations are auto-approved', () async {
        final result = await callback('Grep', {
          'pattern': 'test',
          'path': '/path',
        }, const ToolPermissionContext());

        expect(result, isA<PermissionResultAllow>());
      });

      test('Glob operations are auto-approved', () async {
        final result = await callback('Glob', {
          'pattern': '*.dart',
        }, const ToolPermissionContext());

        expect(result, isA<PermissionResultAllow>());
      });

      test(
        'Write operations without path traversal are auto-approved',
        () async {
          final result = await callback('Write', {
            'file_path': '/project/lib/main.dart',
          }, const ToolPermissionContext());

          expect(result, isA<PermissionResultAllow>());
        },
      );

      test('Edit operations are auto-approved', () async {
        final result = await callback('Edit', {
          'file_path': '/project/lib/main.dart',
        }, const ToolPermissionContext());

        expect(result, isA<PermissionResultAllow>());
      });

      test('safe bash commands are auto-approved', () async {
        final result = await callback('Bash', {
          'command': 'ls -la',
        }, const ToolPermissionContext());

        expect(result, isA<PermissionResultAllow>());
      });

      test('git status is auto-approved', () async {
        final result = await callback('Bash', {
          'command': 'git status',
        }, const ToolPermissionContext());

        expect(result, isA<PermissionResultAllow>());
      });

      test('dart/flutter commands are auto-approved', () async {
        final result = await callback('Bash', {
          'command': 'dart analyze',
        }, const ToolPermissionContext());

        expect(result, isA<PermissionResultAllow>());
      });
    });

    group('dangerous operations', () {
      test('rm -rf is denied', () async {
        final result = await callback('Bash', {
          'command': 'rm -rf /',
        }, const ToolPermissionContext());

        expect(result, isA<PermissionResultDeny>());
        final deny = result as PermissionResultDeny;
        expect(deny.message, contains('Dangerous operation'));
      });

      test('dd command is denied', () async {
        final result = await callback('Bash', {
          'command': 'dd if=/dev/zero of=/dev/sda',
        }, const ToolPermissionContext());

        expect(result, isA<PermissionResultDeny>());
      });

      test('mkfs command is denied', () async {
        final result = await callback('Bash', {
          'command': 'mkfs.ext4 /dev/sda1',
        }, const ToolPermissionContext());

        expect(result, isA<PermissionResultDeny>());
      });

      test('sudo commands are denied', () async {
        final result = await callback('Bash', {
          'command': 'sudo rm -rf /',
        }, const ToolPermissionContext());

        expect(result, isA<PermissionResultDeny>());
      });

      test('chmod 777 is denied', () async {
        final result = await callback('Bash', {
          'command': 'chmod 777 /etc/passwd',
        }, const ToolPermissionContext());

        expect(result, isA<PermissionResultDeny>());
      });

      test('curl to external host is denied', () async {
        final result = await callback('Bash', {
          'command': 'curl https://example.com',
        }, const ToolPermissionContext());

        expect(result, isA<PermissionResultDeny>());
      });

      test('WebFetch to external host is denied', () async {
        final result = await callback('WebFetch', {
          'url': 'https://example.com',
        }, const ToolPermissionContext());

        expect(result, isA<PermissionResultDeny>());
      });

      test('path traversal in file path is denied', () async {
        final result = await callback('Write', {
          'file_path': '../../../etc/passwd',
        }, const ToolPermissionContext());

        expect(result, isA<PermissionResultDeny>());
      });

      test('absolute path outside project directory is denied', () async {
        final result = await callback('Write', {
          'file_path': '/etc/passwd',
        }, const ToolPermissionContext());

        expect(result, isA<PermissionResultDeny>());
        final deny = result as PermissionResultDeny;
        expect(deny.message, contains('Not in safe list'));
      });

      test('absolute path to system directory is denied', () async {
        final result = await callback('Edit', {
          'file_path': '/var/www/html/index.html',
        }, const ToolPermissionContext());

        expect(result, isA<PermissionResultDeny>());
      });

      test('home directory outside project is denied', () async {
        final result = await callback('Write', {
          'file_path': '/Users/someone/.bashrc',
        }, const ToolPermissionContext());

        expect(result, isA<PermissionResultDeny>());
      });
    });

    group('localhost operations', () {
      test('curl to localhost is allowed', () async {
        final result = await callback('Bash', {
          'command': 'curl localhost:8080',
        }, const ToolPermissionContext());

        expect(result, isA<PermissionResultAllow>());
      });

      test('WebFetch to localhost is allowed', () async {
        final result = await callback('WebFetch', {
          'url': 'http://localhost:8080',
        }, const ToolPermissionContext());

        expect(result, isA<PermissionResultAllow>());
      });

      test('WebFetch to 127.0.0.1 is allowed', () async {
        final result = await callback('WebFetch', {
          'url': 'http://127.0.0.1:3000',
        }, const ToolPermissionContext());

        expect(result, isA<PermissionResultAllow>());
      });
    });

    group('default behavior', () {
      test('unknown tool is denied by default', () async {
        final result = await callback(
          'UnknownTool',
          {},
          const ToolPermissionContext(),
        );

        expect(result, isA<PermissionResultDeny>());
        final deny = result as PermissionResultDeny;
        expect(deny.message, contains('Not in safe list'));
      });

      test('unknown bash command is denied by default', () async {
        final result = await callback('Bash', {
          'command': 'custom_dangerous_command',
        }, const ToolPermissionContext());

        expect(result, isA<PermissionResultDeny>());
      });
    });
  });
}
