import 'package:claude_sdk/claude_sdk.dart';
import 'package:codex_sdk/codex_sdk.dart';
import 'package:test/test.dart';

void main() {
  late CodexEventMapper mapper;

  setUp(() {
    mapper = CodexEventMapper();
  });

  group('CodexEventMapper.mapEvent', () {
    group('thread.started', () {
      test('maps to MetaResponse with session_id', () {
        final event = ThreadStartedEvent(threadId: 'thread_abc');
        final responses = mapper.mapEvent(event);
        expect(responses, hasLength(1));
        expect(responses[0], isA<MetaResponse>());
        final meta = responses[0] as MetaResponse;
        expect(meta.id, 'thread_abc');
        expect(meta.metadata['session_id'], 'thread_abc');
      });
    });

    group('turn.started', () {
      test('maps to StatusResponse processing', () {
        const event = TurnStartedEvent();
        final responses = mapper.mapEvent(event);
        expect(responses, hasLength(1));
        expect(responses[0], isA<StatusResponse>());
        expect(
          (responses[0] as StatusResponse).status,
          ClaudeStatus.processing,
        );
      });
    });

    group('turn.completed', () {
      test('maps to CompletionResponse with usage', () {
        final event = TurnCompletedEvent(
          usage: CodexUsage(
            inputTokens: 100,
            cachedInputTokens: 50,
            outputTokens: 200,
          ),
        );
        final responses = mapper.mapEvent(event);
        expect(responses, hasLength(1));
        expect(responses[0], isA<CompletionResponse>());
        final completion = responses[0] as CompletionResponse;
        expect(completion.stopReason, 'completed');
        expect(completion.inputTokens, 100);
        expect(completion.outputTokens, 200);
        expect(completion.cacheReadInputTokens, 50);
      });

      test('maps to CompletionResponse without usage', () {
        const event = TurnCompletedEvent();
        final responses = mapper.mapEvent(event);
        expect(responses, hasLength(1));
        final completion = responses[0] as CompletionResponse;
        expect(completion.inputTokens, isNull);
        expect(completion.outputTokens, isNull);
      });
    });

    group('turn.failed', () {
      test('maps to ErrorResponse', () {
        const event = TurnFailedEvent(
          error: 'rate limit exceeded',
          details: {'code': 429},
        );
        final responses = mapper.mapEvent(event);
        expect(responses, hasLength(1));
        expect(responses[0], isA<ErrorResponse>());
        final error = responses[0] as ErrorResponse;
        expect(error.error, 'rate limit exceeded');
        expect(error.details, contains('429'));
      });

      test('uses fallback message when error is null', () {
        const event = TurnFailedEvent();
        final responses = mapper.mapEvent(event);
        expect(responses, hasLength(1));
        expect((responses[0] as ErrorResponse).error, 'Turn failed');
      });
    });

    group('error event', () {
      test('maps to ErrorResponse', () {
        const event = CodexErrorEvent(message: 'connection lost');
        final responses = mapper.mapEvent(event);
        expect(responses, hasLength(1));
        expect(responses[0], isA<ErrorResponse>());
        expect((responses[0] as ErrorResponse).error, 'connection lost');
      });
    });

    group('unknown event', () {
      test('maps to empty list', () {
        final event = UnknownCodexEvent({'type': 'future.thing'});
        final responses = mapper.mapEvent(event);
        expect(responses, isEmpty);
      });
    });

    group('agent_message item', () {
      test('maps completed event to TextResponse', () {
        const event = ItemEvent(
          eventType: 'item.completed',
          itemId: 'msg_001',
          itemType: 'agent_message',
          data: {'text': 'Hello world'},
        );
        final responses = mapper.mapEvent(event);
        expect(responses, hasLength(1));
        expect(responses[0], isA<TextResponse>());
        final text = responses[0] as TextResponse;
        expect(text.id, 'msg_001');
        expect(text.content, 'Hello world');
        expect(text.isCumulative, isTrue);
      });

      test('returns empty for non-completed event', () {
        const event = ItemEvent(
          eventType: 'item.started',
          itemId: 'msg_001',
          itemType: 'agent_message',
          data: {'text': ''},
        );
        expect(mapper.mapEvent(event), isEmpty);
      });

      test('returns empty for completed event with empty text', () {
        const event = ItemEvent(
          eventType: 'item.completed',
          itemId: 'msg_001',
          itemType: 'agent_message',
          data: {'text': ''},
        );
        expect(mapper.mapEvent(event), isEmpty);
      });

      test('returns empty for completed event with no text key', () {
        const event = ItemEvent(
          eventType: 'item.completed',
          itemId: 'msg_001',
          itemType: 'agent_message',
          data: {},
        );
        expect(mapper.mapEvent(event), isEmpty);
      });
    });

    group('command_execution item', () {
      test('maps started event to ToolUseResponse with Bash', () {
        const event = ItemEvent(
          eventType: 'item.started',
          itemId: 'cmd_001',
          itemType: 'command_execution',
          data: {'command': 'ls -la'},
        );
        final responses = mapper.mapEvent(event);
        expect(responses, hasLength(1));
        expect(responses[0], isA<ToolUseResponse>());
        final tool = responses[0] as ToolUseResponse;
        expect(tool.toolName, 'Bash');
        expect(tool.parameters['command'], 'ls -la');
        expect(tool.toolUseId, 'cmd_001');
      });

      test('maps completed event to ToolResultResponse', () {
        const event = ItemEvent(
          eventType: 'item.completed',
          itemId: 'cmd_001',
          itemType: 'command_execution',
          data: {
            'command': 'ls -la',
            'exit_code': 0,
            'aggregated_output': 'file1.dart\nfile2.dart',
          },
        );
        final responses = mapper.mapEvent(event);
        expect(responses, hasLength(1));
        expect(responses[0], isA<ToolResultResponse>());
        final result = responses[0] as ToolResultResponse;
        expect(result.toolUseId, 'cmd_001');
        expect(result.content, 'file1.dart\nfile2.dart');
        expect(result.isError, isFalse);
      });

      test('marks non-zero exit code as error', () {
        const event = ItemEvent(
          eventType: 'item.completed',
          itemId: 'cmd_001',
          itemType: 'command_execution',
          data: {'exit_code': 1, 'aggregated_output': 'command not found'},
        );
        final responses = mapper.mapEvent(event);
        expect((responses[0] as ToolResultResponse).isError, isTrue);
      });

      test('returns empty for updated event', () {
        const event = ItemEvent(
          eventType: 'item.updated',
          itemId: 'cmd_001',
          itemType: 'command_execution',
          data: {},
        );
        expect(mapper.mapEvent(event), isEmpty);
      });
    });

    group('file_change item', () {
      test('maps started event with changes to ToolUseResponse', () {
        const event = ItemEvent(
          eventType: 'item.started',
          itemId: 'file_001',
          itemType: 'file_change',
          data: {
            'changes': [
              {'path': 'lib/foo.dart', 'kind': 'add'},
            ],
          },
        );
        final responses = mapper.mapEvent(event);
        expect(responses, hasLength(1));
        expect(responses[0], isA<ToolUseResponse>());
        final tool = responses[0] as ToolUseResponse;
        expect(tool.toolName, 'Write');
        expect(tool.parameters['files'], ['lib/foo.dart']);
        expect(tool.parameters['kind'], 'add');
      });

      test('infers Edit tool for update kind', () {
        const event = ItemEvent(
          eventType: 'item.started',
          itemId: 'file_001',
          itemType: 'file_change',
          data: {
            'changes': [
              {'path': 'lib/foo.dart', 'kind': 'update'},
            ],
          },
        );
        final responses = mapper.mapEvent(event);
        expect((responses[0] as ToolUseResponse).toolName, 'Edit');
      });

      test('infers Write tool for delete kind', () {
        const event = ItemEvent(
          eventType: 'item.started',
          itemId: 'file_001',
          itemType: 'file_change',
          data: {
            'changes': [
              {'path': 'lib/old.dart', 'kind': 'delete'},
            ],
          },
        );
        final responses = mapper.mapEvent(event);
        expect((responses[0] as ToolUseResponse).toolName, 'Write');
      });

      test('maps completed event to summary ToolResultResponse', () {
        const event = ItemEvent(
          eventType: 'item.completed',
          itemId: 'file_001',
          itemType: 'file_change',
          data: {
            'changes': [
              {'path': 'lib/foo.dart', 'kind': 'add'},
              {'path': 'lib/bar.dart', 'kind': 'update'},
            ],
          },
        );
        final responses = mapper.mapEvent(event);
        expect(responses, hasLength(1));
        expect(responses[0], isA<ToolResultResponse>());
        final result = responses[0] as ToolResultResponse;
        expect(result.content, 'add: lib/foo.dart\nupdate: lib/bar.dart');
        expect(result.isError, isFalse);
      });

      test('handles started event with no changes', () {
        const event = ItemEvent(
          eventType: 'item.started',
          itemId: 'file_001',
          itemType: 'file_change',
          data: {},
        );
        final responses = mapper.mapEvent(event);
        expect(responses, hasLength(1));
        expect((responses[0] as ToolUseResponse).toolName, 'Write');
      });

      test('handles completed event with no changes', () {
        const event = ItemEvent(
          eventType: 'item.completed',
          itemId: 'file_001',
          itemType: 'file_change',
          data: {},
        );
        final responses = mapper.mapEvent(event);
        expect((responses[0] as ToolResultResponse).content, 'Done');
      });
    });

    group('mcp_tool_call item', () {
      test('maps started event to ToolUseResponse with server prefix', () {
        const event = ItemEvent(
          eventType: 'item.started',
          itemId: 'mcp_001',
          itemType: 'mcp_tool_call',
          data: {
            'server': 'vide-git',
            'tool': 'gitStatus',
            'arguments': {'detailed': true},
          },
        );
        final responses = mapper.mapEvent(event);
        expect(responses, hasLength(1));
        final tool = responses[0] as ToolUseResponse;
        expect(tool.toolName, 'mcp__vide-git__gitStatus');
        expect(tool.parameters['detailed'], true);
      });

      test('uses tool name alone when server is empty', () {
        const event = ItemEvent(
          eventType: 'item.started',
          itemId: 'mcp_001',
          itemType: 'mcp_tool_call',
          data: {'server': '', 'tool': 'someBuiltinTool', 'arguments': {}},
        );
        final responses = mapper.mapEvent(event);
        expect((responses[0] as ToolUseResponse).toolName, 'someBuiltinTool');
      });

      test('handles non-map arguments', () {
        const event = ItemEvent(
          eventType: 'item.started',
          itemId: 'mcp_001',
          itemType: 'mcp_tool_call',
          data: {'server': 'test', 'tool': 'myTool', 'arguments': 'not a map'},
        );
        final responses = mapper.mapEvent(event);
        expect((responses[0] as ToolUseResponse).parameters, isEmpty);
      });

      test('maps completed event with result to ToolResultResponse', () {
        const event = ItemEvent(
          eventType: 'item.completed',
          itemId: 'mcp_001',
          itemType: 'mcp_tool_call',
          data: {'result': 'some output'},
        );
        final responses = mapper.mapEvent(event);
        expect(responses, hasLength(1));
        final result = responses[0] as ToolResultResponse;
        expect(result.content, 'some output');
        expect(result.isError, isFalse);
      });

      test('maps completed event with content block array result', () {
        const event = ItemEvent(
          eventType: 'item.completed',
          itemId: 'mcp_001',
          itemType: 'mcp_tool_call',
          data: {
            'result': [
              {'type': 'text', 'text': 'line 1'},
              {'type': 'text', 'text': 'line 2'},
            ],
          },
        );
        final responses = mapper.mapEvent(event);
        final result = responses[0] as ToolResultResponse;
        expect(result.content, 'line 1\nline 2');
      });

      test('maps completed event with error', () {
        const event = ItemEvent(
          eventType: 'item.completed',
          itemId: 'mcp_001',
          itemType: 'mcp_tool_call',
          data: {'error': 'tool not found'},
        );
        final responses = mapper.mapEvent(event);
        final result = responses[0] as ToolResultResponse;
        expect(result.content, 'tool not found');
        expect(result.isError, isTrue);
      });

      test('maps completed event with structured error', () {
        const event = ItemEvent(
          eventType: 'item.completed',
          itemId: 'mcp_001',
          itemType: 'mcp_tool_call',
          data: {
            'error': {'message': 'permission denied', 'code': 403},
          },
        );
        final responses = mapper.mapEvent(event);
        final result = responses[0] as ToolResultResponse;
        expect(result.content, 'permission denied');
        expect(result.isError, isTrue);
      });

      test('returns empty for updated event', () {
        const event = ItemEvent(
          eventType: 'item.updated',
          itemId: 'mcp_001',
          itemType: 'mcp_tool_call',
          data: {},
        );
        expect(mapper.mapEvent(event), isEmpty);
      });
    });

    group('reasoning item', () {
      test('maps completed event to TextResponse', () {
        const event = ItemEvent(
          eventType: 'item.completed',
          itemId: 'reason_001',
          itemType: 'reasoning',
          data: {'text': 'Let me think about this...'},
        );
        final responses = mapper.mapEvent(event);
        expect(responses, hasLength(1));
        final text = responses[0] as TextResponse;
        expect(text.content, 'Let me think about this...');
        expect(text.isCumulative, isTrue);
      });

      test('falls back to summary field', () {
        const event = ItemEvent(
          eventType: 'item.completed',
          itemId: 'reason_001',
          itemType: 'reasoning',
          data: {'summary': 'Thinking summary'},
        );
        final responses = mapper.mapEvent(event);
        expect((responses[0] as TextResponse).content, 'Thinking summary');
      });

      test('returns empty for non-completed event', () {
        const event = ItemEvent(
          eventType: 'item.started',
          itemId: 'reason_001',
          itemType: 'reasoning',
          data: {},
        );
        expect(mapper.mapEvent(event), isEmpty);
      });

      test('returns empty for empty text', () {
        const event = ItemEvent(
          eventType: 'item.completed',
          itemId: 'reason_001',
          itemType: 'reasoning',
          data: {'text': ''},
        );
        expect(mapper.mapEvent(event), isEmpty);
      });
    });

    group('web_search item', () {
      test('maps started event to WebSearch ToolUseResponse', () {
        const event = ItemEvent(
          eventType: 'item.started',
          itemId: 'search_001',
          itemType: 'web_search',
          data: {'query': 'dart async patterns'},
        );
        final responses = mapper.mapEvent(event);
        expect(responses, hasLength(1));
        final tool = responses[0] as ToolUseResponse;
        expect(tool.toolName, 'WebSearch');
        expect(tool.parameters['query'], 'dart async patterns');
      });

      test('maps completed event to ToolResultResponse', () {
        const event = ItemEvent(
          eventType: 'item.completed',
          itemId: 'search_001',
          itemType: 'web_search',
          data: {},
        );
        final responses = mapper.mapEvent(event);
        expect(responses, hasLength(1));
        final result = responses[0] as ToolResultResponse;
        expect(result.content, 'Search complete');
        expect(result.isError, isFalse);
      });

      test('returns empty for updated event', () {
        const event = ItemEvent(
          eventType: 'item.updated',
          itemId: 'search_001',
          itemType: 'web_search',
          data: {},
        );
        expect(mapper.mapEvent(event), isEmpty);
      });
    });

    group('todo_list item', () {
      test('maps completed event to checklist TextResponse', () {
        const event = ItemEvent(
          eventType: 'item.completed',
          itemId: 'todo_001',
          itemType: 'todo_list',
          data: {
            'items': [
              {'text': 'Write tests', 'completed': true},
              {'text': 'Fix bugs', 'completed': false},
              {'text': 'Deploy', 'completed': false},
            ],
          },
        );
        final responses = mapper.mapEvent(event);
        expect(responses, hasLength(1));
        final text = responses[0] as TextResponse;
        expect(text.content, '[x] Write tests\n[ ] Fix bugs\n[ ] Deploy');
        expect(text.isCumulative, isTrue);
      });

      test('maps updated event to checklist TextResponse', () {
        const event = ItemEvent(
          eventType: 'item.updated',
          itemId: 'todo_001',
          itemType: 'todo_list',
          data: {
            'items': [
              {'text': 'Write tests', 'completed': true},
            ],
          },
        );
        final responses = mapper.mapEvent(event);
        expect(responses, hasLength(1));
        expect((responses[0] as TextResponse).content, '[x] Write tests');
      });

      test('returns empty for started event', () {
        const event = ItemEvent(
          eventType: 'item.started',
          itemId: 'todo_001',
          itemType: 'todo_list',
          data: {'items': []},
        );
        expect(mapper.mapEvent(event), isEmpty);
      });

      test('returns empty for empty items list', () {
        const event = ItemEvent(
          eventType: 'item.completed',
          itemId: 'todo_001',
          itemType: 'todo_list',
          data: {'items': []},
        );
        expect(mapper.mapEvent(event), isEmpty);
      });
    });

    group('unknown item type', () {
      test('returns empty list', () {
        const event = ItemEvent(
          eventType: 'item.completed',
          itemId: 'x_001',
          itemType: 'unknown_future_type',
          data: {},
        );
        expect(mapper.mapEvent(event), isEmpty);
      });
    });
  });

  group('ID generation', () {
    test('generates unique IDs across events', () {
      final ids = <String>{};
      for (var i = 0; i < 5; i++) {
        const event = TurnStartedEvent();
        final responses = mapper.mapEvent(event);
        ids.add(responses[0].id);
      }
      expect(ids, hasLength(5));
    });
  });
}
