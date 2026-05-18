import 'package:test/test.dart';
import 'package:vide_cli/modules/agent_network/components/tool_invocations/shared/code_diff.dart';
import 'package:vide_cli/modules/agent_network/components/tool_invocations/shared/line_pairer.dart';
import 'package:vide_cli/modules/agent_network/components/tool_invocations/shared/side_by_side_models.dart';

void main() {
  group('LinePairer.pairLines', () {
    test('empty input returns empty output', () {
      expect(LinePairer.pairLines([]), isEmpty);
    });

    test('all unchanged lines', () {
      final lines = [
        DiffLine(
            lineNumber: 1,
            oldLineNumber: 1,
            newLineNumber: 1,
            type: DiffLineType.unchanged,
            content: 'line 1'),
        DiffLine(
            lineNumber: 2,
            oldLineNumber: 2,
            newLineNumber: 2,
            type: DiffLineType.unchanged,
            content: 'line 2'),
      ];
      final result = LinePairer.pairLines(lines);
      expect(result.length, 2);
      expect(result[0].type, DiffRowType.unchanged);
      expect(result[0].leftContent, 'line 1');
      expect(result[0].rightContent, 'line 1');
      expect(result[0].leftLineNum, 1);
      expect(result[0].rightLineNum, 1);
    });

    test('1 removed + 1 added = 1 modified', () {
      final lines = [
        DiffLine(
            lineNumber: 5,
            oldLineNumber: 5,
            type: DiffLineType.removed,
            content: 'old line'),
        DiffLine(
            lineNumber: 5,
            newLineNumber: 5,
            type: DiffLineType.added,
            content: 'new line'),
      ];
      final result = LinePairer.pairLines(lines);
      expect(result.length, 1);
      expect(result[0].type, DiffRowType.modified);
      expect(result[0].leftContent, 'old line');
      expect(result[0].rightContent, 'new line');
      expect(result[0].leftLineNum, 5);
      expect(result[0].rightLineNum, 5);
      expect(result[0].leftCharHighlights, isNotNull);
      expect(result[0].rightCharHighlights, isNotNull);
    });

    test('3 removed + 5 added = 3 modified + 2 added', () {
      final lines = [
        DiffLine(oldLineNumber: 1, type: DiffLineType.removed, content: 'r1'),
        DiffLine(oldLineNumber: 2, type: DiffLineType.removed, content: 'r2'),
        DiffLine(oldLineNumber: 3, type: DiffLineType.removed, content: 'r3'),
        DiffLine(newLineNumber: 1, type: DiffLineType.added, content: 'a1'),
        DiffLine(newLineNumber: 2, type: DiffLineType.added, content: 'a2'),
        DiffLine(newLineNumber: 3, type: DiffLineType.added, content: 'a3'),
        DiffLine(newLineNumber: 4, type: DiffLineType.added, content: 'a4'),
        DiffLine(newLineNumber: 5, type: DiffLineType.added, content: 'a5'),
      ];
      final result = LinePairer.pairLines(lines);
      expect(result.length, 5);
      expect(result[0].type, DiffRowType.modified);
      expect(result[1].type, DiffRowType.modified);
      expect(result[2].type, DiffRowType.modified);
      expect(result[3].type, DiffRowType.added);
      expect(result[3].leftContent, isNull);
      expect(result[4].type, DiffRowType.added);
      expect(result[4].leftContent, isNull);
    });

    test('5 removed + 3 added = 3 modified + 2 deleted', () {
      final lines = [
        DiffLine(oldLineNumber: 1, type: DiffLineType.removed, content: 'r1'),
        DiffLine(oldLineNumber: 2, type: DiffLineType.removed, content: 'r2'),
        DiffLine(oldLineNumber: 3, type: DiffLineType.removed, content: 'r3'),
        DiffLine(oldLineNumber: 4, type: DiffLineType.removed, content: 'r4'),
        DiffLine(oldLineNumber: 5, type: DiffLineType.removed, content: 'r5'),
        DiffLine(newLineNumber: 1, type: DiffLineType.added, content: 'a1'),
        DiffLine(newLineNumber: 2, type: DiffLineType.added, content: 'a2'),
        DiffLine(newLineNumber: 3, type: DiffLineType.added, content: 'a3'),
      ];
      final result = LinePairer.pairLines(lines);
      expect(result.length, 5);
      expect(result[0].type, DiffRowType.modified);
      expect(result[1].type, DiffRowType.modified);
      expect(result[2].type, DiffRowType.modified);
      expect(result[3].type, DiffRowType.deleted);
      expect(result[3].rightContent, isNull);
      expect(result[4].type, DiffRowType.deleted);
      expect(result[4].rightContent, isNull);
    });

    test('pure additions (no removed buffer)', () {
      final lines = [
        DiffLine(
            newLineNumber: 1, type: DiffLineType.added, content: 'new1'),
        DiffLine(
            newLineNumber: 2, type: DiffLineType.added, content: 'new2'),
      ];
      final result = LinePairer.pairLines(lines);
      expect(result.length, 2);
      expect(result[0].type, DiffRowType.added);
      expect(result[0].leftContent, isNull);
      expect(result[0].rightContent, 'new1');
      expect(result[1].type, DiffRowType.added);
    });

    test('pure deletions', () {
      final lines = [
        DiffLine(
            oldLineNumber: 1, type: DiffLineType.removed, content: 'old1'),
        DiffLine(
            oldLineNumber: 2, type: DiffLineType.removed, content: 'old2'),
      ];
      final result = LinePairer.pairLines(lines);
      expect(result.length, 2);
      expect(result[0].type, DiffRowType.deleted);
      expect(result[0].leftContent, 'old1');
      expect(result[0].rightContent, isNull);
    });

    test('header lines pass through', () {
      final lines = [
        DiffLine(type: DiffLineType.header, content: '@@ -1,3 +1,3 @@'),
      ];
      final result = LinePairer.pairLines(lines);
      expect(result.length, 1);
      expect(result[0].type, DiffRowType.header);
      expect(result[0].leftContent, '@@ -1,3 +1,3 @@');
      expect(result[0].rightContent, '@@ -1,3 +1,3 @@');
    });

    test('interleaved: removed, removed, added, unchanged', () {
      final lines = [
        DiffLine(
            oldLineNumber: 1, type: DiffLineType.removed, content: 'old1'),
        DiffLine(
            oldLineNumber: 2, type: DiffLineType.removed, content: 'old2'),
        DiffLine(
            newLineNumber: 1, type: DiffLineType.added, content: 'new1'),
        DiffLine(
            oldLineNumber: 3,
            newLineNumber: 2,
            type: DiffLineType.unchanged,
            content: 'same'),
      ];
      final result = LinePairer.pairLines(lines);
      expect(result.length, 3);
      // First removed paired with the added -> modified
      expect(result[0].type, DiffRowType.modified);
      expect(result[0].leftContent, 'old1');
      expect(result[0].rightContent, 'new1');
      // Second removed flushed as deleted (before unchanged)
      expect(result[1].type, DiffRowType.deleted);
      expect(result[1].leftContent, 'old2');
      expect(result[1].rightContent, isNull);
      // Unchanged
      expect(result[2].type, DiffRowType.unchanged);
      expect(result[2].leftContent, 'same');
      expect(result[2].rightContent, 'same');
    });

    test('header flushes removed buffer', () {
      final lines = [
        DiffLine(
            oldLineNumber: 1, type: DiffLineType.removed, content: 'old'),
        DiffLine(type: DiffLineType.header, content: '@@ -5,3 +5,3 @@'),
      ];
      final result = LinePairer.pairLines(lines);
      expect(result.length, 2);
      expect(result[0].type, DiffRowType.deleted);
      expect(result[1].type, DiffRowType.header);
    });

    test('modified rows have char diff highlights', () {
      final lines = [
        DiffLine(
            oldLineNumber: 1,
            type: DiffLineType.removed,
            content: 'hello world'),
        DiffLine(
            newLineNumber: 1,
            type: DiffLineType.added,
            content: 'Hello World'),
      ];
      final result = LinePairer.pairLines(lines);
      expect(result[0].type, DiffRowType.modified);
      expect(result[0].leftCharHighlights, isNotEmpty);
      expect(result[0].rightCharHighlights, isNotEmpty);
    });
  });
}
