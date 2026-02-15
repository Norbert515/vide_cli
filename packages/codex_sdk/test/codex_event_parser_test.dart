import 'package:codex_sdk/codex_sdk.dart';
import 'package:test/test.dart';

void main() {
  late CodexEventParser parser;

  setUp(() {
    parser = CodexEventParser();
  });

  group('CodexEventParser.parseNotification', () {
    test('parses thread/started', () {
      final notification = JsonRpcNotification(
        method: 'thread/started',
        params: {
          'thread': {'id': 'thread_abc123'},
        },
      );
      final event = parser.parseNotification(notification);
      expect(event, isA<ThreadStartedEvent>());
      expect((event as ThreadStartedEvent).threadId, 'thread_abc123');
    });

    test('parses turn/started', () {
      final notification = JsonRpcNotification(
        method: 'turn/started',
        params: {
          'turn': {'id': '0'},
        },
      );
      final event = parser.parseNotification(notification);
      expect(event, isA<TurnStartedEvent>());
      expect((event as TurnStartedEvent).turnId, '0');
    });

    test('parses turn/completed', () {
      final notification = JsonRpcNotification(
        method: 'turn/completed',
        params: {
          'turn': {'id': '0', 'status': 'completed'},
        },
      );
      final event = parser.parseNotification(notification);
      expect(event, isA<TurnCompletedEvent>());
      final completed = event as TurnCompletedEvent;
      expect(completed.turnId, '0');
      expect(completed.status, 'completed');
    });

    test('parses item/started', () {
      final notification = JsonRpcNotification(
        method: 'item/started',
        params: {
          'item': {
            'id': 'item_001',
            'type': 'agentMessage',
          },
        },
      );
      final event = parser.parseNotification(notification);
      expect(event, isA<ItemStartedEvent>());
      final item = event as ItemStartedEvent;
      expect(item.itemId, 'item_001');
      expect(item.itemType, 'agentMessage');
    });

    test('parses item/completed', () {
      final notification = JsonRpcNotification(
        method: 'item/completed',
        params: {
          'item': {
            'id': 'item_001',
            'type': 'agentMessage',
            'text': 'Hello!',
          },
        },
      );
      final event = parser.parseNotification(notification);
      expect(event, isA<ItemCompletedEvent>());
      final item = event as ItemCompletedEvent;
      expect(item.itemId, 'item_001');
      expect(item.itemData['text'], 'Hello!');
    });

    test('parses item/agentMessage/delta', () {
      final notification = JsonRpcNotification(
        method: 'item/agentMessage/delta',
        params: {
          'itemId': 'item_001',
          'delta': 'Hello ',
        },
      );
      final event = parser.parseNotification(notification);
      expect(event, isA<AgentMessageDeltaEvent>());
      final delta = event as AgentMessageDeltaEvent;
      expect(delta.itemId, 'item_001');
      expect(delta.delta, 'Hello ');
    });

    test('parses item/reasoning/summaryTextDelta', () {
      final notification = JsonRpcNotification(
        method: 'item/reasoning/summaryTextDelta',
        params: {
          'itemId': 'r_001',
          'delta': 'thinking...',
        },
      );
      final event = parser.parseNotification(notification);
      expect(event, isA<ReasoningSummaryDeltaEvent>());
      expect((event as ReasoningSummaryDeltaEvent).delta, 'thinking...');
    });

    test('parses item/commandExecution/outputDelta', () {
      final notification = JsonRpcNotification(
        method: 'item/commandExecution/outputDelta',
        params: {
          'itemId': 'cmd_001',
          'delta': 'output line',
        },
      );
      final event = parser.parseNotification(notification);
      expect(event, isA<CommandOutputDeltaEvent>());
      expect((event as CommandOutputDeltaEvent).delta, 'output line');
    });

    test('parses thread/tokenUsage/updated', () {
      final notification = JsonRpcNotification(
        method: 'thread/tokenUsage/updated',
        params: {
          'usage': {
            'input_tokens': 100,
            'cached_input_tokens': 50,
            'output_tokens': 200,
          },
        },
      );
      final event = parser.parseNotification(notification);
      expect(event, isA<TokenUsageUpdatedEvent>());
      final usage = (event as TokenUsageUpdatedEvent).usage;
      expect(usage.inputTokens, 100);
      expect(usage.cachedInputTokens, 50);
      expect(usage.outputTokens, 200);
    });

    test('parses codex/event/task_complete', () {
      final notification = JsonRpcNotification(
        method: 'codex/event/task_complete',
        params: {
          'msg': {
            'type': 'task_complete',
            'last_agent_message': 'Done!',
          },
        },
      );
      final event = parser.parseNotification(notification);
      expect(event, isA<TaskCompleteEvent>());
      expect((event as TaskCompleteEvent).lastAgentMessage, 'Done!');
    });

    test('parses codex/event/mcp_startup_complete', () {
      final notification = JsonRpcNotification(
        method: 'codex/event/mcp_startup_complete',
        params: {},
      );
      final event = parser.parseNotification(notification);
      expect(event, isA<McpStartupCompleteEvent>());
    });

    test('parses error notification', () {
      final notification = JsonRpcNotification(
        method: 'error',
        params: {'message': 'something broke'},
      );
      final event = parser.parseNotification(notification);
      expect(event, isA<CodexErrorEvent>());
      expect((event as CodexErrorEvent).message, 'something broke');
    });

    test('returns UnknownCodexEvent for unrecognized method', () {
      final notification = JsonRpcNotification(
        method: 'future/unknown/event',
        params: {'data': 42},
      );
      final event = parser.parseNotification(notification);
      expect(event, isA<UnknownCodexEvent>());
      final unknown = event as UnknownCodexEvent;
      expect(unknown.method, 'future/unknown/event');
      expect(unknown.params['data'], 42);
    });
  });
}
