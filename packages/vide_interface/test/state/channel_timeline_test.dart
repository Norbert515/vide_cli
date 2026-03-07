import 'package:test/test.dart';
import 'package:vide_interface/vide_interface.dart';

void main() {
  group('ChannelTimelineProjector.project', () {
    test('empty event list returns empty', () {
      expect(ChannelTimelineProjector.project([]), isEmpty);
    });

    test('single complete assistant message with @user prefix', () {
      final events = <VideEvent>[
        MessageEvent(
          agentId: 'agent-1',
          agentType: 'main',
          agentName: 'Main',
          eventId: 'msg-1',
          role: MessageRole.assistant,
          content: '@user Here is my response.',
          isPartial: false,
        ),
      ];

      final entries = ChannelTimelineProjector.project(events);
      expect(entries, hasLength(1));
      expect(entries[0].senderAgentId, 'agent-1');
      expect(entries[0].senderAgentName, 'Main');
      expect(entries[0].senderAgentType, 'main');
      expect(entries[0].target, isA<UserMention>());
      expect(entries[0].content, 'Here is my response.');
      expect(entries[0].source, isA<AssistantMentionSource>());
      expect((entries[0].source as AssistantMentionSource).eventIndex, 0);
    });

    test('sendMessageToAgent tool event produces entry', () {
      final events = <VideEvent>[
        ToolUseEvent(
          agentId: 'agent-1',
          agentType: 'lead',
          agentName: 'Lead',
          toolUseId: 'tool-1',
          toolName: 'mcp__vide-agent__sendMessageToAgent',
          toolInput: {
            'targetAgentId': 'agent-2',
            'message': 'Please implement the auth module.',
          },
        ),
      ];

      final entries = ChannelTimelineProjector.project(events);
      expect(entries, hasLength(1));
      expect(entries[0].senderAgentId, 'agent-1');
      expect(entries[0].target, isA<AgentMention>());
      expect(
        (entries[0].target as AgentMention).agentId,
        'agent-2',
      );
      expect(entries[0].content, 'Please implement the auth module.');
      expect(entries[0].source, isA<ToolMessageSource>());
      expect((entries[0].source as ToolMessageSource).toolUseId, 'tool-1');
    });

    test('non-mention assistant messages are excluded', () {
      final events = <VideEvent>[
        MessageEvent(
          agentId: 'agent-1',
          agentType: 'main',
          eventId: 'msg-1',
          role: MessageRole.assistant,
          content: 'Just some regular text without mentions.',
          isPartial: false,
        ),
      ];

      expect(ChannelTimelineProjector.project(events), isEmpty);
    });

    test('user messages are included in channel', () {
      final events = <VideEvent>[
        MessageEvent(
          agentId: 'agent-1',
          agentType: 'main',
          eventId: 'msg-1',
          role: MessageRole.user,
          content: 'Fix the auth bug please',
          isPartial: false,
        ),
      ];

      final result = ChannelTimelineProjector.project(events);
      expect(result, hasLength(1));
      expect(result[0].senderAgentName, 'You');
      expect(result[0].senderAgentType, 'user');
      expect(result[0].content, 'Fix the auth bug please');
      expect(result[0].target, isA<AgentMention>());
      expect(result[0].source, isA<UserMessageSource>());
    });

    test('system-like user messages are excluded from channel', () {
      final events = <VideEvent>[
        MessageEvent(
          agentId: 'agent-1',
          agentType: 'main',
          eventId: 'msg-1',
          role: MessageRole.user,
          content: '[Request interrupted by user]',
          isPartial: false,
        ),
      ];

      expect(ChannelTimelineProjector.project(events), isEmpty);
    });

    test('partial message streaming accumulates then checks', () {
      final events = <VideEvent>[
        MessageEvent(
          agentId: 'agent-1',
          agentType: 'implementer',
          eventId: 'msg-1',
          role: MessageRole.assistant,
          content: '@us',
          isPartial: true,
        ),
        MessageEvent(
          agentId: 'agent-1',
          agentType: 'implementer',
          eventId: 'msg-1',
          role: MessageRole.assistant,
          content: 'er ',
          isPartial: true,
        ),
        MessageEvent(
          agentId: 'agent-1',
          agentType: 'implementer',
          eventId: 'msg-1',
          role: MessageRole.assistant,
          content: 'Done!',
          isPartial: true,
        ),
        MessageEvent(
          agentId: 'agent-1',
          agentType: 'implementer',
          eventId: 'msg-1',
          role: MessageRole.assistant,
          content: '',
          isPartial: false,
        ),
      ];

      final entries = ChannelTimelineProjector.project(events);
      expect(entries, hasLength(1));
      expect(entries[0].target, isA<UserMention>());
      expect(entries[0].content, 'Done!');
      expect(
        (entries[0].source as AssistantMentionSource).eventIndex,
        3,
      );
    });

    test('partial messages without final non-partial are not included', () {
      // Only partial events, no finalization
      final events = <VideEvent>[
        MessageEvent(
          agentId: 'agent-1',
          agentType: 'main',
          eventId: 'msg-1',
          role: MessageRole.assistant,
          content: '@user Hello',
          isPartial: true,
        ),
      ];

      expect(ChannelTimelineProjector.project(events), isEmpty);
    });

    test('mixed events: only mention and tool events extracted', () {
      final events = <VideEvent>[
        // Non-mention message — excluded
        MessageEvent(
          agentId: 'agent-1',
          agentType: 'main',
          eventId: 'msg-1',
          role: MessageRole.assistant,
          content: 'Let me think about this.',
          isPartial: false,
        ),
        // Unrelated tool — excluded
        ToolUseEvent(
          agentId: 'agent-1',
          agentType: 'main',
          toolUseId: 'tool-1',
          toolName: 'Read',
          toolInput: {'file_path': '/foo.dart'},
        ),
        // Mention message — included
        MessageEvent(
          agentId: 'agent-1',
          agentType: 'main',
          eventId: 'msg-2',
          role: MessageRole.assistant,
          content: '@everyone Status update: all good.',
          isPartial: false,
        ),
        // sendMessageToAgent — included
        ToolUseEvent(
          agentId: 'agent-1',
          agentType: 'main',
          toolUseId: 'tool-2',
          toolName: 'mcp__vide-agent__sendMessageToAgent',
          toolInput: {
            'targetAgentId': 'agent-2',
            'message': 'Go implement this.',
          },
        ),
        // Status event — excluded
        StatusEvent(
          agentId: 'agent-1',
          agentType: 'main',
          status: VideAgentStatus.working,
        ),
      ];

      final entries = ChannelTimelineProjector.project(events);
      expect(entries, hasLength(2));
      expect(entries[0].target, isA<EveryoneMention>());
      expect(entries[0].content, 'Status update: all good.');
      expect(entries[1].target, isA<AgentMention>());
      expect(entries[1].content, 'Go implement this.');
    });

    test('events from terminated agents are still included', () {
      final events = <VideEvent>[
        MessageEvent(
          agentId: 'agent-dead',
          agentType: 'implementer',
          agentName: 'Old Worker',
          eventId: 'msg-1',
          role: MessageRole.assistant,
          content: '@user I finished before being terminated.',
          isPartial: false,
        ),
        AgentTerminatedEvent(
          agentId: 'agent-dead',
          agentType: 'implementer',
          agentName: 'Old Worker',
          reason: 'Task complete',
        ),
      ];

      final entries = ChannelTimelineProjector.project(events);
      expect(entries, hasLength(1));
      expect(entries[0].senderAgentId, 'agent-dead');
      expect(entries[0].senderAgentName, 'Old Worker');
    });

    test('sendMessageToAgent missing targetAgentId is excluded', () {
      final events = <VideEvent>[
        ToolUseEvent(
          agentId: 'agent-1',
          agentType: 'main',
          toolUseId: 'tool-1',
          toolName: 'mcp__vide-agent__sendMessageToAgent',
          toolInput: {'message': 'Missing target'},
        ),
      ];

      expect(ChannelTimelineProjector.project(events), isEmpty);
    });

    test('sendMessageToAgent missing message is excluded', () {
      final events = <VideEvent>[
        ToolUseEvent(
          agentId: 'agent-1',
          agentType: 'main',
          toolUseId: 'tool-1',
          toolName: 'mcp__vide-agent__sendMessageToAgent',
          toolInput: {'targetAgentId': 'agent-2'},
        ),
      ];

      expect(ChannelTimelineProjector.project(events), isEmpty);
    });

    test('@everyone message', () {
      final events = <VideEvent>[
        MessageEvent(
          agentId: 'agent-1',
          agentType: 'lead',
          eventId: 'msg-1',
          role: MessageRole.assistant,
          content: '@everyone All agents please stop.',
          isPartial: false,
        ),
      ];

      final entries = ChannelTimelineProjector.project(events);
      expect(entries, hasLength(1));
      expect(entries[0].target, isA<EveryoneMention>());
      expect(entries[0].content, 'All agents please stop.');
    });

    test('sendMessageToAgent with @everyone creates EveryoneMention', () {
      final events = <VideEvent>[
        ToolUseEvent(
          agentId: 'agent-1',
          agentType: 'lead',
          agentName: 'Lead',
          toolUseId: 'tool-1',
          toolName: 'mcp__vide-agent__sendMessageToAgent',
          toolInput: {
            'targetAgentId': '@everyone',
            'message': 'All agents stand by.',
          },
        ),
      ];

      final entries = ChannelTimelineProjector.project(events);
      expect(entries, hasLength(1));
      expect(entries[0].target, isA<EveryoneMention>());
      expect(entries[0].content, 'All agents stand by.');
      expect(entries[0].source, isA<ToolMessageSource>());
    });

    test('multiple agents produce correctly attributed entries', () {
      final events = <VideEvent>[
        MessageEvent(
          agentId: 'agent-1',
          agentType: 'lead',
          agentName: 'Lead',
          eventId: 'msg-1',
          role: MessageRole.assistant,
          content: '@user Delegating work.',
          isPartial: false,
        ),
        MessageEvent(
          agentId: 'agent-2',
          agentType: 'implementer',
          agentName: 'Worker',
          eventId: 'msg-2',
          role: MessageRole.assistant,
          content: '@user Done with my task.',
          isPartial: false,
        ),
      ];

      final entries = ChannelTimelineProjector.project(events);
      expect(entries, hasLength(2));
      expect(entries[0].senderAgentId, 'agent-1');
      expect(entries[0].senderAgentName, 'Lead');
      expect(entries[1].senderAgentId, 'agent-2');
      expect(entries[1].senderAgentName, 'Worker');
    });
  });
}
