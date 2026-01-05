/// Example demonstrating the Control Protocol Hooks API
///
/// This example shows how to use PreToolUse hooks to intercept and
/// control tool execution in Claude Code.

import 'package:claude_sdk/claude_sdk.dart';

Future<void> main() async {
  // Example 1: Block dangerous bash commands
  final client = await ClaudeClient.create(
    config: const ClaudeConfig(workingDirectory: '/tmp/test-project'),
    hooks: {
      HookEvent.preToolUse: [
        // Block dangerous rm commands
        HookMatcher(
          matcher: 'Bash',
          callback: (input, toolUseId) async {
            if (input is PreToolUseHookInput) {
              final command = input.toolInput['command'] as String? ?? '';

              // Block rm -rf commands
              if (command.contains('rm -rf') || command.contains('rm -r /')) {
                print('BLOCKED: Dangerous rm command: $command');
                return HookOutput.deny(
                  'Dangerous rm command blocked for safety',
                );
              }

              // Block commands that might leak secrets
              if (command.contains('.env') && command.contains('cat')) {
                print('BLOCKED: Attempt to read .env file');
                return HookOutput.deny('Reading .env files is not allowed');
              }
            }

            // Allow all other commands
            return HookOutput.allow();
          },
        ),

        // Log all Write operations
        HookMatcher(
          matcher: 'Write',
          callback: (input, toolUseId) async {
            if (input is PreToolUseHookInput) {
              final filePath = input.toolInput['file_path'] as String? ?? '';
              print('AUDIT: Writing to file: $filePath');
            }
            return HookOutput.allow();
          },
        ),
      ],

      HookEvent.postToolUse: [
        // Log all tool completions
        HookMatcher(
          callback: (input, toolUseId) async {
            if (input is PostToolUseHookInput) {
              print('COMPLETED: ${input.toolName}');
            }
            return const HookOutput();
          },
        ),
      ],
    },
  );

  // Example 2: Permission callback for all tools
  final clientWithPermissions = await ClaudeClient.create(
    config: const ClaudeConfig(workingDirectory: '/tmp/test-project'),
    canUseTool: (toolName, input, context) async {
      // Log all tool usage
      print('Tool requested: $toolName with input: $input');

      // Block specific tools entirely
      if (toolName == 'WebSearch') {
        return const PermissionResultDeny(
          message: 'Web search is disabled in this environment',
        );
      }

      // Allow everything else
      return const PermissionResultAllow();
    },
  );

  // Clean up
  await client.close();
  await clientWithPermissions.close();

  print('Examples completed!');
}

/// Example: Custom hook that modifies tool input
Future<HookOutput> sanitizeFilePathHook(
  HookInput input,
  String? toolUseId,
) async {
  if (input is PreToolUseHookInput) {
    final filePath = input.toolInput['file_path'] as String?;

    // Redirect writes to /etc to a safe directory
    if (filePath != null && filePath.startsWith('/etc/')) {
      return HookOutput(
        hookSpecificOutput: HookSpecificOutput(
          hookEventName: 'PreToolUse',
          permissionDecision: PermissionDecision.allow,
          updatedInput: {
            ...input.toolInput,
            'file_path': '/tmp/sandbox${filePath}',
          },
        ),
      );
    }
  }

  return HookOutput.allow();
}

/// Example: Hook that adds context to the conversation
Future<HookOutput> addContextHook(HookInput input, String? toolUseId) async {
  return HookOutput(
    systemMessage:
        'Remember: All file operations are being logged for audit purposes.',
  );
}
