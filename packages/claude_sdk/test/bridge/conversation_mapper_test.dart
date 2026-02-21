import 'package:agent_sdk/agent_sdk.dart';
import 'package:claude_sdk/src/bridge/type_mappers.dart';
import 'package:claude_sdk/src/models/conversation.dart' as claude;
import 'package:claude_sdk/src/models/response.dart' as claude;
import 'package:test/test.dart';

void main() {
  final now = DateTime.now();

  group('AgentConversationMapper.toClaude', () {
    test('maps empty AgentConversation', () {
      final agent = AgentConversation(
        messages: [],
        state: AgentConversationState.idle,
      );

      final result = AgentConversationMapper.toClaude(agent);

      expect(result.messages, isEmpty);
      expect(result.state, claude.ConversationState.idle);
    });

    test('maps all conversation states', () {
      for (final agentState in AgentConversationState.values) {
        final agent = AgentConversation(
          messages: [],
          state: agentState,
        );
        final result = AgentConversationMapper.toClaude(agent);
        // Just ensure it maps without error
        expect(result.state, isA<claude.ConversationState>());
      }
    });

    test('maps token usage fields', () {
      final agent = AgentConversation(
        messages: [],
        state: AgentConversationState.idle,
        totalInputTokens: 100,
        totalOutputTokens: 200,
        totalCacheReadInputTokens: 50,
        totalCacheCreationInputTokens: 25,
        totalCostUsd: 0.05,
        currentContextInputTokens: 80,
        currentContextCacheReadTokens: 40,
        currentContextCacheCreationTokens: 20,
      );

      final result = AgentConversationMapper.toClaude(agent);

      expect(result.totalInputTokens, 100);
      expect(result.totalOutputTokens, 200);
      expect(result.totalCacheReadInputTokens, 50);
      expect(result.totalCacheCreationInputTokens, 25);
      expect(result.totalCostUsd, 0.05);
      expect(result.currentContextInputTokens, 80);
      expect(result.currentContextCacheReadTokens, 40);
      expect(result.currentContextCacheCreationTokens, 20);
    });

    test('roundtrips: fromClaude then toClaude preserves data', () {
      final original = claude.Conversation(
        messages: [
          claude.ConversationMessage(
            id: 'msg-1',
            role: claude.MessageRole.user,
            content: 'Hello',
            timestamp: now,
            isComplete: true,
            messageType: claude.MessageType.userMessage,
          ),
        ],
        state: claude.ConversationState.idle,
        totalInputTokens: 42,
        totalOutputTokens: 84,
      );

      final agent = AgentConversationMapper.fromClaude(original);
      final roundtripped = AgentConversationMapper.toClaude(agent);

      expect(roundtripped.messages.length, 1);
      expect(roundtripped.messages.first.id, 'msg-1');
      expect(roundtripped.messages.first.content, 'Hello');
      expect(roundtripped.state, claude.ConversationState.idle);
      expect(roundtripped.totalInputTokens, 42);
      expect(roundtripped.totalOutputTokens, 84);
    });
  });

  group('AgentConversationMessageMapper.toClaude', () {
    test('maps basic message fields', () {
      final agent = AgentConversationMessage(
        id: 'test-id',
        role: AgentMessageRole.user,
        content: 'Hello world',
        timestamp: now,
        isStreaming: false,
        isComplete: true,
        messageType: AgentMessageType.userMessage,
      );

      final result = AgentConversationMessageMapper.toClaude(agent);

      expect(result.id, 'test-id');
      expect(result.role, claude.MessageRole.user);
      expect(result.content, 'Hello world');
      expect(result.isComplete, true);
    });

    test('maps all message roles', () {
      for (final role in AgentMessageRole.values) {
        final agent = AgentConversationMessage(
          id: 'id',
          role: role,
          content: '',
          timestamp: now,
        );
        final result = AgentConversationMessageMapper.toClaude(agent);
        expect(result.role, isA<claude.MessageRole>());
      }
    });

    test('maps token usage', () {
      final agent = AgentConversationMessage(
        id: 'id',
        role: AgentMessageRole.assistant,
        content: 'response',
        timestamp: now,
        tokenUsage: TokenUsage(
          inputTokens: 10,
          outputTokens: 20,
          cacheReadInputTokens: 5,
          cacheCreationInputTokens: 3,
        ),
      );

      final result = AgentConversationMessageMapper.toClaude(agent);

      expect(result.tokenUsage, isNotNull);
      expect(result.tokenUsage!.inputTokens, 10);
      expect(result.tokenUsage!.outputTokens, 20);
    });

    test('maps null token usage', () {
      final agent = AgentConversationMessage(
        id: 'id',
        role: AgentMessageRole.user,
        content: '',
        timestamp: now,
      );

      final result = AgentConversationMessageMapper.toClaude(agent);
      expect(result.tokenUsage, isNull);
    });

    test('maps attachments', () {
      final agent = AgentConversationMessage(
        id: 'id',
        role: AgentMessageRole.user,
        content: '',
        timestamp: now,
        attachments: [
          AgentAttachment(type: 'file', path: '/tmp/test.txt'),
        ],
      );

      final result = AgentConversationMessageMapper.toClaude(agent);
      expect(result.attachments, isNotNull);
      expect(result.attachments!.length, 1);
      expect(result.attachments!.first.type, 'file');
      expect(result.attachments!.first.path, '/tmp/test.txt');
    });

    test('maps null attachments', () {
      final agent = AgentConversationMessage(
        id: 'id',
        role: AgentMessageRole.user,
        content: '',
        timestamp: now,
      );

      final result = AgentConversationMessageMapper.toClaude(agent);
      expect(result.attachments, isNull);
    });
  });

  group('AgentResponseMapper.toClaude', () {
    test('maps AgentTextResponse', () {
      final agent = AgentTextResponse(
        id: 'r1',
        timestamp: now,
        content: 'Hello',
        isPartial: true,
        isCumulative: false,
      );

      final result = AgentResponseMapper.toClaude(agent);

      expect(result, isA<claude.TextResponse>());
      final text = result as claude.TextResponse;
      expect(text.id, 'r1');
      expect(text.content, 'Hello');
      expect(text.isPartial, true);
    });

    test('maps AgentToolUseResponse', () {
      final agent = AgentToolUseResponse(
        id: 'r2',
        timestamp: now,
        toolName: 'Read',
        parameters: {'file_path': '/tmp/test'},
        toolUseId: 'tu-1',
      );

      final result = AgentResponseMapper.toClaude(agent);

      expect(result, isA<claude.ToolUseResponse>());
      final toolUse = result as claude.ToolUseResponse;
      expect(toolUse.toolName, 'Read');
      expect(toolUse.parameters, {'file_path': '/tmp/test'});
      expect(toolUse.toolUseId, 'tu-1');
    });

    test('maps AgentToolResultResponse', () {
      final agent = AgentToolResultResponse(
        id: 'r3',
        timestamp: now,
        toolUseId: 'tu-1',
        content: 'file contents',
        isError: false,
        stdout: 'output',
        stderr: 'errors',
      );

      final result = AgentResponseMapper.toClaude(agent);

      expect(result, isA<claude.ToolResultResponse>());
      final toolResult = result as claude.ToolResultResponse;
      expect(toolResult.toolUseId, 'tu-1');
      expect(toolResult.content, 'file contents');
      expect(toolResult.isError, false);
    });

    test('maps AgentCompletionResponse', () {
      final agent = AgentCompletionResponse(
        id: 'r4',
        timestamp: now,
        stopReason: 'end_turn',
        inputTokens: 100,
        outputTokens: 200,
        durationApiMs: 500,
      );

      final result = AgentResponseMapper.toClaude(agent);

      expect(result, isA<claude.CompletionResponse>());
      final completion = result as claude.CompletionResponse;
      expect(completion.stopReason, 'end_turn');
      expect(completion.inputTokens, 100);
      expect(completion.outputTokens, 200);
    });

    test('maps AgentErrorResponse', () {
      final agent = AgentErrorResponse(
        id: 'r5',
        timestamp: now,
        error: 'something failed',
        details: 'details here',
        code: 'ERR_001',
      );

      final result = AgentResponseMapper.toClaude(agent);

      expect(result, isA<claude.ErrorResponse>());
      final error = result as claude.ErrorResponse;
      expect(error.error, 'something failed');
      expect(error.details, 'details here');
      expect(error.code, 'ERR_001');
    });

    test('maps AgentApiErrorResponse', () {
      final agent = AgentApiErrorResponse(
        id: 'r6',
        timestamp: now,
        level: 'error',
        message: 'rate limited',
        errorType: 'rate_limit_error',
        retryInMs: 5000,
        retryAttempt: 1,
        maxRetries: 3,
      );

      final result = AgentResponseMapper.toClaude(agent);

      expect(result, isA<claude.ApiErrorResponse>());
      final apiError = result as claude.ApiErrorResponse;
      expect(apiError.level, 'error');
      expect(apiError.retryInMs, 5000);
    });

    test('maps AgentContextCompactedResponse', () {
      final agent = AgentContextCompactedResponse(
        id: 'r7',
        timestamp: now,
        trigger: 'auto',
        preTokens: 50000,
      );

      final result = AgentResponseMapper.toClaude(agent);

      expect(result, isA<claude.CompactBoundaryResponse>());
      final compact = result as claude.CompactBoundaryResponse;
      expect(compact.trigger, 'auto');
      expect(compact.preTokens, 50000);
    });

    test('maps AgentUserMessageResponse', () {
      final agent = AgentUserMessageResponse(
        id: 'r8',
        timestamp: now,
        content: 'user said this',
        isReplay: true,
      );

      final result = AgentResponseMapper.toClaude(agent);

      expect(result, isA<claude.UserMessageResponse>());
      final userMsg = result as claude.UserMessageResponse;
      expect(userMsg.content, 'user said this');
      expect(userMsg.isReplay, true);
    });

    test('maps AgentUnknownResponse', () {
      final agent = AgentUnknownResponse(
        id: 'r9',
        timestamp: now,
        rawData: {'type': 'foo'},
      );

      final result = AgentResponseMapper.toClaude(agent);

      expect(result, isA<claude.UnknownResponse>());
    });

    test('roundtrips: fromClaude then toClaude for TextResponse', () {
      final original = claude.TextResponse(
        id: 'orig',
        timestamp: now,
        content: 'test content',
        isPartial: false,
        isCumulative: true,
      );

      final agent = AgentResponseMapper.fromClaude(original);
      final roundtripped = AgentResponseMapper.toClaude(agent);

      expect(roundtripped, isA<claude.TextResponse>());
      final text = roundtripped as claude.TextResponse;
      expect(text.id, 'orig');
      expect(text.content, 'test content');
    });
  });
}
