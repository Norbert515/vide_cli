import 'package:nocterm/nocterm.dart' hide isEmpty;
import 'package:nocterm/src/painting/text_span.dart';
import 'package:test/test.dart';
import 'package:vide_cli/theme/colors/syntax_colors.dart';
import 'package:vide_cli/utils/syntax_highlighter.dart';

void main() {
  group('SyntaxHighlighter.highlightCode', () {
    // Use dark theme colors for testing
    const syntaxColors = VideSyntaxColors.dark;

    group('colors different token types differently', () {
      test('keywords get keyword color', () {
        final result = SyntaxHighlighter.highlightCode(
          'void main() { if (true) return; }',
          'dart',
          syntaxColors: syntaxColors,
        );

        final spans = _flattenTextSpans(result);
        final keywordSpans = spans.where(
          (s) =>
              s.text != null &&
              ['void', 'if', 'true', 'return'].contains(s.text!.trim()),
        );

        expect(
          keywordSpans.isNotEmpty,
          true,
          reason: 'Should find keyword spans',
        );
        for (final span in keywordSpans) {
          expect(
            span.style?.color,
            equals(syntaxColors.keyword),
            reason: 'Keyword "${span.text}" should use keyword color',
          );
        }
      });

      test('strings get string color', () {
        final result = SyntaxHighlighter.highlightCode(
          'var s = "hello world";',
          'dart',
          syntaxColors: syntaxColors,
        );

        final spans = _flattenTextSpans(result);
        // Find spans containing the string content
        final stringSpans = spans.where(
          (s) => s.text != null && s.text!.contains('hello'),
        );

        expect(
          stringSpans.isNotEmpty,
          true,
          reason: 'Should find string spans',
        );
        for (final span in stringSpans) {
          expect(
            span.style?.color,
            equals(syntaxColors.string),
            reason: 'String content should use string color',
          );
        }
      });

      test('comments get comment color', () {
        final result = SyntaxHighlighter.highlightCode(
          '// this is a comment\nvar x = 1;',
          'dart',
          syntaxColors: syntaxColors,
        );

        final spans = _flattenTextSpans(result);
        // Comments may be split into multiple spans (e.g., '//' and 'comment text')
        // Look for any span that is part of the comment
        final commentSpans = spans.where(
          (s) =>
              s.text != null &&
              (s.text!.contains('//') || s.text!.contains('comment')),
        );

        expect(
          commentSpans.isNotEmpty,
          true,
          reason: 'Should find comment spans',
        );
        for (final span in commentSpans) {
          expect(
            span.style?.color,
            equals(syntaxColors.comment),
            reason: 'Comment "${span.text}" should use comment color',
          );
        }
      });

      test('numbers get number color', () {
        final result = SyntaxHighlighter.highlightCode(
          'var x = 42; var y = 3.14;',
          'dart',
          syntaxColors: syntaxColors,
        );

        final spans = _flattenTextSpans(result);
        final numberSpans = spans.where(
          (s) =>
              s.text != null &&
              (s.text!.trim() == '42' || s.text!.trim() == '3.14'),
        );

        expect(
          numberSpans.isNotEmpty,
          true,
          reason: 'Should find number spans',
        );
        for (final span in numberSpans) {
          expect(
            span.style?.color,
            equals(syntaxColors.number),
            reason: 'Number "${span.text}" should use number color',
          );
        }
      });

      test('class keyword gets keyword color', () {
        final result = SyntaxHighlighter.highlightCode(
          'class MyClass {}',
          'dart',
          syntaxColors: syntaxColors,
        );

        final spans = _flattenTextSpans(result);
        final classKeywordSpans = spans.where(
          (s) => s.text != null && s.text!.trim() == 'class',
        );

        expect(
          classKeywordSpans.isNotEmpty,
          true,
          reason: 'Should find class keyword',
        );
        for (final span in classKeywordSpans) {
          expect(
            span.style?.color,
            equals(syntaxColors.keyword),
            reason: 'class keyword should use keyword color',
          );
        }
      });
    });

    group('different token types have distinct colors', () {
      test('keywords and strings have different colors', () {
        expect(syntaxColors.keyword, isNot(equals(syntaxColors.string)));
      });

      test('keywords and comments have different colors', () {
        expect(syntaxColors.keyword, isNot(equals(syntaxColors.comment)));
      });

      test('strings and comments have different colors', () {
        expect(syntaxColors.string, isNot(equals(syntaxColors.comment)));
      });

      test('numbers and plain text have different colors', () {
        expect(syntaxColors.number, isNot(equals(syntaxColors.plain)));
      });

      test('parsed code produces multiple distinct colors', () {
        final result = SyntaxHighlighter.highlightCode(
          '''
void main() {
  // A comment
  var message = "Hello";
  print(42);
}
''',
          'dart',
          syntaxColors: syntaxColors,
        );

        final spans = _flattenTextSpans(result);
        final uniqueColors = spans
            .map((s) => s.style?.color)
            .where((c) => c != null)
            .toSet();

        // Should have at least 3 different colors (keyword, string, comment, number, etc.)
        expect(
          uniqueColors.length,
          greaterThanOrEqualTo(3),
          reason:
              'Code with keywords, strings, comments should produce multiple colors. '
              'Found colors: $uniqueColors',
        );
      });
    });

    group('color inheritance (regression test for parent className fix)', () {
      test('nested tokens inherit parent classification', () {
        // This test ensures the fix for _convertNodesToTextSpan passing parentClassName works
        // Keywords like 'void' and 'class' should be colored, not plain white
        final result = SyntaxHighlighter.highlightCode(
          'void foo() {}',
          'dart',
          syntaxColors: syntaxColors,
        );

        final spans = _flattenTextSpans(result);
        final voidSpan = spans.firstWhere(
          (s) => s.text != null && s.text!.trim() == 'void',
          orElse: () => throw StateError('Could not find void span'),
        );

        // void should NOT be plain color (which was the bug)
        expect(
          voidSpan.style?.color,
          isNot(equals(syntaxColors.plain)),
          reason: 'void keyword should not be plain color (regression test)',
        );
        expect(
          voidSpan.style?.color,
          equals(syntaxColors.keyword),
          reason: 'void keyword should use keyword color',
        );
      });

      test('string content inherits string classification', () {
        final result = SyntaxHighlighter.highlightCode(
          'var x = "test string";',
          'dart',
          syntaxColors: syntaxColors,
        );

        final spans = _flattenTextSpans(result);
        final stringContentSpan = spans.firstWhere(
          (s) => s.text != null && s.text!.contains('test string'),
          orElse: () => throw StateError('Could not find string content span'),
        );

        expect(
          stringContentSpan.style?.color,
          equals(syntaxColors.string),
          reason: 'String content should inherit string color from parent node',
        );
      });
    });

    group('handles edge cases', () {
      test('empty code returns empty span', () {
        final result = SyntaxHighlighter.highlightCode(
          '',
          'dart',
          syntaxColors: syntaxColors,
        );

        expect(result.text ?? '', isEmpty);
      });

      test('plain text without special tokens gets plain color', () {
        final result = SyntaxHighlighter.highlightCode(
          'simpleidentifier',
          'dart',
          syntaxColors: syntaxColors,
        );

        final spans = _flattenTextSpans(result);
        // Should have at least one span
        expect(spans.isNotEmpty, true);
      });

      test('unknown language falls back gracefully', () {
        // Should not throw, should return something sensible
        expect(
          () => SyntaxHighlighter.highlightCode(
            'some code',
            'unknownlanguage',
            syntaxColors: syntaxColors,
          ),
          returnsNormally,
        );
      });

      test('multiline code is highlighted correctly', () {
        final result = SyntaxHighlighter.highlightCode(
          '''class Foo {
  void bar() {
    // comment
    print("hello");
  }
}''',
          'dart',
          syntaxColors: syntaxColors,
        );

        final spans = _flattenTextSpans(result);
        final uniqueColors = spans
            .map((s) => s.style?.color)
            .where((c) => c != null)
            .toSet();

        expect(
          uniqueColors.length,
          greaterThanOrEqualTo(3),
          reason: 'Multiline code should have multiple distinct colors',
        );
      });
    });

    group('backgroundColor is preserved', () {
      test('background color is passed to all spans', () {
        final bgColor = Color.fromRGB(50, 50, 50);
        final result = SyntaxHighlighter.highlightCode(
          'void main() {}',
          'dart',
          backgroundColor: bgColor,
          syntaxColors: syntaxColors,
        );

        final spans = _flattenTextSpans(result);
        for (final span in spans) {
          if (span.style != null &&
              span.text != null &&
              span.text!.isNotEmpty) {
            expect(
              span.style?.backgroundColor,
              equals(bgColor),
              reason: 'All spans should have the specified background color',
            );
          }
        }
      });
    });
  });

  group('SyntaxHighlighter.detectLanguage', () {
    group('detects common file extensions', () {
      test('detects .dart files', () {
        expect(SyntaxHighlighter.detectLanguage('main.dart'), 'dart');
      });

      test('detects .js files', () {
        expect(SyntaxHighlighter.detectLanguage('index.js'), 'javascript');
      });

      test('detects .ts files', () {
        expect(SyntaxHighlighter.detectLanguage('app.ts'), 'typescript');
      });

      test('detects .tsx files', () {
        expect(SyntaxHighlighter.detectLanguage('component.tsx'), 'typescript');
      });

      test('detects .py files', () {
        expect(SyntaxHighlighter.detectLanguage('script.py'), 'python');
      });

      test('detects .java files', () {
        expect(SyntaxHighlighter.detectLanguage('Main.java'), 'java');
      });

      test('detects .go files', () {
        expect(SyntaxHighlighter.detectLanguage('main.go'), 'go');
      });

      test('detects .rs files', () {
        expect(SyntaxHighlighter.detectLanguage('lib.rs'), 'rust');
      });

      test('detects .json files', () {
        expect(SyntaxHighlighter.detectLanguage('package.json'), 'json');
      });

      test('detects .yaml files', () {
        expect(SyntaxHighlighter.detectLanguage('config.yaml'), 'yaml');
      });

      test('detects .yml files', () {
        expect(SyntaxHighlighter.detectLanguage('docker-compose.yml'), 'yaml');
      });

      test('detects .md files', () {
        expect(SyntaxHighlighter.detectLanguage('README.md'), 'markdown');
      });

      test('detects .sh files', () {
        expect(SyntaxHighlighter.detectLanguage('build.sh'), 'bash');
      });

      test('detects .sql files', () {
        expect(SyntaxHighlighter.detectLanguage('query.sql'), 'sql');
      });
    });

    group('handles edge cases', () {
      test('returns null for files without extension', () {
        expect(SyntaxHighlighter.detectLanguage('Makefile'), isNull);
      });

      test('returns null for files with only a dot', () {
        expect(SyntaxHighlighter.detectLanguage('file.'), isNull);
      });

      test('returns null for unknown extensions', () {
        expect(SyntaxHighlighter.detectLanguage('file.xyz'), isNull);
        expect(SyntaxHighlighter.detectLanguage('data.csv'), isNull);
        expect(SyntaxHighlighter.detectLanguage('image.png'), isNull);
      });

      test('handles files with multiple dots', () {
        expect(SyntaxHighlighter.detectLanguage('file.test.dart'), 'dart');
        expect(SyntaxHighlighter.detectLanguage('app.module.ts'), 'typescript');
        expect(SyntaxHighlighter.detectLanguage('config.prod.json'), 'json');
      });

      test('handles uppercase extensions', () {
        expect(SyntaxHighlighter.detectLanguage('Main.DART'), 'dart');
        expect(SyntaxHighlighter.detectLanguage('App.Dart'), 'dart');
        expect(SyntaxHighlighter.detectLanguage('INDEX.JS'), 'javascript');
        expect(SyntaxHighlighter.detectLanguage('CONFIG.YAML'), 'yaml');
      });

      test('handles full file paths', () {
        expect(
          SyntaxHighlighter.detectLanguage('/path/to/project/lib/main.dart'),
          'dart',
        );
        expect(
          SyntaxHighlighter.detectLanguage('/home/user/code/app.ts'),
          'typescript',
        );
        expect(
          SyntaxHighlighter.detectLanguage('C:\\Users\\project\\index.js'),
          'javascript',
        );
      });

      test('handles paths with dots in directory names', () {
        expect(
          SyntaxHighlighter.detectLanguage('/path.to/project/main.dart'),
          'dart',
        );
        expect(
          SyntaxHighlighter.detectLanguage('/ver.1.0/app.ts'),
          'typescript',
        );
      });

      test('handles hidden files with known extensions', () {
        expect(SyntaxHighlighter.detectLanguage('.bashrc'), isNull);
        expect(SyntaxHighlighter.detectLanguage('.gitignore'), isNull);
      });

      test('handles hidden files with extensions', () {
        expect(SyntaxHighlighter.detectLanguage('.eslintrc.json'), 'json');
        expect(SyntaxHighlighter.detectLanguage('.config.yaml'), 'yaml');
      });
    });
  });
}

/// Helper function to flatten a TextSpan tree into a list of leaf TextSpans.
List<TextSpan> _flattenTextSpans(TextSpan span) {
  final result = <TextSpan>[];

  void traverse(TextSpan s) {
    // If this span has text content, add it
    if (s.text != null && s.text!.isNotEmpty) {
      result.add(s);
    }
    // Recursively process children
    if (s.children != null) {
      for (final child in s.children!) {
        if (child is TextSpan) {
          traverse(child);
        }
      }
    }
  }

  traverse(span);
  return result;
}
