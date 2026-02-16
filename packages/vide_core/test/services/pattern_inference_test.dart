import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';

void main() {
  group('PatternInference', () {
    group('_inferBashPattern - shell redirects', () {
      test('strips 2>&1 redirect', () {
        final result = PatternInference.inferPattern(
          'Bash',
          BashToolInput(command: 'dart test 2>&1'),
        );
        expect(result, equals('Bash(dart test *)'));
      });

      test('strips 2>&1 redirect with pipe', () {
        final result = PatternInference.inferPattern(
          'Bash',
          BashToolInput(command: 'dart test 2>&1 | grep foo'),
        );
        expect(result, equals('Bash(dart test *)'));
      });

      test('strips >&2 redirect', () {
        final result = PatternInference.inferPattern(
          'Bash',
          BashToolInput(command: 'echo error >&2'),
        );
        expect(result, equals('Bash(echo error *)'));
      });

      test('strips output redirect to file', () {
        final result = PatternInference.inferPattern(
          'Bash',
          BashToolInput(command: 'dart test >/dev/null'),
        );
        expect(result, equals('Bash(dart test *)'));
      });

      test('strips stderr redirect to file', () {
        final result = PatternInference.inferPattern(
          'Bash',
          BashToolInput(command: 'dart test 2>/dev/null'),
        );
        expect(result, equals('Bash(dart test *)'));
      });

      test('strips combined redirect', () {
        final result = PatternInference.inferPattern(
          'Bash',
          BashToolInput(command: 'dart test &>/dev/null'),
        );
        expect(result, equals('Bash(dart test *)'));
      });

      test('strips multiple redirects', () {
        final result = PatternInference.inferPattern(
          'Bash',
          BashToolInput(command: 'dart test >/dev/null 2>&1'),
        );
        expect(result, equals('Bash(dart test *)'));
      });

      test('strips input redirect', () {
        final result = PatternInference.inferPattern(
          'Bash',
          BashToolInput(command: 'sort <input.txt'),
        );
        expect(result, equals('Bash(sort *)'));
      });

      test('strips append redirect', () {
        final result = PatternInference.inferPattern(
          'Bash',
          BashToolInput(command: 'echo log >>output.txt'),
        );
        expect(result, equals('Bash(echo log *)'));
      });

      test('handles redirect after flags', () {
        final result = PatternInference.inferPattern(
          'Bash',
          BashToolInput(command: 'dart test --verbose 2>&1'),
        );
        // Should stop at --verbose (flag), so redirect stripping shouldn't matter
        expect(result, equals('Bash(dart test *)'));
      });

      test('handles command without redirects', () {
        final result = PatternInference.inferPattern(
          'Bash',
          BashToolInput(command: 'dart test'),
        );
        expect(result, equals('Bash(dart test *)'));
      });

      test('handles npm run with redirect', () {
        final result = PatternInference.inferPattern(
          'Bash',
          BashToolInput(command: 'npm run build 2>&1'),
        );
        expect(result, equals('Bash(npm run build *)'));
      });

      test('handles git command with redirect', () {
        final result = PatternInference.inferPattern(
          'Bash',
          BashToolInput(command: 'git status 2>/dev/null'),
        );
        expect(result, equals('Bash(git status *)'));
      });
    });

    group('_inferBashPattern - existing behavior preserved', () {
      test('infers pattern for simple command', () {
        final result = PatternInference.inferPattern(
          'Bash',
          BashToolInput(command: 'dart pub get'),
        );
        expect(result, equals('Bash(dart pub get *)'));
      });

      test('skips cd commands in compound', () {
        final result = PatternInference.inferPattern(
          'Bash',
          BashToolInput(command: 'cd /project && dart pub get'),
        );
        expect(result, equals('Bash(dart pub get *)'));
      });

      test('stops at flags', () {
        final result = PatternInference.inferPattern(
          'Bash',
          BashToolInput(command: 'dart pub get --offline'),
        );
        expect(result, equals('Bash(dart pub get *)'));
      });

      test('stops at path arguments', () {
        final result = PatternInference.inferPattern(
          'Bash',
          BashToolInput(command: 'find /path/to/search -name *.dart'),
        );
        expect(result, equals('Bash(find *)'));
      });

      test('handles empty command', () {
        final result = PatternInference.inferPattern(
          'Bash',
          BashToolInput(command: ''),
        );
        expect(result, equals('Bash(*)'));
      });
    });

    group('_inferBashPattern - quoted arguments', () {
      test('stops at quoted string argument', () {
        final result = PatternInference.inferPattern(
          'Bash',
          BashToolInput(
            command:
                'playwright-cli run-code "async page => { await page.evaluate(() => { admin.scene.clear(); }); }"',
          ),
        );
        expect(result, equals('Bash(playwright-cli run-code *)'));
      });

      test('stops at single-quoted string argument', () {
        final result = PatternInference.inferPattern(
          'Bash',
          BashToolInput(command: "echo 'hello world' > file.txt"),
        );
        expect(result, equals('Bash(echo *)'));
      });

      test('handles command with no quoted args normally', () {
        final result = PatternInference.inferPattern(
          'Bash',
          BashToolInput(command: 'git commit -m "message"'),
        );
        // Stops at -m flag before reaching the quoted string
        expect(result, equals('Bash(git commit *)'));
      });
    });

    group('_inferBashPattern - prefix command skipping', () {
      test('skips sleep prefix and infers from main command', () {
        final result = PatternInference.inferPattern(
          'Bash',
          BashToolInput(
            command: 'sleep 1 && playwright-cli screenshot --filename=test.png',
          ),
        );
        expect(result, equals('Bash(playwright-cli screenshot *)'));
      });

      test('skips timeout prefix and infers from main command', () {
        final result = PatternInference.inferPattern(
          'Bash',
          BashToolInput(command: 'timeout 30 && dart test'),
        );
        expect(result, equals('Bash(dart test *)'));
      });

      test('skips env prefix', () {
        final result = PatternInference.inferPattern(
          'Bash',
          BashToolInput(command: 'env FOO=bar && dart run server'),
        );
        expect(result, equals('Bash(dart run server *)'));
      });

      test('skips cd and sleep together', () {
        final result = PatternInference.inferPattern(
          'Bash',
          BashToolInput(
            command: 'cd /project && sleep 2 && dart pub get',
          ),
        );
        expect(result, equals('Bash(dart pub get *)'));
      });

      test('falls back to prefix command if all commands are prefixes', () {
        final result = PatternInference.inferPattern(
          'Bash',
          BashToolInput(command: 'sleep 1 && sleep 2'),
        );
        // Falls back to first non-cd command
        expect(result, equals('Bash(sleep 1 *)'));
      });

      test('skips nohup prefix', () {
        final result = PatternInference.inferPattern(
          'Bash',
          BashToolInput(command: 'nohup && dart run bin/server.dart'),
        );
        // bin/server.dart is a relative path (not starting with / ./ ~/ ..)
        expect(result, equals('Bash(dart run bin/server.dart *)'));
      });

      test('picks last meaningful command in chain', () {
        final result = PatternInference.inferPattern(
          'Bash',
          BashToolInput(
            command: 'cd /project && sleep 1 && dart pub get && dart test',
          ),
        );
        expect(result, equals('Bash(dart test *)'));
      });
    });
  });
}
