import 'package:test/test.dart';
import 'package:vide_cli/modules/agent_network/components/tool_invocations/shared/char_diff.dart';
import 'package:vide_cli/modules/agent_network/components/tool_invocations/shared/side_by_side_models.dart';

void main() {
  group('CharDiff.compute', () {
    test('identical strings return empty ranges', () {
      final result = CharDiff.compute('hello world', 'hello world');
      expect(result.left, isEmpty);
      expect(result.right, isEmpty);
    });

    test('empty old string', () {
      final result = CharDiff.compute('', 'hello');
      expect(result.left, isEmpty);
      expect(result.right, [CharRange(0, 5)]);
    });

    test('empty new string', () {
      final result = CharDiff.compute('hello', '');
      expect(result.left, [CharRange(0, 5)]);
      expect(result.right, isEmpty);
    });

    test('prefix change', () {
      final result = CharDiff.compute('hello world', 'Hello world');
      expect(result.left, [CharRange(0, 1)]);
      expect(result.right, [CharRange(0, 1)]);
    });

    test('suffix change', () {
      final result = CharDiff.compute('hello', 'help');
      // common prefix: "hel", common suffix: none from end
      // old: "lo" at [3,5), new: "p" at [3,4)
      expect(result.left, [CharRange(3, 5)]);
      expect(result.right, [CharRange(3, 4)]);
    });

    test('middle change', () {
      final result = CharDiff.compute('abcXdef', 'abcYZdef');
      // common prefix: "abc" (3), common suffix: "def" (3)
      // old: "X" at [3,4), new: "YZ" at [3,5)
      expect(result.left, [CharRange(3, 4)]);
      expect(result.right, [CharRange(3, 5)]);
    });

    test('insertion in middle', () {
      final result = CharDiff.compute('abcdef', 'abcXYZdef');
      // common prefix: "abc" (3), common suffix: "def" (3)
      // old: nothing changed (3==3), new: "XYZ" at [3,6)
      expect(result.left, isEmpty);
      expect(result.right, [CharRange(3, 6)]);
    });

    test('deletion in middle', () {
      final result = CharDiff.compute('abcXYZdef', 'abcdef');
      // common prefix: "abc" (3), common suffix: "def" (3)
      // old: "XYZ" at [3,6), new: nothing
      expect(result.left, [CharRange(3, 6)]);
      expect(result.right, isEmpty);
    });

    test('complete replacement', () {
      final result = CharDiff.compute('abc', 'xyz');
      expect(result.left, [CharRange(0, 3)]);
      expect(result.right, [CharRange(0, 3)]);
    });

    test('single character change', () {
      final result = CharDiff.compute('a', 'b');
      expect(result.left, [CharRange(0, 1)]);
      expect(result.right, [CharRange(0, 1)]);
    });

    test('whitespace change - indentation', () {
      final result = CharDiff.compute('  foo()', '    foo()');
      // common prefix: "  " (2), common suffix: "foo()" (5)
      // old: nothing at [2,2), new: "  " at [2,4)
      expect(result.left, isEmpty);
      expect(result.right, [CharRange(2, 4)]);
    });

    test('both empty strings', () {
      final result = CharDiff.compute('', '');
      expect(result.left, isEmpty);
      expect(result.right, isEmpty);
    });
  });
}
