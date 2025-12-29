import 'package:test/test.dart';
import 'package:claude_sdk/claude_sdk.dart';
import 'package:vide_server/services/streaming_delta_handler.dart';

Conversation _createConversation({
  List<ConversationMessage>? messages,
  String? error,
}) {
  return Conversation(
    messages: messages ?? [],
    state: ConversationState.idle,
    currentError: error,
  );
}

ConversationMessage _createMessage({
  required MessageRole role,
  required String content,
  List<ClaudeResponse>? responses,
}) {
  return ConversationMessage(
    id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
    role: role,
    content: content,
    timestamp: DateTime.now(),
    responses: responses ?? [],
  );
}

ToolUseResponse _createToolUse({
  required String toolName,
  String? toolUseId,
  Map<String, dynamic>? parameters,
}) {
  return ToolUseResponse(
    id: 'resp-${DateTime.now().millisecondsSinceEpoch}',
    timestamp: DateTime.now(),
    toolName: toolName,
    toolUseId: toolUseId,
    parameters: parameters ?? {},
  );
}

ToolResultResponse _createToolResult({
  required String toolUseId,
  required String content,
  bool isError = false,
}) {
  return ToolResultResponse(
    id: 'resp-${DateTime.now().millisecondsSinceEpoch}',
    timestamp: DateTime.now(),
    toolUseId: toolUseId,
    content: content,
    isError: isError,
  );
}

