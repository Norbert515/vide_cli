import 'package:codex_sdk/codex_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('CodexConfig.toThreadStartParams', () {
    test('includes cwd when workingDirectory is set', () {
      const config = CodexConfig(workingDirectory: '/tmp/project');
      final params = config.toThreadStartParams();
      expect(params['cwd'], '/tmp/project');
    });

    test('omits cwd when workingDirectory is null', () {
      const config = CodexConfig();
      final params = config.toThreadStartParams();
      expect(params.containsKey('cwd'), isFalse);
    });

    test('includes sandbox mode', () {
      const config = CodexConfig(sandboxMode: 'danger-full-access');
      final params = config.toThreadStartParams();
      expect(params['sandbox'], 'danger-full-access');
    });

    test('uses default sandbox mode workspace-write', () {
      const config = CodexConfig();
      final params = config.toThreadStartParams();
      expect(params['sandbox'], 'workspace-write');
    });

    test('includes approval policy', () {
      const config = CodexConfig(approvalPolicy: 'never');
      final params = config.toThreadStartParams();
      expect(params['approvalPolicy'], 'never');
    });

    test('uses default approval policy on-failure', () {
      const config = CodexConfig();
      final params = config.toThreadStartParams();
      expect(params['approvalPolicy'], 'on-failure');
    });

    test('includes model when set', () {
      const config = CodexConfig(model: 'o3');
      final params = config.toThreadStartParams();
      expect(params['model'], 'o3');
    });

    test('omits model when null', () {
      const config = CodexConfig();
      final params = config.toThreadStartParams();
      expect(params.containsKey('model'), isFalse);
    });

    test('includes developerInstructions from appendSystemPrompt', () {
      const config = CodexConfig(appendSystemPrompt: 'Be concise');
      final params = config.toThreadStartParams();
      expect(params['developerInstructions'], 'Be concise');
    });

    test('omits developerInstructions when appendSystemPrompt is null', () {
      const config = CodexConfig();
      final params = config.toThreadStartParams();
      expect(params.containsKey('developerInstructions'), isFalse);
    });

    test('builds complete params with all fields', () {
      const config = CodexConfig(
        model: 'o4-mini',
        sandboxMode: 'read-only',
        workingDirectory: '/home/user/project',
        appendSystemPrompt: 'Be helpful',
        approvalPolicy: 'on-request',
      );
      final params = config.toThreadStartParams();
      expect(params['model'], 'o4-mini');
      expect(params['sandbox'], 'read-only');
      expect(params['cwd'], '/home/user/project');
      expect(params['developerInstructions'], 'Be helpful');
      expect(params['approvalPolicy'], 'on-request');
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
        additionalDirs: ['/data'],
        approvalPolicy: 'never',
      );

      final copy = original.copyWith(model: 'o4-mini');
      expect(copy.model, 'o4-mini');
      expect(copy.profile, 'test');
      expect(copy.sandboxMode, 'danger-full-access');
      expect(copy.workingDirectory, '/tmp');
      expect(copy.sessionId, 'session_1');
      expect(copy.appendSystemPrompt, 'Be brief');
      expect(copy.additionalDirs, ['/data']);
      expect(copy.approvalPolicy, 'never');
    });

    test('preserves values when no overrides given', () {
      const original = CodexConfig(model: 'o3');
      final copy = original.copyWith();
      expect(copy.model, 'o3');
    });

    test('can override approvalPolicy', () {
      const original = CodexConfig();
      final copy = original.copyWith(approvalPolicy: 'never');
      expect(copy.approvalPolicy, 'never');
    });
  });
}
