import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';

/// Verify the expected outcomes from the requirements
void main() {
  group('Expected outcomes from requirements', () {
    test('1. find /path -name "pubspec.yaml" matches Bash(find:*)', () {
      expect(
        PermissionMatcher.matches(
          'Bash(find:*)',
          'Bash',
          BashToolInput(command: 'find /path -name "pubspec.yaml"'),
        ),
        isTrue,
      );
    });

    test('2. cd /project/sub && dart pub get matches Bash(dart pub:*)', () {
      expect(
        PermissionMatcher.matches(
          'Bash(dart pub:*)',
          'Bash',
          BashToolInput(command: 'cd /project/sub && dart pub get'),
          context: {'cwd': '/project'},
        ),
        isTrue,
      );
    });

    test(
      '3. cd /project/sub && serverpod generate matches Bash(serverpod:*)',
      () {
        expect(
          PermissionMatcher.matches(
            'Bash(serverpod:*)',
            'Bash',
            BashToolInput(command: 'cd /project/sub && serverpod generate'),
            context: {'cwd': '/project'},
          ),
          isTrue,
        );
      },
    );

    test(
      '4. cd /project/sub && dart analyze file.dart matches Bash(dart analyze:*)',
      () {
        expect(
          PermissionMatcher.matches(
            'Bash(dart analyze:*)',
            'Bash',
            BashToolInput(command: 'cd /project/sub && dart analyze file.dart'),
            context: {'cwd': '/project'},
          ),
          isTrue,
        );
      },
    );

    test(
      '5. dart pub deps | grep uuid - grep is auto-approved as safe filter',
      () {
        // grep is now auto-approved as a safe output filter
        // With dart pub:* pattern, it should now pass (grep is auto-approved)
        expect(
          PermissionMatcher.matches(
            'Bash(dart pub:*)',
            'Bash',
            BashToolInput(command: 'dart pub deps | grep uuid'),
          ),
          isTrue, // grep is auto-approved as safe filter
        );

        // With only grep:* pattern, it should also pass (dart pub is what grep filters)
        expect(
          PermissionMatcher.matches(
            'Bash(grep:*)',
            'Bash',
            BashToolInput(command: 'dart pub deps | grep uuid'),
          ),
          isTrue, // dart pub deps doesn't match, but grep matches
        );

        // With a wildcard pattern, it should still pass
        expect(
          PermissionMatcher.matches(
            'Bash(*)',
            'Bash',
            BashToolInput(command: 'dart pub deps | grep uuid'),
          ),
          isTrue,
        );
      },
    );

    test('6. find with head/tail output filters is auto-approved', () {
      // head and tail are safe output filters and should be auto-approved
      expect(
        PermissionMatcher.matches(
          'Bash(find:*)',
          'Bash',
          BashToolInput(command: 'find /path -name ".claude" | head -5'),
        ),
        isTrue,
      );

      expect(
        PermissionMatcher.matches(
          'Bash(find:*)',
          'Bash',
          BashToolInput(command: 'find /path -name "*.dart" | tail -10'),
        ),
        isTrue,
      );

      expect(
        PermissionMatcher.matches(
          'Bash(find:*)',
          'Bash',
          BashToolInput(command: 'find /path -type f 2>/dev/null | head -5'),
        ),
        isTrue,
      );
    });

    test('7. ls with grep/sort/uniq filters is auto-approved', () {
      expect(
        PermissionMatcher.matches(
          'Bash(ls:*)',
          'Bash',
          BashToolInput(command: 'ls -la | grep ".dart"'),
        ),
        isTrue,
      );

      expect(
        PermissionMatcher.matches(
          'Bash(ls:*)',
          'Bash',
          BashToolInput(command: 'ls | sort | uniq'),
        ),
        isTrue,
      );
    });

    test('8. Commands with jq JSON processor are auto-approved', () {
      expect(
        PermissionMatcher.matches(
          'Bash(curl:*)',
          'Bash',
          BashToolInput(command: 'curl https://api.example.com | jq .data'),
        ),
        isTrue,
      );
    });
  });

  group('Pattern inference improvements', () {
    test('find with path infers to Bash(find:*)', () {
      final pattern = PatternInference.inferPattern(
        'Bash',
        BashToolInput(command: 'find /any/path -name "*.dart"'),
      );
      expect(pattern, 'Bash(find:*)');
    });

    test('cd && command infers from non-cd command', () {
      final pattern = PatternInference.inferPattern(
        'Bash',
        BashToolInput(command: 'cd /project/sub && dart pub get'),
      );
      // Infers the full sub-command (more specific is better)
      expect(pattern, 'Bash(dart pub get:*)');
    });

    test('serverpod with cd infers from serverpod command', () {
      final pattern = PatternInference.inferPattern(
        'Bash',
        BashToolInput(command: 'cd packages/server && serverpod generate'),
      );
      // Infers the full sub-command (more specific is better)
      expect(pattern, 'Bash(serverpod generate:*)');
    });

    test('dart analyze with file path infers to Bash(dart analyze:*)', () {
      final pattern = PatternInference.inferPattern(
        'Bash',
        BashToolInput(command: 'dart analyze /path/to/file.dart'),
      );
      expect(pattern, 'Bash(dart analyze:*)');
    });
  });
}
