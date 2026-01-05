import 'dart:convert' show jsonEncode;
import 'package:claude_sdk/claude_sdk.dart';
import 'package:claude_sdk/src/protocol/json_decoder.dart' as protocol;
import 'package:test/test.dart';

void main() {
  group('Response Parsing Integration', () {
    late protocol.JsonDecoder decoder;

    setUp(() {
      decoder = protocol.JsonDecoder();
    });

    test('parses streaming text response sequence', () async {
      // Simulate streaming text responses from Claude CLI
      final responses = [
        {'type': 'text', 'content': 'Hello'},
        {'type': 'text', 'content': ', how '},
        {'type': 'text', 'content': 'are you?'},
      ];

      final stream = Stream.fromIterable(
        responses.map((r) => '${jsonEncode(r)}\n'),
      );

      final parsed = await decoder.decodeStream(stream).toList();

      expect(parsed, hasLength(3));
      expect(parsed[0], isA<TextResponse>());
      expect((parsed[0] as TextResponse).content, equals('Hello'));
      expect((parsed[1] as TextResponse).content, equals(', how '));
      expect((parsed[2] as TextResponse).content, equals('are you?'));
    });

    test('parses tool use followed by tool result', () async {
      // Tool use from assistant message format
      final toolUseJson = {
        'type': 'assistant',
        'uuid': 'asst_1',
        'message': {
          'id': 'msg_1',
          'role': 'assistant',
          'content': [
            {
              'type': 'tool_use',
              'id': 'tool_123',
              'name': 'Read',
              'input': {'file_path': '/path/to/file.txt'},
            },
          ],
        },
      };

      // Tool result from user message format
      final toolResultJson = {
        'type': 'user',
        'uuid': 'user_1',
        'message': {
          'role': 'user',
          'content': [
            {
              'type': 'tool_result',
              'tool_use_id': 'tool_123',
              'content': 'File contents here',
            },
          ],
        },
      };

      final stream = Stream.fromIterable([
        '${jsonEncode(toolUseJson)}\n',
        '${jsonEncode(toolResultJson)}\n',
      ]);

      final parsed = await decoder.decodeStream(stream).toList();

      expect(parsed, hasLength(2));
      expect(parsed[0], isA<ToolUseResponse>());
      expect(parsed[1], isA<ToolResultResponse>());

      final toolUse = parsed[0] as ToolUseResponse;
      expect(toolUse.toolName, equals('Read'));
      expect(toolUse.toolUseId, equals('tool_123'));
      expect(toolUse.parameters['file_path'], equals('/path/to/file.txt'));

      final toolResult = parsed[1] as ToolResultResponse;
      expect(toolResult.toolUseId, equals('tool_123'));
      expect(toolResult.content, equals('File contents here'));
      expect(toolResult.isError, isFalse);
    });

    test('parses multi-tool response', () async {
      // Multiple tool uses in a single conversation turn
      final tool1 = {
        'type': 'assistant',
        'uuid': 'asst_1',
        'message': {
          'id': 'msg_1',
          'role': 'assistant',
          'content': [
            {
              'type': 'tool_use',
              'id': 'tool_1',
              'name': 'Read',
              'input': {'file_path': '/file1.txt'},
            },
          ],
        },
      };

      final result1 = {
        'type': 'user',
        'uuid': 'user_1',
        'message': {
          'role': 'user',
          'content': [
            {
              'type': 'tool_result',
              'tool_use_id': 'tool_1',
              'content': 'Content 1',
            },
          ],
        },
      };

      final tool2 = {
        'type': 'assistant',
        'uuid': 'asst_2',
        'message': {
          'id': 'msg_2',
          'role': 'assistant',
          'content': [
            {
              'type': 'tool_use',
              'id': 'tool_2',
              'name': 'Write',
              'input': {'file_path': '/file2.txt', 'content': 'New content'},
            },
          ],
        },
      };

      final result2 = {
        'type': 'user',
        'uuid': 'user_2',
        'message': {
          'role': 'user',
          'content': [
            {
              'type': 'tool_result',
              'tool_use_id': 'tool_2',
              'content': 'File written successfully',
            },
          ],
        },
      };

      final stream = Stream.fromIterable([
        '${jsonEncode(tool1)}\n',
        '${jsonEncode(result1)}\n',
        '${jsonEncode(tool2)}\n',
        '${jsonEncode(result2)}\n',
      ]);

      final parsed = await decoder.decodeStream(stream).toList();

      expect(parsed, hasLength(4));
      expect(parsed[0], isA<ToolUseResponse>());
      expect(parsed[1], isA<ToolResultResponse>());
      expect(parsed[2], isA<ToolUseResponse>());
      expect(parsed[3], isA<ToolResultResponse>());

      final toolUse1 = parsed[0] as ToolUseResponse;
      final toolUse2 = parsed[2] as ToolUseResponse;

      expect(toolUse1.toolName, equals('Read'));
      expect(toolUse2.toolName, equals('Write'));
      expect(toolUse2.parameters['content'], equals('New content'));
    });

    test('parses error in middle of conversation', () async {
      final text1 = {'type': 'text', 'content': 'Starting task...'};

      final error = {
        'type': 'error',
        'error': 'Rate limit exceeded',
        'details': 'Please wait before retrying',
        'code': 'RATE_LIMIT',
      };

      final stream = Stream.fromIterable([
        '${jsonEncode(text1)}\n',
        '${jsonEncode(error)}\n',
      ]);

      final parsed = await decoder.decodeStream(stream).toList();

      expect(parsed, hasLength(2));
      expect(parsed[0], isA<TextResponse>());
      expect(parsed[1], isA<ErrorResponse>());

      final errorResponse = parsed[1] as ErrorResponse;
      expect(errorResponse.error, equals('Rate limit exceeded'));
      expect(errorResponse.details, equals('Please wait before retrying'));
      expect(errorResponse.code, equals('RATE_LIMIT'));
    });

    test('parses completion with token usage', () async {
      final text = {'type': 'text', 'content': 'Here is my response.'};

      final completion = {
        'type': 'result',
        'subtype': 'success',
        'uuid': 'result_1',
        'usage': {'input_tokens': 150, 'output_tokens': 75},
      };

      final stream = Stream.fromIterable([
        '${jsonEncode(text)}\n',
        '${jsonEncode(completion)}\n',
      ]);

      final parsed = await decoder.decodeStream(stream).toList();

      expect(parsed, hasLength(2));
      expect(parsed[0], isA<TextResponse>());
      expect(parsed[1], isA<CompletionResponse>());

      final completionResponse = parsed[1] as CompletionResponse;
      expect(completionResponse.inputTokens, equals(150));
      expect(completionResponse.outputTokens, equals(75));
      expect(completionResponse.stopReason, equals('completed'));
    });

    test('parses meta response with conversation ID', () {
      final metaJson = {
        'type': 'system',
        'subtype': 'init',
        'conversation_id': 'conv_abc123',
        'metadata': {'version': '1.0', 'model': 'claude-3'},
      };

      final response = ClaudeResponse.fromJson(metaJson);

      expect(response, isA<MetaResponse>());
      final meta = response as MetaResponse;
      expect(meta.conversationId, equals('conv_abc123'));
      expect(meta.metadata['version'], equals('1.0'));
    });

    test('parses status response', () {
      final statusJson = {
        'type': 'status',
        'status': 'processing',
        'message': 'Thinking...',
      };

      final response = ClaudeResponse.fromJson(statusJson);

      expect(response, isA<StatusResponse>());
      final status = response as StatusResponse;
      expect(status.status, equals(ClaudeStatus.processing));
      expect(status.message, equals('Thinking...'));
    });

    test('handles HTML entities in tool responses', () {
      final toolUseJson = {
        'type': 'assistant',
        'uuid': 'asst_1',
        'message': {
          'id': 'msg_1',
          'role': 'assistant',
          'content': [
            {
              'type': 'tool_use',
              'id': 'tool_1',
              'name': 'Read',
              'input': {'file_path': '/path/with&amp;special&lt;chars&gt;.txt'},
            },
          ],
        },
      };

      final response = ClaudeResponse.fromJson(toolUseJson);

      expect(response, isA<ToolUseResponse>());
      final toolUse = response as ToolUseResponse;
      // HTML entities should be decoded
      expect(
        toolUse.parameters['file_path'],
        equals('/path/with&special<chars>.txt'),
      );
    });

    test('handles tool result with MCP content array format', () {
      final toolResultJson = {
        'type': 'user',
        'uuid': 'user_1',
        'message': {
          'role': 'user',
          'content': [
            {
              'type': 'tool_result',
              'tool_use_id': 'tool_123',
              'content': [
                {'type': 'text', 'text': 'First line'},
                {'type': 'text', 'text': ' and second line'},
              ],
            },
          ],
        },
      };

      final response = ClaudeResponse.fromJson(toolResultJson);

      expect(response, isA<ToolResultResponse>());
      final toolResult = response as ToolResultResponse;
      expect(toolResult.content, equals('First line and second line'));
    });

    test('handles tool result with error flag', () {
      final toolResultJson = {
        'type': 'user',
        'uuid': 'user_1',
        'message': {
          'role': 'user',
          'content': [
            {
              'type': 'tool_result',
              'tool_use_id': 'tool_123',
              'content': 'File not found',
              'is_error': true,
            },
          ],
        },
      };

      final response = ClaudeResponse.fromJson(toolResultJson);

      expect(response, isA<ToolResultResponse>());
      final toolResult = response as ToolResultResponse;
      expect(toolResult.isError, isTrue);
      expect(toolResult.content, equals('File not found'));
    });

    test('parses unknown response type gracefully', () {
      final unknownJson = {
        'type': 'some_future_type',
        'data': {'key': 'value'},
      };

      final response = ClaudeResponse.fromJson(unknownJson);

      expect(response, isA<UnknownResponse>());
      expect(response.rawData, equals(unknownJson));
    });

    test('decodeSingle returns null for invalid JSON', () {
      final result = decoder.decodeSingle('not valid json');
      expect(result, isNull);
    });

    test('decodeSingle returns null for empty string', () {
      final result = decoder.decodeSingle('');
      expect(result, isNull);
    });

    test('stream handles partial JSON chunks gracefully', () async {
      // Simulate chunked delivery of a JSON line
      final fullJson = {'type': 'text', 'content': 'Hello world'};
      final encoded = jsonEncode(fullJson);

      // Split into partial chunks (but ultimately complete line)
      final chunk1 = encoded.substring(0, 10);
      final chunk2 = encoded.substring(10) + '\n';

      final stream = Stream.fromIterable([chunk1, chunk2]);
      final parsed = await decoder.decodeStream(stream).toList();

      expect(parsed, hasLength(1));
      expect(parsed[0], isA<TextResponse>());
      expect((parsed[0] as TextResponse).content, equals('Hello world'));
    });

    test('full conversation flow integration', () async {
      // Simulate a complete conversation turn
      final systemInit = {
        'type': 'system',
        'subtype': 'init',
        'conversation_id': 'conv_test',
        'metadata': {},
      };

      // Note: userQuery is not included in the stream as it's sent by the client,
      // not received from Claude. This simulates the response stream only.

      final toolUse = {
        'type': 'assistant',
        'uuid': 'asst_1',
        'message': {
          'id': 'msg_1',
          'role': 'assistant',
          'content': [
            {
              'type': 'tool_use',
              'id': 'tool_read',
              'name': 'Read',
              'input': {'file_path': 'config.yaml'},
            },
          ],
        },
      };

      final toolResult = {
        'type': 'user',
        'uuid': 'user_2',
        'message': {
          'role': 'user',
          'content': [
            {
              'type': 'tool_result',
              'tool_use_id': 'tool_read',
              'content': 'port: 8080\nhost: localhost',
            },
          ],
        },
      };

      final finalResponse = {
        'type': 'assistant',
        'uuid': 'asst_2',
        'message': {
          'id': 'msg_2',
          'role': 'assistant',
          'content': [
            {
              'type': 'text',
              'text':
                  'The config file sets port to 8080 and host to localhost.',
            },
          ],
        },
      };

      final completion = {
        'type': 'result',
        'subtype': 'success',
        'uuid': 'result_1',
        'usage': {'input_tokens': 200, 'output_tokens': 50},
      };

      final stream = Stream.fromIterable([
        '${jsonEncode(systemInit)}\n',
        '${jsonEncode(toolUse)}\n',
        '${jsonEncode(toolResult)}\n',
        '${jsonEncode(finalResponse)}\n',
        '${jsonEncode(completion)}\n',
      ]);

      final parsed = await decoder.decodeStream(stream).toList();

      // Validate the sequence
      expect(parsed, hasLength(5));
      expect(parsed[0], isA<MetaResponse>());
      expect(parsed[1], isA<ToolUseResponse>());
      expect(parsed[2], isA<ToolResultResponse>());
      expect(parsed[3], isA<TextResponse>());
      expect(parsed[4], isA<CompletionResponse>());

      // Validate content
      final meta = parsed[0] as MetaResponse;
      expect(meta.conversationId, equals('conv_test'));

      final tool = parsed[1] as ToolUseResponse;
      expect(tool.toolName, equals('Read'));

      final result = parsed[2] as ToolResultResponse;
      expect(result.content, contains('port: 8080'));

      final text = parsed[3] as TextResponse;
      expect(text.content, contains('8080'));

      final comp = parsed[4] as CompletionResponse;
      expect(comp.inputTokens, equals(200));
    });
  });
}