void main() {
  group('StreamingDeltaHandler', () {
    late StreamingDeltaHandler handler;
    late StreamingState state;

    setUp(() {
      handler = StreamingDeltaHandler();
      state = StreamingState();
    });

    group('handleUpdate', () {
      test('returns empty list for empty conversation', () {
        final conversation = _createConversation();
        final events = handler.handleUpdate(conversation, state);
        expect(events, isEmpty);
      });

      test('sends full message event for new message', () {
        final conversation = _createConversation(
          messages: [_createMessage(role: MessageRole.user, content: 'Hello')],
        );

        final events = handler.handleUpdate(conversation, state);

        expect(events, hasLength(1));
        expect(events.first, isA<MessageEvent>());
        final event = events.first as MessageEvent;
        expect(event.role, equals('user'));
        expect(event.content, equals('Hello'));
      });

      test('sends delta for same message with more content', () {
        // First update: message starts
        final conversation1 = _createConversation(
          messages: [
            _createMessage(role: MessageRole.assistant, content: 'Hello'),
          ],
        );
        handler.handleUpdate(conversation1, state);

        // Second update: message grows
        final conversation2 = _createConversation(
          messages: [
            _createMessage(role: MessageRole.assistant, content: 'Hello world'),
          ],
        );
        final events = handler.handleUpdate(conversation2, state);

        expect(events, hasLength(1));
        expect(events.first, isA<MessageDeltaEvent>());
        final event = events.first as MessageDeltaEvent;
        expect(event.role, equals('assistant'));
        expect(event.delta, equals(' world'));
      });

      test('ignores update when content unchanged', () {
        // First update
        final conversation = _createConversation(
          messages: [
            _createMessage(role: MessageRole.assistant, content: 'Hello'),
          ],
        );
        handler.handleUpdate(conversation, state);

        // Same content again
        final events = handler.handleUpdate(conversation, state);
        expect(events, isEmpty);
      });

      test('handles empty message content', () {
        final conversation = _createConversation(
          messages: [_createMessage(role: MessageRole.assistant, content: '')],
        );

        final events = handler.handleUpdate(conversation, state);

        // No message event for empty content, but state should update
        expect(events, isEmpty);
        expect(state.lastMessageCount, equals(1));
      });

      test('handles rapid successive updates correctly', () {
        // Simulate rapid streaming chunks
        final events = <StreamingEvent>[];

        final conv1 = _createConversation(
          messages: [_createMessage(role: MessageRole.assistant, content: 'A')],
        );
        events.addAll(handler.handleUpdate(conv1, state));

        final conv2 = _createConversation(
          messages: [
            _createMessage(role: MessageRole.assistant, content: 'AB'),
          ],
        );
        events.addAll(handler.handleUpdate(conv2, state));

        final conv3 = _createConversation(
          messages: [
            _createMessage(role: MessageRole.assistant, content: 'ABC'),
          ],
        );
        events.addAll(handler.handleUpdate(conv3, state));

        expect(events, hasLength(3));
        expect(events[0], isA<MessageEvent>());
        expect((events[0] as MessageEvent).content, equals('A'));
        expect(events[1], isA<MessageDeltaEvent>());
        expect((events[1] as MessageDeltaEvent).delta, equals('B'));
        expect(events[2], isA<MessageDeltaEvent>());
        expect((events[2] as MessageDeltaEvent).delta, equals('C'));
      });

      test('sends tool events only for new messages', () {
        // First message with tool use
        final conv1 = _createConversation(
          messages: [
            _createMessage(
              role: MessageRole.assistant,
              content: 'Using tool',
              responses: [
                _createToolUse(
                  toolName: 'testTool',
                  toolUseId: 'tool-1',
                  parameters: {'param': 'value'},
                ),
              ],
            ),
          ],
        );
        final events1 = handler.handleUpdate(conv1, state);

        expect(events1, hasLength(2)); // message + tool_use
        expect(events1[0], isA<MessageEvent>());
        expect(events1[1], isA<ToolUseEvent>());
        final toolEvent = events1[1] as ToolUseEvent;
        expect(toolEvent.toolName, equals('testTool'));

        // Same message grows - no new tool events
        final conv2 = _createConversation(
          messages: [
            _createMessage(
              role: MessageRole.assistant,
              content: 'Using tool now',
              responses: [
                _createToolUse(
                  toolName: 'testTool',
                  toolUseId: 'tool-1',
                  parameters: {'param': 'value'},
                ),
              ],
            ),
          ],
        );
        final events2 = handler.handleUpdate(conv2, state);

        expect(events2, hasLength(1)); // only delta
        expect(events2[0], isA<MessageDeltaEvent>());
      });

      test('sends error event when conversation has error', () {
        final conversation = _createConversation(
          messages: [
            _createMessage(role: MessageRole.assistant, content: 'Partial'),
          ],
          error: 'Connection failed',
        );

        final events = handler.handleUpdate(conversation, state);

        expect(events, hasLength(2)); // message + error
        expect(events[1], isA<ErrorEvent>());
        expect((events[1] as ErrorEvent).message, equals('Connection failed'));
      });

      test('handles new message after previous message complete', () {
        // First message
        final conv1 = _createConversation(
          messages: [_createMessage(role: MessageRole.user, content: 'Hi')],
        );
        handler.handleUpdate(conv1, state);

        // Second message
        final conv2 = _createConversation(
          messages: [
            _createMessage(role: MessageRole.user, content: 'Hi'),
            _createMessage(role: MessageRole.assistant, content: 'Hello!'),
          ],
        );
        final events = handler.handleUpdate(conv2, state);

        expect(events, hasLength(1));
        expect(events.first, isA<MessageEvent>());
        final event = events.first as MessageEvent;
        expect(event.role, equals('assistant'));
        expect(event.content, equals('Hello!'));
      });
    });

    group('StreamingState', () {
      test('tracks message count and content length', () {
        final state = StreamingState();
        expect(state.lastMessageCount, equals(0));
        expect(state.lastContentLength, equals(0));

        state.lastMessageCount = 2;
        state.lastContentLength = 100;

        expect(state.lastMessageCount, equals(2));
        expect(state.lastContentLength, equals(100));
      });

      test('reset clears state', () {
        final state = StreamingState();
        state.lastMessageCount = 5;
        state.lastContentLength = 500;

        state.reset();

        expect(state.lastMessageCount, equals(0));
        expect(state.lastContentLength, equals(0));
      });
    });

    group('sendFullState', () {
      test('returns empty list for empty conversation', () {
        final conversation = _createConversation();
        final events = handler.sendFullState(conversation);
        expect(events, isEmpty);
      });

      test('sends all messages in order', () {
        final conversation = _createConversation(
          messages: [
            _createMessage(role: MessageRole.user, content: 'Question'),
            _createMessage(role: MessageRole.assistant, content: 'Answer'),
            _createMessage(role: MessageRole.user, content: 'Follow-up'),
          ],
        );

        final events = handler.sendFullState(conversation);

        expect(events, hasLength(3));
        expect((events[0] as MessageEvent).content, equals('Question'));
        expect((events[1] as MessageEvent).content, equals('Answer'));
        expect((events[2] as MessageEvent).content, equals('Follow-up'));
      });

      test('sends tool events for each message', () {
        final conversation = _createConversation(
          messages: [
            _createMessage(
              role: MessageRole.assistant,
              content: 'Using tools',
              responses: [
                _createToolUse(toolName: 'tool1', toolUseId: 't1'),
                _createToolResult(toolUseId: 't1', content: 'result1'),
              ],
            ),
          ],
        );

        final events = handler.sendFullState(conversation);

        expect(events, hasLength(3)); // message + tool_use + tool_result
        expect(events[1], isA<ToolUseEvent>());
        expect(events[2], isA<ToolResultEvent>());
      });

      test('skips messages with empty content', () {
        final conversation = _createConversation(
          messages: [
            _createMessage(role: MessageRole.user, content: ''),
            _createMessage(role: MessageRole.assistant, content: 'Response'),
          ],
        );

        final events = handler.sendFullState(conversation);

        expect(events, hasLength(1));
        expect((events[0] as MessageEvent).content, equals('Response'));
      });

      test('sends error if present', () {
        final conversation = _createConversation(
          messages: [_createMessage(role: MessageRole.user, content: 'Test')],
          error: 'Something went wrong',
        );

        final events = handler.sendFullState(conversation);

        expect(events.last, isA<ErrorEvent>());
        expect(
          (events.last as ErrorEvent).message,
          equals('Something went wrong'),
        );
      });
    });

    group('tool name tracking', () {
      test('tracks tool name from tool_use for later tool_result', () {
        final conversation = _createConversation(
          messages: [
            _createMessage(
              role: MessageRole.assistant,
              content: 'Using tool',
              responses: [
                _createToolUse(
                  toolName: 'mySpecialTool',
                  toolUseId: 'unique-id-123',
                  parameters: {'key': 'value'},
                ),
              ],
            ),
          ],
        );

        handler.handleUpdate(conversation, state);

        expect(handler.getToolName('unique-id-123'), equals('mySpecialTool'));
      });

      test('returns unknown for untracked tool use ID', () {
        expect(handler.getToolName('non-existent'), equals('unknown'));
      });

      test('returns unknown for null tool use ID', () {
        expect(handler.getToolName(null), equals('unknown'));
      });

      test('tool_result includes correct tool name from tracking', () {
        // First update with tool use
        final conv1 = _createConversation(
          messages: [
            _createMessage(
              role: MessageRole.assistant,
              content: 'Starting',
              responses: [
                _createToolUse(
                  toolName: 'readFile',
                  toolUseId: 'read-123',
                  parameters: {'path': '/tmp/test'},
                ),
              ],
            ),
          ],
        );
        handler.handleUpdate(conv1, state);

        // Second message with tool result
        final conv2 = _createConversation(
          messages: [
            _createMessage(
              role: MessageRole.assistant,
              content: 'Starting',
              responses: [
                _createToolUse(
                  toolName: 'readFile',
                  toolUseId: 'read-123',
                  parameters: {'path': '/tmp/test'},
                ),
              ],
            ),
            _createMessage(
              role: MessageRole.assistant,
              content: 'Done',
              responses: [
                _createToolResult(
                  toolUseId: 'read-123',
                  content: 'file contents',
                ),
              ],
            ),
          ],
        );
        final events = handler.handleUpdate(conv2, state);

        // Find the tool result event
        final toolResultEvents = events.whereType<ToolResultEvent>().toList();
        expect(toolResultEvents, hasLength(1));
        expect(toolResultEvents.first.toolName, equals('readFile'));
        expect(toolResultEvents.first.toolUseId, equals('read-123'));
      });
    });
  });
}
