import 'package:codex_sdk/codex_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('CodexConfig.toCliArgs', () {
    test('generates minimal args with defaults', () {
      const config = CodexConfig();
      final args = config.toCliArgs();
      expect(args, ['exec', '--json', '--full-auto']);
    });

    test('always includes --full-auto', () {
      const config = CodexConfig();
      final args = config.toCliArgs();
      expect(args, contains('--full-auto'));
    });

    test('includes model flag', () {
      const config = CodexConfig(model: 'o3');
      final args = config.toCliArgs();
      expect(args, contains('--model'));
      expect(args[args.indexOf('--model') + 1], 'o3');
    });

    test('includes profile flag', () {
      const config = CodexConfig(profile: 'my-profile');
      final args = config.toCliArgs();
      expect(args, contains('--profile'));
      expect(args[args.indexOf('--profile') + 1], 'my-profile');
    });

    test('includes sandbox mode when not default', () {
      const config = CodexConfig(sandboxMode: 'danger-full-access');
      final args = config.toCliArgs();
      expect(args, contains('--sandbox'));
      expect(args[args.indexOf('--sandbox') + 1], 'danger-full-access');
    });

    test('omits sandbox mode when default workspace-write', () {
      const config = CodexConfig(sandboxMode: 'workspace-write');
      final args = config.toCliArgs();
      expect(args, isNot(contains('--sandbox')));
    });

    test('includes system prompt append', () {
      const config = CodexConfig(appendSystemPrompt: 'Be concise');
      final args = config.toCliArgs();
      expect(args, contains('-c'));
      final cIndex = args.indexOf('-c');
      expect(args[cIndex + 1], 'instructions.append=Be concise');
    });

    test('includes additional dirs with --add-dir', () {
      const config = CodexConfig(additionalDirs: ['/tmp/a', '/tmp/b']);
      final args = config.toCliArgs();
      expect(args.where((a) => a == '--add-dir').length, 2);
      final firstIdx = args.indexOf('--add-dir');
      expect(args[firstIdx + 1], '/tmp/a');
      final secondIdx = args.indexOf('--add-dir', firstIdx + 1);
      expect(args[secondIdx + 1], '/tmp/b');
    });

    test('includes additional flags', () {
      const config = CodexConfig(additionalFlags: ['--verbose', '--debug']);
      final args = config.toCliArgs();
      expect(args, containsAll(['--verbose', '--debug']));
    });

    test('includes --skip-git-repo-check when set', () {
      const config = CodexConfig(skipGitRepoCheck: true);
      final args = config.toCliArgs();
      expect(args, contains('--skip-git-repo-check'));
    });

    test('omits --skip-git-repo-check by default', () {
      const config = CodexConfig();
      final args = config.toCliArgs();
      expect(args, isNot(contains('--skip-git-repo-check')));
    });

    test('places resume subcommand after all flags', () {
      const config = CodexConfig(model: 'o3', additionalFlags: ['--verbose']);
      final args = config.toCliArgs(
        isResume: true,
        resumeThreadId: 'thread_123',
      );

      final resumeIndex = args.indexOf('resume');
      expect(resumeIndex, isNot(-1));
      expect(args[resumeIndex + 1], 'thread_123');

      // All flags should come before resume
      expect(args.indexOf('--model'), lessThan(resumeIndex));
      expect(args.indexOf('--verbose'), lessThan(resumeIndex));
      expect(args.indexOf('--json'), lessThan(resumeIndex));
    });

    test('does not include resume when isResume is false', () {
      const config = CodexConfig();
      final args = config.toCliArgs(isResume: false);
      expect(args, isNot(contains('resume')));
    });

    test('does not include resume when threadId is null', () {
      const config = CodexConfig();
      final args = config.toCliArgs(isResume: true, resumeThreadId: null);
      expect(args, isNot(contains('resume')));
    });

    test('starts with exec', () {
      const config = CodexConfig();
      final args = config.toCliArgs();
      expect(args.first, 'exec');
    });
  });

  group('CodexConfig.copyWith', () {
    test('copies all fields', () {
      const original = CodexConfig(
        model: 'o3',
        profile: 'test',
        sandboxMode: 'danger-full-access',
        workingDirectory: '/tmp',
        sessionId: 'session_1',
        appendSystemPrompt: 'Be brief',
        additionalFlags: ['--verbose'],
        additionalDirs: ['/data'],
      );

      final copy = original.copyWith(model: 'o4-mini');
      expect(copy.model, 'o4-mini');
      expect(copy.profile, 'test');
      expect(copy.sandboxMode, 'danger-full-access');
      expect(copy.workingDirectory, '/tmp');
      expect(copy.sessionId, 'session_1');
      expect(copy.appendSystemPrompt, 'Be brief');
      expect(copy.additionalFlags, ['--verbose']);
      expect(copy.additionalDirs, ['/data']);
    });

    test('preserves values when no overrides given', () {
      const original = CodexConfig(model: 'o3');
      final copy = original.copyWith();
      expect(copy.model, 'o3');
    });
  });
}
