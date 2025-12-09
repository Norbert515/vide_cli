import 'package:test/test.dart';
import 'package:claude_api/claude_api.dart';
import 'package:claude_api/src/protocol/json_encoder.dart';
import 'package:claude_api/src/protocol/json_decoder.dart';
import 'dart:convert';
import 'dart:io';

void main() {
  group('Image Attachment', () {
    test('Attachment.imageBase64 serializes to Claude API format', () {
      final attachment = Attachment.imageBase64('dGVzdA==', 'image/png');
      final json = attachment.toClaudeJson();

      expect(json['type'], equals('image'));
      expect(json['source']['type'], equals('base64'));
      expect(json['source']['media_type'], equals('image/png'));
      expect(json['source']['data'], equals('dGVzdA=='));
    });

    test('Attachment.imageBase64 with different media types', () {
      final testCases = [
        ('image/png', 'image/png'),
        ('image/jpeg', 'image/jpeg'),
        ('image/gif', 'image/gif'),
        ('image/webp', 'image/webp'),
      ];

      for (final (mediaType, expectedMediaType) in testCases) {
        final attachment = Attachment.imageBase64('dGVzdA==', mediaType);
        final json = attachment.toClaudeJson();

        expect(
          json['source']['media_type'],
          equals(expectedMediaType),
          reason: 'Failed for media type: $mediaType',
        );
      }
    });

    test('Attachment.image reads file and encodes to base64', () async {
      // Create a temporary test image file
      final tempDir = await Directory.systemTemp.createTemp('claude_test_');
      final testFile = File('${tempDir.path}/test_image.png');

      // Write some test data (not a real PNG, but sufficient for testing)
      final testData = [137, 80, 78, 71, 13, 10, 26, 10]; // PNG header bytes
      await testFile.writeAsBytes(testData);

      try {
        final attachment = Attachment.image(testFile.path);
        final json = attachment.toClaudeJson();

        expect(json['type'], equals('image'));
        expect(json['source']['type'], equals('base64'));
        expect(json['source']['media_type'], equals('image/png'));

        // Verify the base64 data matches the file contents
        final expectedBase64 = base64Encode(testData);
        expect(json['source']['data'], equals(expectedBase64));
      } finally {
        // Clean up
        await tempDir.delete(recursive: true);
      }
    });

    test('Media type auto-detection for different extensions', () {
      final testCases = [
        ('test.png', 'image/png'),
        ('test.jpg', 'image/jpeg'),
        ('test.jpeg', 'image/jpeg'),
        ('test.gif', 'image/gif'),
        ('test.webp', 'image/webp'),
        ('test.PNG', 'image/png'), // Case insensitive
        ('test.JPG', 'image/jpeg'),
        ('test.unknown', 'image/jpeg'), // Fallback
      ];

      for (final (filename, expectedMediaType) in testCases) {
        final attachment = Attachment.image(filename);
        expect(
          attachment.mimeType,
          equals(expectedMediaType),
          reason: 'Failed for filename: $filename',
        );
      }
    });

    test('Message with image attachment serializes correctly', () {
      final message = Message(
        text: 'Here is an image',
        attachments: [Attachment.imageBase64('aW1hZ2VkYXRh', 'image/png')],
      );

      final json = message.toClaudeJson();

      expect(json['type'], equals('user'));
      expect(json['message']['role'], equals('user'));
      expect(json['message']['content'].length, equals(2));

      // Text content
      expect(json['message']['content'][0]['type'], equals('text'));
      expect(json['message']['content'][0]['text'], equals('Here is an image'));

      // Image content
      expect(json['message']['content'][1]['type'], equals('image'));
      expect(json['message']['content'][1]['source']['type'], equals('base64'));
      expect(
        json['message']['content'][1]['source']['media_type'],
        equals('image/png'),
      );
      expect(
        json['message']['content'][1]['source']['data'],
        equals('aW1hZ2VkYXRh'),
      );
    });

    test('Message with multiple image attachments', () {
      final message = Message(
        text: 'Multiple images',
        attachments: [
          Attachment.imageBase64('aW1hZ2Ux', 'image/png'),
          Attachment.imageBase64('aW1hZ2Uy', 'image/jpeg'),
        ],
      );

      final json = message.toClaudeJson();

      expect(json['message']['content'].length, equals(3));
      expect(json['message']['content'][0]['type'], equals('text'));
      expect(json['message']['content'][1]['type'], equals('image'));
      expect(json['message']['content'][2]['type'], equals('image'));

      expect(
        json['message']['content'][1]['source']['data'],
        equals('aW1hZ2Ux'),
      );
      expect(
        json['message']['content'][2]['source']['data'],
        equals('aW1hZ2Uy'),
      );
    });

    test('Image attachment without content or path throws ArgumentError', () {
      final attachment = Attachment(type: 'image');

      expect(
        () => attachment.toClaudeJson(),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Either content or path must be provided'),
          ),
        ),
      );
    });

    test('Image attachment uses default media type when none specified', () {
      final attachment = Attachment.imageBase64('dGVzdA==', 'image/png');
      final json = attachment.toClaudeJson();
      expect(json['source']['media_type'], equals('image/png'));
    });

    test(
      'Image attachment from file with no extension uses default media type',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('claude_test_');
        final testFile = File('${tempDir.path}/imagefile');

        await testFile.writeAsBytes([1, 2, 3, 4]);

        try {
          final attachment = Attachment.image(testFile.path);
          final json = attachment.toClaudeJson();

          // Should fall back to image/jpeg
          expect(json['source']['media_type'], equals('image/jpeg'));
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test('Non-image attachment preserves standard JSON format', () {
      final attachment = Attachment.file('/path/to/file.txt');
      final json = attachment.toClaudeJson();

      // Should use standard JSON format, not image format
      expect(json['type'], equals('file'));
      expect(json['path'], equals('/path/to/file.txt'));
      expect(json.containsKey('source'), isFalse);
    });
  });

  group('JsonEncoder', () {
    late JsonEncoder encoder;

    setUp(() {
      encoder = const JsonEncoder();
    });

    test('encodes simple message correctly', () {
      final message = Message(text: 'Hello, Claude!');
      final encoded = encoder.encode(message);

      // Should be valid JSON followed by newline
      expect(encoded.endsWith('\n'), isTrue);

      final json = jsonDecode(encoded.trim()) as Map<String, dynamic>;
      expect(json['type'], equals('user'));
      expect(json['message']['role'], equals('user'));
      expect(json['message']['content'][0]['type'], equals('text'));
      expect(json['message']['content'][0]['text'], equals('Hello, Claude!'));
    });

    test('encodes message with attachments', () {
      final message = Message(
        text: 'Check this file',
        attachments: [Attachment.file('/path/to/file.txt')],
      );

      final encoded = encoder.encode(message);
      final json = jsonDecode(encoded.trim()) as Map<String, dynamic>;

      expect(json['message']['content'].length, equals(2));
      expect(json['message']['content'][1]['type'], equals('file'));
      expect(
        json['message']['content'][1]['path'],
        equals('/path/to/file.txt'),
      );
    });

    test('encodes tool result', () {
      final encoded = encoder.encodeToolResult(
        toolUseId: 'tool-123',
        result: {'answer': 42},
      );

      final json = jsonDecode(encoded.trim()) as Map<String, dynamic>;
      expect(json['type'], equals('tool_result'));
      expect(json['tool_use_id'], equals('tool-123'));
      expect(json['content'], isA<String>());
    });
  });

  group('JsonDecoder', () {
    late JsonDecoder decoder;

    setUp(() {
      decoder = JsonDecoder();
    });

    test('decodes text response', () {
      const json =
          '{"type": "text", "content": "Hello from Claude!", "id": "123"}';
      final response = decoder.decodeSingle(json);

      expect(response, isA<TextResponse>());
      final textResponse = response as TextResponse;
      expect(textResponse.content, equals('Hello from Claude!'));
    });

    test('decodes error response', () {
      const json =
          '{"type": "error", "error": "Something went wrong", "details": "More info"}';
      final response = decoder.decodeSingle(json);

      expect(response, isA<ErrorResponse>());
      final errorResponse = response as ErrorResponse;
      expect(errorResponse.error, equals('Something went wrong'));
      expect(errorResponse.details, equals('More info'));
    });

    test('decodes tool use response', () {
      const json = '''
        {
          "type": "tool_use",
          "name": "calculator",
          "input": {"operation": "multiply", "x": 7, "y": 8}
        }
      ''';
      final response = decoder.decodeSingle(json);

      expect(response, isA<ToolUseResponse>());
      final toolResponse = response as ToolUseResponse;
      expect(toolResponse.toolName, equals('calculator'));
      expect(toolResponse.parameters['operation'], equals('multiply'));
      expect(toolResponse.parameters['x'], equals(7));
    });

    test('decodes stream of responses', () async {
      final stream = Stream.fromIterable([
        '{"type": "text", "content": "First"}\n',
        '{"type": "text", "content": "Second"}\n',
        '{"type": "status", "status": "completed"}\n',
      ]);

      final responses = await decoder.decodeStream(stream).toList();

      expect(responses.length, equals(3));
      expect(responses[0], isA<TextResponse>());
      expect(responses[1], isA<TextResponse>());
      expect(responses[2], isA<StatusResponse>());
    });

    test('handles partial JSON lines', () async {
      final stream = Stream.fromIterable([
        '{"type": "text", ',
        '"content": "Split ',
        'message"}\n',
      ]);

      final responses = await decoder.decodeStream(stream).toList();

      expect(responses.length, equals(1));
      expect(responses[0], isA<TextResponse>());
      expect((responses[0] as TextResponse).content, equals('Split message'));
    });

    test('handles malformed JSON gracefully', () async {
      final stream = Stream.fromIterable([
        'not json\n',
        '{"type": "text", "content": "Valid"}\n',
        'also not json\n',
      ]);

      final responses = await decoder.decodeStream(stream).toList();

      // Should get the valid response and possibly error responses
      expect(responses.any((r) => r is TextResponse), isTrue);
    });
  });

  group('Response models', () {
    test('creates responses from various JSON formats', () {
      // Claude message format
      final messageJson = {
        'type': 'message',
        'role': 'assistant',
        'content': 'Hello!',
      };
      final messageResponse = ClaudeResponse.fromJson(messageJson);
      expect(messageResponse, isA<TextResponse>());

      // Status format
      final statusJson = {
        'type': 'status',
        'status': 'ready',
        'message': 'Ready to process',
      };
      final statusResponse = ClaudeResponse.fromJson(statusJson);
      expect(statusResponse, isA<StatusResponse>());
      expect(
        (statusResponse as StatusResponse).status,
        equals(ClaudeStatus.ready),
      );

      // Unknown format
      final unknownJson = {'type': 'something_new', 'data': 'unknown'};
      final unknownResponse = ClaudeResponse.fromJson(unknownJson);
      expect(unknownResponse, isA<UnknownResponse>());
      expect(unknownResponse.rawData, isNotNull);
    });
  });
}
