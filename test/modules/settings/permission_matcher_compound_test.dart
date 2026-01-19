import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';

void main() {
  group('PermissionMatcher compound commands', () {
    test('matches compound command with cd and approved command', () {
      expect(
        PermissionMatcher.matches(
          'Bash(dart pub:*)',
          'Bash',
          BashToolInput(command: 'cd /project/packages/server && dart pub get'),
          context: {'cwd': '/project'},
        ),
        isTrue,
      );
    });

    test(
      'matches pipe command when first part approved and second is safe filter',
      () {
        expect(
          PermissionMatcher.matches(
            'Bash(dart pub:*)',
            'Bash',
            BashToolInput(command: 'dart pub deps | grep uuid'),
          ),
          isTrue, // dart pub deps matches, grep is safe filter
        );
      },
    );

    test(
      'matches pipe command when second part approved and first is data source',
      () {
        expect(
          PermissionMatcher.matches(
            'Bash(grep:*)',
            'Bash',
            BashToolInput(command: 'dart pub deps | grep uuid'),
          ),
          isTrue, // grep matches, dart pub deps is allowed as data source
        );
      },
    );

    test('does not match when cd goes outside working directory', () {
      expect(
        PermissionMatcher.matches(
          'Bash(dart pub:*)',
          'Bash',
          BashToolInput(command: 'cd /other && dart pub get'),
          context: {'cwd': '/project'},
        ),
        isFalse,
      );
    });

    test('matches when all commands in compound match', () {
      expect(
        PermissionMatcher.matches(
          'Bash(dart:*)',
          'Bash',
          BashToolInput(
            command: 'cd /project/sub && dart pub get && dart analyze',
          ),
          context: {'cwd': '/project'},
        ),
        isTrue,
      );
    });

    test('does not match when one command in compound does not match', () {
      expect(
        PermissionMatcher.matches(
          'Bash(dart pub:*)',
          'Bash',
          BashToolInput(
            command: 'cd /project/sub && dart pub get && serverpod generate',
          ),
          context: {'cwd': '/project'},
        ),
        isFalse, // serverpod generate doesn't match dart pub:*
      );
    });

    test('matches find command regardless of path', () {
      expect(
        PermissionMatcher.matches(
          'Bash(find:*)',
          'Bash',
          BashToolInput(command: 'find /any/path -name "*.dart"'),
        ),
        isTrue,
      );
    });

    test('matches serverpod command in compound', () {
      expect(
        PermissionMatcher.matches(
          'Bash(serverpod:*)',
          'Bash',
          BashToolInput(command: 'cd packages/server && serverpod generate'),
          context: {'cwd': '/project'},
        ),
        isTrue,
      );
    });

    test('auto-approves cd to subdirectory', () {
      expect(
        PermissionMatcher.matches(
          'Bash(serverpod:*)',
          'Bash',
          BashToolInput(command: 'cd packages/server && serverpod generate'),
          context: {'cwd': '/project'},
        ),
        isTrue,
      );
    });

    test('blocks cd outside working directory', () {
      expect(
        PermissionMatcher.matches(
          'Bash(serverpod:*)',
          'Bash',
          BashToolInput(command: 'cd /other/path && serverpod generate'),
          context: {'cwd': '/project'},
        ),
        isFalse,
      );
    });

    test('matches complex pipeline with safe filters', () {
      expect(
        PermissionMatcher.matches(
          'Bash(dart:*)',
          'Bash',
          BashToolInput(command: 'dart pub deps | grep uuid | wc -l'),
        ),
        isTrue, // dart pub deps matches, grep and wc are safe filters
      );
    });

    test('matches wildcard pattern', () {
      expect(
        PermissionMatcher.matches(
          'Bash(*)',
          'Bash',
          BashToolInput(command: 'cd /anywhere && any command | anything'),
        ),
        isTrue,
      );
    });

    test('handles empty command gracefully', () {
      expect(
        PermissionMatcher.matches(
          'Bash(dart:*)',
          'Bash',
          BashToolInput(command: ''),
        ),
        isFalse,
      );
    });

    test('handles command with only cd', () {
      expect(
        PermissionMatcher.matches(
          'Bash(cd:*)',
          'Bash',
          BashToolInput(command: 'cd /project/sub'),
          context: {'cwd': '/project'},
        ),
        isTrue,
      );
    });

    test(
      'matches cd-only command outside working directory if pattern allows',
      () {
        expect(
          PermissionMatcher.matches(
            'Bash(cd:*)',
            'Bash',
            BashToolInput(command: 'cd /other'),
            context: {'cwd': '/project'},
          ),
          isTrue, // cd /other matches cd:* pattern
        );
      },
    );

    test('handles quoted strings with operators', () {
      expect(
        PermissionMatcher.matches(
          'Bash(echo:*)',
          'Bash',
          BashToolInput(command: 'echo "foo && bar" && echo "baz"'),
        ),
        isTrue,
      );
    });

    test('matches relative cd paths', () {
      expect(
        PermissionMatcher.matches(
          'Bash(dart:*)',
          'Bash',
          BashToolInput(
            command: 'cd ./packages/server && dart analyze file.dart',
          ),
          context: {'cwd': '/project'},
        ),
        isTrue,
      );
    });
  });

  group('PermissionMatcher backward compatibility', () {
    test('matches simple command without context', () {
      expect(
        PermissionMatcher.matches(
          'Bash(dart pub:*)',
          'Bash',
          BashToolInput(command: 'dart pub get'),
        ),
        isTrue,
      );
    });

    test('matches regex pattern', () {
      expect(
        PermissionMatcher.matches(
          'Bash(dart (pub|test):*)',
          'Bash',
          BashToolInput(command: 'dart test'),
        ),
        isTrue,
      );
    });
  });
}
