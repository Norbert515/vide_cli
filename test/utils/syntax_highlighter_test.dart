import 'package:test/test.dart';
import 'package:vide_cli/utils/syntax_highlighter.dart';

void main() {
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
