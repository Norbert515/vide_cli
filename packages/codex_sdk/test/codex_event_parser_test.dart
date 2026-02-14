import 'dart:convert';

import 'package:codex_sdk/codex_sdk.dart';
import 'package:test/test.dart';

void main() {
  late CodexEventParser parser;

  setUp(() {
    parser = CodexEventParser();
  });

  group('CodexEventParser.parseLine', () {
    test('returns null for empty string', () {
      expect(parser.parseLine(''), isNull);
    });

    test('returns null for whitespace-only string', () {
      expect(parser.parseLine('   \t  '), isNull);
    });

    test('returns null for invalid JSON', () {
      expect(parser.parseLine('not json at all'), isNull);
    });

    test('returns null for JSON array (not object)', () {
      expect(parser.parseLine('[1, 2, 3]'), isNull);
    });

    test('parses thread.started event', () {
      final json = jsonEncode({
        'type': 'thread.started',
        'thread_id': 'thread_abc123',
      });
      final event = parser.parseLine(json);
      expect(event, isA<ThreadStartedEvent>());
      expect((event as ThreadStartedEvent).threadId, 'thread_abc123');
    });

    test('parses turn.started event', () {
      final json = jsonEncode({'type': 'turn.started'});
      final event = parser.parseLine(json);
      expect(event, isA<TurnStartedEvent>());
    });

    test('parses turn.completed event with usage', () {
      final json = jsonEncode({
        'type': 'turn.completed',
        'usage': {
          'input_tokens': 100,
          'cached_input_tokens': 50,
          'output_tokens': 200,
        },
      });
      final event = parser.parseLine(json);
      expect(event, isA<TurnCompletedEvent>());
      final completed = event as TurnCompletedEvent;
      expect(completed.usage!.inputTokens, 100);
      expect(completed.usage!.cachedInputTokens, 50);
      expect(completed.usage!.outputTokens, 200);
    });

    test('parses turn.completed event without usage', () {
      final json = jsonEncode({'type': 'turn.completed'});
      final event = parser.parseLine(json);
      expect(event, isA<TurnCompletedEvent>());
      expect((event as TurnCompletedEvent).usage, isNull);
    });

    test('parses turn.failed with string error', () {
      final json = jsonEncode({
        'type': 'turn.failed',
        'error': 'something went wrong',
      });
      final event = parser.parseLine(json);
      expect(event, isA<TurnFailedEvent>());
      final failed = event as TurnFailedEvent;
      expect(failed.error, 'something went wrong');
      expect(failed.details, isNull);
    });

    test('parses turn.failed with structured error', () {
      final json = jsonEncode({
        'type': 'turn.failed',
        'error': {'message': 'rate limit', 'code': 429},
      });
      final event = parser.parseLine(json);
      expect(event, isA<TurnFailedEvent>());
      final failed = event as TurnFailedEvent;
      expect(failed.error, 'rate limit');
      expect(failed.details!['code'], 429);
    });

    test('parses item.started event', () {
      final json = jsonEncode({
        'type': 'item.started',
        'item': {
          'id': 'item_001',
          'type': 'agent_message',
          'status': 'in_progress',
          'text': '',
        },
      });
      final event = parser.parseLine(json);
      expect(event, isA<ItemEvent>());
      final item = event as ItemEvent;
      expect(item.eventType, 'item.started');
      expect(item.itemId, 'item_001');
      expect(item.itemType, 'agent_message');
      expect(item.isStarted, isTrue);
      expect(item.isCompleted, isFalse);
      expect(item.isUpdated, isFalse);
    });

    test('parses item.completed event', () {
      final json = jsonEncode({
        'type': 'item.completed',
        'item': {
          'id': 'item_001',
          'type': 'agent_message',
          'status': 'completed',
          'text': 'Hello!',
        },
      });
      final event = parser.parseLine(json);
      expect(event, isA<ItemEvent>());
      final item = event as ItemEvent;
      expect(item.isCompleted, isTrue);
      expect(item.data['text'], 'Hello!');
    });

    test('parses item.updated event', () {
      final json = jsonEncode({
        'type': 'item.updated',
        'item': {'id': 'item_001', 'type': 'todo_list', 'items': []},
      });
      final event = parser.parseLine(json);
      expect(event, isA<ItemEvent>());
      expect((event as ItemEvent).isUpdated, isTrue);
    });

    test('parses error event with string message', () {
      final json = jsonEncode({'type': 'error', 'error': 'connection failed'});
      final event = parser.parseLine(json);
      expect(event, isA<CodexErrorEvent>());
      expect((event as CodexErrorEvent).message, 'connection failed');
    });

    test('parses error event with structured error', () {
      final json = jsonEncode({
        'type': 'error',
        'error': {'message': 'timeout', 'code': 504},
      });
      final event = parser.parseLine(json);
      expect(event, isA<CodexErrorEvent>());
      final error = event as CodexErrorEvent;
      expect(error.message, 'timeout');
      expect(error.details!['code'], 504);
    });

    test('parses unknown event type', () {
      final json = jsonEncode({'type': 'future.event', 'data': 42});
      final event = parser.parseLine(json);
      expect(event, isA<UnknownCodexEvent>());
      expect((event as UnknownCodexEvent).rawData['type'], 'future.event');
    });

    test('trims whitespace before parsing', () {
      final json = '  ${jsonEncode({'type': 'turn.started'})}  ';
      final event = parser.parseLine(json);
      expect(event, isA<TurnStartedEvent>());
    });
  });

  group('CodexEventParser.parseChunk', () {
    test('parses multiple lines', () {
      final chunk = [
        jsonEncode({'type': 'thread.started', 'thread_id': 't1'}),
        jsonEncode({'type': 'turn.started'}),
        jsonEncode({'type': 'turn.completed'}),
      ].join('\n');

      final events = parser.parseChunk(chunk);
      expect(events, hasLength(3));
      expect(events[0], isA<ThreadStartedEvent>());
      expect(events[1], isA<TurnStartedEvent>());
      expect(events[2], isA<TurnCompletedEvent>());
    });

    test('skips empty lines in chunk', () {
      final chunk = [
        jsonEncode({'type': 'turn.started'}),
        '',
        '',
        jsonEncode({'type': 'turn.completed'}),
      ].join('\n');

      final events = parser.parseChunk(chunk);
      expect(events, hasLength(2));
    });

    test('skips unparseable lines in chunk', () {
      final chunk = [
        jsonEncode({'type': 'turn.started'}),
        'not json',
        jsonEncode({'type': 'turn.completed'}),
      ].join('\n');

      final events = parser.parseChunk(chunk);
      expect(events, hasLength(2));
    });

    test('returns empty list for empty chunk', () {
      expect(parser.parseChunk(''), isEmpty);
    });
  });
}
