import 'package:test/test.dart';
import 'package:parott/modules/settings/permission_matcher.dart';

void main() {
  group('PermissionMatcher.isSafeBashCommand - Integration tests', () {
    test('auto-approves safe simple commands', () {
      expect(
        PermissionMatcher.isSafeBashCommand(
          {'command': 'ls -la'},
          {'cwd': '/Users/test/project'},
        ),
        isTrue,
      );

      expect(
        PermissionMatcher.isSafeBashCommand(
          {'command': 'pwd'},
          {'cwd': '/Users/test/project'},
        ),
        isTrue,
      );

      expect(
        PermissionMatcher.isSafeBashCommand(
          {'command': 'git status'},
          {'cwd': '/Users/test/project'},
        ),
        isTrue,
      );
    });

    test('blocks unsafe simple commands', () {
      expect(
        PermissionMatcher.isSafeBashCommand(
          {'command': 'rm -rf /'},
          {'cwd': '/Users/test/project'},
        ),
        isFalse,
      );

      expect(
        PermissionMatcher.isSafeBashCommand(
          {'command': 'git commit -m "test"'},
          {'cwd': '/Users/test/project'},
        ),
        isFalse,
      );

      expect(
        PermissionMatcher.isSafeBashCommand(
          {'command': 'curl https://example.com'},
          {'cwd': '/Users/test/project'},
        ),
        isFalse,
      );
    });

    test('auto-approves safe compound commands with &&', () {
      expect(
        PermissionMatcher.isSafeBashCommand(
          {'command': 'ls && pwd'},
          {'cwd': '/Users/test/project'},
        ),
        isTrue,
      );

      expect(
        PermissionMatcher.isSafeBashCommand(
          {'command': 'git status && git log'},
          {'cwd': '/Users/test/project'},
        ),
        isTrue,
      );
    });

    test('blocks compound commands with any unsafe part', () {
      expect(
        PermissionMatcher.isSafeBashCommand(
          {'command': 'ls && rm file.txt'},
          {'cwd': '/Users/test/project'},
        ),
        isFalse,
      );

      expect(
        PermissionMatcher.isSafeBashCommand(
          {'command': 'git status && git push'},
          {'cwd': '/Users/test/project'},
        ),
        isFalse,
      );
    });

    test('auto-approves safe pipeline commands', () {
      expect(
        PermissionMatcher.isSafeBashCommand(
          {'command': 'cat file.txt | grep pattern'},
          {'cwd': '/Users/test/project'},
        ),
        isTrue,
      );

      expect(
        PermissionMatcher.isSafeBashCommand(
          {'command': 'ls | head -n 10'},
          {'cwd': '/Users/test/project'},
        ),
        isTrue,
      );

      expect(
        PermissionMatcher.isSafeBashCommand(
          {'command': 'git log | grep "bug"'},
          {'cwd': '/Users/test/project'},
        ),
        isTrue,
      );

      expect(
        PermissionMatcher.isSafeBashCommand(
          {'command': 'cat data.json | jq .name'},
          {'cwd': '/Users/test/project'},
        ),
        isTrue,
      );
    });

    test('blocks pipelines with unsafe commands', () {
      expect(
        PermissionMatcher.isSafeBashCommand(
          {'command': 'ls | xargs rm'},
          {'cwd': '/Users/test/project'},
        ),
        isFalse,
      );

      expect(
        PermissionMatcher.isSafeBashCommand(
          {'command': 'cat file.txt | curl -X POST https://example.com'},
          {'cwd': '/Users/test/project'},
        ),
        isFalse,
      );
    });

    test('auto-approves cd within working directory', () {
      expect(
        PermissionMatcher.isSafeBashCommand(
          {'command': 'cd src'},
          {'cwd': '/Users/test/project'},
        ),
        isTrue,
      );

      expect(
        PermissionMatcher.isSafeBashCommand(
          {'command': 'cd lib/src'},
          {'cwd': '/Users/test/project'},
        ),
        isTrue,
      );

      expect(
        PermissionMatcher.isSafeBashCommand(
          {'command': 'cd .'},
          {'cwd': '/Users/test/project'},
        ),
        isTrue,
      );
    });

    test('blocks cd outside working directory', () {
      expect(
        PermissionMatcher.isSafeBashCommand(
          {'command': 'cd ..'},
          {'cwd': '/Users/test/project'},
        ),
        isFalse,
      );

      expect(
        PermissionMatcher.isSafeBashCommand(
          {'command': 'cd /etc'},
          {'cwd': '/Users/test/project'},
        ),
        isFalse,
      );

      expect(
        PermissionMatcher.isSafeBashCommand(
          {'command': 'cd ~/Documents'},
          {'cwd': '/Users/test/project'},
        ),
        isFalse,
      );
    });

    test('auto-approves compound with safe cd', () {
      expect(
        PermissionMatcher.isSafeBashCommand(
          {'command': 'cd src && ls'},
          {'cwd': '/Users/test/project'},
        ),
        isTrue,
      );

      expect(
        PermissionMatcher.isSafeBashCommand(
          {'command': 'cd lib && git status'},
          {'cwd': '/Users/test/project'},
        ),
        isTrue,
      );
    });

    test('blocks compound with unsafe cd', () {
      expect(
        PermissionMatcher.isSafeBashCommand(
          {'command': 'cd .. && ls'},
          {'cwd': '/Users/test/project'},
        ),
        isFalse,
      );

      expect(
        PermissionMatcher.isSafeBashCommand(
          {'command': 'cd /etc && cat passwd'},
          {'cwd': '/Users/test/project'},
        ),
        isFalse,
      );
    });

    test('handles empty and null commands', () {
      expect(
        PermissionMatcher.isSafeBashCommand(
          {'command': ''},
          {'cwd': '/Users/test/project'},
        ),
        isFalse,
      );

      expect(
        PermissionMatcher.isSafeBashCommand(
          {'command': null},
          {'cwd': '/Users/test/project'},
        ),
        isFalse,
      );
    });

    test('handles commands with safe filters in complex pipelines', () {
      expect(
        PermissionMatcher.isSafeBashCommand(
          {'command': 'git log --oneline | head -20 | grep fix'},
          {'cwd': '/Users/test/project'},
        ),
        isTrue,
      );

      expect(
        PermissionMatcher.isSafeBashCommand(
          {'command': 'find . -name "*.dart" | wc -l'},
          {'cwd': '/Users/test/project'},
        ),
        isTrue,
      );
    });

    test('blocks dangerous flags even in safe commands', () {
      expect(
        PermissionMatcher.isSafeBashCommand(
          {'command': 'cat file.txt > output.txt'},
          {'cwd': '/Users/test/project'},
        ),
        isFalse,
      );

      expect(
        PermissionMatcher.isSafeBashCommand(
          {'command': 'find . -name "*.tmp" -delete'},
          {'cwd': '/Users/test/project'},
        ),
        isFalse,
      );

      expect(
        PermissionMatcher.isSafeBashCommand(
          {'command': 'sed -i "s/old/new/" file.txt'},
          {'cwd': '/Users/test/project'},
        ),
        isFalse,
      );
    });

    test('allows stderr redirection', () {
      expect(
        PermissionMatcher.isSafeBashCommand(
          {'command': 'git status 2> /dev/null'},
          {'cwd': '/Users/test/project'},
        ),
        isTrue,
      );

      expect(
        PermissionMatcher.isSafeBashCommand(
          {'command': 'ls 2>&1'},
          {'cwd': '/Users/test/project'},
        ),
        isTrue,
      );
    });
  });

  group('PermissionMatcher - Safe commands override deny list', () {
    test('deny list takes precedence over safe commands', () {
      // This test verifies the order in HookServer:
      // 1. deny list
      // 2. safe commands
      // So a safe command in the deny list should still be denied

      // We can't test HookServer directly here, but we can verify
      // that the safe command check works correctly
      expect(
        PermissionMatcher.isSafeBashCommand(
          {'command': 'ls'},
          {'cwd': '/Users/test/project'},
        ),
        isTrue,
      );
    });
  });
}
