import 'package:test/test.dart';
import 'package:claude_sdk/claude_sdk.dart';
import '../helpers/helpers.dart';

void main() {
  group('ClaudeResponse.fromJson', () {
    group('type routing', () {
      test('parses type=text as TextResponse', () {
        final json = {'type': 'text', 'content': 'Hello', 'id': '123'};
        final response = ClaudeResponse.fromJson(json);
        expect(response, isA<TextResponse>());
      });

      test('parses type=message as TextResponse', () {
        final json = {'type': 'message', 'content': 'Hello', 'id': '123'};
        final response = ClaudeResponse.fromJson(json);
        expect(response, isA<TextResponse>());
      });

      test('parses type=assistant with text content as TextResponse', () {
        final json = {
          'type': 'assistant',
          'message': {
            'id': 'msg_1',
            'role': 'assistant',
            'content': [
              {'type': 'text', 'text': 'Hello from assistant'}
            ]
          }
        };
        final response = ClaudeResponse.fromJson(json);
        expect(response, isA<TextResponse>());
        expect((response as TextResponse).content, 'Hello from assistant');
      });

      test('parses type=assistant with tool_use content as ToolUseResponse',
          () {
        final json = {
          'type': 'assistant',
          'message': {
            'id': 'msg_1',
            'role': 'assistant',
            'content': [
              {
                'type': 'tool_use',
                'id': 'tool_1',
                'name': 'Read',
                'input': {'file_path': '/test.txt'}
              }
            ]
          }
        };
        final response = ClaudeResponse.fromJson(json);
        expect(response, isA<ToolUseResponse>());
      });

      test('parses type=tool_use as ToolUseResponse', () {
        final json = {
          'type': 'tool_use',
          'name': 'Write',
          'input': {'file_path': '/out.txt', 'content': 'data'}
        };
        final response = ClaudeResponse.fromJson(json);
        expect(response, isA<ToolUseResponse>());
      });

      test('parses type=error as ErrorResponse', () {
        final json = {
          'type': 'error',
          'error': 'Failed',
          'details': 'More info'
        };
        final response = ClaudeResponse.fromJson(json);
        expect(response, isA<ErrorResponse>());
      });

      test('parses type=status as StatusResponse', () {
        final json = {'type': 'status', 'status': 'processing'};
        final response = ClaudeResponse.fromJson(json);
        expect(response, isA<StatusResponse>());
      });

      test('parses type=system subtype=init as MetaResponse', () {
        final json = {
          'type': 'system',
          'subtype': 'init',
          'conversation_id': 'conv_123'
        };
        final response = ClaudeResponse.fromJson(json);
        expect(response, isA<MetaResponse>());
      });

      test('parses type=system without init subtype as StatusResponse', () {
        final json = {'type': 'system', 'subtype': 'other', 'status': 'ready'};
        final response = ClaudeResponse.fromJson(json);
        expect(response, isA<StatusResponse>());
      });

      test('parses type=result as CompletionResponse', () {
        final json = {
          'type': 'result',
          'subtype': 'success',
          'usage': {'input_tokens': 100, 'output_tokens': 50}
        };
        final response = ClaudeResponse.fromJson(json);
        expect(response, isA<CompletionResponse>());
      });

      test('parses type=meta as MetaResponse', () {
        final json = {
          'type': 'meta',
          'conversation_id': 'conv_456',
          'metadata': {'key': 'value'}
        };
        final response = ClaudeResponse.fromJson(json);
        expect(response, isA<MetaResponse>());
      });

      test('parses type=completion as CompletionResponse', () {
        final json = {
          'type': 'completion',
          'stop_reason': 'end_turn',
          'usage': {'input_tokens': 200, 'output_tokens': 100}
        };
        final response = ClaudeResponse.fromJson(json);
        expect(response, isA<CompletionResponse>());
      });

      test('parses user message with tool_result as ToolResultResponse', () {
        final json = {
          'type': 'user',
          'message': {
            'role': 'user',
            'content': [
              {
                'type': 'tool_result',
                'tool_use_id': 'tool_123',
                'content': 'Result data'
              }
            ]
          }
        };
        final response = ClaudeResponse.fromJson(json);
        expect(response, isA<ToolResultResponse>());
      });

      test('parses unknown type as UnknownResponse', () {
        final json = {'type': 'future_type', 'data': 'something'};
        final response = ClaudeResponse.fromJson(json);
        expect(response, isA<UnknownResponse>());
        expect(response.rawData, json);
      });
    });
  });

  group('TextResponse', () {
    test('extracts content from content field', () {
      final json = {'type': 'text', 'content': 'Hello world'};
      final response = TextResponse.fromJson(json);
      expect(response.content, 'Hello world');
    });

    test('extracts content from text field', () {
      final json = {'type': 'text', 'text': 'Hello from text field'};
      final response = TextResponse.fromJson(json);
      expect(response.content, 'Hello from text field');
    });

    test('decodes HTML entities in content', () {
      final json = {
        'type': 'text',
        'content': 'a &lt; b &amp;&amp; c &gt; d'
      };
      final response = TextResponse.fromJson(json);
      expect(response.content, 'a < b && c > d');
    });

    test('decodes &quot; and &apos; entities', () {
      final json = {
        'type': 'text',
        'content': '&quot;hello&quot; &apos;world&apos;'
      };
      final response = TextResponse.fromJson(json);
      expect(response.content, '"hello" \'world\'');
    });

    test('handles partial responses', () {
      final json = {'type': 'text', 'content': 'Partial...', 'partial': true};
      final response = TextResponse.fromJson(json);
      expect(response.isPartial, true);
    });

    test('extracts role from json', () {
      final json = {'type': 'text', 'content': 'Hi', 'role': 'assistant'};
      final response = TextResponse.fromJson(json);
      expect(response.role, 'assistant');
    });

    test('preserves rawData', () {
      final json = {'type': 'text', 'content': 'Test', 'extra': 'field'};
      final response = TextResponse.fromJson(json);
      expect(response.rawData, json);
    });

    test('fromAssistantMessage extracts text from content array', () {
      final json = {
        'type': 'assistant',
        'message': {
          'id': 'msg_1',
          'role': 'assistant',
          'content': [
            {'type': 'text', 'text': 'First part'},
            {'type': 'text', 'text': ' second part'}
          ]
        }
      };
      final response = TextResponse.fromAssistantMessage(json);
      expect(response.content, 'First part second part');
    });

    test('fromAssistantMessage decodes HTML entities', () {
      final json = {
        'type': 'assistant',
        'message': {
          'id': 'msg_1',
          'content': [
            {'type': 'text', 'text': 'x &lt; y'}
          ]
        }
      };
      final response = TextResponse.fromAssistantMessage(json);
      expect(response.content, 'x < y');
    });

    test('fromAssistantMessage handles empty content', () {
      final json = {
        'type': 'assistant',
        'message': {'id': 'msg_1', 'content': []}
      };
      final response = TextResponse.fromAssistantMessage(json);
      expect(response.content, '');
    });

    test('fromAssistantMessage is never partial (contains cumulative content)',
        () {
      // fromAssistantMessage always contains CUMULATIVE content, not a delta
      // So it should never be marked as partial, regardless of stop_reason
      final json = {
        'type': 'assistant',
        'message': {
          'id': 'msg_1',
          'content': [
            {'type': 'text', 'text': 'Streaming...'}
          ],
          'stop_reason': null
        }
      };
      final response = TextResponse.fromAssistantMessage(json);
      expect(response.isPartial, false);
    });

    test('fromAssistantMessage not partial when stop_reason present', () {
      final json = {
        'type': 'assistant',
        'message': {
          'id': 'msg_1',
          'content': [
            {'type': 'text', 'text': 'Complete'}
          ],
          'stop_reason': 'end_turn'
        }
      };
      final response = TextResponse.fromAssistantMessage(json);
      expect(response.isPartial, false);
    });
  });

  group('ToolUseResponse', () {
    test('extracts tool name from name field', () {
      final json = <String, dynamic>{
        'type': 'tool_use',
        'name': 'Read',
        'input': <String, dynamic>{}
      };
      final response = ToolUseResponse.fromJson(json);
      expect(response.toolName, 'Read');
    });

    test('extracts tool name from tool_name field', () {
      final json = <String, dynamic>{
        'type': 'tool_use',
        'tool_name': 'Write',
        'parameters': <String, dynamic>{}
      };
      final response = ToolUseResponse.fromJson(json);
      expect(response.toolName, 'Write');
    });

    test('extracts parameters from input field', () {
      final json = <String, dynamic>{
        'type': 'tool_use',
        'name': 'Read',
        'input': <String, dynamic>{'file_path': '/test.txt', 'limit': 100}
      };
      final response = ToolUseResponse.fromJson(json);
      expect(response.parameters['file_path'], '/test.txt');
      expect(response.parameters['limit'], 100);
    });

    test('extracts parameters from parameters field', () {
      final json = <String, dynamic>{
        'type': 'tool_use',
        'name': 'Write',
        'parameters': <String, dynamic>{'file_path': '/out.txt'}
      };
      final response = ToolUseResponse.fromJson(json);
      expect(response.parameters['file_path'], '/out.txt');
    });

    test('extracts toolUseId', () {
      final json = <String, dynamic>{
        'type': 'tool_use',
        'name': 'Read',
        'input': <String, dynamic>{},
        'tool_use_id': 'tool_abc123'
      };
      final response = ToolUseResponse.fromJson(json);
      expect(response.toolUseId, 'tool_abc123');
    });

    test('decodes HTML entities in tool name', () {
      final json = <String, dynamic>{
        'type': 'tool_use',
        'name': 'mcp__test&amp;tool',
        'input': <String, dynamic>{}
      };
      final response = ToolUseResponse.fromJson(json);
      expect(response.toolName, 'mcp__test&tool');
    });

    test('decodes HTML entities in parameters', () {
      final json = <String, dynamic>{
        'type': 'tool_use',
        'name': 'Write',
        'input': <String, dynamic>{'content': 'a &lt; b'}
      };
      final response = ToolUseResponse.fromJson(json);
      expect(response.parameters['content'], 'a < b');
    });

    test('fromAssistantMessage extracts tool from content array', () {
      final json = {
        'type': 'assistant',
        'uuid': 'msg_123',
        'message': {
          'id': 'msg_123',
          'role': 'assistant',
          'content': [
            {
              'type': 'tool_use',
              'id': 'tool_456',
              'name': 'Bash',
              'input': {'command': 'ls -la'}
            }
          ]
        }
      };
      final response = ToolUseResponse.fromAssistantMessage(json);
      expect(response.toolName, 'Bash');
      expect(response.toolUseId, 'tool_456');
      expect(response.parameters['command'], 'ls -la');
    });

    test('fromAssistantMessage handles empty content', () {
      final json = {
        'type': 'assistant',
        'message': {'content': []}
      };
      final response = ToolUseResponse.fromAssistantMessage(json);
      expect(response.toolName, '');
      expect(response.parameters, isEmpty);
    });
  });

  group('ToolResultResponse', () {
    test('extracts tool_use_id from content', () {
      final json = {
        'type': 'user',
        'message': {
          'content': [
            {
              'type': 'tool_result',
              'tool_use_id': 'tool_xyz',
              'content': 'result'
            }
          ]
        }
      };
      final response = ToolResultResponse.fromJson(json);
      expect(response.toolUseId, 'tool_xyz');
    });

    test('extracts string content', () {
      final json = {
        'type': 'user',
        'message': {
          'content': [
            {
              'type': 'tool_result',
              'tool_use_id': 'tool_1',
              'content': 'Simple string result'
            }
          ]
        }
      };
      final response = ToolResultResponse.fromJson(json);
      expect(response.content, 'Simple string result');
    });

    test('extracts content from array format (MCP tools)', () {
      final json = {
        'type': 'user',
        'message': {
          'content': [
            {
              'type': 'tool_result',
              'tool_use_id': 'tool_1',
              'content': [
                {'type': 'text', 'text': 'First part'},
                {'type': 'text', 'text': ' second part'}
              ]
            }
          ]
        }
      };
      final response = ToolResultResponse.fromJson(json);
      expect(response.content, 'First part second part');
    });

    test('extracts is_error flag when true', () {
      final json = {
        'type': 'user',
        'message': {
          'content': [
            {
              'type': 'tool_result',
              'tool_use_id': 'tool_1',
              'content': 'Error occurred',
              'is_error': true
            }
          ]
        }
      };
      final response = ToolResultResponse.fromJson(json);
      expect(response.isError, true);
    });

    test('is_error defaults to false', () {
      final json = {
        'type': 'user',
        'message': {
          'content': [
            {
              'type': 'tool_result',
              'tool_use_id': 'tool_1',
              'content': 'OK'
            }
          ]
        }
      };
      final response = ToolResultResponse.fromJson(json);
      expect(response.isError, false);
    });

    test('decodes HTML entities in content', () {
      final json = {
        'type': 'user',
        'message': {
          'content': [
            {
              'type': 'tool_result',
              'tool_use_id': 'tool_1',
              'content': 'x &lt; y &amp;&amp; z &gt; w'
            }
          ]
        }
      };
      final response = ToolResultResponse.fromJson(json);
      expect(response.content, 'x < y && z > w');
    });

    test('handles empty content array', () {
      final json = {
        'type': 'user',
        'message': {
          'content': [
            {'type': 'tool_result', 'tool_use_id': 'tool_1', 'content': []}
          ]
        }
      };
      final response = ToolResultResponse.fromJson(json);
      expect(response.content, '');
    });
  });

  group('ErrorResponse', () {
    test('extracts error message', () {
      final json = {'type': 'error', 'error': 'Something went wrong'};
      final response = ErrorResponse.fromJson(json);
      expect(response.error, 'Something went wrong');
    });

    test('extracts error from message field', () {
      final json = {'type': 'error', 'message': 'Error via message field'};
      final response = ErrorResponse.fromJson(json);
      expect(response.error, 'Error via message field');
    });

    test('extracts details', () {
      final json = {
        'type': 'error',
        'error': 'Failed',
        'details': 'More information here'
      };
      final response = ErrorResponse.fromJson(json);
      expect(response.details, 'More information here');
    });

    test('extracts details from description field', () {
      final json = {
        'type': 'error',
        'error': 'Failed',
        'description': 'Description info'
      };
      final response = ErrorResponse.fromJson(json);
      expect(response.details, 'Description info');
    });

    test('extracts error code', () {
      final json = {'type': 'error', 'error': 'Failed', 'code': 'ERR_001'};
      final response = ErrorResponse.fromJson(json);
      expect(response.code, 'ERR_001');
    });

    test('defaults to Unknown error when no error field', () {
      final json = {'type': 'error'};
      final response = ErrorResponse.fromJson(json);
      expect(response.error, 'Unknown error');
    });
  });

  group('StatusResponse', () {
    test('parses ready status', () {
      final json = {'type': 'status', 'status': 'ready'};
      final response = StatusResponse.fromJson(json);
      expect(response.status, ClaudeStatus.ready);
    });

    test('parses processing status', () {
      final json = {'type': 'status', 'status': 'processing'};
      final response = StatusResponse.fromJson(json);
      expect(response.status, ClaudeStatus.processing);
    });

    test('parses thinking status', () {
      final json = {'type': 'status', 'status': 'thinking'};
      final response = StatusResponse.fromJson(json);
      expect(response.status, ClaudeStatus.thinking);
    });

    test('parses responding status', () {
      final json = {'type': 'status', 'status': 'responding'};
      final response = StatusResponse.fromJson(json);
      expect(response.status, ClaudeStatus.responding);
    });

    test('parses completed status', () {
      final json = {'type': 'status', 'status': 'completed'};
      final response = StatusResponse.fromJson(json);
      expect(response.status, ClaudeStatus.completed);
    });

    test('parses error status', () {
      final json = {'type': 'status', 'status': 'error'};
      final response = StatusResponse.fromJson(json);
      expect(response.status, ClaudeStatus.error);
    });

    test('parses unknown status', () {
      final json = {'type': 'status', 'status': 'future_status'};
      final response = StatusResponse.fromJson(json);
      expect(response.status, ClaudeStatus.unknown);
    });

    test('extracts message', () {
      final json = {
        'type': 'status',
        'status': 'processing',
        'message': 'Working on it'
      };
      final response = StatusResponse.fromJson(json);
      expect(response.message, 'Working on it');
    });

    test('handles missing status field', () {
      final json = {'type': 'status'};
      final response = StatusResponse.fromJson(json);
      expect(response.status, ClaudeStatus.unknown);
    });
  });

  group('MetaResponse', () {
    test('extracts conversation_id', () {
      final json = {
        'type': 'system',
        'subtype': 'init',
        'conversation_id': 'conv_abc123'
      };
      final response = MetaResponse.fromJson(json);
      expect(response.conversationId, 'conv_abc123');
    });

    test('extracts metadata', () {
      final json = {
        'type': 'meta',
        'metadata': {'version': '1.0', 'model': 'claude-3'}
      };
      final response = MetaResponse.fromJson(json);
      expect(response.metadata['version'], '1.0');
      expect(response.metadata['model'], 'claude-3');
    });

    test('uses full json as metadata when metadata field missing', () {
      final json = {
        'type': 'meta',
        'conversation_id': 'conv_1',
        'extra': 'data'
      };
      final response = MetaResponse.fromJson(json);
      expect(response.metadata['extra'], 'data');
    });
  });

  group('CompletionResponse', () {
    test('extracts stop_reason', () {
      final json = {'type': 'completion', 'stop_reason': 'end_turn'};
      final response = CompletionResponse.fromJson(json);
      expect(response.stopReason, 'end_turn');
    });

    test('extracts input_tokens from usage', () {
      final json = {
        'type': 'completion',
        'usage': {'input_tokens': 150, 'output_tokens': 75}
      };
      final response = CompletionResponse.fromJson(json);
      expect(response.inputTokens, 150);
    });

    test('extracts output_tokens from usage', () {
      final json = {
        'type': 'completion',
        'usage': {'input_tokens': 150, 'output_tokens': 75}
      };
      final response = CompletionResponse.fromJson(json);
      expect(response.outputTokens, 75);
    });

    test('handles missing usage', () {
      final json = {'type': 'completion', 'stop_reason': 'max_tokens'};
      final response = CompletionResponse.fromJson(json);
      expect(response.inputTokens, isNull);
      expect(response.outputTokens, isNull);
    });

    test('fromResultJson extracts success stop_reason', () {
      final json = {'type': 'result', 'subtype': 'success'};
      final response = CompletionResponse.fromResultJson(json);
      expect(response.stopReason, 'completed');
    });

    test('fromResultJson extracts error stop_reason', () {
      final json = {'type': 'result', 'subtype': 'error'};
      final response = CompletionResponse.fromResultJson(json);
      expect(response.stopReason, 'error');
    });

    test('fromResultJson extracts tokens from usage', () {
      final json = {
        'type': 'result',
        'subtype': 'success',
        'usage': {'input_tokens': 200, 'output_tokens': 100}
      };
      final response = CompletionResponse.fromResultJson(json);
      expect(response.inputTokens, 200);
      expect(response.outputTokens, 100);
    });
  });

  group('UnknownResponse', () {
    test('preserves rawData', () {
      final json = {'type': 'new_type', 'field1': 'value1', 'field2': 42};
      final response = UnknownResponse.fromJson(json);
      expect(response.rawData, json);
    });

    test('generates id when not provided', () {
      final json = {'type': 'unknown'};
      final response = UnknownResponse.fromJson(json);
      expect(response.id, isNotEmpty);
    });

    test('uses provided id', () {
      final json = {'type': 'unknown', 'id': 'custom_id_123'};
      final response = UnknownResponse.fromJson(json);
      expect(response.id, 'custom_id_123');
    });
  });

  group('ClaudeStatus enum', () {
    test('fromString parses all known values', () {
      expect(ClaudeStatus.fromString('ready'), ClaudeStatus.ready);
      expect(ClaudeStatus.fromString('processing'), ClaudeStatus.processing);
      expect(ClaudeStatus.fromString('thinking'), ClaudeStatus.thinking);
      expect(ClaudeStatus.fromString('responding'), ClaudeStatus.responding);
      expect(ClaudeStatus.fromString('completed'), ClaudeStatus.completed);
      expect(ClaudeStatus.fromString('error'), ClaudeStatus.error);
    });

    test('fromString is case insensitive', () {
      expect(ClaudeStatus.fromString('READY'), ClaudeStatus.ready);
      expect(ClaudeStatus.fromString('Processing'), ClaudeStatus.processing);
    });

    test('fromString returns unknown for unrecognized values', () {
      expect(ClaudeStatus.fromString('invalid'), ClaudeStatus.unknown);
      expect(ClaudeStatus.fromString(''), ClaudeStatus.unknown);
    });
  });

  group('Fixture loading', () {
    test('text_response.json parses correctly', () {
      final json = FixtureLoader.loadJson('responses/text_response.json');
      final response = ClaudeResponse.fromJson(json);
      expect(response, isA<TextResponse>());
      expect((response as TextResponse).content, 'Hello from Claude!');
    });

    test('tool_use_response.json parses correctly', () {
      final json = FixtureLoader.loadJson('responses/tool_use_response.json');
      final response = ClaudeResponse.fromJson(json);
      expect(response, isA<ToolUseResponse>());
      expect((response as ToolUseResponse).toolName, 'Read');
      expect(response.toolUseId, 'tool_test_789');
    });

    test('completion_response.json parses correctly', () {
      final json =
          FixtureLoader.loadJson('responses/completion_response.json');
      final response = ClaudeResponse.fromJson(json);
      expect(response, isA<CompletionResponse>());
      expect((response as CompletionResponse).inputTokens, 100);
      expect(response.outputTokens, 50);
    });

    test('error_response.json parses correctly', () {
      final json = FixtureLoader.loadJson('responses/error_response.json');
      final response = ClaudeResponse.fromJson(json);
      expect(response, isA<ErrorResponse>());
      expect((response as ErrorResponse).error, 'Something went wrong');
      expect(response.code, 'ERR_001');
    });

    test('tool_result_response.json parses correctly', () {
      final json =
          FixtureLoader.loadJson('responses/tool_result_response.json');
      final response = ClaudeResponse.fromJson(json);
      expect(response, isA<ToolResultResponse>());
      expect((response as ToolResultResponse).toolUseId, 'tool_test_789');
      expect(response.content, 'File contents here');
    });

    test('meta_response.json parses correctly', () {
      final json = FixtureLoader.loadJson('responses/meta_response.json');
      final response = ClaudeResponse.fromJson(json);
      expect(response, isA<MetaResponse>());
      expect((response as MetaResponse).conversationId, 'conv_test_123');
    });
  });

  group('FixtureLoader pre-built fixtures', () {
    test('textResponseJson matches expected structure', () {
      final json = FixtureLoader.textResponseJson;
      final response = ClaudeResponse.fromJson(json);
      expect(response, isA<TextResponse>());
      expect((response as TextResponse).content, 'Hello from Claude!');
    });

    test('toolUseResponseJson matches expected structure', () {
      final json = FixtureLoader.toolUseResponseJson;
      final response = ClaudeResponse.fromJson(json);
      expect(response, isA<ToolUseResponse>());
      expect((response as ToolUseResponse).toolName, 'Read');
    });

    test('toolResultResponseJson matches expected structure', () {
      final json = FixtureLoader.toolResultResponseJson;
      final response = ClaudeResponse.fromJson(json);
      expect(response, isA<ToolResultResponse>());
      expect((response as ToolResultResponse).content, 'File contents here');
    });

    test('completionResponseJson matches expected structure', () {
      final json = FixtureLoader.completionResponseJson;
      final response = ClaudeResponse.fromJson(json);
      expect(response, isA<CompletionResponse>());
      expect((response as CompletionResponse).inputTokens, 100);
    });

    test('errorResponseJson matches expected structure', () {
      final json = FixtureLoader.errorResponseJson;
      final response = ClaudeResponse.fromJson(json);
      expect(response, isA<ErrorResponse>());
      expect((response as ErrorResponse).error, 'Something went wrong');
    });

    test('metaResponseJson matches expected structure', () {
      final json = FixtureLoader.metaResponseJson;
      final response = ClaudeResponse.fromJson(json);
      expect(response, isA<MetaResponse>());
      expect((response as MetaResponse).conversationId, 'conv_test_123');
    });

    test('statusResponseJson matches expected structure', () {
      final json = FixtureLoader.statusResponseJson;
      final response = ClaudeResponse.fromJson(json);
      expect(response, isA<StatusResponse>());
      expect((response as StatusResponse).status, ClaudeStatus.processing);
      expect(response.message, 'Working on it...');
    });
  });

  group('Edge cases', () {
    test('handles nested HTML entities', () {
      final json = {
        'type': 'text',
        'content': '&amp;lt; should become &lt; which becomes <'
      };
      final response = TextResponse.fromJson(json);
      // Note: HTML decoding happens in one pass, not recursively
      expect(response.content, '&lt; should become < which becomes <');
    });

    test('handles empty string content', () {
      final json = {'type': 'text', 'content': ''};
      final response = TextResponse.fromJson(json);
      expect(response.content, '');
    });

    test('handles missing content field gracefully', () {
      final json = {'type': 'text'};
      final response = TextResponse.fromJson(json);
      expect(response.content, '');
    });

    test('assistant message with null content list', () {
      final json = {
        'type': 'assistant',
        'message': {'id': 'msg_1', 'content': null}
      };
      final response = TextResponse.fromAssistantMessage(json);
      expect(response.content, '');
    });

    test('tool use with empty parameters', () {
      // Note: Must provide typed empty map, as production code fallback {} is
      // inferred as Map<dynamic, dynamic> which causes type errors
      final json = <String, dynamic>{
        'type': 'tool_use',
        'name': 'NoArgs',
        'input': <String, dynamic>{}
      };
      final response = ToolUseResponse.fromJson(json);
      expect(response.toolName, 'NoArgs');
      expect(response.parameters, isEmpty);
    });

    test('handles deeply nested parameter decoding', () {
      final json = <String, dynamic>{
        'type': 'tool_use',
        'name': 'Write',
        'input': <String, dynamic>{
          'nested': <String, dynamic>{
            'value': 'a &lt; b',
            'array': ['x &gt; y', 'z &amp; w']
          }
        }
      };
      final response = ToolUseResponse.fromJson(json);
      expect(response.parameters['nested']['value'], 'a < b');
      expect(response.parameters['nested']['array'][0], 'x > y');
      expect(response.parameters['nested']['array'][1], 'z & w');
    });
  });
}
