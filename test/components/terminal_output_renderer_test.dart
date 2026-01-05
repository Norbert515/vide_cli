import 'package:test/test.dart';

/// Process carriage returns to simulate terminal behavior.
/// This is extracted from TerminalOutputRenderer for testing.
String processCarriageReturns(String text) {
  final lines = text.split('\n');
  final processedLines = <String>[];

  for (final line in lines) {
    if (line.contains('\r')) {
      final segments = line.split('\r');
      final lastSegment = segments.last;
      if (lastSegment.trim().isNotEmpty) {
        processedLines.add(lastSegment);
      }
    } else if (line.trim().isNotEmpty) {
      processedLines.add(line);
    }
  }

  return processedLines.join('\n');
}

void main() {
  group('processCarriageReturns', () {
    test('handles dart test progress output with carriage returns', () {
      // Simulates dart test output where \r overwrites the line
      final input =
          '00:00 +0: loading test.dart\r'
          '00:00 +1: test one passed\r'
          '00:00 +2: test two passed\r'
          '00:00 +3: All tests passed!';

      final result = processCarriageReturns(input);

      // Should only show the final state after all overwrites
      expect(result, equals('00:00 +3: All tests passed!'));
    });

    test('handles multiple lines with carriage returns', () {
      final input =
          'line1 start\rline1 end\n'
          'line2 start\rline2 end\n'
          'line3 no cr';

      final result = processCarriageReturns(input);

      expect(result, equals('line1 end\nline2 end\nline3 no cr'));
    });

    test('preserves lines without carriage returns', () {
      final input = 'line 1\nline 2\nline 3';

      final result = processCarriageReturns(input);

      expect(result, equals('line 1\nline 2\nline 3'));
    });

    test('handles empty last segment after carriage return', () {
      // When \r is at the end with nothing after it
      final input = 'some text\r';

      final result = processCarriageReturns(input);

      // Empty segment after \r should be ignored
      expect(result, equals(''));
    });

    test('handles mixed content', () {
      final input =
          'Building project...\r'
          'Building project... 50%\r'
          'Building project... 100%\n'
          'Build complete!\n'
          'Running tests...\r'
          'All 42 tests passed!';

      final result = processCarriageReturns(input);

      expect(
        result,
        equals(
          'Building project... 100%\nBuild complete!\nAll 42 tests passed!',
        ),
      );
    });

    test('handles realistic dart test output', () {
      // Real-world example of dart test output
      final input =
          '00:00 +0: loading test/permission_persistence_test.dart\r'
          '00:00 +0: test/permission_persistence_test.dart: Permission Persistence\r'
          '00:00 +1: test/permission_persistence_test.dart: Permission Persistence\r'
          '00:00 +2: test/permission_persistence_test.dart: Permission Persistence\r'
          '00:00 +3: All tests passed!';

      final result = processCarriageReturns(input);

      expect(result, equals('00:00 +3: All tests passed!'));
    });

    test('handles whitespace-only segments after carriage return', () {
      final input = 'text\r   \r  \r';

      final result = processCarriageReturns(input);

      // All segments after \r are whitespace-only, should result in empty
      expect(result, equals(''));
    });
  });
}
