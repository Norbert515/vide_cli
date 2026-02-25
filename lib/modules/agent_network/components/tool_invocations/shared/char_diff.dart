import 'side_by_side_models.dart';

/// Result of a character-level diff between two strings.
class CharDiffResult {
  /// Ranges of characters in the old string that were deleted/changed.
  final List<CharRange> left;

  /// Ranges of characters in the new string that were added/changed.
  final List<CharRange> right;

  const CharDiffResult(this.left, this.right);
}

/// Computes character-level diffs between two strings.
class CharDiff {
  /// Compute character-level diff between two strings.
  ///
  /// Returns ranges of characters that differ on each side.
  /// Uses prefix/suffix trimming for efficiency — finds the common
  /// prefix and suffix, marks everything in between as changed.
  static CharDiffResult compute(String oldStr, String newStr) {
    if (oldStr == newStr) return const CharDiffResult([], []);
    if (oldStr.isEmpty) {
      return CharDiffResult([], [CharRange(0, newStr.length)]);
    }
    if (newStr.isEmpty) {
      return CharDiffResult([CharRange(0, oldStr.length)], []);
    }

    // Find common prefix
    int prefixLen = 0;
    final minLen =
        oldStr.length < newStr.length ? oldStr.length : newStr.length;
    while (prefixLen < minLen && oldStr[prefixLen] == newStr[prefixLen]) {
      prefixLen++;
    }

    // Find common suffix (not overlapping with prefix)
    int oldSuffixStart = oldStr.length;
    int newSuffixStart = newStr.length;
    while (oldSuffixStart > prefixLen &&
        newSuffixStart > prefixLen &&
        oldStr[oldSuffixStart - 1] == newStr[newSuffixStart - 1]) {
      oldSuffixStart--;
      newSuffixStart--;
    }

    final leftRanges = oldSuffixStart > prefixLen
        ? [CharRange(prefixLen, oldSuffixStart)]
        : <CharRange>[];
    final rightRanges = newSuffixStart > prefixLen
        ? [CharRange(prefixLen, newSuffixStart)]
        : <CharRange>[];

    return CharDiffResult(leftRanges, rightRanges);
  }
}
