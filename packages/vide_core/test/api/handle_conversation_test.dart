/// Tests for LocalVideSession._handleConversation behavior.
///
/// Since _handleConversation is private and requires a full ProviderContainer,
/// these tests verify that ConversationStateManager correctly builds
/// ToolContent from the event sequences that _handleConversation produces
/// when processing a loaded conversation with multiple messages.
///
/// The key scenario: when a session is resumed and ClaudeClient loads a
/// conversation from disk, _handleConversation receives all messages at once.
/// Previously, only the LAST message's tool events were emitted (bug).
/// After the fix, ALL messages' tool events are emitted.
library;

import 'package:test/test.dart';
import 'package:vide_interface/vide_interface.dart';

void main() {
  group('Conversation loading with tool calls', () {
    late ConversationStateManager manager;
    const agentId = 'agent-1';
    const agentType = 'main';
    const agentName = 'Main Agent';

    setUp(() {
      manager = ConversationStateManager();
    });

    tearDown(() {
      manager.dispose();
    });

    test('tool events from all messages are captured (not just last)', () {
      // Simulate the event sequence that _handleConversation produces
      // when loading a conversation with 3 assistant messages,
      // each containing tool calls.
      //
      // Message 0: user "Hello"
      // Message 1: assistant "Let me check..." + Bash(ls) -> "file.txt"
      // Message 2: assistant "Reading file..." + Read(/file.txt) -> "contents"
      // Message 3: assistant "Done!" (no tools)

      // --- Message 0: user message ---
      manager.handleEvent(
        MessageEvent(
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          eventId: 'evt-0',
          role: 'user',
          content: 'Hello',
          isPartial: false,
        ),
      );

      // --- Message 1: assistant with tool call ---
      manager.handleEvent(
        MessageEvent(
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          eventId: 'evt-1',
          role: 'assistant',
          content: 'Let me check...',
          isPartial: false,
        ),
      );
      // Finalize the text block before tool events
      manager.handleEvent(
        MessageEvent(
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          eventId: 'evt-1',
          role: 'assistant',
          content: '',
          isPartial: false,
        ),
      );
      manager.handleEvent(
        ToolUseEvent(
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          toolUseId: 'tool-1',
          toolName: 'Bash',
          toolInput: {'command': 'ls'},
        ),
      );
      manager.handleEvent(
        ToolResultEvent(
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          toolUseId: 'tool-1',
          toolName: 'Bash',
          result: 'file.txt',
          isError: false,
        ),
      );

      // --- Message 2: assistant with another tool call ---
      manager.handleEvent(
        MessageEvent(
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          eventId: 'evt-2',
          role: 'assistant',
          content: 'Reading file...',
          isPartial: false,
        ),
      );
      manager.handleEvent(
        MessageEvent(
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          eventId: 'evt-2',
          role: 'assistant',
          content: '',
          isPartial: false,
        ),
      );
      manager.handleEvent(
        ToolUseEvent(
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          toolUseId: 'tool-2',
          toolName: 'Read',
          toolInput: {'file_path': '/file.txt'},
        ),
      );
      manager.handleEvent(
        ToolResultEvent(
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          toolUseId: 'tool-2',
          toolName: 'Read',
          result: 'file contents here',
          isError: false,
        ),
      );

      // --- Message 3: final assistant text (no tools) ---
      manager.handleEvent(
        MessageEvent(
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          eventId: 'evt-3',
          role: 'assistant',
          content: 'Done!',
          isPartial: true,
        ),
      );

      // Verify state
      final state = manager.getAgentState(agentId);
      expect(state, isNotNull);
      // User message + merged assistant entry (consecutive assistant messages
      // are merged into a single entry for consistent rendering).
      expect(state!.messages.length, equals(2));

      // Message 0: user
      expect(state.messages[0].role, equals('user'));
      expect(state.messages[0].text, equals('Hello'));

      // Message 1: merged assistant entry with all text blocks and tool calls
      final assistantMsg = state.messages[1];
      expect(assistantMsg.role, equals('assistant'));

      // Should contain: TextContent("Let me check...") + ToolContent(Bash)
      //               + TextContent("Reading file...") + ToolContent(Read)
      //               + TextContent("Done!")
      final textContents = assistantMsg.content
          .whereType<TextContent>()
          .toList();
      expect(textContents.length, equals(3));
      expect(textContents[0].text, equals('Let me check...'));
      expect(textContents[1].text, equals('Reading file...'));
      expect(textContents[2].text, equals('Done!'));

      final toolContents = assistantMsg.content
          .whereType<ToolContent>()
          .toList();
      expect(
        toolContents.length,
        equals(2),
        reason: 'Both tool calls should be in the merged entry',
      );
      expect(toolContents[0].toolName, equals('Bash'));
      expect(toolContents[0].result, equals('file.txt'));
      expect(toolContents[1].toolName, equals('Read'));
      expect(toolContents[1].result, equals('file contents here'));
    });

    test(
      'event history captures all events including tools from all messages',
      () {
        // Emit events for 2 assistant messages with tool calls
        manager.handleEvent(
          MessageEvent(
            agentId: agentId,
            agentType: agentType,
            agentName: agentName,
            eventId: 'evt-0',
            role: 'user',
            content: 'Do stuff',
            isPartial: false,
          ),
        );

        // First assistant turn with tool
        manager.handleEvent(
          MessageEvent(
            agentId: agentId,
            agentType: agentType,
            agentName: agentName,
            eventId: 'evt-1',
            role: 'assistant',
            content: 'Checking...',
            isPartial: false,
          ),
        );
        manager.handleEvent(
          ToolUseEvent(
            agentId: agentId,
            agentType: agentType,
            agentName: agentName,
            toolUseId: 'tool-1',
            toolName: 'Bash',
            toolInput: {'command': 'ls'},
          ),
        );
        manager.handleEvent(
          ToolResultEvent(
            agentId: agentId,
            agentType: agentType,
            agentName: agentName,
            toolUseId: 'tool-1',
            toolName: 'Bash',
            result: 'output',
            isError: false,
          ),
        );

        // Second assistant turn with tool
        manager.handleEvent(
          MessageEvent(
            agentId: agentId,
            agentType: agentType,
            agentName: agentName,
            eventId: 'evt-2',
            role: 'assistant',
            content: 'Reading...',
            isPartial: true,
          ),
        );
        manager.handleEvent(
          ToolUseEvent(
            agentId: agentId,
            agentType: agentType,
            agentName: agentName,
            toolUseId: 'tool-2',
            toolName: 'Read',
            toolInput: {'file_path': '/x'},
          ),
        );
        manager.handleEvent(
          ToolResultEvent(
            agentId: agentId,
            agentType: agentType,
            agentName: agentName,
            toolUseId: 'tool-2',
            toolName: 'Read',
            result: 'data',
            isError: false,
          ),
        );

        // Event history should have all events
        final history = manager.eventHistory;
        expect(history.length, equals(7));

        final toolUseEvents = history.whereType<ToolUseEvent>().toList();
        expect(
          toolUseEvents.length,
          equals(2),
          reason: 'Both tool use events should be in history',
        );
        expect(toolUseEvents[0].toolName, equals('Bash'));
        expect(toolUseEvents[1].toolName, equals('Read'));

        final toolResultEvents = history.whereType<ToolResultEvent>().toList();
        expect(
          toolResultEvents.length,
          equals(2),
          reason: 'Both tool result events should be in history',
        );
      },
    );

    test('multiple tool calls within a single message are all captured', () {
      // Single assistant message with multiple tool calls
      manager.handleEvent(
        MessageEvent(
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          eventId: 'evt-0',
          role: 'assistant',
          content: 'Checking multiple files...',
          isPartial: true,
        ),
      );

      // First tool
      manager.handleEvent(
        ToolUseEvent(
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          toolUseId: 'tool-1',
          toolName: 'Read',
          toolInput: {'file_path': '/a.dart'},
        ),
      );
      manager.handleEvent(
        ToolResultEvent(
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          toolUseId: 'tool-1',
          toolName: 'Read',
          result: 'content-a',
          isError: false,
        ),
      );

      // Second tool
      manager.handleEvent(
        ToolUseEvent(
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          toolUseId: 'tool-2',
          toolName: 'Read',
          toolInput: {'file_path': '/b.dart'},
        ),
      );
      manager.handleEvent(
        ToolResultEvent(
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          toolUseId: 'tool-2',
          toolName: 'Read',
          result: 'content-b',
          isError: false,
        ),
      );

      // Third tool
      manager.handleEvent(
        ToolUseEvent(
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          toolUseId: 'tool-3',
          toolName: 'Bash',
          toolInput: {'command': 'dart test'},
        ),
      );
      manager.handleEvent(
        ToolResultEvent(
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          toolUseId: 'tool-3',
          toolName: 'Bash',
          result: 'All tests passed',
          isError: false,
        ),
      );

      final state = manager.getAgentState(agentId);
      expect(state, isNotNull);
      expect(state!.messages.length, equals(1));

      final toolContents = state.messages[0].content
          .whereType<ToolContent>()
          .toList();
      expect(
        toolContents.length,
        equals(3),
        reason: 'All 3 tool calls should be present',
      );
      expect(toolContents[0].toolName, equals('Read'));
      expect(toolContents[0].result, equals('content-a'));
      expect(toolContents[1].toolName, equals('Read'));
      expect(toolContents[1].result, equals('content-b'));
      expect(toolContents[2].toolName, equals('Bash'));
      expect(toolContents[2].result, equals('All tests passed'));
    });
  });
}
