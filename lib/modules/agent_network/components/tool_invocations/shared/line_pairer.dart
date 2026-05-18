import 'code_diff.dart';
import 'side_by_side_models.dart';
import 'char_diff.dart';

class LinePairer {
  /// Convert a flat unified diff line list into side-by-side paired rows.
  ///
  /// The algorithm pairs consecutive removed+added lines as "modified" rows.
  /// If 3 removed + 5 added: first 3 are modified, remaining 2 are added.
  /// If 5 removed + 3 added: first 3 are modified, remaining 2 are deleted.
  static List<SideBySideDiffRow> pairLines(List<DiffLine> flatLines) {
    final result = <SideBySideDiffRow>[];
    final removedBuffer = <DiffLine>[];

    for (final line in flatLines) {
      switch (line.type) {
        case DiffLineType.header:
          _flushRemoved(removedBuffer, result);
          result.add(SideBySideDiffRow(
            leftContent: line.content,
            rightContent: line.content,
            type: DiffRowType.header,
          ));

        case DiffLineType.removed:
          removedBuffer.add(line);

        case DiffLineType.added:
          if (removedBuffer.isNotEmpty) {
            final removed = removedBuffer.removeAt(0);
            final charDiffs = CharDiff.compute(removed.content, line.content);
            result.add(SideBySideDiffRow(
              leftContent: removed.content,
              leftLineNum: removed.oldLineNumber ?? removed.lineNumber,
              rightContent: line.content,
              rightLineNum: line.newLineNumber ?? line.lineNumber,
              type: DiffRowType.modified,
              leftCharHighlights: charDiffs.left,
              rightCharHighlights: charDiffs.right,
            ));
          } else {
            result.add(SideBySideDiffRow(
              rightContent: line.content,
              rightLineNum: line.newLineNumber ?? line.lineNumber,
              type: DiffRowType.added,
            ));
          }

        case DiffLineType.unchanged:
          _flushRemoved(removedBuffer, result);
          result.add(SideBySideDiffRow(
            leftContent: line.content,
            leftLineNum: line.oldLineNumber ?? line.lineNumber,
            rightContent: line.content,
            rightLineNum: line.newLineNumber ?? line.lineNumber,
            type: DiffRowType.unchanged,
          ));
      }
    }
    _flushRemoved(removedBuffer, result);
    return result;
  }

  static void _flushRemoved(
    List<DiffLine> buffer,
    List<SideBySideDiffRow> result,
  ) {
    for (final removed in buffer) {
      result.add(SideBySideDiffRow(
        leftContent: removed.content,
        leftLineNum: removed.oldLineNumber ?? removed.lineNumber,
        type: DiffRowType.deleted,
      ));
    }
    buffer.clear();
  }
}
