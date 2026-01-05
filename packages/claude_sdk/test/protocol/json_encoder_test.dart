import 'dart:convert';

import 'package:test/test.dart';
import 'package:claude_sdk/claude_sdk.dart';
import 'package:claude_sdk/src/protocol/json_encoder.dart';

void main() {
  group('JsonEncoder - Edge Cases', () {
    late JsonEncoder encoder;

    setUp(() {
      encoder = const JsonEncoder();
    });

    group('unicode in messages', () {
      test('encodes emoji correctly', () {
        final message = Message(text: 'Hello 👋 World 🌍!');
        final encoded = encoder.encode(message);

        // Should be valid JSON
        expect(encoded.endsWith('\n'), isTrue);
        final decoded = jsonDecode(encoded.trim()) as Map<String, dynamic>;

        expect(
          decoded['message']['content'][0]['text'],
          equals('Hello 👋 World 🌍!'),
        );
      });

      test('encodes Chinese characters correctly', () {
        final message = Message(text: '你好世界 - Hello World');
        final encoded = encoder.encode(message);

        final decoded = jsonDecode(encoded.trim()) as Map<String, dynamic>;
        expect(
          decoded['message']['content'][0]['text'],
          equals('你好世界 - Hello World'),
        );
      });

      test('encodes Japanese characters correctly', () {
        final message = Message(text: 'こんにちは世界');
        final encoded = encoder.encode(message);

        final decoded = jsonDecode(encoded.trim()) as Map<String, dynamic>;
        expect(decoded['message']['content'][0]['text'], equals('こんにちは世界'));
      });

      test('encodes Arabic RTL text correctly', () {
        final message = Message(text: 'مرحبا بالعالم');
        final encoded = encoder.encode(message);

        final decoded = jsonDecode(encoded.trim()) as Map<String, dynamic>;
        expect(
          decoded['message']['content'][0]['text'],
          equals('مرحبا بالعالم'),
        );
      });

      test('encodes mixed unicode scripts', () {
        final message = Message(text: 'English 日本語 العربية Ελληνικά');
        final encoded = encoder.encode(message);

        final decoded = jsonDecode(encoded.trim()) as Map<String, dynamic>;
        expect(
          decoded['message']['content'][0]['text'],
          equals('English 日本語 العربية Ελληνικά'),
        );
      });

      test('encodes special unicode symbols', () {
        final message = Message(text: '© ® ™ € £ ¥ → ← ↑ ↓ ✓ ✗ ♠ ♥ ♦ ♣');
        final encoded = encoder.encode(message);

        final decoded = jsonDecode(encoded.trim()) as Map<String, dynamic>;
        expect(
          decoded['message']['content'][0]['text'],
          equals('© ® ™ € £ ¥ → ← ↑ ↓ ✓ ✗ ♠ ♥ ♦ ♣'),
        );
      });
    });

    group('very long messages', () {
      test('encodes message with 100KB content', () {
        final longText = 'a' * 100000;
        final message = Message(text: longText);
        final encoded = encoder.encode(message);

        expect(encoded.endsWith('\n'), isTrue);

        final decoded = jsonDecode(encoded.trim()) as Map<String, dynamic>;
        expect(decoded['message']['content'][0]['text'].length, equals(100000));
      });

      test('encodes message with many lines', () {
        final lines = List.generate(1000, (i) => 'Line $i').join('\n');
        final message = Message(text: lines);
        final encoded = encoder.encode(message);

        final decoded = jsonDecode(encoded.trim()) as Map<String, dynamic>;
        expect(decoded['message']['content'][0]['text'], contains('Line 0'));
        expect(decoded['message']['content'][0]['text'], contains('Line 999'));
      });

      test('encodes message with mixed content and long text', () {
        final longContent = 'Code:\n${'x' * 50000}\nEnd';
        final message = Message(text: longContent);
        final encoded = encoder.encode(message);

        final decoded = jsonDecode(encoded.trim()) as Map<String, dynamic>;
        expect(decoded['message']['content'][0]['text'], startsWith('Code:\n'));
        expect(decoded['message']['content'][0]['text'], endsWith('\nEnd'));
      });
    });

    group('special characters requiring escaping', () {
      test('escapes double quotes', () {
        final message = Message(text: 'He said "Hello"');
        final encoded = encoder.encode(message);

        // Should parse correctly
        final decoded = jsonDecode(encoded.trim()) as Map<String, dynamic>;
        expect(
          decoded['message']['content'][0]['text'],
          equals('He said "Hello"'),
        );
      });

      test('escapes backslashes', () {
        final message = Message(text: r'Path: C:\Users\test');
        final encoded = encoder.encode(message);

        final decoded = jsonDecode(encoded.trim()) as Map<String, dynamic>;
        expect(
          decoded['message']['content'][0]['text'],
          equals(r'Path: C:\Users\test'),
        );
      });

      test('escapes newlines and tabs', () {
        final message = Message(text: 'Line 1\n\tIndented\nLine 3');
        final encoded = encoder.encode(message);

        final decoded = jsonDecode(encoded.trim()) as Map<String, dynamic>;
        expect(
          decoded['message']['content'][0]['text'],
          equals('Line 1\n\tIndented\nLine 3'),
        );
      });

      test('escapes control characters', () {
        final message = Message(text: 'Bell: \x07 Form feed: \x0C');
        final encoded = encoder.encode(message);

        // Should still be valid JSON
        final decoded = jsonDecode(encoded.trim()) as Map<String, dynamic>;
        expect(decoded['message']['content'][0]['text'], isNotEmpty);
      });

      test('escapes null character', () {
        final message = Message(text: 'Before\x00After');
        final encoded = encoder.encode(message);

        // Should be valid JSON
        final decoded = jsonDecode(encoded.trim()) as Map<String, dynamic>;
        expect(decoded['message']['content'][0]['text'], contains('Before'));
      });

      test('handles nested JSON-like strings in text', () {
        final message = Message(
          text: 'The JSON is: {"key": "value", "num": 42}',
        );
        final encoded = encoder.encode(message);

        final decoded = jsonDecode(encoded.trim()) as Map<String, dynamic>;
        expect(
          decoded['message']['content'][0]['text'],
          equals('The JSON is: {"key": "value", "num": 42}'),
        );
      });

      test('handles code with various brackets', () {
        final message = Message(text: 'function test() { return [1, 2, 3]; }');
        final encoded = encoder.encode(message);

        final decoded = jsonDecode(encoded.trim()) as Map<String, dynamic>;
        expect(
          decoded['message']['content'][0]['text'],
          equals('function test() { return [1, 2, 3]; }'),
        );
      });
    });

    group('empty attachments array', () {
      test('encodes message with null attachments', () {
        final message = Message(text: 'No attachments');
        final encoded = encoder.encode(message);

        final decoded = jsonDecode(encoded.trim()) as Map<String, dynamic>;
        final content = decoded['message']['content'] as List;

        // Should only have text content, no attachment entries
        expect(content.length, equals(1));
        expect(content[0]['type'], equals('text'));
      });

      test('encodes message with empty attachments list', () {
        final message = Message(text: 'Empty attachments', attachments: []);
        final encoded = encoder.encode(message);

        final decoded = jsonDecode(encoded.trim()) as Map<String, dynamic>;
        final content = decoded['message']['content'] as List;

        expect(content.length, equals(1));
        expect(content[0]['type'], equals('text'));
      });
    });

    group('multiple attachment types', () {
      test('encodes message with multiple file attachments', () {
        final message = Message(
          text: 'Multiple files',
          attachments: [
            Attachment.file('/path/to/file1.txt'),
            Attachment.file('/path/to/file2.txt'),
            Attachment.file('/path/to/file3.txt'),
          ],
        );
        final encoded = encoder.encode(message);

        final decoded = jsonDecode(encoded.trim()) as Map<String, dynamic>;
        final content = decoded['message']['content'] as List;

        expect(content.length, equals(4)); // 1 text + 3 files
        expect(content[0]['type'], equals('text'));
        expect(content[1]['type'], equals('file'));
        expect(content[2]['type'], equals('file'));
        expect(content[3]['type'], equals('file'));
      });

      test('encodes message with mixed image and file attachments', () {
        final message = Message(
          text: 'Mixed attachments',
          attachments: [
            Attachment.imageBase64('aW1hZ2VkYXRh', 'image/png'),
            Attachment.file('/path/to/doc.txt'),
            Attachment.imageBase64('b3RoZXJpbWFnZQ==', 'image/jpeg'),
          ],
        );
        final encoded = encoder.encode(message);

        final decoded = jsonDecode(encoded.trim()) as Map<String, dynamic>;
        final content = decoded['message']['content'] as List;

        expect(content.length, equals(4)); // 1 text + 3 attachments
        expect(content[0]['type'], equals('text'));
        expect(content[1]['type'], equals('image'));
        expect(content[2]['type'], equals('file'));
        expect(content[3]['type'], equals('image'));
      });

      test('encodes message with document attachment', () {
        final message = Message(
          text: 'With document',
          attachments: [
            Attachment.documentText(
              text: 'Document content here',
              title: 'My Document',
            ),
          ],
        );
        final encoded = encoder.encode(message);

        final decoded = jsonDecode(encoded.trim()) as Map<String, dynamic>;
        final content = decoded['message']['content'] as List;

        expect(content.length, equals(2));
        expect(content[1]['type'], equals('document'));
        expect(content[1]['source']['type'], equals('text'));
        expect(content[1]['source']['data'], equals('Document content here'));
        expect(content[1]['title'], equals('My Document'));
      });
    });

    group('encodeToolResult', () {
      test('encodes simple tool result', () {
        final encoded = encoder.encodeToolResult(
          toolUseId: 'tool-abc123',
          result: {'success': true, 'output': 'Done'},
        );

        expect(encoded.endsWith('\n'), isTrue);

        final decoded = jsonDecode(encoded.trim()) as Map<String, dynamic>;
        expect(decoded['type'], equals('tool_result'));
        expect(decoded['tool_use_id'], equals('tool-abc123'));
        expect(decoded['content'], isA<String>());

        // Content is JSON encoded
        final content = jsonDecode(decoded['content']);
        expect(content['success'], isTrue);
        expect(content['output'], equals('Done'));
      });

      test('encodes tool result with complex nested data', () {
        final encoded = encoder.encodeToolResult(
          toolUseId: 'tool-xyz',
          result: {
            'files': [
              {'name': 'a.dart', 'lines': 100},
              {'name': 'b.dart', 'lines': 200},
            ],
            'metadata': {
              'total': 300,
              'nested': {'deep': 'value'},
            },
          },
        );

        final decoded = jsonDecode(encoded.trim()) as Map<String, dynamic>;
        final content = jsonDecode(decoded['content']);

        expect(content['files'], hasLength(2));
        expect(content['metadata']['nested']['deep'], equals('value'));
      });

      test('encodes tool result with unicode in result', () {
        final encoded = encoder.encodeToolResult(
          toolUseId: 'tool-unicode',
          result: {'message': '成功 ✓ Complete 🎉'},
        );

        final decoded = jsonDecode(encoded.trim()) as Map<String, dynamic>;
        final content = jsonDecode(decoded['content']);

        expect(content['message'], equals('成功 ✓ Complete 🎉'));
      });

      test('encodes tool result with error', () {
        final encoded = encoder.encodeToolResult(
          toolUseId: 'tool-error',
          result: {'error': 'File not found', 'path': '/missing/file.txt'},
        );

        final decoded = jsonDecode(encoded.trim()) as Map<String, dynamic>;
        final content = jsonDecode(decoded['content']);

        expect(content['error'], equals('File not found'));
      });
    });

    group('encodeRaw', () {
      test('encodes arbitrary JSON map', () {
        final encoded = encoder.encodeRaw({
          'custom': 'field',
          'number': 42,
          'nested': {'a': 1},
        });

        expect(encoded.endsWith('\n'), isTrue);

        final decoded = jsonDecode(encoded.trim()) as Map<String, dynamic>;
        expect(decoded['custom'], equals('field'));
        expect(decoded['number'], equals(42));
        expect(decoded['nested']['a'], equals(1));
      });

      test('encodes empty map', () {
        final encoded = encoder.encodeRaw({});

        final decoded = jsonDecode(encoded.trim()) as Map<String, dynamic>;
        expect(decoded, isEmpty);
      });

      test('encodes map with list values', () {
        final encoded = encoder.encodeRaw({
          'items': [1, 2, 3],
          'mixed': ['a', 1, true, null],
        });

        final decoded = jsonDecode(encoded.trim()) as Map<String, dynamic>;
        expect(decoded['items'], equals([1, 2, 3]));
        expect(decoded['mixed'], equals(['a', 1, true, null]));
      });
    });

    group('message format compliance', () {
      test('follows Claude API user message format', () {
        final message = Message(text: 'Test message');
        final encoded = encoder.encode(message);

        final decoded = jsonDecode(encoded.trim()) as Map<String, dynamic>;

        // Verify structure matches Claude API expectations
        expect(decoded['type'], equals('user'));
        expect(decoded['message'], isA<Map>());
        expect(decoded['message']['role'], equals('user'));
        expect(decoded['message']['content'], isA<List>());
        expect(decoded['message']['content'][0]['type'], equals('text'));
        expect(decoded['message']['content'][0]['text'], isA<String>());
      });

      test('content is always an array', () {
        final message = Message(text: 'Single text');
        final encoded = encoder.encode(message);

        final decoded = jsonDecode(encoded.trim()) as Map<String, dynamic>;

        // Even with single content, should be array
        expect(decoded['message']['content'], isA<List>());
        expect((decoded['message']['content'] as List).length, equals(1));
      });
    });

    group('edge cases', () {
      test('encodes empty text message', () {
        final message = Message(text: '');
        final encoded = encoder.encode(message);

        final decoded = jsonDecode(encoded.trim()) as Map<String, dynamic>;
        expect(decoded['message']['content'][0]['text'], equals(''));
      });

      test('encodes message with only whitespace', () {
        final message = Message(text: '   \n\t  ');
        final encoded = encoder.encode(message);

        final decoded = jsonDecode(encoded.trim()) as Map<String, dynamic>;
        expect(decoded['message']['content'][0]['text'], equals('   \n\t  '));
      });

      test('output always ends with exactly one newline', () {
        final message = Message(text: 'Test');
        final encoded = encoder.encode(message);

        expect(encoded.endsWith('\n'), isTrue);
        expect(encoded.endsWith('\n\n'), isFalse);
      });
    });
  });
}
