import 'package:gemini_sdk/gemini_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('GeminiEvent.fromJson', () {
    test('parses init event', () {
      final json = {
        'type': 'init',
        'timestamp': '2026-02-19T10:30:00.000Z',
        'session_id': 'sess_abc123',
        'model': 'gemini-2.5-pro',
      };

      final event = GeminiEvent.fromJson(json);
      expect(event, isA<GeminiInitEvent>());
      final init = event as GeminiInitEvent;
      expect(init.sessionId, 'sess_abc123');
      expect(init.model, 'gemini-2.5-pro');
      expect(init.timestamp.year, 2026);
    });

    test('parses message event with delta', () {
      final json = {
        'type': 'message',
        'timestamp': '2026-02-19T10:30:01.000Z',
        'role': 'assistant',
        'content': 'Hello ',
        'delta': true,
      };

      final event = GeminiEvent.fromJson(json);
      expect(event, isA<GeminiMessageEvent>());
      final msg = event as GeminiMessageEvent;
      expect(msg.role, 'assistant');
      expect(msg.content, 'Hello ');
      expect(msg.isDelta, true);
    });

    test('parses message event without delta', () {
      final json = {
        'type': 'message',
        'timestamp': '2026-02-19T10:30:02.000Z',
        'role': 'assistant',
        'content': 'Hello world!',
      };

      final event = GeminiEvent.fromJson(json);
      expect(event, isA<GeminiMessageEvent>());
      final msg = event as GeminiMessageEvent;
      expect(msg.isDelta, false);
      expect(msg.content, 'Hello world!');
    });

    test('parses tool_use event', () {
      final json = {
        'type': 'tool_use',
        'timestamp': '2026-02-19T10:30:03.000Z',
        'tool_name': 'ReadFile',
        'tool_id': 'tool_123',
        'parameters': {'path': '/tmp/test.txt'},
      };

      final event = GeminiEvent.fromJson(json);
      expect(event, isA<GeminiToolUseEvent>());
      final tool = event as GeminiToolUseEvent;
      expect(tool.toolName, 'ReadFile');
      expect(tool.toolId, 'tool_123');
      expect(tool.parameters, {'path': '/tmp/test.txt'});
    });

    test('parses tool_result event', () {
      final json = {
        'type': 'tool_result',
        'timestamp': '2026-02-19T10:30:04.000Z',
        'tool_id': 'tool_123',
        'status': 'success',
        'output': 'file contents here',
      };

      final event = GeminiEvent.fromJson(json);
      expect(event, isA<GeminiToolResultEvent>());
      final result = event as GeminiToolResultEvent;
      expect(result.toolId, 'tool_123');
      expect(result.status, 'success');
      expect(result.output, 'file contents here');
    });

    test('parses error event', () {
      final json = {
        'type': 'error',
        'timestamp': '2026-02-19T10:30:05.000Z',
        'severity': 'error',
        'message': 'Rate limit exceeded',
      };

      final event = GeminiEvent.fromJson(json);
      expect(event, isA<GeminiErrorEvent>());
      final err = event as GeminiErrorEvent;
      expect(err.severity, 'error');
      expect(err.message, 'Rate limit exceeded');
    });

    test('parses result event with stats', () {
      final json = {
        'type': 'result',
        'timestamp': '2026-02-19T10:30:06.000Z',
        'status': 'completed',
        'stats': {
          'total_tokens': 1500,
          'input_tokens': 1000,
          'output_tokens': 500,
          'duration_ms': 3200,
        },
      };

      final event = GeminiEvent.fromJson(json);
      expect(event, isA<GeminiResultEvent>());
      final result = event as GeminiResultEvent;
      expect(result.status, 'completed');
      expect(result.stats, isNotNull);
      expect(result.stats!.totalTokens, 1500);
      expect(result.stats!.inputTokens, 1000);
      expect(result.stats!.outputTokens, 500);
      expect(result.stats!.durationMs, 3200);
    });

    test('parses result event without stats', () {
      final json = {
        'type': 'result',
        'timestamp': '2026-02-19T10:30:07.000Z',
        'status': 'error',
      };

      final event = GeminiEvent.fromJson(json);
      expect(event, isA<GeminiResultEvent>());
      final result = event as GeminiResultEvent;
      expect(result.status, 'error');
      expect(result.stats, isNull);
    });

    test('parses unknown event type', () {
      final json = {
        'type': 'future_event_type',
        'timestamp': '2026-02-19T10:30:08.000Z',
        'some_field': 'some_value',
      };

      final event = GeminiEvent.fromJson(json);
      expect(event, isA<GeminiUnknownEvent>());
      final unknown = event as GeminiUnknownEvent;
      expect(unknown.type, 'future_event_type');
      expect(unknown.data['some_field'], 'some_value');
    });

    test('handles missing timestamp', () {
      final json = {'type': 'init', 'session_id': 'sess_abc'};

      final event = GeminiEvent.fromJson(json);
      expect(event, isA<GeminiInitEvent>());
      // Should use DateTime.now() as fallback
      expect(
        event.timestamp.difference(DateTime.now()).inSeconds.abs(),
        lessThan(2),
      );
    });

    test('handles missing fields gracefully', () {
      final json = <String, dynamic>{'type': 'message'};

      final event = GeminiEvent.fromJson(json);
      expect(event, isA<GeminiMessageEvent>());
      final msg = event as GeminiMessageEvent;
      expect(msg.role, 'assistant');
      expect(msg.content, '');
      expect(msg.isDelta, false);
    });

    test('handles missing type field', () {
      final json = <String, dynamic>{'timestamp': '2026-02-19T10:30:00.000Z'};

      final event = GeminiEvent.fromJson(json);
      expect(event, isA<GeminiUnknownEvent>());
    });
  });

  group('GeminiStats.fromJson', () {
    test('parses all fields', () {
      final json = {
        'total_tokens': 2000,
        'input_tokens': 1500,
        'output_tokens': 500,
        'duration_ms': 4500,
      };

      final stats = GeminiStats.fromJson(json);
      expect(stats.totalTokens, 2000);
      expect(stats.inputTokens, 1500);
      expect(stats.outputTokens, 500);
      expect(stats.durationMs, 4500);
    });

    test('defaults missing fields to zero', () {
      final stats = GeminiStats.fromJson({});
      expect(stats.totalTokens, 0);
      expect(stats.inputTokens, 0);
      expect(stats.outputTokens, 0);
      expect(stats.durationMs, 0);
    });
  });

  group('GeminiConfig', () {
    test('toCliArgs produces correct basic args', () {
      const config = GeminiConfig();
      final args = config.toCliArgs('hello world');

      expect(args, contains('-p'));
      expect(args, contains('hello world'));
      expect(args, contains('-o'));
      expect(args, contains('stream-json'));
      expect(args, contains('--approval-mode'));
      expect(args, contains('yolo'));
    });

    test('toCliArgs includes model when set', () {
      const config = GeminiConfig(model: 'gemini-2.5-flash');
      final args = config.toCliArgs('test');

      expect(args, contains('-m'));
      expect(args, contains('gemini-2.5-flash'));
    });

    test('toCliArgs includes resume when sessionId is set', () {
      const config = GeminiConfig(sessionId: 'sess_abc123');
      final args = config.toCliArgs('test');

      expect(args, contains('--resume'));
      expect(args, contains('sess_abc123'));
    });

    test('toCliArgs includes sandbox when set', () {
      const config = GeminiConfig(sandbox: 'strict');
      final args = config.toCliArgs('test');

      expect(args, contains('--sandbox'));
      expect(args, contains('strict'));
    });

    test('default approvalMode is yolo', () {
      const config = GeminiConfig();
      expect(config.approvalMode, 'yolo');
    });

    test('copyWith preserves unchanged fields', () {
      const config = GeminiConfig(
        model: 'gemini-2.5-pro',
        approvalMode: 'yolo',
        apiKey: 'key123',
      );

      final copied = config.copyWith(model: 'gemini-2.5-flash');
      expect(copied.model, 'gemini-2.5-flash');
      expect(copied.approvalMode, 'yolo');
      expect(copied.apiKey, 'key123');
    });
  });
}
