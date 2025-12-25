import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';

void main() {
  group('PermissionMatcher - Bash patterns', () {
    test('matches exact bash command', () {
      expect(
        PermissionMatcher.matches('Bash(pwd)', 'Bash', {'command': 'pwd'}),
        isTrue,
      );
    });

    test('matches bash with wildcard prefix (dart pub:*)', () {
      expect(
        PermissionMatcher.matches('Bash(dart pub:*)', 'Bash', {
          'command': 'dart pub get',
        }),
        isTrue,
      );

      expect(
        PermissionMatcher.matches('Bash(dart pub:*)', 'Bash', {
          'command': 'dart pub upgrade',
        }),
        isTrue,
      );

      expect(
        PermissionMatcher.matches('Bash(dart pub:*)', 'Bash', {
          'command': 'dart run main.dart',
        }),
        isFalse,
      );
    });

    test('matches bash with wildcard suffix (dart run:*)', () {
      expect(
        PermissionMatcher.matches('Bash(dart run:*)', 'Bash', {
          'command': 'dart run main.dart',
        }),
        isTrue,
      );

      expect(
        PermissionMatcher.matches('Bash(dart run:*)', 'Bash', {
          'command': 'dart run bin/server.dart --port 8080',
        }),
        isTrue,
      );
    });

    test('matches complex bash command with spaces and special chars', () {
      expect(
        PermissionMatcher.matches(
          'Bash(head -5 /Users/norbertkozsir/.claude/projects/-Users-norbertkozsir-IdeaProjects-parott/05596612-32c4-4df9-b8d3-5bdf29e7b98b.jsonl | jq \'.\' 2>/dev/null)',
          'Bash',
          {
            'command':
                'head -5 /Users/norbertkozsir/.claude/projects/-Users-norbertkozsir-IdeaProjects-parott/05596612-32c4-4df9-b8d3-5bdf29e7b98b.jsonl | jq \'.\' 2>/dev/null',
          },
        ),
        isTrue,
      );
    });

    test('matches timeout command with escaped regex special chars', () {
      // For exact command matching, need to escape regex special chars or use wildcard
      expect(
        PermissionMatcher.matches(
          'Bash(timeout 10 dart run bin/debug_claude_stream\\.dart --json ".*")',
          'Bash',
          {
            'command':
                'timeout 10 dart run bin/debug_claude_stream.dart --json "What is 10 + 15?"',
          },
        ),
        isTrue,
      );
    });

    test('does not match different bash command', () {
      expect(
        PermissionMatcher.matches('Bash(ls:*)', 'Bash', {'command': 'pwd'}),
        isFalse,
      );
    });

    test('matches bash wildcard (*) for any command', () {
      expect(
        PermissionMatcher.matches('Bash(*)', 'Bash', {
          'command': 'any command here',
        }),
        isTrue,
      );
    });
  });

  group('PermissionMatcher - Read patterns', () {
    test('matches exact file path', () {
      expect(
        PermissionMatcher.matches(
          'Read(/Users/norbertkozsir/IdeaProjects/parott/lib/main.dart)',
          'Read',
          {
            'file_path':
                '/Users/norbertkozsir/IdeaProjects/parott/lib/main.dart',
          },
        ),
        isTrue,
      );
    });

    test('matches glob pattern with **', () {
      expect(
        PermissionMatcher.matches(
          'Read(/Users/norbertkozsir/IdeaProjects/dart_tui/lib/**)',
          'Read',
          {
            'file_path':
                '/Users/norbertkozsir/IdeaProjects/dart_tui/lib/main.dart',
          },
        ),
        isTrue,
      );

      expect(
        PermissionMatcher.matches(
          'Read(/Users/norbertkozsir/IdeaProjects/dart_tui/lib/**)',
          'Read',
          {
            'file_path':
                '/Users/norbertkozsir/IdeaProjects/dart_tui/lib/src/components/button.dart',
          },
        ),
        isTrue,
      );
    });

    test('matches glob pattern with double slash prefix', () {
      expect(
        PermissionMatcher.matches(
          'Read(//Users/norbertkozsir/IdeaProjects/nocterm/lib/**)',
          'Read',
          {
            'file_path':
                '//Users/norbertkozsir/IdeaProjects/nocterm/lib/main.dart',
          },
        ),
        isTrue,
      );
    });

    test('does not match files outside glob pattern', () {
      expect(
        PermissionMatcher.matches(
          'Read(/Users/norbertkozsir/IdeaProjects/dart_tui/lib/**)',
          'Read',
          {
            'file_path':
                '/Users/norbertkozsir/IdeaProjects/dart_tui/test/main_test.dart',
          },
        ),
        isFalse,
      );
    });

    test('matches specific subdirectory pattern', () {
      expect(
        PermissionMatcher.matches(
          'Read(/Users/norbertkozsir/IdeaProjects/dart_tui/lib/src/components/**)',
          'Read',
          {
            'file_path':
                '/Users/norbertkozsir/IdeaProjects/dart_tui/lib/src/components/button.dart',
          },
        ),
        isTrue,
      );

      expect(
        PermissionMatcher.matches(
          'Read(/Users/norbertkozsir/IdeaProjects/dart_tui/lib/src/components/**)',
          'Read',
          {
            'file_path':
                '/Users/norbertkozsir/IdeaProjects/dart_tui/lib/src/framework/widget.dart',
          },
        ),
        isFalse,
      );
    });

    test('matches parent and child directory patterns correctly', () {
      // Child pattern (more specific)
      expect(
        PermissionMatcher.matches(
          'Read(/Users/norbertkozsir/IdeaProjects/dart_tui/lib/src/**)',
          'Read',
          {
            'file_path':
                '/Users/norbertkozsir/IdeaProjects/dart_tui/lib/src/components/button.dart',
          },
        ),
        isTrue,
      );

      // Parent pattern (less specific)
      expect(
        PermissionMatcher.matches(
          'Read(/Users/norbertkozsir/IdeaProjects/dart_tui/lib/**)',
          'Read',
          {
            'file_path':
                '/Users/norbertkozsir/IdeaProjects/dart_tui/lib/src/components/button.dart',
          },
        ),
        isTrue,
      );
    });

    test('blocks path traversal attempts', () {
      expect(
        PermissionMatcher.matches(
          'Read(/Users/norbertkozsir/safe/**)',
          'Read',
          {'file_path': '/Users/norbertkozsir/safe/../sensitive/file.txt'},
        ),
        isFalse,
      );

      expect(
        PermissionMatcher.matches(
          'Read(/Users/norbertkozsir/safe/**)',
          'Read',
          {'file_path': '/Users/norbertkozsir/safe/../../etc/passwd'},
        ),
        isFalse,
      );
    });

    test('blocks encoded path traversal attempts', () {
      expect(
        PermissionMatcher.matches(
          'Read(/Users/norbertkozsir/safe/**)',
          'Read',
          {'file_path': '/Users/norbertkozsir/safe/%2e%2e/sensitive/file.txt'},
        ),
        isFalse,
      );
    });
  });

  group('PermissionMatcher - Write patterns', () {
    test('matches exact file path for Write', () {
      expect(
        PermissionMatcher.matches(
          'Write(/Users/norbertkozsir/IdeaProjects/parott/claude_api/lib/src/client/conversation_loader.dart)',
          'Write',
          {
            'file_path':
                '/Users/norbertkozsir/IdeaProjects/parott/claude_api/lib/src/client/conversation_loader.dart',
          },
        ),
        isTrue,
      );
    });

    test('does not match different file for exact Write pattern', () {
      expect(
        PermissionMatcher.matches(
          'Write(/Users/norbertkozsir/IdeaProjects/parott/claude_api/lib/src/client/conversation_loader.dart)',
          'Write',
          {
            'file_path':
                '/Users/norbertkozsir/IdeaProjects/parott/claude_api/lib/src/client/other_file.dart',
          },
        ),
        isFalse,
      );
    });

    test('matches Write with glob pattern', () {
      expect(
        PermissionMatcher.matches(
          'Write(/Users/norbertkozsir/IdeaProjects/parott/**)',
          'Write',
          {
            'file_path':
                '/Users/norbertkozsir/IdeaProjects/parott/lib/main.dart',
          },
        ),
        isTrue,
      );
    });
  });

  group('PermissionMatcher - Edit patterns', () {
    test('matches Edit with glob pattern', () {
      expect(
        PermissionMatcher.matches(
          'Edit(/Users/norbertkozsir/IdeaProjects/parott/**)',
          'Edit',
          {
            'file_path':
                '/Users/norbertkozsir/IdeaProjects/parott/lib/main.dart',
          },
        ),
        isTrue,
      );
    });

    test('blocks path traversal for Edit', () {
      expect(
        PermissionMatcher.matches(
          'Edit(/Users/norbertkozsir/safe/**)',
          'Edit',
          {'file_path': '/Users/norbertkozsir/safe/../sensitive/file.txt'},
        ),
        isFalse,
      );
    });
  });

  group('PermissionMatcher - WebFetch patterns', () {
    test('matches WebFetch by domain', () {
      expect(
        PermissionMatcher.matches('WebFetch(domain:pub.dev)', 'WebFetch', {
          'url': 'https://pub.dev/packages/flutter',
        }),
        isTrue,
      );

      expect(
        PermissionMatcher.matches('WebFetch(domain:github.com)', 'WebFetch', {
          'url': 'https://github.com/flutter/flutter',
        }),
        isTrue,
      );

      expect(
        PermissionMatcher.matches(
          'WebFetch(domain:docs.claude.com)',
          'WebFetch',
          {'url': 'https://docs.claude.com/en/api'},
        ),
        isTrue,
      );
    });

    test('matches WebFetch subdomains', () {
      expect(
        PermissionMatcher.matches('WebFetch(domain:github.com)', 'WebFetch', {
          'url': 'https://api.github.com/repos/flutter/flutter',
        }),
        isTrue,
      );

      expect(
        PermissionMatcher.matches('WebFetch(domain:github.com)', 'WebFetch', {
          'url':
              'https://raw.githubusercontent.com/flutter/flutter/main/README.md',
        }),
        isFalse, // githubusercontent.com is not a subdomain of github.com
      );
    });

    test('does not match WebFetch from different domain', () {
      expect(
        PermissionMatcher.matches('WebFetch(domain:pub.dev)', 'WebFetch', {
          'url': 'https://github.com/flutter/flutter',
        }),
        isFalse,
      );
    });

    test('matches WebFetch with wildcard', () {
      expect(
        PermissionMatcher.matches('WebFetch(*)', 'WebFetch', {
          'url': 'https://any-domain.com/path',
        }),
        isTrue,
      );
    });
  });

  group('PermissionMatcher - WebSearch patterns', () {
    test('matches WebSearch without arguments', () {
      expect(
        PermissionMatcher.matches('WebSearch', 'WebSearch', {
          'query': 'how to use flutter',
        }),
        isTrue,
      );
    });

    test('matches WebSearch with wildcard', () {
      expect(
        PermissionMatcher.matches('WebSearch(*)', 'WebSearch', {
          'query': 'any query here',
        }),
        isTrue,
      );
    });

    test('matches WebSearch with query pattern', () {
      expect(
        PermissionMatcher.matches('WebSearch(query:flutter.*)', 'WebSearch', {
          'query': 'flutter tutorial',
        }),
        isTrue,
      );

      expect(
        PermissionMatcher.matches('WebSearch(query:flutter.*)', 'WebSearch', {
          'query': 'dart tutorial',
        }),
        isFalse,
      );
    });
  });

  group('PermissionMatcher - MCP tool patterns', () {
    test('matches MCP tool without arguments', () {
      expect(
        PermissionMatcher.matches(
          'mcp__dart__dart_fix',
          'mcp__dart__dart_fix',
          {},
        ),
        isTrue,
      );

      expect(
        PermissionMatcher.matches(
          'mcp__dart__resolve_workspace_symbol',
          'mcp__dart__resolve_workspace_symbol',
          {'query': 'Widget'},
        ),
        isTrue,
      );

      expect(
        PermissionMatcher.matches(
          'mcp__dart__pub_dev_search',
          'mcp__dart__pub_dev_search',
          {'query': 'http'},
        ),
        isTrue,
      );
    });
  });

  group('PermissionMatcher - Tool name regex', () {
    test('matches exact tool name', () {
      expect(
        PermissionMatcher.matches('Read', 'Read', {'file_path': '/any/path'}),
        isTrue,
      );
    });

    test('does not match different tool name', () {
      expect(
        PermissionMatcher.matches('Read', 'Write', {'file_path': '/any/path'}),
        isFalse,
      );
    });

    test('matches tool name with regex pattern', () {
      expect(
        PermissionMatcher.matches('Read|Write', 'Read', {
          'file_path': '/any/path',
        }),
        isTrue,
      );

      expect(
        PermissionMatcher.matches('Read|Write', 'Write', {
          'file_path': '/any/path',
        }),
        isTrue,
      );

      expect(
        PermissionMatcher.matches('Read|Write', 'Edit', {
          'file_path': '/any/path',
        }),
        isFalse,
      );
    });
  });

  group('PermissionMatcher - Edge cases', () {
    test('handles missing tool input gracefully', () {
      expect(PermissionMatcher.matches('Bash(ls)', 'Bash', {}), isFalse);
    });

    test('handles null file_path', () {
      expect(
        PermissionMatcher.matches('Read(/path/**)', 'Read', {
          'file_path': null,
        }),
        isFalse,
      );
    });

    test('handles empty pattern arguments - only matches empty file_path', () {
      // Empty pattern () means empty string, not wildcard
      expect(
        PermissionMatcher.matches('Read()', 'Read', {'file_path': ''}),
        isTrue,
      );

      expect(
        PermissionMatcher.matches('Read()', 'Read', {'file_path': '/any/path'}),
        isFalse,
      );
    });

    test('matches tools without parentheses in pattern', () {
      expect(
        PermissionMatcher.matches('WebSearch', 'WebSearch', {'query': 'test'}),
        isTrue,
      );
    });
  });

  group('PermissionMatcher - Real-world allow list scenarios', () {
    test('allows multiple Read patterns from allow list', () {
      final allowPatterns = [
        'Read(/Users/norbertkozsir/IdeaProjects/dart_tui/lib/**)',
        'Read(/Users/norbertkozsir/IdeaProjects/dart_tui/lib/src/components/**)',
        'Read(/Users/norbertkozsir/IdeaProjects/nocterm/**)',
      ];

      // Should match first pattern
      final matched1 = allowPatterns.any(
        (pattern) => PermissionMatcher.matches(pattern, 'Read', {
          'file_path':
              '/Users/norbertkozsir/IdeaProjects/dart_tui/lib/main.dart',
        }),
      );
      expect(matched1, isTrue);

      // Should match second pattern (and also first)
      final matched2 = allowPatterns.any(
        (pattern) => PermissionMatcher.matches(pattern, 'Read', {
          'file_path':
              '/Users/norbertkozsir/IdeaProjects/dart_tui/lib/src/components/button.dart',
        }),
      );
      expect(matched2, isTrue);

      // Should match third pattern only
      final matched3 = allowPatterns.any(
        (pattern) => PermissionMatcher.matches(pattern, 'Read', {
          'file_path':
              '/Users/norbertkozsir/IdeaProjects/nocterm/lib/main.dart',
        }),
      );
      expect(matched3, isTrue);

      // Should not match any pattern
      final matched4 = allowPatterns.any(
        (pattern) => PermissionMatcher.matches(pattern, 'Read', {
          'file_path':
              '/Users/norbertkozsir/IdeaProjects/other_project/lib/main.dart',
        }),
      );
      expect(matched4, isFalse);
    });

    test('allows multiple Bash patterns from allow list', () {
      final allowPatterns = [
        'Bash(dart pub:*)',
        'Bash(dart run:*)',
        'Bash(dart test:*)',
        'Bash(pwd:*)',
        'Bash(ls:*)',
      ];

      expect(
        allowPatterns.any(
          (p) =>
              PermissionMatcher.matches(p, 'Bash', {'command': 'dart pub get'}),
        ),
        isTrue,
      );

      expect(
        allowPatterns.any(
          (p) => PermissionMatcher.matches(p, 'Bash', {
            'command': 'dart run main.dart',
          }),
        ),
        isTrue,
      );

      expect(
        allowPatterns.any(
          (p) => PermissionMatcher.matches(p, 'Bash', {'command': 'dart test'}),
        ),
        isTrue,
      );

      expect(
        allowPatterns.any(
          (p) => PermissionMatcher.matches(p, 'Bash', {'command': 'rm -rf /'}),
        ),
        isFalse,
      );
    });

    test('allows multiple WebFetch domains from allow list', () {
      final allowPatterns = [
        'WebFetch(domain:pub.dev)',
        'WebFetch(domain:github.com)',
        'WebFetch(domain:raw.githubusercontent.com)',
        'WebFetch(domain:docs.claude.com)',
        'WebFetch(domain:docs.anthropic.com)',
      ];

      expect(
        allowPatterns.any(
          (p) => PermissionMatcher.matches(p, 'WebFetch', {
            'url': 'https://pub.dev/packages/flutter',
          }),
        ),
        isTrue,
      );

      expect(
        allowPatterns.any(
          (p) => PermissionMatcher.matches(p, 'WebFetch', {
            'url': 'https://github.com/flutter/flutter',
          }),
        ),
        isTrue,
      );

      expect(
        allowPatterns.any(
          (p) => PermissionMatcher.matches(p, 'WebFetch', {
            'url':
                'https://raw.githubusercontent.com/flutter/flutter/main/README.md',
          }),
        ),
        isTrue,
      );

      expect(
        allowPatterns.any(
          (p) => PermissionMatcher.matches(p, 'WebFetch', {
            'url': 'https://malicious-site.com',
          }),
        ),
        isFalse,
      );
    });
  });
}
