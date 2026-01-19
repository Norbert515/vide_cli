import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';

void main() {
  group('BashCommandParser.parse', () {
    test('parses simple command', () {
      final result = BashCommandParser.parse('dart pub get');
      expect(result.length, 1);
      expect(result[0].command, 'dart pub get');
      expect(result[0].type, CommandType.simple);
    });

    test('parses compound command with &&', () {
      final result = BashCommandParser.parse('cd /path && dart pub get');
      expect(result.length, 2);
      expect(result[0].command, 'cd /path');
      expect(result[0].type, CommandType.cd);
      expect(result[1].command, 'dart pub get');
      expect(result[1].type, CommandType.simple);
    });

    test('parses compound command with ||', () {
      final result = BashCommandParser.parse('dart test || echo "failed"');
      expect(result.length, 2);
      expect(result[0].command, 'dart test');
      expect(result[1].command, 'echo "failed"');
    });

    test('parses compound command with ;', () {
      final result = BashCommandParser.parse('cd /path ; dart pub get');
      expect(result.length, 2);
      expect(result[0].command, 'cd /path');
      expect(result[1].command, 'dart pub get');
    });

    test('parses pipe command', () {
      final result = BashCommandParser.parse('dart pub deps | grep uuid');
      expect(result.length, 2);
      expect(result[0].command, 'dart pub deps');
      expect(result[0].type, CommandType.pipelinePart);
      expect(result[1].command, 'grep uuid');
      expect(result[1].type, CommandType.pipelinePart);
    });

    test('parses complex command with && and |', () {
      final result = BashCommandParser.parse(
        'cd /path && dart pub deps | grep uuid',
      );
      expect(result.length, 3);
      expect(result[0].command, 'cd /path');
      expect(result[0].type, CommandType.cd);
      expect(result[1].command, 'dart pub deps');
      expect(result[1].type, CommandType.pipelinePart);
      expect(result[2].command, 'grep uuid');
      expect(result[2].type, CommandType.pipelinePart);
    });

    test('handles || operator (not pipe)', () {
      final result = BashCommandParser.parse(
        'test -f file || echo "not found"',
      );
      expect(result.length, 2);
      expect(result[0].command, 'test -f file');
      expect(result[0].type, CommandType.simple);
      expect(result[1].command, 'echo "not found"');
      expect(result[1].type, CommandType.simple);
    });

    test('handles quoted strings with operators', () {
      final result = BashCommandParser.parse('echo "foo && bar" && echo "baz"');
      expect(result.length, 2);
      expect(result[0].command, 'echo "foo && bar"');
      expect(result[1].command, 'echo "baz"');
    });

    test('handles empty command', () {
      final result = BashCommandParser.parse('');
      expect(result.length, 0);
    });

    test('handles multiple pipes', () {
      final result = BashCommandParser.parse('cat file.txt | grep foo | sort');
      expect(result.length, 3);
      expect(result[0].type, CommandType.pipelinePart);
      expect(result[1].type, CommandType.pipelinePart);
      expect(result[2].type, CommandType.pipelinePart);
    });

    test('handles complex real-world example', () {
      final result = BashCommandParser.parse(
        'cd packages/server && serverpod generate && dart analyze',
      );
      expect(result.length, 3);
      expect(result[0].command, 'cd packages/server');
      expect(result[0].type, CommandType.cd);
      expect(result[1].command, 'serverpod generate');
      expect(result[1].type, CommandType.simple);
      expect(result[2].command, 'dart analyze');
      expect(result[2].type, CommandType.simple);
    });
  });

  group('BashCommandParser.isCdWithinWorkingDir', () {
    test('returns true for cd to subdirectory', () {
      expect(
        BashCommandParser.isCdWithinWorkingDir(
          'cd /project/packages/server',
          '/project',
        ),
        isTrue,
      );
    });

    test('returns true for cd to same directory', () {
      expect(
        BashCommandParser.isCdWithinWorkingDir('cd /project', '/project'),
        isTrue,
      );
    });

    test('returns false for cd outside working directory', () {
      expect(
        BashCommandParser.isCdWithinWorkingDir('cd /other', '/project'),
        isFalse,
      );
    });

    test('handles relative paths', () {
      expect(
        BashCommandParser.isCdWithinWorkingDir(
          'cd packages/server',
          '/project',
        ),
        isTrue,
      );
    });

    test('returns false for cd to home directory', () {
      expect(
        BashCommandParser.isCdWithinWorkingDir('cd ~/', '/project'),
        isFalse,
      );
    });

    test('returns false for cd without argument', () {
      expect(BashCommandParser.isCdWithinWorkingDir('cd', '/project'), isFalse);
    });

    test('returns false for non-cd command', () {
      expect(
        BashCommandParser.isCdWithinWorkingDir('ls /project', '/project'),
        isFalse,
      );
    });

    test('handles relative path with ..', () {
      expect(
        BashCommandParser.isCdWithinWorkingDir(
          'cd packages/../server',
          '/project',
        ),
        isTrue,
      );
    });

    test('returns false when .. goes outside working directory', () {
      expect(
        BashCommandParser.isCdWithinWorkingDir('cd ../..', '/project'),
        isFalse,
      );
    });

    test('handles complex relative path', () {
      expect(
        BashCommandParser.isCdWithinWorkingDir(
          'cd ./packages/server',
          '/project',
        ),
        isTrue,
      );
    });
  });
}
