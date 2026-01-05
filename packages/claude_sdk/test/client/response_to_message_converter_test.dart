import 'package:test/test.dart';

import 'package:claude_sdk/src/client/response_to_message_converter.dart';
import 'package:claude_sdk/src/models/response.dart';
import 'package:claude_sdk/src/models/conversation.dart';

void main() {
  group('ResponseToMessageConverter', () {
    group('convert', () {
      test('converts TextResponse to assistant message', () {
        final response = TextResponse(
          id: 'text-1',
          timestamp: DateTime.now(),
          content: 'Hello, world!',
        );

        final message = ResponseToMessageConverter.convert(response);

        expect(message.role, equals(MessageRole.assistant));
        expect(message.responses.length, equals(1));
        expect(message.isStreaming, isTrue);
      });

      test('converts ToolUseResponse to assistant message', () {
        final response = ToolUseResponse(
          id: 'tool-1',
          timestamp: DateTime.now(),
          toolName: 'Read',
          parameters: {'file_path': '/test.txt'},
          toolUseId: 'toolu_123',
        );

        final message = ResponseToMessageConverter.convert(response);

        expect(message.role, equals(MessageRole.assistant));
        expect(message.responses.first, isA<ToolUseResponse>());
      });

      test(
        'converts ToolResultResponse to assistant message (for merging)',
        () {
          final response = ToolResultResponse(
            id: 'result-1',
            timestamp: DateTime.now(),
            toolUseId: 'toolu_123',
            content: 'File contents here',
            isError: false,
          );

          final message = ResponseToMessageConverter.convert(response);

          expect(message.role, equals(MessageRole.assistant));
          expect(message.responses.first, isA<ToolResultResponse>());
        },
      );

      test('converts CompactBoundaryResponse to compact boundary message', () {
        final response = CompactBoundaryResponse(
          id: 'compact-1',
          timestamp: DateTime.now(),
          trigger: 'manual',
          preTokens: 47000,
        );

        final message = ResponseToMessageConverter.convert(response);

        expect(message.role, equals(MessageRole.system));
        expect(message.messageType, equals(MessageType.compactBoundary));
        expect(message.content, contains('Compacted'));
        expect(message.content, contains('manual'));
      });

      test(
        'converts CompactSummaryResponse to user message with isCompactSummary',
        () {
          final response = CompactSummaryResponse(
            id: 'summary-1',
            timestamp: DateTime.now(),
            content: 'This session is being continued...',
            isVisibleInTranscriptOnly: true,
          );

          final message = ResponseToMessageConverter.convert(response);

          expect(message.role, equals(MessageRole.user));
          expect(message.messageType, equals(MessageType.compactSummary));
          expect(message.content, equals('This session is being continued...'));
          expect(message.isCompactSummary, isTrue);
          expect(message.isVisibleInTranscriptOnly, isTrue);
        },
      );

      test('converts UserMessageResponse to user message', () {
        final response = UserMessageResponse(
          id: 'user-1',
          timestamp: DateTime.now(),
          content: 'User question here',
        );

        final message = ResponseToMessageConverter.convert(response);

        expect(message.role, equals(MessageRole.user));
        expect(message.messageType, equals(MessageType.userMessage));
        expect(message.content, equals('User question here'));
        expect(message.isCompactSummary, isFalse);
      });

      test('converts ErrorResponse to assistant message with error', () {
        final response = ErrorResponse(
          id: 'error-1',
          timestamp: DateTime.now(),
          error: 'Something went wrong',
        );

        final message = ResponseToMessageConverter.convert(response);

        expect(message.role, equals(MessageRole.assistant));
        expect(message.messageType, equals(MessageType.error));
        expect(message.error, equals('Something went wrong'));
      });

      test('converts StatusResponse to system message with status type', () {
        final response = StatusResponse(
          id: 'status-1',
          timestamp: DateTime.now(),
          status: ClaudeStatus.processing,
        );

        final message = ResponseToMessageConverter.convert(response);

        expect(message.role, equals(MessageRole.system));
        expect(message.messageType, equals(MessageType.status));
      });

      test('converts MetaResponse to system message with meta type', () {
        final response = MetaResponse(
          id: 'meta-1',
          timestamp: DateTime.now(),
          conversationId: 'session-123',
          metadata: {'projectPath': '/project'},
        );

        final message = ResponseToMessageConverter.convert(response);

        expect(message.role, equals(MessageRole.system));
        expect(message.messageType, equals(MessageType.meta));
        expect(message.content, equals('session-123'));
      });

      test(
        'converts CompletionResponse to system message with completion type',
        () {
          final response = CompletionResponse(
            id: 'completion-1',
            timestamp: DateTime.now(),
            stopReason: 'end_turn',
            inputTokens: 1000,
            outputTokens: 500,
          );

          final message = ResponseToMessageConverter.convert(response);

          expect(message.role, equals(MessageRole.system));
          expect(message.messageType, equals(MessageType.completion));
          expect(message.tokenUsage, isNotNull);
          expect(message.tokenUsage!.inputTokens, equals(1000));
          expect(message.tokenUsage!.outputTokens, equals(500));
        },
      );

      test('converts UnknownResponse to system message with unknown type', () {
        final response = UnknownResponse(
          id: 'unknown-1',
          timestamp: DateTime.now(),
        );

        final message = ResponseToMessageConverter.convert(response);

        expect(message.role, equals(MessageRole.system));
        expect(message.messageType, equals(MessageType.unknown));
      });
    });

    group('isToolResult', () {
      test('returns true for ToolResultResponse', () {
        final response = ToolResultResponse(
          id: 'result-1',
          timestamp: DateTime.now(),
          toolUseId: 'toolu_123',
          content: 'Result',
          isError: false,
        );

        expect(ResponseToMessageConverter.isToolResult(response), isTrue);
      });

      test('returns false for other response types', () {
        final textResponse = TextResponse(
          id: 'text-1',
          timestamp: DateTime.now(),
          content: 'Hello',
        );

        expect(ResponseToMessageConverter.isToolResult(textResponse), isFalse);
      });
    });

    group('isAssistantResponse', () {
      test('returns true for TextResponse', () {
        final response = TextResponse(
          id: 'text-1',
          timestamp: DateTime.now(),
          content: 'Hello',
        );

        expect(
          ResponseToMessageConverter.isAssistantResponse(response),
          isTrue,
        );
      });

      test('returns true for ToolUseResponse', () {
        final response = ToolUseResponse(
          id: 'tool-1',
          timestamp: DateTime.now(),
          toolName: 'Read',
          parameters: {},
        );

        expect(
          ResponseToMessageConverter.isAssistantResponse(response),
          isTrue,
        );
      });

      test('returns true for CompactBoundaryResponse', () {
        final response = CompactBoundaryResponse(
          id: 'compact-1',
          timestamp: DateTime.now(),
          trigger: 'auto',
          preTokens: 1000,
        );

        expect(
          ResponseToMessageConverter.isAssistantResponse(response),
          isTrue,
        );
      });

      test('returns false for UserMessageResponse', () {
        final response = UserMessageResponse(
          id: 'user-1',
          timestamp: DateTime.now(),
          content: 'Hello',
        );

        expect(
          ResponseToMessageConverter.isAssistantResponse(response),
          isFalse,
        );
      });
    });

    group('isUserResponse', () {
      test('returns true for CompactSummaryResponse', () {
        final response = CompactSummaryResponse(
          id: 'summary-1',
          timestamp: DateTime.now(),
          content: 'Summary',
        );

        expect(ResponseToMessageConverter.isUserResponse(response), isTrue);
      });

      test('returns true for UserMessageResponse', () {
        final response = UserMessageResponse(
          id: 'user-1',
          timestamp: DateTime.now(),
          content: 'Hello',
        );

        expect(ResponseToMessageConverter.isUserResponse(response), isTrue);
      });

      test('returns false for TextResponse', () {
        final response = TextResponse(
          id: 'text-1',
          timestamp: DateTime.now(),
          content: 'Hello',
        );

        expect(ResponseToMessageConverter.isUserResponse(response), isFalse);
      });
    });
  });

  group('JsonlMessageParser', () {
    group('parseLine', () {
      test('parses user message', () {
        final json = {
          'type': 'user',
          'message': {'role': 'user', 'content': 'Hello'},
          'uuid': 'user-123',
        };

        final response = JsonlMessageParser.parseLine(json);

        expect(response, isA<UserMessageResponse>());
        expect((response as UserMessageResponse).content, equals('Hello'));
      });

      test('parses assistant text message', () {
        final json = {
          'type': 'assistant',
          'message': {
            'content': [
              {'type': 'text', 'text': 'Hello, world!'},
            ],
          },
          'uuid': 'assistant-123',
        };

        final response = JsonlMessageParser.parseLine(json);

        expect(response, isA<TextResponse>());
      });

      test('parses compact boundary', () {
        final json = {
          'type': 'system',
          'subtype': 'compact_boundary',
          'uuid': 'compact-123',
          'compactMetadata': {'trigger': 'manual', 'preTokens': 50000},
        };

        final response = JsonlMessageParser.parseLine(json);

        expect(response, isA<CompactBoundaryResponse>());
        final compact = response as CompactBoundaryResponse;
        expect(compact.trigger, equals('manual'));
        expect(compact.preTokens, equals(50000));
      });

      test('skips meta messages', () {
        final json = {
          'type': 'user',
          'isMeta': true,
          'message': {'content': 'command'},
        };

        final response = JsonlMessageParser.parseLine(json);

        expect(response, isNull);
      });

      test('returns null for unknown types', () {
        final json = {'type': 'unknown_type'};

        final response = JsonlMessageParser.parseLine(json);

        expect(response, isNull);
      });
    });

    group('parseLineMultiple', () {
      test('expands assistant message with multiple content blocks', () {
        final json = {
          'type': 'assistant',
          'message': {
            'content': [
              {'type': 'text', 'text': 'First text'},
              {'type': 'tool_use', 'id': 'tool-1', 'name': 'Read', 'input': {}},
              {'type': 'text', 'text': 'Second text'},
            ],
          },
          'uuid': 'assistant-123',
        };

        final responses = JsonlMessageParser.parseLineMultiple(json);

        expect(responses.length, equals(3));
        expect(responses[0], isA<TextResponse>());
        expect(responses[1], isA<ToolUseResponse>());
        expect(responses[2], isA<TextResponse>());
      });

      test('returns single response for non-assistant messages', () {
        final json = {
          'type': 'user',
          'message': {'role': 'user', 'content': 'Hello'},
          'uuid': 'user-123',
        };

        final responses = JsonlMessageParser.parseLineMultiple(json);

        expect(responses.length, equals(1));
        expect(responses.first, isA<UserMessageResponse>());
      });

      test('skips meta messages', () {
        final json = {
          'type': 'user',
          'isMeta': true,
          'message': {'content': 'command'},
        };

        final responses = JsonlMessageParser.parseLineMultiple(json);

        expect(responses, isEmpty);
      });
    });

    group('extractUsage', () {
      test('extracts usage from message.usage', () {
        final json = {
          'type': 'assistant',
          'message': {
            'usage': {
              'input_tokens': 1000,
              'cache_read_input_tokens': 500,
              'cache_creation_input_tokens': 200,
            },
          },
        };

        final usage = JsonlMessageParser.extractUsage(json);

        expect(usage, isNotNull);
        expect(usage!.inputTokens, equals(1000));
        expect(usage.cacheReadTokens, equals(500));
        expect(usage.cacheCreationTokens, equals(200));
      });

      test('returns null when no message', () {
        final json = {'type': 'system'};

        final usage = JsonlMessageParser.extractUsage(json);

        expect(usage, isNull);
      });

      test('returns null when no usage', () {
        final json = {
          'type': 'assistant',
          'message': {'content': 'Hello'},
        };

        final usage = JsonlMessageParser.extractUsage(json);

        expect(usage, isNull);
      });

      test('returns null when all tokens are zero', () {
        final json = {
          'type': 'assistant',
          'message': {
            'usage': {
              'input_tokens': 0,
              'cache_read_input_tokens': 0,
              'cache_creation_input_tokens': 0,
            },
          },
        };

        final usage = JsonlMessageParser.extractUsage(json);

        expect(usage, isNull);
      });
    });

    group('extractMessageId', () {
      test('extracts id from message', () {
        final json = {
          'type': 'assistant',
          'message': {'id': 'msg-123', 'content': 'Hello'},
        };

        final id = JsonlMessageParser.extractMessageId(json);

        expect(id, equals('msg-123'));
      });

      test('returns null when no message', () {
        final json = {'type': 'system'};

        final id = JsonlMessageParser.extractMessageId(json);

        expect(id, isNull);
      });

      test('returns null when message has no id', () {
        final json = {
          'type': 'assistant',
          'message': {'content': 'Hello'},
        };

        final id = JsonlMessageParser.extractMessageId(json);

        expect(id, isNull);
      });
    });
  });

  group('End-to-end unified parsing', () {
    test(
      'compaction flow: compact_boundary → user summary → assistant response',
      () {
        // Simulated JSONL lines for a compaction event
        final compactBoundaryJson = {
          'type': 'system',
          'subtype': 'compact_boundary',
          'uuid': 'compact-uuid',
          'compactMetadata': {'trigger': 'manual', 'preTokens': 51185},
        };

        final userSummaryJson = {
          'type': 'user',
          'message': {
            'role': 'user',
            'content':
                'This session is being continued from a previous conversation...',
          },
          'uuid': 'summary-uuid',
          'isCompactSummary': true,
          'isVisibleInTranscriptOnly': true,
        };

        final assistantResponseJson = {
          'type': 'assistant',
          'message': {
            'content': [
              {'type': 'text', 'text': 'I understand. How can I help?'},
            ],
          },
          'uuid': 'response-uuid',
        };

        // Parse using unified parser
        final compactResponse = JsonlMessageParser.parseLine(
          compactBoundaryJson,
        );
        final summaryResponse = JsonlMessageParser.parseLine(userSummaryJson);
        final assistantResponse = JsonlMessageParser.parseLine(
          assistantResponseJson,
        );

        // Verify correct response types
        expect(compactResponse, isA<CompactBoundaryResponse>());
        expect(summaryResponse, isA<CompactSummaryResponse>());
        expect(assistantResponse, isA<TextResponse>());

        // Convert to messages (parseLine returns nullable, so use !)
        final compactMessage = ResponseToMessageConverter.convert(
          compactResponse!,
        );
        final summaryMessage = ResponseToMessageConverter.convert(
          summaryResponse!,
        );
        final responseMessage = ResponseToMessageConverter.convert(
          assistantResponse!,
        );

        // Verify compact boundary message
        expect(compactMessage.messageType, equals(MessageType.compactBoundary));
        expect(compactMessage.content, contains('manual'));

        // Verify summary message has correct flags
        expect(summaryMessage.role, equals(MessageRole.user));
        expect(summaryMessage.messageType, equals(MessageType.compactSummary));
        expect(summaryMessage.isCompactSummary, isTrue);
        expect(summaryMessage.isVisibleInTranscriptOnly, isTrue);

        // Verify assistant response
        expect(responseMessage.role, equals(MessageRole.assistant));
      },
    );

    test('tool invocation flow: text → tool_use → tool_result → text', () {
      final responses = <ClaudeResponse>[];

      // Text before tool
      responses.addAll(
        JsonlMessageParser.parseLineMultiple({
          'type': 'assistant',
          'message': {
            'content': [
              {'type': 'text', 'text': "I'll read the file."},
            ],
          },
          'uuid': 'msg-1',
        }),
      );

      // Tool use
      responses.addAll(
        JsonlMessageParser.parseLineMultiple({
          'type': 'assistant',
          'message': {
            'content': [
              {
                'type': 'tool_use',
                'id': 'toolu_123',
                'name': 'Read',
                'input': {'file_path': '/test.txt'},
              },
            ],
          },
          'uuid': 'msg-2',
        }),
      );

      // Tool result (comes as user message type)
      final toolResultJson = {
        'type': 'user',
        'message': {
          'content': [
            {
              'type': 'tool_result',
              'tool_use_id': 'toolu_123',
              'content': 'File contents here',
            },
          ],
        },
        'uuid': 'msg-3',
      };
      responses.addAll(JsonlMessageParser.parseLineMultiple(toolResultJson));

      // Text after tool
      responses.addAll(
        JsonlMessageParser.parseLineMultiple({
          'type': 'assistant',
          'message': {
            'content': [
              {'type': 'text', 'text': 'The file contains...'},
            ],
          },
          'uuid': 'msg-4',
        }),
      );

      // Verify we got all responses
      expect(responses.length, equals(4));
      expect(responses[0], isA<TextResponse>());
      expect(responses[1], isA<ToolUseResponse>());
      expect(responses[2], isA<ToolResultResponse>());
      expect(responses[3], isA<TextResponse>());

      // Verify tool use has correct properties
      final toolUse = responses[1] as ToolUseResponse;
      expect(toolUse.toolName, equals('Read'));
      expect(toolUse.toolUseId, equals('toolu_123'));

      // Verify tool result has correct properties
      final toolResult = responses[2] as ToolResultResponse;
      expect(toolResult.toolUseId, equals('toolu_123'));
      expect(toolResult.content, equals('File contents here'));
    });
  });
}
