import 'package:test/test.dart';
import 'package:vide_cli/utils/diff_utils.dart';

void main() {
  group('DiffUtils', () {
    group('isValidLineFormat', () {
      test('validates lines with single digit line numbers', () {
        expect(DiffUtils.isValidLineFormat('  1→content'), isTrue);
        expect(DiffUtils.isValidLineFormat('  9→more content'), isTrue);
      });

      test('validates lines with multi-digit line numbers', () {
        expect(DiffUtils.isValidLineFormat(' 10→content'), isTrue);
        expect(DiffUtils.isValidLineFormat('123→content'), isTrue);
        expect(DiffUtils.isValidLineFormat('9999→content'), isTrue);
      });

      test('validates lines with varying leading spaces', () {
        expect(DiffUtils.isValidLineFormat('1→content'), isTrue);
        expect(DiffUtils.isValidLineFormat(' 1→content'), isTrue);
        expect(DiffUtils.isValidLineFormat('  1→content'), isTrue);
        expect(DiffUtils.isValidLineFormat('   1→content'), isTrue);
      });

      test('validates lines with empty content', () {
        expect(DiffUtils.isValidLineFormat('  1→'), isTrue);
        expect(DiffUtils.isValidLineFormat(' 10→'), isTrue);
      });

      test('rejects lines without arrow separator', () {
        expect(DiffUtils.isValidLineFormat('  1 content'), isFalse);
        expect(DiffUtils.isValidLineFormat('  1: content'), isFalse);
        expect(DiffUtils.isValidLineFormat('  1-content'), isFalse);
      });

      test('rejects lines without line number', () {
        expect(DiffUtils.isValidLineFormat('→content'), isFalse);
        expect(DiffUtils.isValidLineFormat('  →content'), isFalse);
        expect(DiffUtils.isValidLineFormat('abc→content'), isFalse);
      });

      test('rejects empty lines', () {
        expect(DiffUtils.isValidLineFormat(''), isFalse);
        expect(DiffUtils.isValidLineFormat('   '), isFalse);
      });

      test('rejects lines that start with text', () {
        expect(DiffUtils.isValidLineFormat('content 1→'), isFalse);
        expect(DiffUtils.isValidLineFormat('abc123→content'), isFalse);
      });
    });

    group('parseLine', () {
      test('parses valid lines with content', () {
        final result = DiffUtils.parseLine('  1→hello world');
        expect(result, isNotNull);
        expect(result!.lineNumber, 1);
        expect(result.content, 'hello world');
      });

      test('parses lines with multi-digit line numbers', () {
        final result = DiffUtils.parseLine('123→some code');
        expect(result, isNotNull);
        expect(result!.lineNumber, 123);
        expect(result.content, 'some code');
      });

      test('parses lines with empty content', () {
        final result = DiffUtils.parseLine('  5→');
        expect(result, isNotNull);
        expect(result!.lineNumber, 5);
        expect(result.content, '');
      });

      test('preserves leading spaces in content', () {
        final result = DiffUtils.parseLine('  1→  indented code');
        expect(result, isNotNull);
        expect(result!.content, '  indented code');
      });

      test('preserves trailing spaces in content', () {
        final result = DiffUtils.parseLine('  1→code with trailing  ');
        expect(result, isNotNull);
        expect(result!.content, 'code with trailing  ');
      });

      test('handles content with special characters', () {
        final result = DiffUtils.parseLine('  1→const x = "hello→world";');
        expect(result, isNotNull);
        expect(result!.content, 'const x = "hello→world";');
      });

      test('returns null for invalid lines', () {
        expect(DiffUtils.parseLine(''), isNull);
        expect(DiffUtils.parseLine('invalid'), isNull);
        expect(DiffUtils.parseLine('→no number'), isNull);
        expect(DiffUtils.parseLine('abc→text'), isNull);
      });
    });

    group('determineLineChangeType', () {
      test('identifies added lines (in new but not old)', () {
        final oldLines = {'line1', 'line2'};
        final newLines = {'line1', 'line2', 'line3'};

        expect(
          DiffUtils.determineLineChangeType(
            content: 'line3',
            oldLines: oldLines,
            newLines: newLines,
          ),
          LineChangeType.added,
        );
      });

      test('identifies removed lines (in old but not new)', () {
        final oldLines = {'line1', 'line2', 'line3'};
        final newLines = {'line1', 'line2'};

        expect(
          DiffUtils.determineLineChangeType(
            content: 'line3',
            oldLines: oldLines,
            newLines: newLines,
          ),
          LineChangeType.removed,
        );
      });

      test('identifies unchanged lines (in both)', () {
        final oldLines = {'line1', 'line2'};
        final newLines = {'line1', 'line2', 'line3'};

        expect(
          DiffUtils.determineLineChangeType(
            content: 'line1',
            oldLines: oldLines,
            newLines: newLines,
          ),
          LineChangeType.unchanged,
        );
        expect(
          DiffUtils.determineLineChangeType(
            content: 'line2',
            oldLines: oldLines,
            newLines: newLines,
          ),
          LineChangeType.unchanged,
        );
      });

      test('identifies context lines (in neither)', () {
        final oldLines = {'line1'};
        final newLines = {'line2'};

        expect(
          DiffUtils.determineLineChangeType(
            content: 'line3',
            oldLines: oldLines,
            newLines: newLines,
          ),
          LineChangeType.unchanged,
        );
      });

      test('trims content before comparison', () {
        final oldLines = {'line1'};
        final newLines = {'line2'};

        // Content with leading/trailing spaces should still match
        expect(
          DiffUtils.determineLineChangeType(
            content: '  line1  ',
            oldLines: oldLines,
            newLines: newLines,
          ),
          LineChangeType.removed,
        );
        expect(
          DiffUtils.determineLineChangeType(
            content: '  line2  ',
            oldLines: oldLines,
            newLines: newLines,
          ),
          LineChangeType.added,
        );
      });

      test('handles empty content', () {
        final oldLines = {'', 'line1'};
        final newLines = {'line1', 'line2'};

        expect(
          DiffUtils.determineLineChangeType(
            content: '',
            oldLines: oldLines,
            newLines: newLines,
          ),
          LineChangeType.removed,
        );
      });

      test('handles whitespace-only content', () {
        final oldLines = {''};
        final newLines = {'line1'};

        // '  ' trims to '', which is in oldLines
        expect(
          DiffUtils.determineLineChangeType(
            content: '  ',
            oldLines: oldLines,
            newLines: newLines,
          ),
          LineChangeType.removed,
        );
      });
    });

    group('createLineSets', () {
      test('creates sets from simple strings', () {
        final result = DiffUtils.createLineSets(
          oldString: 'line1\nline2',
          newString: 'line2\nline3',
        );

        expect(result.oldSet, containsAll(['line1', 'line2']));
        expect(result.newSet, containsAll(['line2', 'line3']));
      });

      test('trims lines in the sets', () {
        final result = DiffUtils.createLineSets(
          oldString: '  line1  \n  line2',
          newString: 'line2  \n  line3  ',
        );

        expect(result.oldSet, containsAll(['line1', 'line2']));
        expect(result.newSet, containsAll(['line2', 'line3']));
      });

      test('handles empty strings', () {
        final result = DiffUtils.createLineSets(oldString: '', newString: '');

        expect(result.oldSet, hasLength(1)); // Contains empty string
        expect(result.newSet, hasLength(1));
      });

      test('handles single line strings', () {
        final result = DiffUtils.createLineSets(
          oldString: 'single',
          newString: 'other',
        );

        expect(result.oldSet, equals({'single'}));
        expect(result.newSet, equals({'other'}));
      });

      test('deduplicates identical lines', () {
        final result = DiffUtils.createLineSets(
          oldString: 'line1\nline1\nline1',
          newString: 'line2\nline2',
        );

        // Sets deduplicate, so only one instance of each
        expect(result.oldSet, equals({'line1'}));
        expect(result.newSet, equals({'line2'}));
      });

      test('handles lines with only whitespace', () {
        final result = DiffUtils.createLineSets(
          oldString: '   \n\t\t',
          newString: '\n  ',
        );

        // All whitespace trims to empty string
        expect(result.oldSet, equals({''}));
        expect(result.newSet, equals({''}));
      });
    });

    group('integration: mixed diff scenarios', () {
      test('processes a complete edit scenario', () {
        // Simulating: changed "old line" to "new line" in a file
        const oldString = 'old line';
        const newString = 'new line';

        final sets = DiffUtils.createLineSets(
          oldString: oldString,
          newString: newString,
        );

        // Line that was removed
        expect(
          DiffUtils.determineLineChangeType(
            content: 'old line',
            oldLines: sets.oldSet,
            newLines: sets.newSet,
          ),
          LineChangeType.removed,
        );

        // Line that was added
        expect(
          DiffUtils.determineLineChangeType(
            content: 'new line',
            oldLines: sets.oldSet,
            newLines: sets.newSet,
          ),
          LineChangeType.added,
        );

        // Context line (not in edit)
        expect(
          DiffUtils.determineLineChangeType(
            content: 'context line',
            oldLines: sets.oldSet,
            newLines: sets.newSet,
          ),
          LineChangeType.unchanged,
        );
      });

      test('processes multi-line changes', () {
        // Simulating: replaced "a\nb" with "b\nc"
        const oldString = 'a\nb';
        const newString = 'b\nc';

        final sets = DiffUtils.createLineSets(
          oldString: oldString,
          newString: newString,
        );

        expect(
          DiffUtils.determineLineChangeType(
            content: 'a',
            oldLines: sets.oldSet,
            newLines: sets.newSet,
          ),
          LineChangeType.removed, // a is only in old
        );

        expect(
          DiffUtils.determineLineChangeType(
            content: 'b',
            oldLines: sets.oldSet,
            newLines: sets.newSet,
          ),
          LineChangeType.unchanged, // b is in both
        );

        expect(
          DiffUtils.determineLineChangeType(
            content: 'c',
            oldLines: sets.oldSet,
            newLines: sets.newSet,
          ),
          LineChangeType.added, // c is only in new
        );
      });

      test('handles large diffs efficiently', () {
        // Create old and new strings with 1000 lines each
        final oldLines = List.generate(1000, (i) => 'line $i').join('\n');
        final newLines = List.generate(
          1000,
          (i) => 'line ${i + 500}',
        ).join('\n');

        final stopwatch = Stopwatch()..start();

        final sets = DiffUtils.createLineSets(
          oldString: oldLines,
          newString: newLines,
        );

        // Check a few lines
        for (int i = 0; i < 1000; i++) {
          DiffUtils.determineLineChangeType(
            content: 'line $i',
            oldLines: sets.oldSet,
            newLines: sets.newSet,
          );
        }

        stopwatch.stop();

        // Should complete in reasonable time (< 100ms for O(1) lookups)
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(1000),
          reason: 'Set-based lookups should be fast (O(1))',
        );
      });
    });
  });
}
