import 'package:test/test.dart';
import 'package:claude_sdk/claude_sdk.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('ToolInvocation', () {
    group('constructor and basic properties', () {
      test('creates invocation with toolCall only', () {
        final toolCall = createToolUseResponse('Read', {
          'file_path': '/test.dart',
        });
        final invocation = ToolInvocation(toolCall: toolCall);

        expect(invocation.toolCall, equals(toolCall));
        expect(invocation.toolResult, isNull);
        expect(invocation.hasResult, isFalse);
        expect(invocation.isComplete, isFalse);
        expect(invocation.isError, isFalse);
        expect(invocation.isExpanded, isFalse);
        expect(invocation.sessionId, isNull);
      });

      test('creates invocation with toolCall and toolResult', () {
        final toolCall = createToolUseResponse('Read', {
          'file_path': '/test.dart',
        }, toolUseId: 'tool-123');
        final toolResult = createToolResultResponse(
          'tool-123',
          'file contents',
        );
        final invocation = ToolInvocation(
          toolCall: toolCall,
          toolResult: toolResult,
        );

        expect(invocation.toolCall, equals(toolCall));
        expect(invocation.toolResult, equals(toolResult));
        expect(invocation.hasResult, isTrue);
        expect(invocation.isComplete, isTrue);
        expect(invocation.isError, isFalse);
      });

      test('isError reflects toolResult error state', () {
        final toolCall = createToolUseResponse('Read', {
          'file_path': '/missing.dart',
        }, toolUseId: 'tool-456');
        final errorResult = createToolResultResponse(
          'tool-456',
          'File not found',
          isError: true,
        );
        final invocation = ToolInvocation(
          toolCall: toolCall,
          toolResult: errorResult,
        );

        expect(invocation.isError, isTrue);
      });

      test('toolName returns the tool name from toolCall', () {
        final toolCall = createToolUseResponse('Bash', {'command': 'ls'});
        final invocation = ToolInvocation(toolCall: toolCall);

        expect(invocation.toolName, equals('Bash'));
      });

      test('parameters returns parameters from toolCall', () {
        final params = {'command': 'git status', 'timeout': 30000};
        final toolCall = createToolUseResponse('Bash', params);
        final invocation = ToolInvocation(toolCall: toolCall);

        expect(invocation.parameters, equals(params));
      });

      test('resultContent returns content from toolResult', () {
        final toolCall = createToolUseResponse('Bash', {
          'command': 'echo hi',
        }, toolUseId: 'id1');
        final toolResult = createToolResultResponse('id1', 'hi\n');
        final invocation = ToolInvocation(
          toolCall: toolCall,
          toolResult: toolResult,
        );

        expect(invocation.resultContent, equals('hi\n'));
      });

      test('resultContent is null when no toolResult', () {
        final toolCall = createToolUseResponse('Bash', {'command': 'echo hi'});
        final invocation = ToolInvocation(toolCall: toolCall);

        expect(invocation.resultContent, isNull);
      });
    });

    group('displayName', () {
      test('returns tool name as-is for non-MCP tools', () {
        final toolCall = createToolUseResponse('Read', {});
        final invocation = ToolInvocation(toolCall: toolCall);

        expect(invocation.displayName, equals('Read'));
      });

      test('formats MCP tool names with server and tool name', () {
        final toolCall = createToolUseResponse('mcp__vide-git__gitStatus', {});
        final invocation = ToolInvocation(toolCall: toolCall);

        expect(invocation.displayName, equals('Vide Git: gitStatus'));
      });

      test('formats server name with dashes to title case', () {
        final toolCall = createToolUseResponse(
          'mcp__flutter-runtime__flutterStart',
          {},
        );
        final invocation = ToolInvocation(toolCall: toolCall);

        expect(invocation.displayName, equals('Flutter Runtime: flutterStart'));
      });

      test('handles spawnAgent like any other tool', () {
        final toolCall = createToolUseResponse('mcp__vide-agent__spawnAgent', {
          'agentType': 'implementation',
          'name': 'Bug Fix',
        });
        final invocation = ToolInvocation(toolCall: toolCall);

        expect(invocation.displayName, equals('Vide Agent: spawnAgent'));
      });

      test('handles malformed MCP tool names gracefully', () {
        final toolCall = createToolUseResponse('mcp__invalidname', {});
        final invocation = ToolInvocation(toolCall: toolCall);

        expect(invocation.displayName, equals('mcp__invalidname'));
      });
    });

    group('copyWith', () {
      test('creates copy with updated toolResult', () {
        final toolCall = createToolUseResponse('Read', {
          'file_path': '/test.dart',
        }, toolUseId: 'id1');
        final invocation = ToolInvocation(toolCall: toolCall);
        final toolResult = createToolResultResponse('id1', 'contents');

        final updated = invocation.copyWith(toolResult: toolResult);

        expect(updated.toolCall, equals(toolCall));
        expect(updated.toolResult, equals(toolResult));
        expect(updated.hasResult, isTrue);
      });

      test('creates copy with updated isExpanded', () {
        final toolCall = createToolUseResponse('Read', {});
        final invocation = ToolInvocation(
          toolCall: toolCall,
          isExpanded: false,
        );

        final updated = invocation.copyWith(isExpanded: true);

        expect(updated.isExpanded, isTrue);
      });

      test('preserves existing values when not specified', () {
        final toolCall = createToolUseResponse('Read', {}, toolUseId: 'id1');
        final toolResult = createToolResultResponse('id1', 'data');
        final invocation = ToolInvocation(
          toolCall: toolCall,
          toolResult: toolResult,
          isExpanded: true,
          sessionId: 'session-abc',
        );

        final updated = invocation.copyWith();

        expect(updated.toolCall, equals(toolCall));
        expect(updated.toolResult, equals(toolResult));
        expect(updated.isExpanded, isTrue);
        expect(updated.sessionId, equals('session-abc'));
      });
    });
  });

  group('ConversationMessage.createTypedInvocation', () {
    test('returns base ToolInvocation for spawnAgent (not special-cased)', () {
      final toolCall = createToolUseResponse('spawnAgent', {
        'agentType': 'contextCollection',
        'name': 'Researcher',
        'initialPrompt': 'Find auth patterns',
      });

      final invocation = ConversationMessage.createTypedInvocation(
        toolCall,
        null,
      );

      // spawnAgent is no longer special-cased - returns base ToolInvocation
      expect(invocation.runtimeType, equals(ToolInvocation));
    });

    test('returns WriteToolInvocation for Write tool', () {
      final toolCall = createToolUseResponse('Write', {
        'file_path': '/Users/test/file.dart',
        'content': 'void main() {}',
      });

      final invocation = ConversationMessage.createTypedInvocation(
        toolCall,
        null,
      );

      expect(invocation, isA<WriteToolInvocation>());
      final write = invocation as WriteToolInvocation;
      expect(write.filePath, equals('/Users/test/file.dart'));
      expect(write.content, equals('void main() {}'));
    });

    test('returns WriteToolInvocation for lowercase write', () {
      final toolCall = createToolUseResponse('write', {
        'file_path': '/test.txt',
        'content': 'hello',
      });

      final invocation = ConversationMessage.createTypedInvocation(
        toolCall,
        null,
      );

      expect(invocation, isA<WriteToolInvocation>());
    });

    test('returns EditToolInvocation for Edit tool', () {
      final toolCall = createToolUseResponse('Edit', {
        'file_path': '/test.dart',
        'old_string': 'oldCode',
        'new_string': 'newCode',
      });

      final invocation = ConversationMessage.createTypedInvocation(
        toolCall,
        null,
      );

      expect(invocation, isA<EditToolInvocation>());
      final edit = invocation as EditToolInvocation;
      expect(edit.filePath, equals('/test.dart'));
      expect(edit.oldString, equals('oldCode'));
      expect(edit.newString, equals('newCode'));
    });

    test('returns EditToolInvocation for lowercase edit', () {
      final toolCall = createToolUseResponse('edit', {
        'file_path': '/test.dart',
        'old_string': 'a',
        'new_string': 'b',
      });

      final invocation = ConversationMessage.createTypedInvocation(
        toolCall,
        null,
      );

      expect(invocation, isA<EditToolInvocation>());
    });

    test('returns EditToolInvocation for MultiEdit', () {
      final toolCall = createToolUseResponse('MultiEdit', {
        'file_path': '/test.dart',
        'old_string': 'x',
        'new_string': 'y',
        'replace_all': true,
      });

      final invocation = ConversationMessage.createTypedInvocation(
        toolCall,
        null,
      );

      expect(invocation, isA<EditToolInvocation>());
      final edit = invocation as EditToolInvocation;
      expect(edit.replaceAll, isTrue);
    });

    test('returns FileOperationToolInvocation for Read', () {
      final toolCall = createToolUseResponse('Read', {
        'file_path': '/Users/test/code.dart',
      });

      final invocation = ConversationMessage.createTypedInvocation(
        toolCall,
        null,
      );

      expect(invocation, isA<FileOperationToolInvocation>());
      final fileOp = invocation as FileOperationToolInvocation;
      expect(fileOp.filePath, equals('/Users/test/code.dart'));
    });

    test('returns FileOperationToolInvocation for Glob', () {
      final toolCall = createToolUseResponse('Glob', {'pattern': '**/*.dart'});

      final invocation = ConversationMessage.createTypedInvocation(
        toolCall,
        null,
      );

      expect(invocation, isA<FileOperationToolInvocation>());
    });

    test('returns FileOperationToolInvocation for Grep', () {
      final toolCall = createToolUseResponse('Grep', {
        'pattern': 'class.*Widget',
      });

      final invocation = ConversationMessage.createTypedInvocation(
        toolCall,
        null,
      );

      expect(invocation, isA<FileOperationToolInvocation>());
    });

    test('returns base ToolInvocation for unknown tools', () {
      final toolCall = createToolUseResponse('UnknownTool', {'foo': 'bar'});

      final invocation = ConversationMessage.createTypedInvocation(
        toolCall,
        null,
      );

      expect(invocation.runtimeType, equals(ToolInvocation));
    });

    test('returns base ToolInvocation for Bash', () {
      final toolCall = createToolUseResponse('Bash', {'command': 'ls -la'});

      final invocation = ConversationMessage.createTypedInvocation(
        toolCall,
        null,
      );

      expect(invocation.runtimeType, equals(ToolInvocation));
    });

    test('preserves sessionId and isExpanded', () {
      final toolCall = createToolUseResponse('Read', {
        'file_path': '/test.dart',
      });

      final invocation = ConversationMessage.createTypedInvocation(
        toolCall,
        null,
        sessionId: 'session-xyz',
        isExpanded: true,
      );

      expect(invocation.sessionId, equals('session-xyz'));
      expect(invocation.isExpanded, isTrue);
    });

    test('includes toolResult when provided', () {
      final toolCall = createToolUseResponse('Read', {
        'file_path': '/test.dart',
      }, toolUseId: 'id1');
      final toolResult = createToolResultResponse('id1', 'file content here');

      final invocation = ConversationMessage.createTypedInvocation(
        toolCall,
        toolResult,
      );

      expect(invocation.hasResult, isTrue);
      expect(invocation.resultContent, equals('file content here'));
    });
  });

  group('FileOperationToolInvocation', () {
    test('extracts file_path from parameters', () {
      final toolCall = createToolUseResponse('Read', {
        'file_path': '/Users/test/project/lib/main.dart',
      });
      final baseInvocation = ToolInvocation(toolCall: toolCall);

      final fileOp = FileOperationToolInvocation.fromToolInvocation(
        baseInvocation,
      );

      expect(fileOp.filePath, equals('/Users/test/project/lib/main.dart'));
    });

    test('handles missing file_path gracefully', () {
      final toolCall = createToolUseResponse('Glob', {'pattern': '*.dart'});
      final baseInvocation = ToolInvocation(toolCall: toolCall);

      final fileOp = FileOperationToolInvocation.fromToolInvocation(
        baseInvocation,
      );

      expect(fileOp.filePath, equals(''));
    });

    test('extracts pattern from parameters for Glob', () {
      final toolCall = createToolUseResponse('Glob', {
        'pattern': '**/*.dart',
        'path': '/Users/test/project',
      });
      final baseInvocation = ToolInvocation(toolCall: toolCall);

      final fileOp = FileOperationToolInvocation.fromToolInvocation(
        baseInvocation,
      );

      // pattern is accessible via parameters
      expect(fileOp.parameters['pattern'], equals('**/*.dart'));
    });

    test('extracts pattern from parameters for Grep', () {
      final toolCall = createToolUseResponse('Grep', {
        'pattern': 'TODO:',
        'path': '/src',
      });
      final baseInvocation = ToolInvocation(toolCall: toolCall);

      final fileOp = FileOperationToolInvocation.fromToolInvocation(
        baseInvocation,
      );

      expect(fileOp.parameters['pattern'], equals('TODO:'));
    });

    group('getRelativePath', () {
      test('returns relative path when shorter', () {
        final toolCall = createToolUseResponse('Read', {
          'file_path': '/Users/test/project/lib/main.dart',
        });
        final fileOp = FileOperationToolInvocation.fromToolInvocation(
          ToolInvocation(toolCall: toolCall),
        );

        final relative = fileOp.getRelativePath('/Users/test/project');

        expect(relative, equals('lib/main.dart'));
      });

      test('returns absolute path when relative is longer', () {
        final toolCall = createToolUseResponse('Read', {
          'file_path': '/a/b.dart',
        });
        final fileOp = FileOperationToolInvocation.fromToolInvocation(
          ToolInvocation(toolCall: toolCall),
        );

        // Working directory is far away, so relative path would be longer
        final relative = fileOp.getRelativePath(
          '/Users/very/long/path/to/somewhere/else',
        );

        expect(relative, equals('/a/b.dart'));
      });

      test('returns absolute path when workingDirectory is empty', () {
        final toolCall = createToolUseResponse('Read', {
          'file_path': '/Users/test/file.dart',
        });
        final fileOp = FileOperationToolInvocation.fromToolInvocation(
          ToolInvocation(toolCall: toolCall),
        );

        final relative = fileOp.getRelativePath('');

        expect(relative, equals('/Users/test/file.dart'));
      });

      test('handles same directory correctly', () {
        final toolCall = createToolUseResponse('Read', {
          'file_path': '/Users/test/project/file.dart',
        });
        final fileOp = FileOperationToolInvocation.fromToolInvocation(
          ToolInvocation(toolCall: toolCall),
        );

        final relative = fileOp.getRelativePath('/Users/test/project');

        expect(relative, equals('file.dart'));
      });
    });
  });

  group('WriteToolInvocation', () {
    test('extracts file_path from parameters', () {
      final toolCall = createToolUseResponse('Write', {
        'file_path': '/Users/test/new_file.dart',
        'content': 'void main() {}',
      });

      final write = WriteToolInvocation.fromToolInvocation(
        ToolInvocation(toolCall: toolCall),
      );

      expect(write.filePath, equals('/Users/test/new_file.dart'));
    });

    test('extracts content from parameters', () {
      final content = '''import 'package:test/test.dart';

void main() {
  test('example', () {
    expect(true, isTrue);
  });
}
''';
      final toolCall = createToolUseResponse('Write', {
        'file_path': '/test_file.dart',
        'content': content,
      });

      final write = WriteToolInvocation.fromToolInvocation(
        ToolInvocation(toolCall: toolCall),
      );

      expect(write.content, equals(content));
    });

    test('handles missing content gracefully', () {
      final toolCall = createToolUseResponse('Write', {
        'file_path': '/test.dart',
      });

      final write = WriteToolInvocation.fromToolInvocation(
        ToolInvocation(toolCall: toolCall),
      );

      expect(write.content, equals(''));
    });

    group('getLineCount', () {
      test('counts lines correctly for multi-line content', () {
        final toolCall = createToolUseResponse('Write', {
          'file_path': '/test.dart',
          'content': 'line1\nline2\nline3\nline4',
        });

        final write = WriteToolInvocation.fromToolInvocation(
          ToolInvocation(toolCall: toolCall),
        );

        expect(write.getLineCount(), equals(4));
      });

      test('counts single line correctly', () {
        final toolCall = createToolUseResponse('Write', {
          'file_path': '/test.dart',
          'content': 'single line content',
        });

        final write = WriteToolInvocation.fromToolInvocation(
          ToolInvocation(toolCall: toolCall),
        );

        expect(write.getLineCount(), equals(1));
      });

      test('returns 0 for empty content', () {
        final toolCall = createToolUseResponse('Write', {
          'file_path': '/test.dart',
          'content': '',
        });

        final write = WriteToolInvocation.fromToolInvocation(
          ToolInvocation(toolCall: toolCall),
        );

        expect(write.getLineCount(), equals(0));
      });

      test('handles trailing newline', () {
        final toolCall = createToolUseResponse('Write', {
          'file_path': '/test.dart',
          'content': 'line1\nline2\n',
        });

        final write = WriteToolInvocation.fromToolInvocation(
          ToolInvocation(toolCall: toolCall),
        );

        // 'line1\nline2\n'.split('\n') = ['line1', 'line2', ''] = 3 elements
        expect(write.getLineCount(), equals(3));
      });
    });
  });

  group('EditToolInvocation', () {
    test('extracts file_path from parameters', () {
      final toolCall = createToolUseResponse('Edit', {
        'file_path': '/Users/test/edit_me.dart',
        'old_string': 'old',
        'new_string': 'new',
      });

      final edit = EditToolInvocation.fromToolInvocation(
        ToolInvocation(toolCall: toolCall),
      );

      expect(edit.filePath, equals('/Users/test/edit_me.dart'));
    });

    test('extracts old_string from parameters', () {
      final toolCall = createToolUseResponse('Edit', {
        'file_path': '/test.dart',
        'old_string': 'const oldValue = 42;',
        'new_string': 'const newValue = 100;',
      });

      final edit = EditToolInvocation.fromToolInvocation(
        ToolInvocation(toolCall: toolCall),
      );

      expect(edit.oldString, equals('const oldValue = 42;'));
    });

    test('extracts new_string from parameters', () {
      final toolCall = createToolUseResponse('Edit', {
        'file_path': '/test.dart',
        'old_string': 'foo',
        'new_string': 'bar',
      });

      final edit = EditToolInvocation.fromToolInvocation(
        ToolInvocation(toolCall: toolCall),
      );

      expect(edit.newString, equals('bar'));
    });

    test('extracts replace_all flag', () {
      final toolCall = createToolUseResponse('Edit', {
        'file_path': '/test.dart',
        'old_string': 'var',
        'new_string': 'final',
        'replace_all': true,
      });

      final edit = EditToolInvocation.fromToolInvocation(
        ToolInvocation(toolCall: toolCall),
      );

      expect(edit.replaceAll, isTrue);
    });

    test('defaults replace_all to false', () {
      final toolCall = createToolUseResponse('Edit', {
        'file_path': '/test.dart',
        'old_string': 'a',
        'new_string': 'b',
      });

      final edit = EditToolInvocation.fromToolInvocation(
        ToolInvocation(toolCall: toolCall),
      );

      expect(edit.replaceAll, isFalse);
    });

    test('handles missing old_string gracefully', () {
      final toolCall = createToolUseResponse('Edit', {
        'file_path': '/test.dart',
        'new_string': 'new content',
      });

      final edit = EditToolInvocation.fromToolInvocation(
        ToolInvocation(toolCall: toolCall),
      );

      expect(edit.oldString, equals(''));
    });

    test('handles missing new_string gracefully', () {
      final toolCall = createToolUseResponse('Edit', {
        'file_path': '/test.dart',
        'old_string': 'old content',
      });

      final edit = EditToolInvocation.fromToolInvocation(
        ToolInvocation(toolCall: toolCall),
      );

      expect(edit.newString, equals(''));
    });

    group('hasChanges', () {
      test('returns true when old and new strings differ', () {
        final toolCall = createToolUseResponse('Edit', {
          'file_path': '/test.dart',
          'old_string': 'original',
          'new_string': 'modified',
        });

        final edit = EditToolInvocation.fromToolInvocation(
          ToolInvocation(toolCall: toolCall),
        );

        expect(edit.hasChanges(), isTrue);
      });

      test('returns false when old and new strings are identical', () {
        final toolCall = createToolUseResponse('Edit', {
          'file_path': '/test.dart',
          'old_string': 'same',
          'new_string': 'same',
        });

        final edit = EditToolInvocation.fromToolInvocation(
          ToolInvocation(toolCall: toolCall),
        );

        expect(edit.hasChanges(), isFalse);
      });

      test('returns false when both are empty', () {
        final toolCall = createToolUseResponse('Edit', {
          'file_path': '/test.dart',
          'old_string': '',
          'new_string': '',
        });

        final edit = EditToolInvocation.fromToolInvocation(
          ToolInvocation(toolCall: toolCall),
        );

        expect(edit.hasChanges(), isFalse);
      });

      test('returns true when adding content (empty old)', () {
        final toolCall = createToolUseResponse('Edit', {
          'file_path': '/test.dart',
          'old_string': '',
          'new_string': 'new content',
        });

        final edit = EditToolInvocation.fromToolInvocation(
          ToolInvocation(toolCall: toolCall),
        );

        expect(edit.hasChanges(), isTrue);
      });

      test('returns true when deleting content (empty new)', () {
        final toolCall = createToolUseResponse('Edit', {
          'file_path': '/test.dart',
          'old_string': 'content to delete',
          'new_string': '',
        });

        final edit = EditToolInvocation.fromToolInvocation(
          ToolInvocation(toolCall: toolCall),
        );

        expect(edit.hasChanges(), isTrue);
      });
    });

    group('getOldLineCount', () {
      test('counts lines in old string', () {
        final toolCall = createToolUseResponse('Edit', {
          'file_path': '/test.dart',
          'old_string': 'line1\nline2\nline3',
          'new_string': 'replacement',
        });

        final edit = EditToolInvocation.fromToolInvocation(
          ToolInvocation(toolCall: toolCall),
        );

        expect(edit.getOldLineCount(), equals(3));
      });

      test('returns 0 for empty old string', () {
        final toolCall = createToolUseResponse('Edit', {
          'file_path': '/test.dart',
          'old_string': '',
          'new_string': 'new',
        });

        final edit = EditToolInvocation.fromToolInvocation(
          ToolInvocation(toolCall: toolCall),
        );

        expect(edit.getOldLineCount(), equals(0));
      });

      test('returns 1 for single line', () {
        final toolCall = createToolUseResponse('Edit', {
          'file_path': '/test.dart',
          'old_string': 'single line',
          'new_string': 'replacement',
        });

        final edit = EditToolInvocation.fromToolInvocation(
          ToolInvocation(toolCall: toolCall),
        );

        expect(edit.getOldLineCount(), equals(1));
      });
    });

    group('getNewLineCount', () {
      test('counts lines in new string', () {
        final toolCall = createToolUseResponse('Edit', {
          'file_path': '/test.dart',
          'old_string': 'old',
          'new_string': 'new1\nnew2\nnew3\nnew4\nnew5',
        });

        final edit = EditToolInvocation.fromToolInvocation(
          ToolInvocation(toolCall: toolCall),
        );

        expect(edit.getNewLineCount(), equals(5));
      });

      test('returns 0 for empty new string', () {
        final toolCall = createToolUseResponse('Edit', {
          'file_path': '/test.dart',
          'old_string': 'to delete',
          'new_string': '',
        });

        final edit = EditToolInvocation.fromToolInvocation(
          ToolInvocation(toolCall: toolCall),
        );

        expect(edit.getNewLineCount(), equals(0));
      });

      test('returns 1 for single line', () {
        final toolCall = createToolUseResponse('Edit', {
          'file_path': '/test.dart',
          'old_string': 'old',
          'new_string': 'single line replacement',
        });

        final edit = EditToolInvocation.fromToolInvocation(
          ToolInvocation(toolCall: toolCall),
        );

        expect(edit.getNewLineCount(), equals(1));
      });
    });
  });
}
