import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';

void main() {
  group('PermissionMatcher - Bash patterns', () {
    test('matches exact bash command', () {
      expect(
        PermissionMatcher.matches(
          'Bash(pwd)',
          'Bash',
          BashToolInput(command: 'pwd'),
        ),
        isTrue,
      );
    });

    test('matches bash with wildcard prefix (dart pub:*)', () {
      expect(
        PermissionMatcher.matches(
          'Bash(dart pub:*)',
          'Bash',
          BashToolInput(command: 'dart pub get'),
        ),
        isTrue,
      );

      expect(
        PermissionMatcher.matches(
          'Bash(dart pub:*)',
          'Bash',
          BashToolInput(command: 'dart pub upgrade'),
        ),
        isTrue,
      );

      expect(
        PermissionMatcher.matches(
          'Bash(dart pub:*)',
          'Bash',
          BashToolInput(command: 'dart run main.dart'),
        ),
        isFalse,
      );
    });

    test('matches bash with wildcard suffix (dart run:*)', () {
      expect(
        PermissionMatcher.matches(
          'Bash(dart run:*)',
          'Bash',
          BashToolInput(command: 'dart run main.dart'),
        ),
        isTrue,
      );

      expect(
        PermissionMatcher.matches(
          'Bash(dart run:*)',
          'Bash',
          BashToolInput(command: 'dart run bin/server.dart --port 8080'),
        ),
        isTrue,
      );
    });

    test('matches complex bash command with spaces and special chars', () {
      expect(
        PermissionMatcher.matches(
          'Bash(head -5 /Users/norbertkozsir/.claude/projects/-Users-norbertkozsir-IdeaProjects-parott/05596612-32c4-4df9-b8d3-5bdf29e7b98b.jsonl | jq \'.\' 2>/dev/null)',
          'Bash',
          BashToolInput(
            command:
                'head -5 /Users/norbertkozsir/.claude/projects/-Users-norbertkozsir-IdeaProjects-parott/05596612-32c4-4df9-b8d3-5bdf29e7b98b.jsonl | jq \'.\' 2>/dev/null',
          ),
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
          BashToolInput(
            command:
                'timeout 10 dart run bin/debug_claude_stream.dart --json "What is 10 + 15?"',
          ),
        ),
        isTrue,
      );
    });

    test('does not match different bash command', () {
      expect(
        PermissionMatcher.matches(
          'Bash(ls:*)',
          'Bash',
          BashToolInput(command: 'pwd'),
        ),
        isFalse,
      );
    });

    test('matches bash wildcard (*) for any command', () {
      expect(
        PermissionMatcher.matches(
          'Bash(*)',
          'Bash',
          BashToolInput(command: 'any command here'),
        ),
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
          ReadToolInput(
            filePath: '/Users/norbertkozsir/IdeaProjects/parott/lib/main.dart',
          ),
        ),
        isTrue,
      );
    });

    test('matches glob pattern with **', () {
      expect(
        PermissionMatcher.matches(
          'Read(/Users/norbertkozsir/IdeaProjects/dart_tui/lib/**)',
          'Read',
          ReadToolInput(
            filePath:
                '/Users/norbertkozsir/IdeaProjects/dart_tui/lib/main.dart',
          ),
        ),
        isTrue,
      );

      expect(
        PermissionMatcher.matches(
          'Read(/Users/norbertkozsir/IdeaProjects/dart_tui/lib/**)',
          'Read',
          ReadToolInput(
            filePath:
                '/Users/norbertkozsir/IdeaProjects/dart_tui/lib/src/components/button.dart',
          ),
        ),
        isTrue,
      );
    });

    test('matches glob pattern with double slash prefix', () {
      expect(
        PermissionMatcher.matches(
          'Read(//Users/norbertkozsir/IdeaProjects/nocterm/lib/**)',
          'Read',
          ReadToolInput(
            filePath:
                '//Users/norbertkozsir/IdeaProjects/nocterm/lib/main.dart',
          ),
        ),
        isTrue,
      );
    });

    test('does not match files outside glob pattern', () {
      expect(
        PermissionMatcher.matches(
          'Read(/Users/norbertkozsir/IdeaProjects/dart_tui/lib/**)',
          'Read',
          ReadToolInput(
            filePath:
                '/Users/norbertkozsir/IdeaProjects/dart_tui/test/main_test.dart',
          ),
        ),
        isFalse,
      );
    });

    test('matches specific subdirectory pattern', () {
      expect(
        PermissionMatcher.matches(
          'Read(/Users/norbertkozsir/IdeaProjects/dart_tui/lib/src/components/**)',
          'Read',
          ReadToolInput(
            filePath:
                '/Users/norbertkozsir/IdeaProjects/dart_tui/lib/src/components/button.dart',
          ),
        ),
        isTrue,
      );

      expect(
        PermissionMatcher.matches(
          'Read(/Users/norbertkozsir/IdeaProjects/dart_tui/lib/src/components/**)',
          'Read',
          ReadToolInput(
            filePath:
                '/Users/norbertkozsir/IdeaProjects/dart_tui/lib/src/framework/widget.dart',
          ),
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
          ReadToolInput(
            filePath:
                '/Users/norbertkozsir/IdeaProjects/dart_tui/lib/src/components/button.dart',
          ),
        ),
        isTrue,
      );

      // Parent pattern (less specific)
      expect(
        PermissionMatcher.matches(
          'Read(/Users/norbertkozsir/IdeaProjects/dart_tui/lib/**)',
          'Read',
          ReadToolInput(
            filePath:
                '/Users/norbertkozsir/IdeaProjects/dart_tui/lib/src/components/button.dart',
          ),
        ),
        isTrue,
      );
    });

    test('blocks path traversal attempts', () {
      expect(
        PermissionMatcher.matches(
          'Read(/Users/norbertkozsir/safe/**)',
          'Read',
          ReadToolInput(
            filePath: '/Users/norbertkozsir/safe/../sensitive/file.txt',
          ),
        ),
        isFalse,
      );

      expect(
        PermissionMatcher.matches(
          'Read(/Users/norbertkozsir/safe/**)',
          'Read',
          ReadToolInput(filePath: '/Users/norbertkozsir/safe/../../etc/passwd'),
        ),
        isFalse,
      );
    });

    test('blocks encoded path traversal attempts', () {
      expect(
        PermissionMatcher.matches(
          'Read(/Users/norbertkozsir/safe/**)',
          'Read',
          ReadToolInput(
            filePath: '/Users/norbertkozsir/safe/%2e%2e/sensitive/file.txt',
          ),
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
          WriteToolInput(
            filePath:
                '/Users/norbertkozsir/IdeaProjects/parott/claude_api/lib/src/client/conversation_loader.dart',
            content: '',
          ),
        ),
        isTrue,
      );
    });

    test('does not match different file for exact Write pattern', () {
      expect(
        PermissionMatcher.matches(
          'Write(/Users/norbertkozsir/IdeaProjects/parott/claude_api/lib/src/client/conversation_loader.dart)',
          'Write',
          WriteToolInput(
            filePath:
                '/Users/norbertkozsir/IdeaProjects/parott/claude_api/lib/src/client/other_file.dart',
            content: '',
          ),
        ),
        isFalse,
      );
    });

    test('matches Write with glob pattern', () {
      expect(
        PermissionMatcher.matches(
          'Write(/Users/norbertkozsir/IdeaProjects/parott/**)',
          'Write',
          WriteToolInput(
            filePath: '/Users/norbertkozsir/IdeaProjects/parott/lib/main.dart',
            content: '',
          ),
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
          EditToolInput(
            filePath: '/Users/norbertkozsir/IdeaProjects/parott/lib/main.dart',
            oldString: '',
            newString: '',
          ),
        ),
        isTrue,
      );
    });

    test('blocks path traversal for Edit', () {
      expect(
        PermissionMatcher.matches(
          'Edit(/Users/norbertkozsir/safe/**)',
          'Edit',
          EditToolInput(
            filePath: '/Users/norbertkozsir/safe/../sensitive/file.txt',
            oldString: '',
            newString: '',
          ),
        ),
        isFalse,
      );
    });
  });

  group('PermissionMatcher - WebFetch patterns', () {
    test('matches WebFetch by domain', () {
      expect(
        PermissionMatcher.matches(
          'WebFetch(domain:pub.dev)',
          'WebFetch',
          WebFetchToolInput(url: 'https://pub.dev/packages/flutter'),
        ),
        isTrue,
      );

      expect(
        PermissionMatcher.matches(
          'WebFetch(domain:github.com)',
          'WebFetch',
          WebFetchToolInput(url: 'https://github.com/flutter/flutter'),
        ),
        isTrue,
      );

      expect(
        PermissionMatcher.matches(
          'WebFetch(domain:docs.claude.com)',
          'WebFetch',
          WebFetchToolInput(url: 'https://docs.claude.com/en/api'),
        ),
        isTrue,
      );
    });

    test('matches WebFetch subdomains', () {
      expect(
        PermissionMatcher.matches(
          'WebFetch(domain:github.com)',
          'WebFetch',
          WebFetchToolInput(
            url: 'https://api.github.com/repos/flutter/flutter',
          ),
        ),
        isTrue,
      );

      expect(
        PermissionMatcher.matches(
          'WebFetch(domain:github.com)',
          'WebFetch',
          WebFetchToolInput(
            url:
                'https://raw.githubusercontent.com/flutter/flutter/main/README.md',
          ),
        ),
        isFalse, // githubusercontent.com is not a subdomain of github.com
      );
    });

    test('does not match WebFetch from different domain', () {
      expect(
        PermissionMatcher.matches(
          'WebFetch(domain:pub.dev)',
          'WebFetch',
          WebFetchToolInput(url: 'https://github.com/flutter/flutter'),
        ),
        isFalse,
      );
    });

    test('matches WebFetch with wildcard', () {
      expect(
        PermissionMatcher.matches(
          'WebFetch(*)',
          'WebFetch',
          WebFetchToolInput(url: 'https://any-domain.com/path'),
        ),
        isTrue,
      );
    });
  });

  group('PermissionMatcher - WebSearch patterns', () {
    test('matches WebSearch without arguments', () {
      expect(
        PermissionMatcher.matches(
          'WebSearch',
          'WebSearch',
          WebSearchToolInput(query: 'how to use flutter'),
        ),
        isTrue,
      );
    });

    test('matches WebSearch with wildcard', () {
      expect(
        PermissionMatcher.matches(
          'WebSearch(*)',
          'WebSearch',
          WebSearchToolInput(query: 'any query here'),
        ),
        isTrue,
      );
    });

    test('matches WebSearch with query pattern', () {
      expect(
        PermissionMatcher.matches(
          'WebSearch(query:flutter.*)',
          'WebSearch',
          WebSearchToolInput(query: 'flutter tutorial'),
        ),
        isTrue,
      );

      expect(
        PermissionMatcher.matches(
          'WebSearch(query:flutter.*)',
          'WebSearch',
          WebSearchToolInput(query: 'dart tutorial'),
        ),
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
          UnknownToolInput(toolName: 'mcp__dart__dart_fix', raw: {}),
        ),
        isTrue,
      );

      expect(
        PermissionMatcher.matches(
          'mcp__dart__resolve_workspace_symbol',
          'mcp__dart__resolve_workspace_symbol',
          UnknownToolInput(
            toolName: 'mcp__dart__resolve_workspace_symbol',
            raw: {'query': 'Widget'},
          ),
        ),
        isTrue,
      );

      expect(
        PermissionMatcher.matches(
          'mcp__dart__pub_dev_search',
          'mcp__dart__pub_dev_search',
          UnknownToolInput(
            toolName: 'mcp__dart__pub_dev_search',
            raw: {'query': 'http'},
          ),
        ),
        isTrue,
      );
    });

    test('matches MCP server wildcard pattern (mcp__dart__.*)', () {
      // Pattern mcp__dart__.* should match all tools from dart MCP server
      expect(
        PermissionMatcher.matches(
          'mcp__dart__.*',
          'mcp__dart__dart_fix',
          UnknownToolInput(toolName: 'mcp__dart__dart_fix', raw: {}),
        ),
        isTrue,
      );

      expect(
        PermissionMatcher.matches(
          'mcp__dart__.*',
          'mcp__dart__pub_dev_search',
          UnknownToolInput(
            toolName: 'mcp__dart__pub_dev_search',
            raw: {'query': 'http'},
          ),
        ),
        isTrue,
      );
    });

    test('MCP server wildcard does not match tools from different server', () {
      // Pattern mcp__dart__.* should NOT match tools from vide-git server
      expect(
        PermissionMatcher.matches(
          'mcp__dart__.*',
          'mcp__vide-git__gitCommit',
          UnknownToolInput(
            toolName: 'mcp__vide-git__gitCommit',
            raw: {'message': 'test'},
          ),
        ),
        isFalse,
      );
    });

    test('matches vide-git MCP server wildcard pattern', () {
      // Pattern mcp__vide-git__.* should match all tools from vide-git server
      expect(
        PermissionMatcher.matches(
          'mcp__vide-git__.*',
          'mcp__vide-git__gitCommit',
          UnknownToolInput(
            toolName: 'mcp__vide-git__gitCommit',
            raw: {'message': 'test'},
          ),
        ),
        isTrue,
      );

      expect(
        PermissionMatcher.matches(
          'mcp__vide-git__.*',
          'mcp__vide-git__gitStatus',
          UnknownToolInput(toolName: 'mcp__vide-git__gitStatus', raw: {}),
        ),
        isTrue,
      );
    });
  });

  group('PermissionMatcher - Tool name regex', () {
    test('matches exact tool name', () {
      expect(
        PermissionMatcher.matches(
          'Read',
          'Read',
          ReadToolInput(filePath: '/any/path'),
        ),
        isTrue,
      );
    });

    test('does not match different tool name', () {
      expect(
        PermissionMatcher.matches(
          'Read',
          'Write',
          WriteToolInput(filePath: '/any/path', content: ''),
        ),
        isFalse,
      );
    });

    test('matches tool name with regex pattern', () {
      expect(
        PermissionMatcher.matches(
          'Read|Write',
          'Read',
          ReadToolInput(filePath: '/any/path'),
        ),
        isTrue,
      );

      expect(
        PermissionMatcher.matches(
          'Read|Write',
          'Write',
          WriteToolInput(filePath: '/any/path', content: ''),
        ),
        isTrue,
      );

      expect(
        PermissionMatcher.matches(
          'Read|Write',
          'Edit',
          EditToolInput(filePath: '/any/path', oldString: '', newString: ''),
        ),
        isFalse,
      );
    });
  });

  group('PermissionMatcher - Edge cases', () {
    test('handles missing tool input gracefully', () {
      expect(
        PermissionMatcher.matches(
          'Bash(ls)',
          'Bash',
          BashToolInput(command: ''),
        ),
        isFalse,
      );
    });

    test('handles empty file_path', () {
      expect(
        PermissionMatcher.matches(
          'Read(/path/**)',
          'Read',
          ReadToolInput(filePath: ''),
        ),
        isFalse,
      );
    });

    test('handles empty pattern arguments - empty filePath does not match', () {
      // Empty pattern () means empty string - but empty file paths are rejected for security
      expect(
        PermissionMatcher.matches(
          'Read()',
          'Read',
          ReadToolInput(filePath: ''),
        ),
        isFalse, // Empty file paths are rejected
      );

      expect(
        PermissionMatcher.matches(
          'Read()',
          'Read',
          ReadToolInput(filePath: '/any/path'),
        ),
        isFalse, // /any/path doesn't match empty pattern
      );
    });

    test('matches tools without parentheses in pattern', () {
      expect(
        PermissionMatcher.matches(
          'WebSearch',
          'WebSearch',
          WebSearchToolInput(query: 'test'),
        ),
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
        (pattern) => PermissionMatcher.matches(
          pattern,
          'Read',
          ReadToolInput(
            filePath:
                '/Users/norbertkozsir/IdeaProjects/dart_tui/lib/main.dart',
          ),
        ),
      );
      expect(matched1, isTrue);

      // Should match second pattern (and also first)
      final matched2 = allowPatterns.any(
        (pattern) => PermissionMatcher.matches(
          pattern,
          'Read',
          ReadToolInput(
            filePath:
                '/Users/norbertkozsir/IdeaProjects/dart_tui/lib/src/components/button.dart',
          ),
        ),
      );
      expect(matched2, isTrue);

      // Should match third pattern only
      final matched3 = allowPatterns.any(
        (pattern) => PermissionMatcher.matches(
          pattern,
          'Read',
          ReadToolInput(
            filePath: '/Users/norbertkozsir/IdeaProjects/nocterm/lib/main.dart',
          ),
        ),
      );
      expect(matched3, isTrue);

      // Should not match any pattern
      final matched4 = allowPatterns.any(
        (pattern) => PermissionMatcher.matches(
          pattern,
          'Read',
          ReadToolInput(
            filePath:
                '/Users/norbertkozsir/IdeaProjects/other_project/lib/main.dart',
          ),
        ),
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
          (p) => PermissionMatcher.matches(
            p,
            'Bash',
            BashToolInput(command: 'dart pub get'),
          ),
        ),
        isTrue,
      );

      expect(
        allowPatterns.any(
          (p) => PermissionMatcher.matches(
            p,
            'Bash',
            BashToolInput(command: 'dart run main.dart'),
          ),
        ),
        isTrue,
      );

      expect(
        allowPatterns.any(
          (p) => PermissionMatcher.matches(
            p,
            'Bash',
            BashToolInput(command: 'dart test'),
          ),
        ),
        isTrue,
      );

      expect(
        allowPatterns.any(
          (p) => PermissionMatcher.matches(
            p,
            'Bash',
            BashToolInput(command: 'rm -rf /'),
          ),
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
          (p) => PermissionMatcher.matches(
            p,
            'WebFetch',
            WebFetchToolInput(url: 'https://pub.dev/packages/flutter'),
          ),
        ),
        isTrue,
      );

      expect(
        allowPatterns.any(
          (p) => PermissionMatcher.matches(
            p,
            'WebFetch',
            WebFetchToolInput(url: 'https://github.com/flutter/flutter'),
          ),
        ),
        isTrue,
      );

      expect(
        allowPatterns.any(
          (p) => PermissionMatcher.matches(
            p,
            'WebFetch',
            WebFetchToolInput(
              url:
                  'https://raw.githubusercontent.com/flutter/flutter/main/README.md',
            ),
          ),
        ),
        isTrue,
      );

      expect(
        allowPatterns.any(
          (p) => PermissionMatcher.matches(
            p,
            'WebFetch',
            WebFetchToolInput(url: 'https://malicious-site.com'),
          ),
        ),
        isFalse,
      );
    });
  });
}
