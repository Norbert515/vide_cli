import 'dart:io';
import 'package:test/test.dart';
import 'package:claude_sdk/claude_sdk.dart';
import 'package:vide_server/services/rest_permission_service.dart';

void main() {
  late CanUseToolCallback callback;
  late Directory tempDir;

  setUp(() async {
    // Create a temp directory to use as the project root
    tempDir = await Directory.systemTemp.createTemp('rest_permission_test');
    callback = createRestPermissionCallback(tempDir.path);
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  group('RestPermissionService', () {
    group('auto-approved operations', () {
      test('Read operations are auto-approved', () async {
        final result = await callback('Read', {
          'file_path': '${tempDir.path}/file.dart',
        }, const ToolPermissionContext());

        expect(result, isA<PermissionResultAllow>());
      });

      test('Grep operations are auto-approved', () async {
        final result = await callback('Grep', {
          'pattern': 'test',
          'path': tempDir.path,
        }, const ToolPermissionContext());

        expect(result, isA<PermissionResultAllow>());
      });

      test('Glob operations are auto-approved', () async {
        final result = await callback('Glob', {
          'pattern': '*.dart',
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

      test('dart commands are auto-approved', () async {
        final result = await callback('Bash', {
          'command': 'dart analyze',
        }, const ToolPermissionContext());

        expect(result, isA<PermissionResultAllow>());
      });

      test('vide MCP tools are auto-approved', () async {
        final result = await callback('mcp__vide-agent__spawnAgent', {
          'agentType': 'implementation',
          'name': 'Test',
          'initialPrompt': 'test',
        }, const ToolPermissionContext());

        expect(result, isA<PermissionResultAllow>());
      });

      test('flutter runtime MCP tools are auto-approved', () async {
        final result = await callback('mcp__flutter-runtime__flutterStart', {
          'command': 'flutter run',
          'instanceId': 'test-123',
        }, const ToolPermissionContext());

        expect(result, isA<PermissionResultAllow>());
      });

      test('TodoWrite is auto-approved', () async {
        final result = await callback('TodoWrite', {
          'todos': [],
        }, const ToolPermissionContext());

        expect(result, isA<PermissionResultAllow>());
      });
    });

    group('denied operations', () {
      test('mcp__dart__analyze_files is blocked', () async {
        final result = await callback('mcp__dart__analyze_files', {
          'roots': [],
        }, const ToolPermissionContext());

        expect(result, isA<PermissionResultDeny>());
        final deny = result as PermissionResultDeny;
        expect(deny.message, contains('floods context'));
      });
    });

    group('operations requiring user approval convert to deny', () {
      test('Write to project directory converts to deny for REST', () async {
        // Write operations outside the allow list should require user approval
        // but REST API cannot prompt, so it converts to deny
        final result = await callback('Write', {
          'file_path': '${tempDir.path}/new_file.dart',
          'content': 'test content',
        }, const ToolPermissionContext());

        // The PermissionChecker will return PermissionAskUser for Write operations
        // not in the allow list, which REST API converts to deny
        expect(result, isA<PermissionResultDeny>());
      });

      test('unknown tool converts to deny for REST', () async {
        final result = await callback(
          'UnknownTool',
          {},
          const ToolPermissionContext(),
        );

        // Unknown tools require user approval, converted to deny for REST
        expect(result, isA<PermissionResultDeny>());
        final deny = result as PermissionResultDeny;
        expect(deny.message, contains('requires user approval'));
      });

      test('unknown bash command converts to deny for REST', () async {
        final result = await callback('Bash', {
          'command': 'custom_command_not_in_safe_list',
        }, const ToolPermissionContext());

        // Non-safe bash commands require user approval, converted to deny
        expect(result, isA<PermissionResultDeny>());
      });
    });
  });
}
