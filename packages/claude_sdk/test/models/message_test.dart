import 'package:test/test.dart';
import 'package:claude_sdk/claude_sdk.dart';
import 'dart:convert';

void main() {
  group('Message', () {
    group('constructors', () {
      test('creates message with text only', () {
        final message = Message(text: 'Hello');
        expect(message.text, equals('Hello'));
        expect(message.attachments, isNull);
        expect(message.metadata, isNull);
      });

      test('creates message with text and attachments', () {
        final message = Message(
          text: 'Hello',
          attachments: [Attachment.file('/path/to/file.txt')],
        );
        expect(message.text, equals('Hello'));
        expect(message.attachments, hasLength(1));
        expect(message.attachments![0].type, equals('file'));
      });

      test('creates message with metadata', () {
        final message = Message(
          text: 'Hello',
          metadata: {'source': 'test', 'priority': 1},
        );
        expect(message.text, equals('Hello'));
        expect(message.metadata, isNotNull);
        expect(message.metadata!['source'], equals('test'));
        expect(message.metadata!['priority'], equals(1));
      });

      test('Message.text factory creates text-only message', () {
        final message = Message.text('Simple text');
        expect(message.text, equals('Simple text'));
        expect(message.attachments, isNull);
        expect(message.metadata, isNull);
      });

      test('handles empty text', () {
        final message = Message(text: '');
        expect(message.text, equals(''));
      });

      test('handles multiline text', () {
        final text = '''Line 1
Line 2
Line 3''';
        final message = Message(text: text);
        expect(message.text, equals(text));
        expect(message.text.split('\n'), hasLength(3));
      });

      test('handles text with special characters', () {
        final text = 'Special chars: <>&"\'`\${}[]\\n\\t';
        final message = Message(text: text);
        expect(message.text, equals(text));
      });

      test('handles unicode text', () {
        final text = 'Unicode: 你好世界 🌍 привет мир';
        final message = Message(text: text);
        expect(message.text, equals(text));
      });
    });

    group('JSON serialization', () {
      test('toJson and fromJson round-trip for simple message', () {
        final original = Message(text: 'Test message');
        final json = original.toJson();
        final restored = Message.fromJson(json);
        expect(restored.text, equals(original.text));
      });

      test('toJson and fromJson round-trip with attachments', () {
        final original = Message(
          text: 'With attachments',
          attachments: [
            Attachment.file('/path/file.txt'),
            Attachment.imageBase64('dGVzdA==', 'image/png'),
          ],
        );
        // Need to go through JSON encoding to get proper Map structures
        final jsonString = jsonEncode(original.toJson());
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        final restored = Message.fromJson(json);
        expect(restored.text, equals(original.text));
        expect(restored.attachments, hasLength(2));
        expect(restored.attachments![0].type, equals('file'));
        expect(restored.attachments![1].type, equals('image'));
      });

      test('toJson and fromJson round-trip with metadata', () {
        final original = Message(
          text: 'With metadata',
          metadata: {
            'key': 'value',
            'nested': {'a': 1},
          },
        );
        final json = original.toJson();
        final restored = Message.fromJson(json);
        expect(restored.text, equals(original.text));
        expect(restored.metadata, equals(original.metadata));
      });
    });

    group('toClaudeJson', () {
      test('serializes to Claude API format', () {
        final message = Message(text: 'Hello Claude');
        final json = message.toClaudeJson();

        expect(json['type'], equals('user'));
        expect(json['message']['role'], equals('user'));
        expect(json['message']['content'], isList);
        expect(json['message']['content'][0]['type'], equals('text'));
        expect(json['message']['content'][0]['text'], equals('Hello Claude'));
      });

      test('message without attachments has single content item', () {
        final message = Message(text: 'No attachments');
        final json = message.toClaudeJson();

        expect(json['message']['content'], hasLength(1));
        expect(json['message']['content'][0]['type'], equals('text'));
      });

      test('message with empty text serializes correctly', () {
        final message = Message(text: '');
        final json = message.toClaudeJson();

        expect(json['message']['content'][0]['text'], equals(''));
      });

      test('content array includes text before attachments', () {
        final message = Message(
          text: 'Text first',
          attachments: [
            Attachment.imageBase64('aW1n', 'image/png'),
            Attachment.documentText(text: 'doc content'),
          ],
        );
        final json = message.toClaudeJson();
        final content = json['message']['content'] as List;

        expect(content[0]['type'], equals('text'));
        expect(content[0]['text'], equals('Text first'));
        expect(content[1]['type'], equals('image'));
        expect(content[2]['type'], equals('document'));
      });
    });
  });

  group('Attachment', () {
    group('Attachment.file factory', () {
      test('creates file attachment with path', () {
        final attachment = Attachment.file('/path/to/file.txt');
        expect(attachment.type, equals('file'));
        expect(attachment.path, equals('/path/to/file.txt'));
        expect(attachment.content, isNull);
        expect(attachment.mimeType, isNull);
      });

      test('handles paths with spaces', () {
        final attachment = Attachment.file('/path/with spaces/file.txt');
        expect(attachment.path, equals('/path/with spaces/file.txt'));
      });

      test('handles Windows-style paths', () {
        final attachment = Attachment.file('C:\\Users\\test\\file.txt');
        expect(attachment.path, equals('C:\\Users\\test\\file.txt'));
      });
    });

    group('Attachment.image factory', () {
      test('creates image attachment with path and detected mime type', () {
        final attachment = Attachment.image('/path/to/image.png');
        expect(attachment.type, equals('image'));
        expect(attachment.path, equals('/path/to/image.png'));
        expect(attachment.mimeType, equals('image/png'));
      });

      test('detects various image formats', () {
        expect(Attachment.image('test.png').mimeType, equals('image/png'));
        expect(Attachment.image('test.jpg').mimeType, equals('image/jpeg'));
        expect(Attachment.image('test.jpeg').mimeType, equals('image/jpeg'));
        expect(Attachment.image('test.gif').mimeType, equals('image/gif'));
        expect(Attachment.image('test.webp').mimeType, equals('image/webp'));
      });

      test('is case-insensitive for extension detection', () {
        expect(Attachment.image('test.PNG').mimeType, equals('image/png'));
        expect(Attachment.image('test.JPEG').mimeType, equals('image/jpeg'));
        expect(Attachment.image('test.GIF').mimeType, equals('image/gif'));
      });

      test('defaults to jpeg for unknown extensions', () {
        expect(Attachment.image('test.bmp').mimeType, equals('image/jpeg'));
        expect(Attachment.image('test.tiff').mimeType, equals('image/jpeg'));
        expect(Attachment.image('test.unknown').mimeType, equals('image/jpeg'));
        expect(Attachment.image('noextension').mimeType, equals('image/jpeg'));
      });
    });

    group('Attachment.imageBase64 factory', () {
      test('creates image attachment with base64 content', () {
        final attachment = Attachment.imageBase64('dGVzdA==', 'image/png');
        expect(attachment.type, equals('image'));
        expect(attachment.content, equals('dGVzdA=='));
        expect(attachment.mimeType, equals('image/png'));
        expect(attachment.path, isNull);
      });

      test('preserves various media types', () {
        final pngAttachment = Attachment.imageBase64('data', 'image/png');
        final jpegAttachment = Attachment.imageBase64('data', 'image/jpeg');
        final webpAttachment = Attachment.imageBase64('data', 'image/webp');

        expect(pngAttachment.mimeType, equals('image/png'));
        expect(jpegAttachment.mimeType, equals('image/jpeg'));
        expect(webpAttachment.mimeType, equals('image/webp'));
      });
    });

    group('Attachment.documentText factory', () {
      test('creates document attachment with text content', () {
        final attachment = Attachment.documentText(text: 'Document content');
        expect(attachment.type, equals('document'));
        expect(attachment.content, equals('Document content'));
        expect(attachment.mimeType, equals('text/plain'));
        expect(attachment.path, isNull); // No title provided
      });

      test('creates document attachment with title', () {
        final attachment = Attachment.documentText(
          text: 'Document content',
          title: 'My Document',
        );
        expect(attachment.type, equals('document'));
        expect(attachment.content, equals('Document content'));
        expect(attachment.path, equals('My Document')); // Title stored in path
      });

      test('toClaudeJson serializes document correctly', () {
        final attachment = Attachment.documentText(text: 'Hello world');
        final json = attachment.toClaudeJson();

        expect(json['type'], equals('document'));
        expect(json['source']['type'], equals('text'));
        expect(json['source']['media_type'], equals('text/plain'));
        expect(json['source']['data'], equals('Hello world'));
        expect(json.containsKey('title'), isFalse);
      });

      test('toClaudeJson includes title when provided', () {
        final attachment = Attachment.documentText(
          text: 'Content',
          title: 'Doc Title',
        );
        final json = attachment.toClaudeJson();

        expect(json['type'], equals('document'));
        expect(json['title'], equals('Doc Title'));
        expect(json['source']['data'], equals('Content'));
      });

      test('handles multiline document content', () {
        final text = 'Line 1\nLine 2\nLine 3';
        final attachment = Attachment.documentText(text: text);
        final json = attachment.toClaudeJson();

        expect(json['source']['data'], equals(text));
      });

      test('document without content throws ArgumentError', () {
        final attachment = Attachment(type: 'document');
        expect(
          () => attachment.toClaudeJson(),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Content must be provided'),
            ),
          ),
        );
      });
    });

    group('JSON serialization', () {
      test('toJson and fromJson round-trip for file attachment', () {
        final original = Attachment.file('/path/to/file.dart');
        final json = original.toJson();
        final restored = Attachment.fromJson(json);

        expect(restored.type, equals(original.type));
        expect(restored.path, equals(original.path));
      });

      test('toJson and fromJson round-trip for image attachment', () {
        final original = Attachment.imageBase64('dGVzdA==', 'image/png');
        final json = original.toJson();
        final restored = Attachment.fromJson(json);

        expect(restored.type, equals(original.type));
        expect(restored.content, equals(original.content));
        expect(restored.mimeType, equals(original.mimeType));
      });

      test('toJson and fromJson round-trip for document attachment', () {
        final original = Attachment.documentText(
          text: 'Content',
          title: 'Title',
        );
        final json = original.toJson();
        final restored = Attachment.fromJson(json);

        expect(restored.type, equals(original.type));
        expect(restored.content, equals(original.content));
        expect(restored.path, equals(original.path)); // Title stored in path
        expect(restored.mimeType, equals(original.mimeType));
      });

      test('handles JSON with null optional fields', () {
        final json = {'type': 'file'};
        final attachment = Attachment.fromJson(json);

        expect(attachment.type, equals('file'));
        expect(attachment.path, isNull);
        expect(attachment.content, isNull);
        expect(attachment.mimeType, isNull);
      });
    });

    group('toClaudeJson edge cases', () {
      test('file attachment returns standard JSON', () {
        final attachment = Attachment.file('/path/file.txt');
        final json = attachment.toClaudeJson();

        expect(json['type'], equals('file'));
        expect(json['path'], equals('/path/file.txt'));
        expect(json.containsKey('source'), isFalse);
      });

      test('unknown type returns standard JSON', () {
        final attachment = Attachment(type: 'custom', content: 'data');
        final json = attachment.toClaudeJson();

        expect(json['type'], equals('custom'));
        expect(json['content'], equals('data'));
        expect(json.containsKey('source'), isFalse);
      });

      test('image with null mimeType defaults to jpeg', () {
        final attachment = Attachment(type: 'image', content: 'base64data');
        final json = attachment.toClaudeJson();

        expect(json['source']['media_type'], equals('image/jpeg'));
      });

      test('document with null mimeType defaults to text/plain', () {
        final attachment = Attachment(type: 'document', content: 'text');
        final json = attachment.toClaudeJson();

        expect(json['source']['media_type'], equals('text/plain'));
      });
    });
  });

  group('Message and Attachment integration', () {
    test('complex message with all attachment types', () {
      final message = Message(
        text: 'Complex message',
        attachments: [
          Attachment.file('/path/file.txt'),
          Attachment.imageBase64('aW1hZ2U=', 'image/png'),
          Attachment.documentText(text: 'Document', title: 'Doc'),
        ],
      );

      final json = message.toClaudeJson();
      final content = json['message']['content'] as List;

      expect(content, hasLength(4)); // 1 text + 3 attachments
      expect(content[0]['type'], equals('text'));
      expect(content[1]['type'], equals('file'));
      expect(content[2]['type'], equals('image'));
      expect(content[3]['type'], equals('document'));
    });

    test('full JSON serialization round-trip for complex message', () {
      final original = Message(
        text: 'Test',
        attachments: [
          Attachment.file('/path'),
          Attachment.documentText(text: 'doc'),
        ],
        metadata: {'key': 'value'},
      );

      final jsonString = jsonEncode(original.toJson());
      final decodedJson = jsonDecode(jsonString) as Map<String, dynamic>;
      final restored = Message.fromJson(decodedJson);

      expect(restored.text, equals(original.text));
      expect(
        restored.attachments?.length,
        equals(original.attachments?.length),
      );
      expect(restored.metadata, equals(original.metadata));
    });

    test('toClaudeJson is valid JSON', () {
      final message = Message(
        text: 'Test with unicode: 你好',
        attachments: [Attachment.documentText(text: 'Content "quoted"')],
      );

      final claudeJson = message.toClaudeJson();

      // Should be encodable without error
      final encoded = jsonEncode(claudeJson);
      expect(encoded, isA<String>());

      // Should be decodable back
      final decoded = jsonDecode(encoded);
      expect(decoded, isA<Map>());
    });
  });
}
