import 'package:test/test.dart';
import 'package:vide_interface/vide_interface.dart';

void main() {
  group('ConversationStateManager event ordering', () {
    late ConversationStateManager manager;

    setUp(() {
      manager = ConversationStateManager();
    });

    tearDown(() {
      manager.dispose();
    });

    test(
      'message is finalized before tool-use event arrives (correct ordering)',
      () {
        // Simulate the CORRECT event ordering:
        // 1. MessageEvent(isPartial: true) - streaming text
        // 2. MessageEvent(isPartial: true) - more streaming text
        // 3. MessageEvent(isPartial: false) - text finalized
        // 4. ToolUseEvent - tool call after text is done

        manager.handleEvent(
          MessageEvent(
            agentId: 'agent-1',
            agentType: 'main',
            eventId: 'msg-1',
            role: 'assistant',
            content: 'Let me ',
            isPartial: true,
          ),
        );

        manager.handleEvent(
          MessageEvent(
            agentId: 'agent-1',
            agentType: 'main',
            eventId: 'msg-1',
            role: 'assistant',
            content: 'read that file.',
            isPartial: true,
          ),
        );

        // Finalize the text block before the tool use
        manager.handleEvent(
          MessageEvent(
            agentId: 'agent-1',
            agentType: 'main',
            eventId: 'msg-1',
            role: 'assistant',
            content: '',
            isPartial: false,
          ),
        );

        // Now the tool use arrives
        manager.handleEvent(
          ToolUseEvent(
            agentId: 'agent-1',
            agentType: 'main',
            toolUseId: 'tool-1',
            toolName: 'Read',
            toolInput: {'file_path': '/foo/bar.dart'},
          ),
        );

        final state = manager.getAgentState('agent-1');
        expect(state, isNotNull);
        expect(state!.messages, hasLength(1));

        final msg = state.messages.first;
        expect(msg.role, 'assistant');
        expect(msg.content, hasLength(2)); // TextContent + ToolContent

        // Text should be finalized (not streaming)
        final textContent = msg.content[0] as TextContent;
        expect(textContent.text, 'Let me read that file.');
        expect(textContent.isStreaming, isFalse);

        // Tool should be present
        final toolContent = msg.content[1] as ToolContent;
        expect(toolContent.toolName, 'Read');
        expect(toolContent.isExecuting, isTrue);
      },
    );

    test(
      'text content is streaming when tool-use arrives without finalization (bug scenario)',
      () {
        // Simulate the BUGGY ordering (before the fix):
        // 1. MessageEvent(isPartial: true) - streaming text
        // 2. ToolUseEvent - tool call BEFORE text is finalized

        manager.handleEvent(
          MessageEvent(
            agentId: 'agent-1',
            agentType: 'main',
            eventId: 'msg-1',
            role: 'assistant',
            content: 'Let me read that.',
            isPartial: true,
          ),
        );

        // Tool use without prior finalization
        manager.handleEvent(
          ToolUseEvent(
            agentId: 'agent-1',
            agentType: 'main',
            toolUseId: 'tool-1',
            toolName: 'Read',
            toolInput: {'file_path': '/foo/bar.dart'},
          ),
        );

        final state = manager.getAgentState('agent-1');
        expect(state, isNotNull);
        expect(state!.messages, hasLength(1));

        final msg = state.messages.first;
        expect(msg.content, hasLength(2));

        // ConversationStateManager's _handleToolUse marks streaming text as done
        // (this is the defensive fix in the consumer), but the event stream
        // itself had incorrect ordering
        final textContent = msg.content[0] as TextContent;
        expect(textContent.text, 'Let me read that.');
        expect(
          textContent.isStreaming,
          isFalse,
          reason:
              'ConversationStateManager defensively finalizes text on tool-use',
        );
      },
    );

    test('multiple tool calls interleaved with text', () {
      // Simulate: text → finalize → tool1 → tool1 result → text → finalize → tool2

      // First text block
      manager.handleEvent(
        MessageEvent(
          agentId: 'agent-1',
          agentType: 'main',
          eventId: 'msg-1',
          role: 'assistant',
          content: 'First text.',
          isPartial: true,
        ),
      );

      // Finalize before tool
      manager.handleEvent(
        MessageEvent(
          agentId: 'agent-1',
          agentType: 'main',
          eventId: 'msg-1',
          role: 'assistant',
          content: '',
          isPartial: false,
        ),
      );

      // Tool 1
      manager.handleEvent(
        ToolUseEvent(
          agentId: 'agent-1',
          agentType: 'main',
          toolUseId: 'tool-1',
          toolName: 'Read',
          toolInput: {'file_path': '/a.dart'},
        ),
      );

      // Tool 1 result
      manager.handleEvent(
        ToolResultEvent(
          agentId: 'agent-1',
          agentType: 'main',
          toolUseId: 'tool-1',
          toolName: 'Read',
          result: 'file contents',
          isError: false,
        ),
      );

      // Second text block (same message, new event ID for the new text segment)
      manager.handleEvent(
        MessageEvent(
          agentId: 'agent-1',
          agentType: 'main',
          eventId: 'msg-2',
          role: 'assistant',
          content: 'Second text.',
          isPartial: true,
        ),
      );

      // Finalize before tool
      manager.handleEvent(
        MessageEvent(
          agentId: 'agent-1',
          agentType: 'main',
          eventId: 'msg-2',
          role: 'assistant',
          content: '',
          isPartial: false,
        ),
      );

      // Tool 2
      manager.handleEvent(
        ToolUseEvent(
          agentId: 'agent-1',
          agentType: 'main',
          toolUseId: 'tool-2',
          toolName: 'Write',
          toolInput: {'file_path': '/b.dart'},
        ),
      );

      final state = manager.getAgentState('agent-1');
      expect(state, isNotNull);
      // Consecutive assistant messages are merged into a single entry
      // so that interleaved text/tool sequences render with consistent spacing.
      expect(state!.messages, hasLength(1));

      final msg = state.messages[0];
      // text1 + tool1 + text2 + tool2
      expect(msg.content, hasLength(4));
      expect((msg.content[0] as TextContent).text, 'First text.');
      expect((msg.content[0] as TextContent).isStreaming, isFalse);
      expect((msg.content[1] as ToolContent).toolName, 'Read');
      expect((msg.content[1] as ToolContent).result, 'file contents');
      expect((msg.content[2] as TextContent).text, 'Second text.');
      expect((msg.content[2] as TextContent).isStreaming, isFalse);
      expect((msg.content[3] as ToolContent).toolName, 'Write');
    });

    test('turn complete finalizes any remaining streaming text', () {
      manager.handleEvent(
        MessageEvent(
          agentId: 'agent-1',
          agentType: 'main',
          eventId: 'msg-1',
          role: 'assistant',
          content: 'Still streaming...',
          isPartial: true,
        ),
      );

      var state = manager.getAgentState('agent-1');
      var textContent = state!.messages.last.content.first as TextContent;
      expect(textContent.isStreaming, isTrue);

      // Turn complete should finalize
      manager.handleEvent(
        TurnCompleteEvent(
          agentId: 'agent-1',
          agentType: 'main',
          reason: 'end_turn',
        ),
      );

      state = manager.getAgentState('agent-1');
      textContent = state!.messages.last.content.first as TextContent;
      expect(textContent.isStreaming, isFalse);
    });
  });
}
