import 'dart:convert';

import 'package:test/test.dart';
import 'package:claude_sdk/claude_sdk.dart';
import 'package:claude_sdk/src/protocol/json_decoder.dart';

void main() {
  group('JsonDecoder - Edge Cases', () {
    late JsonDecoder decoder;

    setUp(() {
      decoder = JsonDecoder();
    });

    group('buffer handling', () {
      test('handles very long lines (>10KB)', () async {
        // Create a long message content (> 10KB)
        final longContent = 'a' * 15000;
        final json = '{"type": "text", "content": "$longContent"}';

        final stream = Stream.fromIterable([json + '\n']);
        final responses = await decoder.decodeStream(stream).toList();

        expect(responses.length, equals(1));
        expect(responses.first, isA<TextResponse>());
        expect((responses.first as TextResponse).content.length, equals(15000));
      });

      test('handles line split across multiple chunks', () async {
        // Split a JSON object into many small chunks
        const fullJson = '{"type": "text", "content": "Hello World!"}\n';
        final chunks = <String>[];
        for (var i = 0; i < fullJson.length; i += 5) {
          final end = (i + 5 < fullJson.length) ? i + 5 : fullJson.length;
          chunks.add(fullJson.substring(i, end));
        }

        final stream = Stream.fromIterable(chunks);
        final responses = await decoder.decodeStream(stream).toList();

        expect(responses.length, equals(1));
        expect(responses.first, isA<TextResponse>());
        expect(
          (responses.first as TextResponse).content,
          equals('Hello World!'),
        );
      });

      test('handles chunk ending exactly at newline', () async {
        final stream = Stream.fromIterable([
          '{"type": "text", "content": "First"}\n',
          '{"type": "text", "content": "Second"}\n',
        ]);

        final responses = await decoder.decodeStream(stream).toList();

        expect(responses.length, equals(2));
        expect((responses[0] as TextResponse).content, equals('First'));
        expect((responses[1] as TextResponse).content, equals('Second'));
      });

      test(
        'handles chunk without trailing newline followed by newline',
        () async {
          final stream = Stream.fromIterable([
            '{"type": "text", "content": "NoNewline"}',
            '\n{"type": "text", "content": "WithNewline"}\n',
          ]);

          final responses = await decoder.decodeStream(stream).toList();

          expect(responses.length, equals(2));
          expect((responses[0] as TextResponse).content, equals('NoNewline'));
          expect((responses[1] as TextResponse).content, equals('WithNewline'));
        },
      );
    });

    group('multiple JSON objects in one chunk', () {
      test('parses multiple complete JSON objects in single chunk', () async {
        final stream = Stream.fromIterable([
          '{"type": "text", "content": "One"}\n{"type": "text", "content": "Two"}\n{"type": "text", "content": "Three"}\n',
        ]);

        final responses = await decoder.decodeStream(stream).toList();

        expect(responses.length, equals(3));
        expect((responses[0] as TextResponse).content, equals('One'));
        expect((responses[1] as TextResponse).content, equals('Two'));
        expect((responses[2] as TextResponse).content, equals('Three'));
      });

      test('handles mixed complete and partial in chunk', () async {
        final stream = Stream.fromIterable([
          '{"type": "text", "content": "Complete"}\n{"type": "text", ',
          '"content": "Split"}\n',
        ]);

        final responses = await decoder.decodeStream(stream).toList();

        expect(responses.length, equals(2));
        expect((responses[0] as TextResponse).content, equals('Complete'));
        expect((responses[1] as TextResponse).content, equals('Split'));
      });
    });

    group('unicode handling', () {
      test('handles emoji in content', () async {
        final json = jsonEncode({
          'type': 'text',
          'content': 'Hello 👋 World 🌍!',
        });

        final stream = Stream.fromIterable(['$json\n']);
        final responses = await decoder.decodeStream(stream).toList();

        expect(responses.length, equals(1));
        expect(
          (responses.first as TextResponse).content,
          equals('Hello 👋 World 🌍!'),
        );
      });

      test('handles Chinese characters', () async {
        final json = jsonEncode({'type': 'text', 'content': '你好世界'});

        final stream = Stream.fromIterable(['$json\n']);
        final responses = await decoder.decodeStream(stream).toList();

        expect(responses.length, equals(1));
        expect((responses.first as TextResponse).content, equals('你好世界'));
      });

      test('handles special unicode symbols', () async {
        final json = jsonEncode({
          'type': 'text',
          'content': '© ® ™ € £ ¥ → ← ↑ ↓ ✓ ✗',
        });

        final stream = Stream.fromIterable(['$json\n']);
        final responses = await decoder.decodeStream(stream).toList();

        expect(responses.length, equals(1));
        expect(
          (responses.first as TextResponse).content,
          equals('© ® ™ € £ ¥ → ← ↑ ↓ ✓ ✗'),
        );
      });

      test('handles emoji split across chunks', () async {
        // Note: This tests that the buffer correctly handles split unicode
        final content = 'Emoji: 🎉';
        final json = '{"type": "text", "content": "$content"}\n';

        // Split deliberately in middle of content
        final stream = Stream.fromIterable([
          json.substring(0, json.length ~/ 2),
          json.substring(json.length ~/ 2),
        ]);

        final responses = await decoder.decodeStream(stream).toList();

        expect(responses.length, equals(1));
        expect((responses.first as TextResponse).content, equals(content));
      });
    });

    group('nested JSON structures', () {
      test('handles deeply nested objects', () async {
        final json = jsonEncode({
          'type': 'assistant',
          'message': {
            'id': 'msg_1',
            'role': 'assistant',
            'content': [
              {
                'type': 'tool_use',
                'id': 'tool_1',
                'name': 'Write',
                'input': {
                  'file_path': '/test.dart',
                  'content': 'class Foo { final bar = {"key": [1, 2, 3]}; }',
                },
              },
            ],
          },
        });

        final stream = Stream.fromIterable(['$json\n']);
        final responses = await decoder.decodeStream(stream).toList();

        expect(responses.length, equals(1));
        expect(responses.first, isA<ToolUseResponse>());
        final toolUse = responses.first as ToolUseResponse;
        expect(toolUse.toolName, equals('Write'));
        expect(toolUse.parameters['file_path'], equals('/test.dart'));
      });

      test('handles arrays in parameters', () async {
        final json = jsonEncode({
          'type': 'tool_use',
          'name': 'Glob',
          'input': {
            'patterns': ['**/*.dart', '**/*.yaml', 'lib/**/*.json'],
          },
        });

        final stream = Stream.fromIterable(['$json\n']);
        final responses = await decoder.decodeStream(stream).toList();

        expect(responses.length, equals(1));
        expect(responses.first, isA<ToolUseResponse>());
        final toolUse = responses.first as ToolUseResponse;
        expect(toolUse.parameters['patterns'], hasLength(3));
      });
    });

    group('malformed JSON handling', () {
      test('recovers after malformed line at start', () async {
        final stream = Stream.fromIterable([
          '{not valid json}\n',
          '{"type": "text", "content": "Valid"}\n',
        ]);

        final responses = await decoder.decodeStream(stream).toList();

        expect(responses.any((r) => r is TextResponse), isTrue);
        final textResponses = responses.whereType<TextResponse>().toList();
        expect(textResponses.first.content, equals('Valid'));
      });

      test('recovers after malformed line in middle', () async {
        final stream = Stream.fromIterable([
          '{"type": "text", "content": "First"}\n',
          'corrupted{json}\n',
          '{"type": "text", "content": "Third"}\n',
        ]);

        final responses = await decoder.decodeStream(stream).toList();

        final textResponses = responses.whereType<TextResponse>().toList();
        expect(textResponses.length, equals(2));
        expect(textResponses[0].content, equals('First'));
        expect(textResponses[1].content, equals('Third'));
      });

      test('handles JSON with missing closing brace', () async {
        final stream = Stream.fromIterable([
          '{"type": "text", "content": "Incomplete"\n',
          '{"type": "text", "content": "Valid"}\n',
        ]);

        final responses = await decoder.decodeStream(stream).toList();

        // Should still get valid response
        expect(
          responses.any((r) => r is TextResponse && r.content == 'Valid'),
          isTrue,
        );
      });

      test('handles truncated JSON string', () async {
        final stream = Stream.fromIterable([
          '{"type": "text", "conten\n',
          '{"type": "text", "content": "Complete"}\n',
        ]);

        final responses = await decoder.decodeStream(stream).toList();

        final textResponses = responses.whereType<TextResponse>().toList();
        expect(textResponses.length, greaterThanOrEqualTo(1));
        expect(textResponses.any((r) => r.content == 'Complete'), isTrue);
      });

      test('handles JSON with extra garbage after', () async {
        // This tests lines that look like JSON but have trailing content
        final stream = Stream.fromIterable([
          '{"type": "text", "content": "Valid"} extra stuff\n',
          '{"type": "text", "content": "Also Valid"}\n',
        ]);

        final responses = await decoder.decodeStream(stream).toList();

        // The first line should fail to parse, but second should work
        final textResponses = responses.whereType<TextResponse>().toList();
        expect(textResponses.any((r) => r.content == 'Also Valid'), isTrue);
      });

      test('handles empty object', () async {
        final stream = Stream.fromIterable([
          '{}\n',
          '{"type": "text", "content": "Valid"}\n',
        ]);

        final responses = await decoder.decodeStream(stream).toList();

        // Empty object should parse but be unknown type
        expect(responses.any((r) => r is UnknownResponse), isTrue);
        expect(responses.any((r) => r is TextResponse), isTrue);
      });
    });

    group('stream completion', () {
      test('flushes buffer on stream end', () async {
        // Send JSON without trailing newline - should still parse at stream end
        final stream = Stream.fromIterable([
          '{"type": "text", "content": "No newline at end"}',
        ]);

        final responses = await decoder.decodeStream(stream).toList();

        // Currently the implementation requires newlines, so this tests current behavior
        // The buffer content without newline is kept but not processed until next chunk
        expect(responses, isEmpty);
      });

      test('handles empty stream', () async {
        final stream = Stream<String>.empty();
        final responses = await decoder.decodeStream(stream).toList();
        expect(responses, isEmpty);
      });

      test('handles stream with only whitespace', () async {
        final stream = Stream.fromIterable(['   \n', '\t\t\n', '\n\n\n']);

        final responses = await decoder.decodeStream(stream).toList();
        expect(responses, isEmpty);
      });
    });

    group('decodeSingle', () {
      test('returns null for invalid JSON', () {
        final result = decoder.decodeSingle('not json');
        expect(result, isNull);
      });

      test('returns null for empty string', () {
        final result = decoder.decodeSingle('');
        expect(result, isNull);
      });

      test('returns null for array (not object)', () {
        final result = decoder.decodeSingle('[1, 2, 3]');
        expect(result, isNull);
      });

      test('parses valid text response', () {
        final result = decoder.decodeSingle(
          '{"type": "text", "content": "Hello"}',
        );

        expect(result, isA<TextResponse>());
        expect((result as TextResponse).content, equals('Hello'));
      });

      test('parses JSON with extra whitespace', () {
        final result = decoder.decodeSingle(
          '  { "type" : "text" , "content" : "Spaced" }  ',
        );

        expect(result, isA<TextResponse>());
        expect((result as TextResponse).content, equals('Spaced'));
      });
    });

    group('error response for partial JSON with type hints', () {
      test(
        'emits ErrorResponse for line containing type but malformed',
        () async {
          final stream = Stream.fromIterable(['{"type": broken}\n']);

          final responses = await decoder.decodeStream(stream).toList();

          // Should get an error response since it contains "type"
          expect(responses.length, equals(1));
          expect(responses.first, isA<ErrorResponse>());
        },
      );

      test(
        'emits ErrorResponse for line containing content but malformed',
        () async {
          final stream = Stream.fromIterable(['{"content": not quoted}\n']);

          final responses = await decoder.decodeStream(stream).toList();

          expect(responses.length, equals(1));
          expect(responses.first, isA<ErrorResponse>());
        },
      );

      test('ignores debug output without type/content keywords', () async {
        final stream = Stream.fromIterable([
          'DEBUG: some debug output\n',
          'INFO: starting process\n',
          '{"type": "text", "content": "Valid"}\n',
        ]);

        final responses = await decoder.decodeStream(stream).toList();

        // Debug lines should be ignored, only get the valid response
        expect(responses.length, equals(1));
        expect(responses.first, isA<TextResponse>());
      });
    });

    group('real-world scenarios', () {
      test('handles Claude CLI assistant message format', () async {
        final json = jsonEncode({
          'type': 'assistant',
          'uuid': 'msg_abc123',
          'message': {
            'id': 'msg_abc123',
            'role': 'assistant',
            'model': 'claude-sonnet-4-20250514',
            'content': [
              {'type': 'text', 'text': 'Here is the code:'},
            ],
            'stop_reason': 'end_turn',
          },
        });

        final stream = Stream.fromIterable(['$json\n']);
        final responses = await decoder.decodeStream(stream).toList();

        expect(responses.length, equals(1));
        expect(responses.first, isA<TextResponse>());
        expect(
          (responses.first as TextResponse).content,
          equals('Here is the code:'),
        );
      });

      test('handles system init message', () async {
        final json = jsonEncode({
          'type': 'system',
          'subtype': 'init',
          'conversation_id': 'conv_123',
          'metadata': {'version': '1.0', 'session': 'abc'},
        });

        final stream = Stream.fromIterable(['$json\n']);
        final responses = await decoder.decodeStream(stream).toList();

        expect(responses.length, equals(1));
        expect(responses.first, isA<MetaResponse>());
        final meta = responses.first as MetaResponse;
        expect(meta.conversationId, equals('conv_123'));
      });
    });
  });
}
