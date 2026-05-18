import 'package:nocterm/nocterm.dart';

/// The type of a row in the side-by-side diff view.
enum DiffRowType {
  unchanged,
  deleted,
  added,
  modified,
  header,
}

/// A range of characters within a line for character-level diff highlighting.
class CharRange {
  final int start; // inclusive, 0-based
  final int end; // exclusive

  const CharRange(this.start, this.end);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CharRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'CharRange($start, $end)';
}

/// A single row in the side-by-side diff view.
class SideBySideDiffRow {
  final String? leftContent;
  final int? leftLineNum;
  final String? rightContent;
  final int? rightLineNum;
  final DiffRowType type;
  final List<CharRange>? leftCharHighlights;
  final List<CharRange>? rightCharHighlights;

  /// Pre-computed syntax-highlighted content for the left panel.
  /// Mutable — set during the highlighting pass.
  TextSpan? leftHighlighted;

  /// Pre-computed syntax-highlighted content for the right panel.
  /// Mutable — set during the highlighting pass.
  TextSpan? rightHighlighted;

  SideBySideDiffRow({
    this.leftContent,
    this.leftLineNum,
    this.rightContent,
    this.rightLineNum,
    required this.type,
    this.leftCharHighlights,
    this.rightCharHighlights,
    this.leftHighlighted,
    this.rightHighlighted,
  });
}
