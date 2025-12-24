import 'package:test/test.dart';
import 'package:claude_api/claude_api.dart';

void main() {
  group('ClaudeConfig', () {
    test('creates default config', () {
      final config = ClaudeConfig.defaults();

      expect(config.timeout, equals(const Duration(seconds: 120)));
      expect(config.retryAttempts, equals(3));
      expect(config.verbose, isFalse);
      expect(config.model, isNull);
    });

    test('generates correct CLI arguments', () {
      final config = ClaudeConfig(
        model: 'claude-3-opus',
        verbose: true,
        appendSystemPrompt: 'You are helpful',
        temperature: 0.7,
        maxTokens: 1000,
      );

      final args = config.toCliArgs();

      // Control protocol args (always used)
      expect(args, contains('--output-format=stream-json'));
      expect(args, contains('--input-format=stream-json'));
      expect(args, contains('--verbose'));
      // Model and other params
      expect(args, contains('--model'));
      expect(args, contains('claude-3-opus'));
      expect(args, contains('--append-system-prompt'));
      expect(args, contains('You are helpful'));
      expect(args, contains('--temperature'));
      expect(args, contains('0.7'));
      expect(args, contains('--max-tokens'));
      expect(args, contains('1000'));
    });

    test('includes additional flags', () {
      final config = ClaudeConfig(additionalFlags: ['--debug', '--no-cache']);

      final args = config.toCliArgs();

      expect(args, contains('--debug'));
      expect(args, contains('--no-cache'));
    });

    test('copyWith creates new instance with changes', () {
      final original = ClaudeConfig(model: 'claude-3-opus', verbose: false);

      final modified = original.copyWith(verbose: true, temperature: 0.5);

      expect(modified.model, equals('claude-3-opus'));
      expect(modified.verbose, isTrue);
      expect(modified.temperature, equals(0.5));

      // Original should be unchanged
      expect(original.verbose, isFalse);
      expect(original.temperature, isNull);
    });

    test('includes permission mode in CLI args', () {
      final config = ClaudeConfig(permissionMode: 'acceptEdits');

      final args = config.toCliArgs();

      expect(args, contains('--permission-mode'));
      expect(args, contains('acceptEdits'));
    });

    test('copyWith updates permission mode', () {
      final original = ClaudeConfig(model: 'claude-3-opus');

      final modified = original.copyWith(permissionMode: 'acceptEdits');

      expect(modified.permissionMode, equals('acceptEdits'));
      expect(original.permissionMode, isNull);
    });
  });
}
