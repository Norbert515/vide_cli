import 'package:agent_sdk/agent_sdk.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.now();

  AgentToolUseResponse _makeToolCall({
    required String toolName,
    required Map<String, dynamic> parameters,
    String? toolUseId,
  }) {
    return AgentToolUseResponse(
      id: 'id-${toolName.hashCode}',
      timestamp: now,
      toolName: toolName,
      parameters: parameters,
      toolUseId: toolUseId ?? 'tu-${toolName.hashCode}',
    );
  }

  group('AgentToolInvocation.createTyped', () {
    test('returns AgentWriteToolInvocation for Write tool', () {
      final toolCall = _makeToolCall(
        toolName: 'Write',
        parameters: {
          'file_path': '/tmp/test.dart',
          'content': 'void main() {}',
        },
      );

      final result = AgentToolInvocation.createTyped(toolCall: toolCall);

      expect(result, isA<AgentWriteToolInvocation>());
      final write = result as AgentWriteToolInvocation;
      expect(write.filePath, '/tmp/test.dart');
      expect(write.content, 'void main() {}');
    });

    test('returns AgentWriteToolInvocation for NotebookEdit tool', () {
      final toolCall = _makeToolCall(
        toolName: 'NotebookEdit',
        parameters: {
          'notebook_path': '/tmp/notebook.ipynb',
          'new_source': 'print("hello")',
        },
      );

      final result = AgentToolInvocation.createTyped(toolCall: toolCall);

      expect(result, isA<AgentWriteToolInvocation>());
      final write = result as AgentWriteToolInvocation;
      expect(write.filePath, '/tmp/notebook.ipynb');
      expect(write.content, 'print("hello")');
    });

    test('returns AgentEditToolInvocation for Edit tool', () {
      final toolCall = _makeToolCall(
        toolName: 'Edit',
        parameters: {
          'file_path': '/tmp/test.dart',
          'old_string': 'foo',
          'new_string': 'bar',
          'replace_all': true,
        },
      );

      final result = AgentToolInvocation.createTyped(toolCall: toolCall);

      expect(result, isA<AgentEditToolInvocation>());
      final edit = result as AgentEditToolInvocation;
      expect(edit.filePath, '/tmp/test.dart');
      expect(edit.oldString, 'foo');
      expect(edit.newString, 'bar');
      expect(edit.replaceAll, true);
    });

    test('returns AgentEditToolInvocation for MultiEdit tool', () {
      final toolCall = _makeToolCall(
        toolName: 'MultiEdit',
        parameters: {
          'file_path': '/tmp/test.dart',
          'old_string': 'a',
          'new_string': 'b',
        },
      );

      final result = AgentToolInvocation.createTyped(toolCall: toolCall);

      expect(result, isA<AgentEditToolInvocation>());
    });

    test('returns AgentFileOperationToolInvocation for Read tool', () {
      final toolCall = _makeToolCall(
        toolName: 'Read',
        parameters: {'file_path': '/tmp/test.dart'},
      );

      final result = AgentToolInvocation.createTyped(toolCall: toolCall);

      expect(result, isA<AgentFileOperationToolInvocation>());
      expect(result, isNot(isA<AgentWriteToolInvocation>()));
      expect(result, isNot(isA<AgentEditToolInvocation>()));
      final fileOp = result as AgentFileOperationToolInvocation;
      expect(fileOp.filePath, '/tmp/test.dart');
    });

    test('returns AgentFileOperationToolInvocation for Glob tool', () {
      final toolCall = _makeToolCall(
        toolName: 'Glob',
        parameters: {'pattern': '**/*.dart'},
      );

      final result = AgentToolInvocation.createTyped(toolCall: toolCall);

      expect(result, isA<AgentFileOperationToolInvocation>());
      final fileOp = result as AgentFileOperationToolInvocation;
      expect(fileOp.filePath, '**/*.dart');
    });

    test('returns AgentFileOperationToolInvocation for Grep tool', () {
      final toolCall = _makeToolCall(
        toolName: 'Grep',
        parameters: {'pattern': 'TODO'},
      );

      final result = AgentToolInvocation.createTyped(toolCall: toolCall);

      expect(result, isA<AgentFileOperationToolInvocation>());
    });

    test('returns base AgentToolInvocation for unknown tools', () {
      final toolCall = _makeToolCall(
        toolName: 'Bash',
        parameters: {'command': 'ls -la'},
      );

      final result = AgentToolInvocation.createTyped(toolCall: toolCall);

      expect(result, isA<AgentToolInvocation>());
      expect(result, isNot(isA<AgentFileOperationToolInvocation>()));
    });

    test('handles missing parameters gracefully', () {
      final toolCall = _makeToolCall(
        toolName: 'Write',
        parameters: {},
      );

      final result = AgentToolInvocation.createTyped(toolCall: toolCall);

      expect(result, isA<AgentWriteToolInvocation>());
      final write = result as AgentWriteToolInvocation;
      expect(write.filePath, '');
      expect(write.content, '');
    });

    test('case-insensitive tool name matching', () {
      final toolCall = _makeToolCall(
        toolName: 'WRITE',
        parameters: {'file_path': '/test', 'content': 'hello'},
      );

      final result = AgentToolInvocation.createTyped(toolCall: toolCall);
      expect(result, isA<AgentWriteToolInvocation>());
    });

    test('preserves toolResult', () {
      final toolCall = _makeToolCall(
        toolName: 'Write',
        parameters: {'file_path': '/test', 'content': 'hello'},
      );
      final toolResult = AgentToolResultResponse(
        id: 'r1',
        timestamp: now,
        toolUseId: 'tu-1',
        content: 'Success',
      );

      final result = AgentToolInvocation.createTyped(
        toolCall: toolCall,
        toolResult: toolResult,
      );

      expect(result.hasResult, true);
      expect(result.resultContent, 'Success');
    });
  });

  group('AgentWriteToolInvocation', () {
    test('getLineCount returns correct count', () {
      final toolCall = _makeToolCall(
        toolName: 'Write',
        parameters: {'file_path': '/test', 'content': 'line1\nline2\nline3'},
      );
      final invocation = AgentToolInvocation.createTyped(toolCall: toolCall)
          as AgentWriteToolInvocation;

      expect(invocation.getLineCount(), 3);
    });

    test('getLineCount returns 0 for empty content', () {
      final toolCall = _makeToolCall(
        toolName: 'Write',
        parameters: {'file_path': '/test', 'content': ''},
      );
      final invocation = AgentToolInvocation.createTyped(toolCall: toolCall)
          as AgentWriteToolInvocation;

      expect(invocation.getLineCount(), 0);
    });
  });

  group('AgentEditToolInvocation', () {
    test('hasChanges returns true when strings differ', () {
      final toolCall = _makeToolCall(
        toolName: 'Edit',
        parameters: {
          'file_path': '/test',
          'old_string': 'foo',
          'new_string': 'bar',
        },
      );
      final invocation = AgentToolInvocation.createTyped(toolCall: toolCall)
          as AgentEditToolInvocation;

      expect(invocation.hasChanges(), true);
    });

    test('hasChanges returns false when strings are same', () {
      final toolCall = _makeToolCall(
        toolName: 'Edit',
        parameters: {
          'file_path': '/test',
          'old_string': 'same',
          'new_string': 'same',
        },
      );
      final invocation = AgentToolInvocation.createTyped(toolCall: toolCall)
          as AgentEditToolInvocation;

      expect(invocation.hasChanges(), false);
    });

    test('getOldLineCount and getNewLineCount', () {
      final toolCall = _makeToolCall(
        toolName: 'Edit',
        parameters: {
          'file_path': '/test',
          'old_string': 'a\nb\nc',
          'new_string': 'x\ny',
        },
      );
      final invocation = AgentToolInvocation.createTyped(toolCall: toolCall)
          as AgentEditToolInvocation;

      expect(invocation.getOldLineCount(), 3);
      expect(invocation.getNewLineCount(), 2);
    });

    test('replaceAll defaults to false', () {
      final toolCall = _makeToolCall(
        toolName: 'Edit',
        parameters: {
          'file_path': '/test',
          'old_string': 'a',
          'new_string': 'b',
        },
      );
      final invocation = AgentToolInvocation.createTyped(toolCall: toolCall)
          as AgentEditToolInvocation;

      expect(invocation.replaceAll, false);
    });
  });

  group('AgentFileOperationToolInvocation', () {
    test('getRelativePath with working directory', () {
      final toolCall = _makeToolCall(
        toolName: 'Read',
        parameters: {'file_path': '/home/user/project/lib/main.dart'},
      );
      final invocation = AgentToolInvocation.createTyped(toolCall: toolCall)
          as AgentFileOperationToolInvocation;

      final relative = invocation.getRelativePath('/home/user/project');
      expect(relative, 'lib/main.dart');
    });

    test('getRelativePath returns absolute when shorter', () {
      final toolCall = _makeToolCall(
        toolName: 'Read',
        parameters: {'file_path': '/a'},
      );
      final invocation = AgentToolInvocation.createTyped(toolCall: toolCall)
          as AgentFileOperationToolInvocation;

      final relative = invocation.getRelativePath('/very/long/working/dir');
      // Should return whichever is shorter
      expect(relative.length <= '/a'.length || relative.contains('..'), true);
    });

    test('getRelativePath with empty working directory', () {
      final toolCall = _makeToolCall(
        toolName: 'Read',
        parameters: {'file_path': '/tmp/test.dart'},
      );
      final invocation = AgentToolInvocation.createTyped(toolCall: toolCall)
          as AgentFileOperationToolInvocation;

      expect(invocation.getRelativePath(''), '/tmp/test.dart');
    });
  });

  group('toolInvocations getter returns typed subclasses', () {
    test('Write tool invocation is typed', () {
      final message = AgentConversationMessage(
        id: 'msg-1',
        role: AgentMessageRole.assistant,
        content: '',
        timestamp: now,
        responses: [
          AgentToolUseResponse(
            id: 'r1',
            timestamp: now,
            toolName: 'Write',
            parameters: {
              'file_path': '/tmp/test.dart',
              'content': 'hello',
            },
            toolUseId: 'tu-1',
          ),
          AgentToolResultResponse(
            id: 'r2',
            timestamp: now,
            toolUseId: 'tu-1',
            content: 'Written',
          ),
        ],
      );

      final invocations = message.toolInvocations;
      expect(invocations.length, 1);
      expect(invocations.first, isA<AgentWriteToolInvocation>());
    });

    test('Edit tool invocation is typed', () {
      final message = AgentConversationMessage(
        id: 'msg-1',
        role: AgentMessageRole.assistant,
        content: '',
        timestamp: now,
        responses: [
          AgentToolUseResponse(
            id: 'r1',
            timestamp: now,
            toolName: 'Edit',
            parameters: {
              'file_path': '/tmp/test.dart',
              'old_string': 'foo',
              'new_string': 'bar',
            },
            toolUseId: 'tu-1',
          ),
          AgentToolResultResponse(
            id: 'r2',
            timestamp: now,
            toolUseId: 'tu-1',
            content: 'Edited',
          ),
        ],
      );

      final invocations = message.toolInvocations;
      expect(invocations.length, 1);
      expect(invocations.first, isA<AgentEditToolInvocation>());
    });

    test('Bash tool invocation remains base type', () {
      final message = AgentConversationMessage(
        id: 'msg-1',
        role: AgentMessageRole.assistant,
        content: '',
        timestamp: now,
        responses: [
          AgentToolUseResponse(
            id: 'r1',
            timestamp: now,
            toolName: 'Bash',
            parameters: {'command': 'ls'},
            toolUseId: 'tu-1',
          ),
          AgentToolResultResponse(
            id: 'r2',
            timestamp: now,
            toolUseId: 'tu-1',
            content: 'file1.dart',
          ),
        ],
      );

      final invocations = message.toolInvocations;
      expect(invocations.length, 1);
      expect(invocations.first, isNot(isA<AgentFileOperationToolInvocation>()));
    });
  });
}
