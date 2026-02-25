import 'package:nocterm/nocterm.dart';

import 'side_by_side_models.dart';

/// Apply character-level highlight ranges to a syntax-highlighted [TextSpan].
///
/// Flattens the span tree into segments with character offsets, then splits
/// segments at highlight range boundaries, applying a brighter background
/// to the highlighted portions.
TextSpan applyCharHighlights(
  TextSpan span,
  List<CharRange> ranges,
  Color highlightColor,
) {
  if (ranges.isEmpty) return span;

  // Flatten span tree to segments with char offsets.
  final segments = <_FlatSegment>[];
  _flattenSpan(span, segments, 0);

  // Sort ranges by start for correct application.
  final sorted = List<CharRange>.from(ranges)
    ..sort((a, b) => a.start.compareTo(b.start));

  final newChildren = <TextSpan>[];

  for (final seg in segments) {
    final segEnd = seg.start + seg.text.length;
    var currentStart = seg.start;
    var remaining = seg.text;

    for (final range in sorted) {
      if (range.end <= currentStart || range.start >= segEnd) continue;

      // Part before the highlight.
      final highlightStart =
          (range.start - currentStart).clamp(0, remaining.length);
      if (highlightStart > 0) {
        newChildren.add(TextSpan(
          text: remaining.substring(0, highlightStart),
          style: seg.style,
        ));
        remaining = remaining.substring(highlightStart);
        currentStart += highlightStart;
      }

      // Highlighted part.
      final highlightEnd =
          (range.end - currentStart).clamp(0, remaining.length);
      if (highlightEnd > 0) {
        final highlightStyle =
            (seg.style ?? const TextStyle()).copyWith(
          backgroundColor: highlightColor,
        );
        newChildren.add(TextSpan(
          text: remaining.substring(0, highlightEnd),
          style: highlightStyle,
        ));
        remaining = remaining.substring(highlightEnd);
        currentStart += highlightEnd;
      }
    }

    // Remaining unhighlighted part.
    if (remaining.isNotEmpty) {
      newChildren.add(TextSpan(text: remaining, style: seg.style));
    }
  }

  return TextSpan(children: newChildren);
}

/// Flatten a [TextSpan] tree into a list of leaf segments with character offsets.
int _flattenSpan(
  TextSpan span,
  List<_FlatSegment> out,
  int offset,
) {
  if (span.text != null) {
    out.add(_FlatSegment(span.text!, span.style, offset));
    offset += span.text!.length;
  }
  if (span.children != null) {
    for (final child in span.children!) {
      offset = _flattenSpan(child as TextSpan, out, offset);
    }
  }
  return offset;
}

/// A flattened segment of text with its style and character offset.
class _FlatSegment {
  final String text;
  final TextStyle? style;
  final int start;

  const _FlatSegment(this.text, this.style, this.start);
}
