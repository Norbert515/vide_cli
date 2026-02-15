import 'package:claude_sdk/claude_sdk.dart';
import 'package:codex_sdk/codex_sdk.dart';
import 'package:test/test.dart';

void main() {
  late CodexEventMapper mapper;

  setUp(() {
    mapper = CodexEventMapper();
  });

  group('CodexEventMapper.mapEvent', () {
    group('thread/started', () {
      test('maps to MetaResponse with session_id', () {
        const event = ThreadStartedEvent(
          threadId: 'thread_abc',
          threadData: {},
        );
        final responses = mapper.mapEvent(event);
        expect(responses, hasLength(1));
        expect(responses[0], isA<MetaResponse>());
        final meta = responses[0] as MetaResponse;
        expect(meta.id, 'thread_abc');
        expect(meta.metadata['session_id'], 'thread_abc');
      });
    });

    group('turn/started', () {
      test('maps to StatusResponse processing', () {
        const event = TurnStartedEvent(turnId: '0', turnData: {});
        final responses = mapper.mapEvent(event);
        expect(responses, hasLength(1));
        expect(responses[0], isA<StatusResponse>());
        expect(
          (responses[0] as StatusResponse).status,
          ClaudeStatus.processing,
        );
      });
    });

    group('turn/completed', () {
      test('maps to CompletionResponse', () {
        const event = TurnCompletedEvent(
          turnId: '0',
          status: 'completed',
          turnData: {},
        );
        final responses = mapper.mapEvent(event);
        expect(responses, hasLength(1));
        expect(responses[0], isA<CompletionResponse>());
        final completion = responses[0] as CompletionResponse;
        expect(completion.stopReason, 'completed');
      });
    });

    group('task_complete', () {
      test('maps to CompletionResponse', () {
        const event = TaskCompleteEvent(
          lastAgentMessage: 'Done!',
          params: {},
        );
        final responses = mapper.mapEvent(event);
        expect(responses, hasLength(1));
        expect(responses[0], isA<CompletionResponse>());
        expect((responses[0] as CompletionResponse).stopReason, 'completed');
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
        const event = UnknownCodexEvent(method: 'future/thing', params: {});
        final responses = mapper.mapEvent(event);
        expect(responses, isEmpty);
      });
    });

    group('token usage', () {
      test('maps to CompletionResponse with usage data', () {
        final event = TokenUsageUpdatedEvent(
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
        expect(completion.stopReason, 'usage_update');
        expect(completion.inputTokens, 100);
        expect(completion.outputTokens, 200);
        expect(completion.cacheReadInputTokens, 50);
      });
    });

    group('agentMessage delta', () {
      test('maps to non-cumulative TextResponse', () {
        const event = AgentMessageDeltaEvent(
          itemId: 'msg_001',
          delta: 'Hello ',
        );
        final responses = mapper.mapEvent(event);
        expect(responses, hasLength(1));
        expect(responses[0], isA<TextResponse>());
        final text = responses[0] as TextResponse;
        expect(text.id, 'msg_001');
        expect(text.content, 'Hello ');
        expect(text.isCumulative, isFalse);
      });
    });

    group('agentMessage item completed', () {
      test('maps to cumulative TextResponse', () {
        const event = ItemCompletedEvent(
          itemId: 'msg_001',
          itemType: 'agentMessage',
          itemData: {'text': 'Hello world'},
        );
        final responses = mapper.mapEvent(event);
        expect(responses, hasLength(1));
        expect(responses[0], isA<TextResponse>());
        final text = responses[0] as TextResponse;
        expect(text.id, 'msg_001');
        expect(text.content, 'Hello world');
        expect(text.isCumulative, isTrue);
      });

      test('returns empty for empty text', () {
        const event = ItemCompletedEvent(
          itemId: 'msg_001',
          itemType: 'agentMessage',
          itemData: {'text': ''},
        );
        expect(mapper.mapEvent(event), isEmpty);
      });

      test('returns empty for no text key', () {
        const event = ItemCompletedEvent(
          itemId: 'msg_001',
          itemType: 'agentMessage',
          itemData: {},
        );
        expect(mapper.mapEvent(event), isEmpty);
      });
    });

    group('commandExecution item', () {
      test('maps started event to ToolUseResponse with Bash', () {
        const event = ItemStartedEvent(
          itemId: 'cmd_001',
          itemType: 'commandExecution',
          itemData: {'command': 'ls -la'},
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
        const event = ItemCompletedEvent(
          itemId: 'cmd_001',
          itemType: 'commandExecution',
          itemData: {
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
        const event = ItemCompletedEvent(
          itemId: 'cmd_001',
          itemType: 'commandExecution',
          itemData: {'exit_code': 1, 'aggregated_output': 'command not found'},
        );
        final responses = mapper.mapEvent(event);
        expect((responses[0] as ToolResultResponse).isError, isTrue);
      });

      test('falls back to output field when aggregated_output missing', () {
        const event = ItemCompletedEvent(
          itemId: 'cmd_001',
          itemType: 'commandExecution',
          itemData: {'exit_code': 0, 'output': 'fallback output'},
        );
        final responses = mapper.mapEvent(event);
        expect((responses[0] as ToolResultResponse).content, 'fallback output');
      });
    });

    group('fileChange item', () {
      test('maps started event with changes to ToolUseResponse', () {
        const event = ItemStartedEvent(
          itemId: 'file_001',
          itemType: 'fileChange',
          itemData: {
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
        const event = ItemStartedEvent(
          itemId: 'file_001',
          itemType: 'fileChange',
          itemData: {
            'changes': [
              {'path': 'lib/foo.dart', 'kind': 'update'},
            ],
          },
        );
        final responses = mapper.mapEvent(event);
        expect((responses[0] as ToolUseResponse).toolName, 'Edit');
      });

      test('maps completed event to summary ToolResultResponse', () {
        const event = ItemCompletedEvent(
          itemId: 'file_001',
          itemType: 'fileChange',
          itemData: {
            'changes': [
              {'path': 'lib/foo.dart', 'kind': 'add'},
              {'path': 'lib/bar.dart', 'kind': 'update'},
            ],
          },
        );
        final responses = mapper.mapEvent(event);
        expect(responses, hasLength(1));
        final result = responses[0] as ToolResultResponse;
        expect(result.content, 'add: lib/foo.dart\nupdate: lib/bar.dart');
        expect(result.isError, isFalse);
      });

      test('handles completed event with no changes', () {
        const event = ItemCompletedEvent(
          itemId: 'file_001',
          itemType: 'fileChange',
          itemData: {},
        );
        final responses = mapper.mapEvent(event);
        expect((responses[0] as ToolResultResponse).content, 'Done');
      });
    });

    group('mcpToolCall item', () {
      test('maps started event with server prefix', () {
        const event = ItemStartedEvent(
          itemId: 'mcp_001',
          itemType: 'mcpToolCall',
          itemData: {
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
        const event = ItemStartedEvent(
          itemId: 'mcp_001',
          itemType: 'mcpToolCall',
          itemData: {'server': '', 'tool': 'someBuiltinTool', 'arguments': {}},
        );
        final responses = mapper.mapEvent(event);
        expect((responses[0] as ToolUseResponse).toolName, 'someBuiltinTool');
      });

      test('handles non-map arguments', () {
        const event = ItemStartedEvent(
          itemId: 'mcp_001',
          itemType: 'mcpToolCall',
          itemData: {
            'server': 'test',
            'tool': 'myTool',
            'arguments': 'not a map',
          },
        );
        final responses = mapper.mapEvent(event);
        expect((responses[0] as ToolUseResponse).parameters, isEmpty);
      });

      test('maps completed event with string result', () {
        const event = ItemCompletedEvent(
          itemId: 'mcp_001',
          itemType: 'mcpToolCall',
          itemData: {'result': 'some output'},
        );
        final responses = mapper.mapEvent(event);
        final result = responses[0] as ToolResultResponse;
        expect(result.content, 'some output');
        expect(result.isError, isFalse);
      });

      test('maps completed event with content block array result', () {
        const event = ItemCompletedEvent(
          itemId: 'mcp_001',
          itemType: 'mcpToolCall',
          itemData: {
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
        const event = ItemCompletedEvent(
          itemId: 'mcp_001',
          itemType: 'mcpToolCall',
          itemData: {'error': 'tool not found'},
        );
        final responses = mapper.mapEvent(event);
        final result = responses[0] as ToolResultResponse;
        expect(result.content, 'tool not found');
        expect(result.isError, isTrue);
      });
    });

    group('reasoning item', () {
      test('maps completed event to TextResponse', () {
        const event = ItemCompletedEvent(
          itemId: 'reason_001',
          itemType: 'reasoning',
          itemData: {'text': 'Let me think...'},
        );
        final responses = mapper.mapEvent(event);
        expect(responses, hasLength(1));
        final text = responses[0] as TextResponse;
        expect(text.content, 'Let me think...');
        expect(text.isCumulative, isTrue);
      });

      test('falls back to summary field', () {
        const event = ItemCompletedEvent(
          itemId: 'reason_001',
          itemType: 'reasoning',
          itemData: {'summary': 'Thinking summary'},
        );
        final responses = mapper.mapEvent(event);
        expect((responses[0] as TextResponse).content, 'Thinking summary');
      });

      test('handles summary as list of content blocks', () {
        const event = ItemCompletedEvent(
          itemId: 'reason_001',
          itemType: 'reasoning',
          itemData: {
            'summary': [
              {'type': 'summary_text', 'text': 'Thinking about it'},
            ],
          },
        );
        final responses = mapper.mapEvent(event);
        expect(responses, hasLength(1));
        expect(
            (responses[0] as TextResponse).content, 'Thinking about it');
      });

      test('returns empty for empty text', () {
        const event = ItemCompletedEvent(
          itemId: 'reason_001',
          itemType: 'reasoning',
          itemData: {'text': ''},
        );
        expect(mapper.mapEvent(event), isEmpty);
      });
    });

    group('webSearch item', () {
      test('maps started event to WebSearch ToolUseResponse', () {
        const event = ItemStartedEvent(
          itemId: 'search_001',
          itemType: 'webSearch',
          itemData: {'query': 'dart async patterns'},
        );
        final responses = mapper.mapEvent(event);
        expect(responses, hasLength(1));
        final tool = responses[0] as ToolUseResponse;
        expect(tool.toolName, 'WebSearch');
        expect(tool.parameters['query'], 'dart async patterns');
      });

      test('maps completed event to ToolResultResponse', () {
        const event = ItemCompletedEvent(
          itemId: 'search_001',
          itemType: 'webSearch',
          itemData: {},
        );
        final responses = mapper.mapEvent(event);
        final result = responses[0] as ToolResultResponse;
        expect(result.content, 'Search complete');
        expect(result.isError, isFalse);
      });
    });

    group('todoList item', () {
      test('maps completed event to checklist TextResponse', () {
        const event = ItemCompletedEvent(
          itemId: 'todo_001',
          itemType: 'todoList',
          itemData: {
            'items': [
              {'text': 'Write tests', 'completed': true},
              {'text': 'Fix bugs', 'completed': false},
            ],
          },
        );
        final responses = mapper.mapEvent(event);
        expect(responses, hasLength(1));
        final text = responses[0] as TextResponse;
        expect(text.content, '[x] Write tests\n[ ] Fix bugs');
        expect(text.isCumulative, isTrue);
      });

      test('returns empty for empty items list', () {
        const event = ItemCompletedEvent(
          itemId: 'todo_001',
          itemType: 'todoList',
          itemData: {'items': []},
        );
        expect(mapper.mapEvent(event), isEmpty);
      });
    });

    group('unknown item type', () {
      test('returns empty list for started', () {
        const event = ItemStartedEvent(
          itemId: 'x_001',
          itemType: 'unknownFutureType',
          itemData: {},
        );
        expect(mapper.mapEvent(event), isEmpty);
      });

      test('returns empty list for completed', () {
        const event = ItemCompletedEvent(
          itemId: 'x_001',
          itemType: 'unknownFutureType',
          itemData: {},
        );
        expect(mapper.mapEvent(event), isEmpty);
      });
    });

    group('events that map to empty', () {
      test('ThreadNameUpdatedEvent maps to empty', () {
        const event = ThreadNameUpdatedEvent(threadId: 't', name: 'n');
        expect(mapper.mapEvent(event), isEmpty);
      });

      test('McpStartupCompleteEvent maps to empty', () {
        const event = McpStartupCompleteEvent();
        expect(mapper.mapEvent(event), isEmpty);
      });

      test('ReasoningSummaryDeltaEvent maps to empty', () {
        const event = ReasoningSummaryDeltaEvent(itemId: 'r', delta: 'x');
        expect(mapper.mapEvent(event), isEmpty);
      });

      test('CommandOutputDeltaEvent maps to empty', () {
        const event = CommandOutputDeltaEvent(itemId: 'c', delta: 'x');
        expect(mapper.mapEvent(event), isEmpty);
      });
    });
  });

  group('ID generation', () {
    test('generates unique IDs across events', () {
      final ids = <String>{};
      for (var i = 0; i < 5; i++) {
        const event = TurnStartedEvent(turnId: '0', turnData: {});
        final responses = mapper.mapEvent(event);
        ids.add(responses[0].id);
      }
      expect(ids, hasLength(5));
    });
  });
}
