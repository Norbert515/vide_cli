import 'package:test/test.dart';

import 'package:claude_sdk/src/client/response_processor.dart';
import 'package:claude_sdk/src/models/response.dart';
import 'package:claude_sdk/src/models/conversation.dart';

void main() {
  group('ResponseProcessor', () {
    late ResponseProcessor processor;

    setUp(() {
      processor = ResponseProcessor();
    });

    group('processResponse', () {
      group('TextResponse', () {
        test(
          'adds new assistant message when no existing assistant message',
          () {
            final conversation = Conversation.empty();
            final response = TextResponse(
              id: 'text-1',
              timestamp: DateTime.now(),
              content: 'Hello, world!',
            );

            final result = processor.processResponse(response, conversation);

            expect(result.updatedConversation.messages.length, equals(1));
            expect(
              result.updatedConversation.messages.last.role,
              equals(MessageRole.assistant),
            );
            expect(
              result.updatedConversation.messages.last.content,
              equals('Hello, world!'),
            );
            expect(
              result.updatedConversation.messages.last.isStreaming,
              isTrue,
            );
            expect(
              result.updatedConversation.state,
              equals(ConversationState.receivingResponse),
            );
            expect(result.turnComplete, isFalse);
          },
        );

        test('updates existing streaming assistant message', () {
          // Start with an assistant message already streaming
          final existingMessage = ConversationMessage.assistant(
            id: 'msg-1',
            responses: [
              TextResponse(
                id: 'text-1',
                timestamp: DateTime.now(),
                content: 'Hello, ',
              ),
            ],
            isStreaming: true,
          );
          final conversation = Conversation(
            messages: [existingMessage],
            state: ConversationState.receivingResponse,
          );

          final response = TextResponse(
            id: 'text-2',
            timestamp: DateTime.now(),
            content: 'world!',
          );

          final result = processor.processResponse(response, conversation);

          expect(result.updatedConversation.messages.length, equals(1));
          expect(result.updatedConversation.messages.last.id, equals('msg-1'));
          expect(
            result.updatedConversation.messages.last.responses.length,
            equals(2),
          );
          expect(
            result.updatedConversation.messages.last.content,
            equals('Hello, world!'),
          );
          expect(result.turnComplete, isFalse);
        });

        test('creates new message after completed assistant message', () {
          // Start with a completed assistant message
          final existingMessage = ConversationMessage.assistant(
            id: 'msg-1',
            responses: [
              TextResponse(
                id: 'text-1',
                timestamp: DateTime.now(),
                content: 'Previous message',
              ),
            ],
            isStreaming: false,
            isComplete: true,
          );
          final conversation = Conversation(
            messages: [existingMessage],
            state: ConversationState.idle,
          );

          final response = TextResponse(
            id: 'text-2',
            timestamp: DateTime.now(),
            content: 'New message',
          );

          final result = processor.processResponse(response, conversation);

          expect(result.updatedConversation.messages.length, equals(2));
          expect(
            result.updatedConversation.messages.last.content,
            equals('New message'),
          );
          expect(result.updatedConversation.messages.last.isStreaming, isTrue);
        });

        test('extracts and accumulates usage from rawData with end_turn', () {
          final conversation = Conversation(
            messages: [],
            state: ConversationState.idle,
            totalInputTokens: 100,
            totalOutputTokens: 50,
            totalCacheReadInputTokens: 10,
            totalCacheCreationInputTokens: 20,
          );

          // Simulate Claude CLI format with usage in message.usage
          final response = TextResponse(
            id: 'text-1',
            timestamp: DateTime.now(),
            content: 'Hello!',
            rawData: {
              'type': 'assistant',
              'message': {
                'stop_reason': 'end_turn',
                'usage': {
                  'input_tokens': 50,
                  'output_tokens': 30,
                  'cache_read_input_tokens': 5,
                  'cache_creation_input_tokens': 10,
                },
              },
            },
          );

          final result = processor.processResponse(response, conversation);

          // Verify tokens are accumulated (totals)
          expect(result.updatedConversation.totalInputTokens, equals(150));
          expect(result.updatedConversation.totalOutputTokens, equals(80));
          expect(
            result.updatedConversation.totalCacheReadInputTokens,
            equals(15),
          );
          expect(
            result.updatedConversation.totalCacheCreationInputTokens,
            equals(30),
          );

          // Verify current context values are set (replaced, not accumulated)
          expect(
            result.updatedConversation.currentContextInputTokens,
            equals(50),
          );
          expect(
            result.updatedConversation.currentContextCacheReadTokens,
            equals(5),
          );
          expect(
            result.updatedConversation.currentContextCacheCreationTokens,
            equals(10),
          );
          expect(
            result.updatedConversation.currentContextWindowTokens,
            equals(65),
          ); // 50 + 5 + 10

          // Verify turn is complete
          expect(result.turnComplete, isTrue);
          expect(result.updatedConversation.messages.last.isStreaming, isFalse);
          expect(result.updatedConversation.messages.last.isComplete, isTrue);
          expect(
            result.updatedConversation.state,
            equals(ConversationState.idle),
          );
        });

        test('does not mark turn complete for tool_use stop_reason', () {
          final conversation = Conversation(
            messages: [],
            state: ConversationState.idle,
            totalInputTokens: 0,
            totalOutputTokens: 0,
          );

          // Simulate Claude CLI format with tool_use stop_reason
          final response = TextResponse(
            id: 'text-1',
            timestamp: DateTime.now(),
            content: 'Let me check that file...',
            rawData: {
              'type': 'assistant',
              'message': {
                'stop_reason': 'tool_use',
                'usage': {'input_tokens': 50, 'output_tokens': 30},
              },
            },
          );

          final result = processor.processResponse(response, conversation);

          // Verify tokens are still accumulated
          expect(result.updatedConversation.totalInputTokens, equals(50));
          expect(result.updatedConversation.totalOutputTokens, equals(30));

          // Verify turn is NOT complete (tool_use means more coming)
          expect(result.turnComplete, isFalse);
          expect(result.updatedConversation.messages.last.isStreaming, isTrue);
          expect(result.updatedConversation.messages.last.isComplete, isFalse);
        });
      });

      group('ToolUseResponse', () {
        test('adds tool use to new assistant message', () {
          final conversation = Conversation.empty();
          final response = ToolUseResponse(
            id: 'tool-1',
            timestamp: DateTime.now(),
            toolName: 'Read',
            parameters: {'file_path': '/test.txt'},
            toolUseId: 'call-1',
          );

          final result = processor.processResponse(response, conversation);

          expect(result.updatedConversation.messages.length, equals(1));
          expect(
            result.updatedConversation.messages.last.role,
            equals(MessageRole.assistant),
          );
          expect(result.updatedConversation.messages.last.isStreaming, isTrue);
          expect(
            result.updatedConversation.state,
            equals(ConversationState.processing),
          );
          expect(result.turnComplete, isFalse);

          // Verify tool invocation is accessible
          final invocations =
              result.updatedConversation.messages.last.toolInvocations;
          expect(invocations.length, equals(1));
          expect(invocations.first.toolCall.toolName, equals('Read'));
        });

        test('adds tool use to existing streaming message', () {
          final existingMessage = ConversationMessage.assistant(
            id: 'msg-1',
            responses: [
              TextResponse(
                id: 'text-1',
                timestamp: DateTime.now(),
                content: 'Let me read that file.',
              ),
            ],
            isStreaming: true,
          );
          final conversation = Conversation(
            messages: [existingMessage],
            state: ConversationState.receivingResponse,
          );

          final response = ToolUseResponse(
            id: 'tool-1',
            timestamp: DateTime.now(),
            toolName: 'Read',
            parameters: {'file_path': '/test.txt'},
            toolUseId: 'call-1',
          );

          final result = processor.processResponse(response, conversation);

          expect(result.updatedConversation.messages.length, equals(1));
          expect(
            result.updatedConversation.messages.last.responses.length,
            equals(2),
          );
          expect(
            result.updatedConversation.state,
            equals(ConversationState.processing),
          );
        });
      });

      group('ToolResultResponse', () {
        test('adds tool result to message with matching tool call', () {
          final toolCall = ToolUseResponse(
            id: 'tool-1',
            timestamp: DateTime.now(),
            toolName: 'Read',
            parameters: {'file_path': '/test.txt'},
            toolUseId: 'call-1',
          );
          final existingMessage = ConversationMessage.assistant(
            id: 'msg-1',
            responses: [toolCall],
            isStreaming: true,
          );
          final conversation = Conversation(
            messages: [existingMessage],
            state: ConversationState.processing,
          );

          final response = ToolResultResponse(
            id: 'result-1',
            timestamp: DateTime.now(),
            toolUseId: 'call-1',
            content: 'File contents here',
            isError: false,
          );

          final result = processor.processResponse(response, conversation);

          expect(result.updatedConversation.messages.length, equals(1));
          expect(
            result.updatedConversation.messages.last.responses.length,
            equals(2),
          );
          expect(
            result.updatedConversation.state,
            equals(ConversationState.processing),
          );
          expect(result.turnComplete, isFalse);

          // Verify tool invocation is complete
          final invocations =
              result.updatedConversation.messages.last.toolInvocations;
          expect(invocations.length, equals(1));
          expect(invocations.first.toolResult, isNotNull);
          expect(
            invocations.first.toolResult!.content,
            equals('File contents here'),
          );
        });

        test('handles tool error result', () {
          final toolCall = ToolUseResponse(
            id: 'tool-1',
            timestamp: DateTime.now(),
            toolName: 'Read',
            parameters: {'file_path': '/nonexistent.txt'},
            toolUseId: 'call-1',
          );
          final existingMessage = ConversationMessage.assistant(
            id: 'msg-1',
            responses: [toolCall],
            isStreaming: true,
          );
          final conversation = Conversation(
            messages: [existingMessage],
            state: ConversationState.processing,
          );

          final response = ToolResultResponse(
            id: 'result-1',
            timestamp: DateTime.now(),
            toolUseId: 'call-1',
            content: 'File not found',
            isError: true,
          );

          final result = processor.processResponse(response, conversation);

          final invocations =
              result.updatedConversation.messages.last.toolInvocations;
          expect(invocations.first.toolResult!.isError, isTrue);
        });
      });

      group('CompletionResponse (ResultResponse)', () {
        test('marks turn as complete and updates message state', () {
          final existingMessage = ConversationMessage.assistant(
            id: 'msg-1',
            responses: [
              TextResponse(
                id: 'text-1',
                timestamp: DateTime.now(),
                content: 'All done!',
              ),
            ],
            isStreaming: true,
          );
          final conversation = Conversation(
            messages: [existingMessage],
            state: ConversationState.receivingResponse,
          );

          final response = CompletionResponse(
            id: 'completion-1',
            timestamp: DateTime.now(),
            stopReason: 'end_turn',
            inputTokens: 100,
            outputTokens: 50,
          );

          final result = processor.processResponse(response, conversation);

          expect(result.turnComplete, isTrue);
          expect(result.updatedConversation.messages.last.isStreaming, isFalse);
          expect(result.updatedConversation.messages.last.isComplete, isTrue);
          expect(
            result.updatedConversation.state,
            equals(ConversationState.idle),
          );
        });

        test('updates token counts', () {
          final existingMessage = ConversationMessage.assistant(
            id: 'msg-1',
            responses: [
              TextResponse(
                id: 'text-1',
                timestamp: DateTime.now(),
                content: 'Response',
              ),
            ],
            isStreaming: true,
          );
          final conversation = Conversation(
            messages: [existingMessage],
            state: ConversationState.receivingResponse,
            totalInputTokens: 50,
            totalOutputTokens: 25,
          );

          final response = CompletionResponse(
            id: 'completion-1',
            timestamp: DateTime.now(),
            stopReason: 'end_turn',
            inputTokens: 100,
            outputTokens: 75,
          );

          final result = processor.processResponse(response, conversation);

          expect(result.updatedConversation.totalInputTokens, equals(150));
          expect(result.updatedConversation.totalOutputTokens, equals(100));
        });

        test('handles null token counts', () {
          final existingMessage = ConversationMessage.assistant(
            id: 'msg-1',
            responses: [
              TextResponse(
                id: 'text-1',
                timestamp: DateTime.now(),
                content: 'Response',
              ),
            ],
            isStreaming: true,
          );
          final conversation = Conversation(
            messages: [existingMessage],
            state: ConversationState.receivingResponse,
            totalInputTokens: 50,
            totalOutputTokens: 25,
          );

          final response = CompletionResponse(
            id: 'completion-1',
            timestamp: DateTime.now(),
            stopReason: 'end_turn',
          );

          final result = processor.processResponse(response, conversation);

          // Token counts should remain unchanged when null
          expect(result.updatedConversation.totalInputTokens, equals(50));
          expect(result.updatedConversation.totalOutputTokens, equals(25));
        });
      });

      group('ErrorResponse', () {
        test('marks turn as complete with error', () {
          final existingMessage = ConversationMessage.assistant(
            id: 'msg-1',
            responses: [
              TextResponse(
                id: 'text-1',
                timestamp: DateTime.now(),
                content: 'Starting...',
              ),
            ],
            isStreaming: true,
          );
          final conversation = Conversation(
            messages: [existingMessage],
            state: ConversationState.receivingResponse,
          );

          final response = ErrorResponse(
            id: 'error-1',
            timestamp: DateTime.now(),
            error: 'Rate limit exceeded',
            details: 'Too many requests',
          );

          final result = processor.processResponse(response, conversation);

          expect(result.turnComplete, isTrue);
          expect(result.updatedConversation.messages.last.isStreaming, isFalse);
          expect(result.updatedConversation.messages.last.isComplete, isTrue);
          expect(
            result.updatedConversation.messages.last.error,
            equals('Rate limit exceeded'),
          );
          expect(
            result.updatedConversation.state,
            equals(ConversationState.error),
          );
          expect(
            result.updatedConversation.currentError,
            equals('Rate limit exceeded'),
          );
        });

        test('creates new message when no existing assistant message', () {
          final conversation = Conversation.empty();
          final response = ErrorResponse(
            id: 'error-1',
            timestamp: DateTime.now(),
            error: 'Connection failed',
          );

          final result = processor.processResponse(response, conversation);

          expect(result.updatedConversation.messages.length, equals(1));
          expect(
            result.updatedConversation.messages.last.error,
            equals('Connection failed'),
          );
          expect(result.turnComplete, isTrue);
        });
      });

      group('StatusResponse', () {
        test('is ignored (returns unchanged conversation)', () {
          final existingMessage = ConversationMessage.assistant(
            id: 'msg-1',
            responses: [
              TextResponse(
                id: 'text-1',
                timestamp: DateTime.now(),
                content: 'Working...',
              ),
            ],
            isStreaming: true,
          );
          final conversation = Conversation(
            messages: [existingMessage],
            state: ConversationState.receivingResponse,
          );

          final response = StatusResponse(
            id: 'status-1',
            timestamp: DateTime.now(),
            status: ClaudeStatus.processing,
            message: 'Thinking...',
          );

          final result = processor.processResponse(response, conversation);

          // Status responses should not modify the conversation
          expect(result.updatedConversation.messages.length, equals(1));
          expect(
            result.updatedConversation.messages.last.responses.length,
            equals(1),
          );
          expect(result.turnComplete, isFalse);
        });
      });

      group('MetaResponse', () {
        test('is ignored (returns unchanged conversation)', () {
          final conversation = Conversation.empty();
          final response = MetaResponse(
            id: 'meta-1',
            timestamp: DateTime.now(),
            conversationId: 'conv-123',
            metadata: {'version': '1.0'},
          );

          final result = processor.processResponse(response, conversation);

          expect(result.updatedConversation.messages.isEmpty, isTrue);
          expect(result.turnComplete, isFalse);
        });
      });

      group('UnknownResponse', () {
        test('is ignored (returns unchanged conversation)', () {
          final conversation = Conversation.empty();
          final response = UnknownResponse(
            id: 'unknown-1',
            timestamp: DateTime.now(),
            rawData: {'type': 'future_type', 'data': 'value'},
          );

          final result = processor.processResponse(response, conversation);

          expect(result.updatedConversation.messages.isEmpty, isTrue);
          expect(result.turnComplete, isFalse);
        });
      });

      group('edge cases', () {
        test(
          'handles user message as last message (creates new assistant message)',
          () {
            final userMessage = ConversationMessage.user(content: 'Hello');
            final conversation = Conversation(
              messages: [userMessage],
              state: ConversationState.sendingMessage,
            );

            final response = TextResponse(
              id: 'text-1',
              timestamp: DateTime.now(),
              content: 'Hi there!',
            );

            final result = processor.processResponse(response, conversation);

            expect(result.updatedConversation.messages.length, equals(2));
            expect(
              result.updatedConversation.messages.first.role,
              equals(MessageRole.user),
            );
            expect(
              result.updatedConversation.messages.last.role,
              equals(MessageRole.assistant),
            );
          },
        );

        test('handles multiple sequential text responses', () {
          var conversation = Conversation.empty();

          // First text response
          final response1 = TextResponse(
            id: 'text-1',
            timestamp: DateTime.now(),
            content: 'Hello, ',
          );
          var result = processor.processResponse(response1, conversation);
          conversation = result.updatedConversation;

          // Second text response
          final response2 = TextResponse(
            id: 'text-2',
            timestamp: DateTime.now(),
            content: 'how are ',
          );
          result = processor.processResponse(response2, conversation);
          conversation = result.updatedConversation;

          // Third text response
          final response3 = TextResponse(
            id: 'text-3',
            timestamp: DateTime.now(),
            content: 'you?',
          );
          result = processor.processResponse(response3, conversation);
          conversation = result.updatedConversation;

          expect(conversation.messages.length, equals(1));
          expect(
            conversation.messages.last.content,
            equals('Hello, how are you?'),
          );
          expect(conversation.messages.last.responses.length, equals(3));
        });

        test('handles interleaved text and tool responses', () {
          var conversation = Conversation.empty();

          // Text response
          final textResponse = TextResponse(
            id: 'text-1',
            timestamp: DateTime.now(),
            content: 'Let me read that file.',
          );
          var result = processor.processResponse(textResponse, conversation);
          conversation = result.updatedConversation;

          // Tool use response
          final toolUseResponse = ToolUseResponse(
            id: 'tool-1',
            timestamp: DateTime.now(),
            toolName: 'Read',
            parameters: {'file_path': '/test.txt'},
            toolUseId: 'call-1',
          );
          result = processor.processResponse(toolUseResponse, conversation);
          conversation = result.updatedConversation;

          // Tool result response
          final toolResultResponse = ToolResultResponse(
            id: 'result-1',
            timestamp: DateTime.now(),
            toolUseId: 'call-1',
            content: 'File contents',
            isError: false,
          );
          result = processor.processResponse(toolResultResponse, conversation);
          conversation = result.updatedConversation;

          // More text response
          final moreTextResponse = TextResponse(
            id: 'text-2',
            timestamp: DateTime.now(),
            content: ' The file contains: File contents',
          );
          result = processor.processResponse(moreTextResponse, conversation);
          conversation = result.updatedConversation;

          expect(conversation.messages.length, equals(1));
          expect(conversation.messages.last.responses.length, equals(4));
          expect(conversation.messages.last.toolInvocations.length, equals(1));
          expect(
            conversation.messages.last.toolInvocations.first.toolResult,
            isNotNull,
          );
        });
      });
    });
  });

  group('ProcessResult', () {
    test('stores updatedConversation and turnComplete correctly', () {
      final conversation = Conversation.empty();
      final result = ProcessResult(
        updatedConversation: conversation,
        turnComplete: true,
      );

      expect(result.updatedConversation, equals(conversation));
      expect(result.turnComplete, isTrue);
    });
  });

  group('Compaction flow', () {
    late ResponseProcessor processor;

    setUp(() {
      processor = ResponseProcessor();
    });

    test('CompactBoundaryResponse adds compact boundary message', () {
      final conversation = Conversation.empty();
      final response = CompactBoundaryResponse(
        id: 'compact-1',
        timestamp: DateTime.now(),
        trigger: 'manual',
        preTokens: 47000,
      );

      final result = processor.processResponse(response, conversation);

      expect(result.updatedConversation.messages.length, equals(1));
      final message = result.updatedConversation.messages.first;
      expect(message.role, equals(MessageRole.system));
      expect(message.messageType, equals(MessageType.compactBoundary));
      expect(message.content, contains('Compacted'));
      expect(message.content, contains('manual'));
      expect(result.turnComplete, isFalse);
    });

    test('UserMessageResponse adds user message to conversation', () {
      final conversation = Conversation.empty();
      final response = UserMessageResponse(
        id: 'user-1',
        timestamp: DateTime.now(),
        content: 'This is the continuation summary...',
      );

      final result = processor.processResponse(response, conversation);

      expect(result.updatedConversation.messages.length, equals(1));
      final message = result.updatedConversation.messages.first;
      expect(message.role, equals(MessageRole.user));
      expect(message.content, equals('This is the continuation summary...'));
      expect(result.turnComplete, isFalse);
    });

    test('full compaction flow: compact_boundary followed by user summary', () {
      var conversation = Conversation.empty();

      // 1. Receive compact_boundary
      final compactBoundary = CompactBoundaryResponse(
        id: 'compact-1',
        timestamp: DateTime.now(),
        trigger: 'manual',
        preTokens: 47000,
      );
      var result = processor.processResponse(compactBoundary, conversation);
      conversation = result.updatedConversation;

      expect(conversation.messages.length, equals(1));
      expect(conversation.messages[0].role, equals(MessageRole.system));
      expect(
        conversation.messages[0].messageType,
        equals(MessageType.compactBoundary),
      );
      expect(conversation.messages[0].content, contains('Compacted'));

      // 2. Receive continuation summary (user message)
      final userSummary = UserMessageResponse(
        id: 'user-1',
        timestamp: DateTime.now(),
        content:
            'This session is being continued from a previous conversation...',
      );
      result = processor.processResponse(userSummary, conversation);
      conversation = result.updatedConversation;

      expect(conversation.messages.length, equals(2));
      expect(conversation.messages[1].role, equals(MessageRole.user));
      expect(
        conversation.messages[1].content,
        contains('continued from a previous'),
      );
    });

    test('e2e: parse streaming JSON and process through ResponseProcessor', () {
      // Actual streaming JSON from Claude CLI during compaction
      final compactBoundaryJson = {
        'type': 'system',
        'subtype': 'compact_boundary',
        'session_id': 'test-session',
        'uuid': 'compact-uuid-123',
        'compact_metadata': {'trigger': 'manual', 'pre_tokens': 51185},
      };

      final userSummaryJson = {
        'type': 'user',
        'message': {
          'role': 'user',
          'content':
              'This session is being continued from a previous conversation that ran out of context. The conversation is summarized below:\nAnalysis: ...',
        },
        'session_id': 'test-session',
        'parent_tool_use_id': null,
        'uuid': 'user-uuid-456',
        'isReplay': false,
      };

      // Parse responses
      final compactResponse = ClaudeResponse.fromJson(compactBoundaryJson);
      final userResponse = ClaudeResponse.fromJson(userSummaryJson);

      // Verify parsing
      expect(compactResponse, isA<CompactBoundaryResponse>());
      expect(userResponse, isA<UserMessageResponse>());

      final compactBoundary = compactResponse as CompactBoundaryResponse;
      expect(compactBoundary.trigger, equals('manual'));
      expect(compactBoundary.preTokens, equals(51185));

      final userMessage = userResponse as UserMessageResponse;
      expect(
        userMessage.content,
        contains('continued from a previous conversation'),
      );

      // Process through ResponseProcessor
      var conversation = Conversation.empty();

      var result = processor.processResponse(compactResponse, conversation);
      conversation = result.updatedConversation;

      result = processor.processResponse(userResponse, conversation);
      conversation = result.updatedConversation;

      // Verify final state
      expect(conversation.messages.length, equals(2));
      expect(
        conversation.messages[0].role,
        equals(MessageRole.system),
      ); // compact boundary
      expect(
        conversation.messages[0].messageType,
        equals(MessageType.compactBoundary),
      );
      expect(conversation.messages[0].content, contains('Compacted'));
      expect(
        conversation.messages[1].role,
        equals(MessageRole.user),
      ); // continuation summary
      expect(
        conversation.messages[1].content,
        contains('continued from a previous'),
      );
    });

    test(
      'e2e: user message without isCompactSummary flag is still processed',
      () {
        // This is the key test - streaming doesn't include isCompactSummary flag
        final userJson = {
          'type': 'user',
          'message': {'role': 'user', 'content': 'Some user message content'},
          'session_id': 'test-session',
          'uuid': 'user-123',
          // Note: NO isCompactSummary field!
        };

        final response = ClaudeResponse.fromJson(userJson);

        // Should be parsed as UserMessageResponse (not UnknownResponse!)
        expect(response, isA<UserMessageResponse>());
        expect(response, isNot(isA<UnknownResponse>()));

        final userMessage = response as UserMessageResponse;
        expect(userMessage.content, equals('Some user message content'));

        // Process it
        final conversation = Conversation.empty();
        final result = processor.processResponse(response, conversation);

        // Should be added to conversation
        expect(result.updatedConversation.messages.length, equals(1));
        expect(
          result.updatedConversation.messages[0].role,
          equals(MessageRole.user),
        );
        expect(
          result.updatedConversation.messages[0].content,
          equals('Some user message content'),
        );
      },
    );
  });
}
