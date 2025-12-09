import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:moondream_api/moondream_api.dart';

void main() {
  group('ImageEncoder', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('moondream_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('encodes bytes to data URI', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final result = ImageEncoder.encodeBytes(bytes);

      expect(result, startsWith('data:image/jpeg;base64,'));
      expect(result, contains(base64Encode(bytes)));
    });

    test('encodes bytes with custom MIME type', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final result = ImageEncoder.encodeBytes(bytes, mimeType: 'image/png');

      expect(result, startsWith('data:image/png;base64,'));
    });

    test('encodes file to data URI', () {
      final testFile = File('${tempDir.path}/test.jpg')
        ..writeAsBytesSync([1, 2, 3, 4, 5]);

      final result = ImageEncoder.encodeFile(testFile.path);

      expect(result, startsWith('data:image/jpeg;base64,'));
      expect(result, contains(base64Encode([1, 2, 3, 4, 5])));
    });

    test('detects MIME type from extension', () {
      final extensions = {
        'test.jpg': 'image/jpeg',
        'test.jpeg': 'image/jpeg',
        'test.png': 'image/png',
        'test.gif': 'image/gif',
        'test.webp': 'image/webp',
        'test.unknown': 'image/jpeg', // Default
      };

      for (final entry in extensions.entries) {
        final file = File('${tempDir.path}/${entry.key}')
          ..writeAsBytesSync([1, 2, 3]);

        final result = ImageEncoder.encodeFile(file.path);
        expect(result, startsWith('data:${entry.value};base64,'));
      }
    });

    test('throws on non-existent file', () {
      expect(
        () => ImageEncoder.encodeFile('/nonexistent/file.jpg'),
        throwsArgumentError,
      );
    });

    test('throws on empty bytes', () {
      expect(() => ImageEncoder.encodeBytes(Uint8List(0)), throwsArgumentError);
    });

    test('throws on file larger than 10MB', () {
      // Create 11MB of data
      final largeBytes = Uint8List(11 * 1024 * 1024);

      expect(() => ImageEncoder.encodeBytes(largeBytes), throwsArgumentError);
    });

    test('validates data URI format', () {
      expect(
        ImageEncoder.isValidDataUri('data:image/jpeg;base64,AQIDBA=='),
        isTrue,
      );
      expect(
        ImageEncoder.isValidDataUri('data:image/png;base64,AQIDBA=='),
        isTrue,
      );
      expect(ImageEncoder.isValidDataUri('not-a-data-uri'), isFalse);
      expect(
        ImageEncoder.isValidDataUri('data:text/plain;base64,AQIDBA=='),
        isFalse,
      );
    });

    test('extracts MIME type from data URI', () {
      expect(
        ImageEncoder.extractMimeType('data:image/jpeg;base64,AQIDBA=='),
        equals('image/jpeg'),
      );
      expect(
        ImageEncoder.extractMimeType('data:image/png;base64,AQIDBA=='),
        equals('image/png'),
      );
      expect(ImageEncoder.extractMimeType('invalid'), isNull);
    });

    test('encodes base64 string to data URI', () {
      final base64Data = base64Encode([1, 2, 3, 4, 5]);
      final result = ImageEncoder.encodeBase64String(base64Data);

      expect(result, equals('data:image/jpeg;base64,$base64Data'));
    });

    test('removes existing data URI prefix when encoding base64 string', () {
      final base64Data = base64Encode([1, 2, 3, 4, 5]);
      final withPrefix = 'data:image/png;base64,$base64Data';

      final result = ImageEncoder.encodeBase64String(
        withPrefix,
        mimeType: 'image/jpeg',
      );

      expect(result, equals('data:image/jpeg;base64,$base64Data'));
    });
  });
}
