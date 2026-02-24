/// Tests for computed getters on ConversationContent subclasses,
/// ConversationEntry, and AgentConversationState.
///
/// These getters consolidate content interpretation logic that was previously
/// duplicated across multiple UI consumers (TUI, Mobile, In-app SDK).
library;

import 'package:test/test.dart';
import 'package:vide_interface/vide_interface.dart';

ToolContent _tool({
  String name = 'Bash',
  Map<String, dynamic> input = const {},
  String? result,
  bool isError = false,
}) {
  return ToolContent(
    toolUseId: 'tool-${name.hashCode}',
    toolName: name,
    toolInput: input,
    result: result,
    isError: isError,
  );
}

ConversationEntry _entry({
  MessageRole role = MessageRole.assistant,
  List<ConversationContent> content = const [],
}) {
  return ConversationEntry(role: role, content: content);
}

void main() {
  group('ToolContent.isHidden', () {
    test('hidden tool names return true', () {
      final hiddenNames = [
        'mcp__vide-agent__setTaskName',
        'mcp__vide-agent__setAgentTaskName',
        'mcp__vide-task-management__setTaskName',
        'mcp__vide-task-management__setAgentTaskName',
        'mcp__vide-agent__setAgentStatus',
        'TodoWrite',
        'EnterPlanMode',
      ];
      for (final name in hiddenNames) {
        expect(
          _tool(name: name).isHidden,
          isTrue,
          reason: '$name should be hidden',
        );
      }
    });

    test('Write targeting .claude/plans/ is hidden', () {
      expect(
        _tool(
          name: 'Write',
          input: {'file_path': '/home/user/.claude/plans/my-plan.md'},
        ).isHidden,
        isTrue,
      );
    });

    test('Write targeting other paths is not hidden', () {
      expect(
        _tool(
          name: 'Write',
          input: {'file_path': '/home/user/project/lib/main.dart'},
        ).isHidden,
        isFalse,
      );
    });

    test('regular tools are not hidden', () {
      expect(_tool(name: 'Bash').isHidden, isFalse);
      expect(_tool(name: 'Read').isHidden, isFalse);
      expect(_tool(name: 'Edit').isHidden, isFalse);
      expect(_tool(name: 'Grep').isHidden, isFalse);
    });
  });

  group('ToolContent.isSpawnAgent', () {
    test('matches spawn agent tool name', () {
      expect(_tool(name: 'mcp__vide-agent__spawnAgent').isSpawnAgent, isTrue);
    });

    test('does not match other tools', () {
      expect(_tool(name: 'Bash').isSpawnAgent, isFalse);
      expect(
        _tool(name: 'mcp__vide-agent__setAgentStatus').isSpawnAgent,
        isFalse,
      );
    });
  });

  group('ToolContent.isPlanResult', () {
    test('matches ExitPlanMode', () {
      expect(_tool(name: 'ExitPlanMode').isPlanResult, isTrue);
    });

    test('does not match other tools', () {
      expect(_tool(name: 'EnterPlanMode').isPlanResult, isFalse);
      expect(_tool(name: 'Bash').isPlanResult, isFalse);
    });
  });

  group('ToolContent.displayName', () {
    test('strips MCP prefix', () {
      expect(
        _tool(name: 'mcp__vide-agent__spawnAgent').displayName,
        equals('spawnAgent'),
      );
      expect(
        _tool(name: 'mcp__vide-task-management__setTaskName').displayName,
        equals('setTaskName'),
      );
    });

    test('preserves non-MCP tool names', () {
      expect(_tool(name: 'Bash').displayName, equals('Bash'));
      expect(_tool(name: 'Read').displayName, equals('Read'));
      expect(_tool(name: 'ExitPlanMode').displayName, equals('ExitPlanMode'));
    });
  });

  group('ToolContent.subtitle', () {
    test('Read/Edit/Write returns file_path', () {
      for (final name in ['Read', 'Edit', 'Write']) {
        expect(
          _tool(name: name, input: {'file_path': '/a.dart'}).subtitle,
          equals('/a.dart'),
        );
      }
    });

    test('Bash returns command', () {
      expect(
        _tool(name: 'Bash', input: {'command': 'ls -la'}).subtitle,
        equals('ls -la'),
      );
    });

    test('Grep returns pattern and path', () {
      expect(
        _tool(name: 'Grep', input: {'pattern': 'foo', 'path': '/src'}).subtitle,
        equals('"foo" in /src'),
      );
    });

    test('Grep returns pattern only when no path', () {
      expect(
        _tool(name: 'Grep', input: {'pattern': 'foo'}).subtitle,
        equals('"foo"'),
      );
    });

    test('Glob returns pattern', () {
      expect(
        _tool(name: 'Glob', input: {'pattern': '**/*.dart'}).subtitle,
        equals('**/*.dart'),
      );
    });

    test('WebFetch returns url', () {
      expect(
        _tool(name: 'WebFetch', input: {'url': 'https://x.com'}).subtitle,
        equals('https://x.com'),
      );
    });

    test('WebSearch returns query', () {
      expect(
        _tool(name: 'WebSearch', input: {'query': 'dart test'}).subtitle,
        equals('dart test'),
      );
    });

    test('TodoWrite returns null', () {
      expect(_tool(name: 'TodoWrite', input: {'todos': []}).subtitle, isNull);
    });

    test('Task returns description', () {
      expect(
        _tool(name: 'Task', input: {'description': 'explore'}).subtitle,
        equals('explore'),
      );
    });

    test('NotebookEdit returns notebook_path', () {
      expect(
        _tool(
          name: 'NotebookEdit',
          input: {'notebook_path': '/nb.ipynb'},
        ).subtitle,
        equals('/nb.ipynb'),
      );
    });

    test('unknown tool falls back to common keys', () {
      expect(
        _tool(name: 'CustomTool', input: {'file_path': '/x'}).subtitle,
        equals('/x'),
      );
      expect(
        _tool(name: 'CustomTool', input: {'command': 'echo'}).subtitle,
        equals('echo'),
      );
      expect(
        _tool(name: 'CustomTool', input: {'unrelated': 'val'}).subtitle,
        isNull,
      );
    });

    test('MCP-prefixed tools use display name for switch', () {
      expect(
        _tool(
          name: 'mcp__some-server__Read',
          input: {'file_path': '/a.dart'},
        ).subtitle,
        equals('/a.dart'),
      );
    });
  });

  group('TextContent.isContextWindowError', () {
    test('detects "prompt is too long"', () {
      expect(
        const TextContent(
          text: 'The prompt is too long for this model',
        ).isContextWindowError,
        isTrue,
      );
    });

    test('detects "context window"', () {
      expect(
        const TextContent(
          text: 'Exceeded the context window limit',
        ).isContextWindowError,
        isTrue,
      );
    });

    test('detects "token limit"', () {
      expect(
        const TextContent(
          text: 'You have hit the token limit',
        ).isContextWindowError,
        isTrue,
      );
    });

    test('case insensitive', () {
      expect(
        const TextContent(text: 'CONTEXT WINDOW exceeded').isContextWindowError,
        isTrue,
      );
    });

    test('normal text returns false', () {
      expect(
        const TextContent(
          text: 'Here is the implementation',
        ).isContextWindowError,
        isFalse,
      );
    });
  });

  group('ConversationEntry.isSlashCommand', () {
    test('user message starting with / is slash command', () {
      final entry = _entry(
        role: MessageRole.user,
        content: [const TextContent(text: '/compact')],
      );
      expect(entry.isSlashCommand, isTrue);
    });

    test('user message not starting with / is not slash command', () {
      final entry = _entry(
        role: MessageRole.user,
        content: [const TextContent(text: 'Hello')],
      );
      expect(entry.isSlashCommand, isFalse);
    });

    test('assistant message starting with / is not slash command', () {
      final entry = _entry(
        role: MessageRole.assistant,
        content: [const TextContent(text: '/compact')],
      );
      expect(entry.isSlashCommand, isFalse);
    });
  });

  group('ConversationEntry.hasVisibleText', () {
    test('has text content', () {
      final entry = _entry(content: [const TextContent(text: 'Hello')]);
      expect(entry.hasVisibleText, isTrue);
    });

    test('has thinking content', () {
      final entry = _entry(content: [const ThinkingContent(text: 'Hmm...')]);
      expect(entry.hasVisibleText, isTrue);
    });

    test('empty text is not visible', () {
      final entry = _entry(content: [const TextContent(text: '')]);
      expect(entry.hasVisibleText, isFalse);
    });

    test('whitespace-only text is not visible', () {
      final entry = _entry(content: [const TextContent(text: '   ')]);
      expect(entry.hasVisibleText, isFalse);
    });

    test('only tools is not visible text', () {
      final entry = _entry(content: [_tool()]);
      expect(entry.hasVisibleText, isFalse);
    });

    test('tools plus text is visible', () {
      final entry = _entry(
        content: [
          _tool(),
          const TextContent(text: 'Done'),
        ],
      );
      expect(entry.hasVisibleText, isTrue);
    });
  });

  group('ConversationEntry.isAllHidden', () {
    test('all hidden tools, no text', () {
      final entry = _entry(
        content: [
          _tool(name: 'TodoWrite'),
          _tool(name: 'EnterPlanMode'),
        ],
      );
      expect(entry.isAllHidden, isTrue);
    });

    test('mix of hidden and visible tools', () {
      final entry = _entry(
        content: [
          _tool(name: 'TodoWrite'),
          _tool(name: 'Bash'),
        ],
      );
      expect(entry.isAllHidden, isFalse);
    });

    test('hidden tools with visible text', () {
      final entry = _entry(
        content: [
          const TextContent(text: 'Working on it'),
          _tool(name: 'TodoWrite'),
        ],
      );
      expect(entry.isAllHidden, isFalse);
    });

    test('no tools returns false', () {
      final entry = _entry(content: [const TextContent(text: '')]);
      expect(entry.isAllHidden, isFalse);
    });

    test('user entry returns false', () {
      final entry = _entry(
        role: MessageRole.user,
        content: [_tool(name: 'TodoWrite')],
      );
      expect(entry.isAllHidden, isFalse);
    });
  });

  group('AgentConversationState.latestTodos', () {
    test('returns null when no TodoWrite exists', () {
      final state = AgentConversationState(
        agentId: 'a1',
        agentType: 'main',
        messages: [
          _entry(content: [const TextContent(text: 'Hello')]),
        ],
      );
      expect(state.latestTodos, isNull);
    });

    test('returns todos from latest TodoWrite', () {
      final state = AgentConversationState(
        agentId: 'a1',
        agentType: 'main',
        messages: [
          _entry(
            content: [
              _tool(
                name: 'TodoWrite',
                input: {
                  'todos': [
                    {'content': 'Old task', 'status': 'completed'},
                  ],
                },
              ),
            ],
          ),
          _entry(
            content: [
              _tool(
                name: 'TodoWrite',
                input: {
                  'todos': [
                    {'content': 'New task', 'status': 'in_progress'},
                  ],
                },
              ),
            ],
          ),
        ],
      );

      final todos = state.latestTodos;
      expect(todos, isNotNull);
      expect(todos, hasLength(1));
      expect(todos![0]['content'], equals('New task'));
    });

    test('skips non-TodoWrite tools', () {
      final state = AgentConversationState(
        agentId: 'a1',
        agentType: 'main',
        messages: [
          _entry(
            content: [
              _tool(
                name: 'TodoWrite',
                input: {
                  'todos': [
                    {'content': 'Task', 'status': 'pending'},
                  ],
                },
              ),
            ],
          ),
          _entry(
            content: [
              _tool(name: 'Bash', input: {'command': 'ls'}),
            ],
          ),
        ],
      );

      final todos = state.latestTodos;
      expect(todos, isNotNull);
      expect(todos![0]['content'], equals('Task'));
    });
  });

  group('ThinkingContent normalization', () {
    test('bold markers are stripped at accumulation time', () {
      final manager = ConversationStateManager();
      addTearDown(manager.dispose);

      manager.handleEvent(
        ThinkingEvent(
          agentId: 'a1',
          agentType: 'main',
          content: '**Some bold reasoning**',
        ),
      );

      final state = manager.getAgentState('a1');
      expect(state, isNotNull);
      final thinking = state!.messages.last.content
          .whereType<ThinkingContent>()
          .first;
      expect(thinking.text, equals('Some bold reasoning'));
    });

    test('non-bold thinking is preserved', () {
      final manager = ConversationStateManager();
      addTearDown(manager.dispose);

      manager.handleEvent(
        ThinkingEvent(
          agentId: 'a1',
          agentType: 'main',
          content: 'Normal reasoning text',
        ),
      );

      final state = manager.getAgentState('a1');
      final thinking = state!.messages.last.content
          .whereType<ThinkingContent>()
          .first;
      expect(thinking.text, equals('Normal reasoning text'));
    });

    test('accumulated chunks are each normalized', () {
      final manager = ConversationStateManager();
      addTearDown(manager.dispose);

      manager.handleEvent(
        ThinkingEvent(
          agentId: 'a1',
          agentType: 'main',
          content: '**First chunk',
        ),
      );
      manager.handleEvent(
        ThinkingEvent(
          agentId: 'a1',
          agentType: 'main',
          content: ' second chunk**',
        ),
      );

      final state = manager.getAgentState('a1');
      final thinking = state!.messages.last.content
          .whereType<ThinkingContent>()
          .first;
      expect(thinking.text, equals('First chunk second chunk'));
    });

    test('thinking interleaved with text creates separate blocks', () {
      final manager = ConversationStateManager();
      addTearDown(manager.dispose);

      // Thinking block 1
      manager.handleEvent(
        ThinkingEvent(
          agentId: 'a1',
          agentType: 'main',
          content: 'thought 1',
        ),
      );

      // Text block 1 (new eventId triggers merge into same assistant entry)
      manager.handleEvent(
        MessageEvent(
          agentId: 'a1',
          agentType: 'main',
          eventId: 'msg-1',
          role: MessageRole.assistant,
          content: 'text 1',
          isPartial: false,
        ),
      );

      // Thinking block 2 — should NOT be concatenated with thinking block 1
      manager.handleEvent(
        ThinkingEvent(
          agentId: 'a1',
          agentType: 'main',
          content: 'thought 2',
        ),
      );

      // Text block 2
      manager.handleEvent(
        MessageEvent(
          agentId: 'a1',
          agentType: 'main',
          eventId: 'msg-2',
          role: MessageRole.assistant,
          content: 'text 2',
          isPartial: false,
        ),
      );

      final state = manager.getAgentState('a1');
      expect(state, isNotNull);
      expect(state!.messages, hasLength(1));

      final content = state.messages.first.content;
      expect(content, hasLength(4));
      expect(content[0], isA<ThinkingContent>());
      expect((content[0] as ThinkingContent).text, equals('thought 1'));
      expect(content[1], isA<TextContent>());
      expect((content[1] as TextContent).text, equals('text 1'));
      expect(content[2], isA<ThinkingContent>());
      expect((content[2] as ThinkingContent).text, equals('thought 2'));
      expect(content[3], isA<TextContent>());
      expect((content[3] as TextContent).text, equals('text 2'));
    });

    test('consecutive thinking chunks still merge into one block', () {
      final manager = ConversationStateManager();
      addTearDown(manager.dispose);

      manager.handleEvent(
        ThinkingEvent(
          agentId: 'a1',
          agentType: 'main',
          content: 'chunk 1 ',
        ),
      );
      manager.handleEvent(
        ThinkingEvent(
          agentId: 'a1',
          agentType: 'main',
          content: 'chunk 2',
        ),
      );

      final state = manager.getAgentState('a1');
      final content = state!.messages.first.content;
      expect(content, hasLength(1));
      expect(content[0], isA<ThinkingContent>());
      expect((content[0] as ThinkingContent).text, equals('chunk 1 chunk 2'));
    });

    test('cumulative thinking replaces accumulated deltas (no duplication)', () {
      final manager = ConversationStateManager();
      addTearDown(manager.dispose);

      // Simulate streaming thinking deltas
      manager.handleEvent(
        ThinkingEvent(
          agentId: 'a1',
          agentType: 'main',
          content: 'I need to ',
        ),
      );
      manager.handleEvent(
        ThinkingEvent(
          agentId: 'a1',
          agentType: 'main',
          content: 'analyze this.',
        ),
      );

      // Simulate cumulative thinking from the final assistant message
      // (sent when --include-partial-messages is enabled)
      manager.handleEvent(
        ThinkingEvent(
          agentId: 'a1',
          agentType: 'main',
          content: 'I need to analyze this.',
          isCumulative: true,
        ),
      );

      final state = manager.getAgentState('a1');
      final content = state!.messages.first.content;
      expect(content, hasLength(1));
      expect(content[0], isA<ThinkingContent>());
      // Should be the cumulative text, NOT "I need to analyze this.I need to analyze this."
      expect(
        (content[0] as ThinkingContent).text,
        equals('I need to analyze this.'),
      );
    });

    test('cumulative thinking works as first event (non-streaming mode)', () {
      final manager = ConversationStateManager();
      addTearDown(manager.dispose);

      // In non-streaming mode, only a cumulative event arrives (no prior deltas)
      manager.handleEvent(
        ThinkingEvent(
          agentId: 'a1',
          agentType: 'main',
          content: 'Full thinking text.',
          isCumulative: true,
        ),
      );

      final state = manager.getAgentState('a1');
      final content = state!.messages.first.content;
      expect(content, hasLength(1));
      expect(content[0], isA<ThinkingContent>());
      expect(
        (content[0] as ThinkingContent).text,
        equals('Full thinking text.'),
      );
    });

    test('cumulative thinking after interleaved content creates new block', () {
      final manager = ConversationStateManager();
      addTearDown(manager.dispose);

      // Thinking block
      manager.handleEvent(
        ThinkingEvent(
          agentId: 'a1',
          agentType: 'main',
          content: 'thought 1',
        ),
      );

      // Text interleaved
      manager.handleEvent(
        MessageEvent(
          agentId: 'a1',
          agentType: 'main',
          eventId: 'msg-1',
          role: MessageRole.assistant,
          content: 'response text',
          isPartial: false,
        ),
      );

      // Cumulative thinking after text — should create a new block,
      // NOT replace the first thinking block
      manager.handleEvent(
        ThinkingEvent(
          agentId: 'a1',
          agentType: 'main',
          content: 'thought 2 full',
          isCumulative: true,
        ),
      );

      final state = manager.getAgentState('a1');
      final content = state!.messages.first.content;
      expect(content, hasLength(3));
      expect(content[0], isA<ThinkingContent>());
      expect((content[0] as ThinkingContent).text, equals('thought 1'));
      expect(content[1], isA<TextContent>());
      expect(content[2], isA<ThinkingContent>());
      expect((content[2] as ThinkingContent).text, equals('thought 2 full'));
    });
  });
}
