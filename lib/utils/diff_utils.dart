/// Utility functions for diff parsing and line type detection.
///
/// These are extracted from DiffRenderer to enable unit testing.

/// Represents the type of change for a line in a diff
enum LineChangeType {
  /// Line was added (in new but not old)
  added,

  /// Line was removed (in old but not new)
  removed,

  /// Line is unchanged (in both or in neither)
  unchanged,
}

/// Utility class for diff-related operations
class DiffUtils {
  // Pre-compiled regex patterns for parsing diff output
  static final lineValidationRegex = RegExp(r'^\s*\d+→');
  static final lineParseRegex = RegExp(r'^\s*(\d+)→(.*)');

  /// Validates if a line matches the expected cat -n format
  ///
  /// Expected format: "  1→content" or "123→content"
  static bool isValidLineFormat(String line) {
    return lineValidationRegex.hasMatch(line);
  }

  /// Parses a cat -n formatted line and extracts line number and content
  ///
  /// Returns null if the line doesn't match the expected format
  static ({int lineNumber, String content})? parseLine(String line) {
    final match = lineParseRegex.firstMatch(line);
    if (match == null) return null;

    final lineNumber = int.tryParse(match.group(1)!);
    if (lineNumber == null) return null;

    return (lineNumber: lineNumber, content: match.group(2)!);
  }

  /// Determines the change type for a line based on old and new content sets
  ///
  /// The logic is:
  /// - Line in newSet but NOT in oldSet → added
  /// - Line in oldSet but NOT in newSet → removed
  /// - Line in BOTH sets → unchanged
  /// - Line in NEITHER set → unchanged (context line)
  static LineChangeType determineLineChangeType({
    required String content,
    required Set<String> oldLines,
    required Set<String> newLines,
  }) {
    final trimmedContent = content.trim();
    final isInNew = newLines.contains(trimmedContent);
    final isInOld = oldLines.contains(trimmedContent);

    if (isInNew && !isInOld) {
      // Line is in new but not old = added
      return LineChangeType.added;
    } else if (!isInNew && isInOld) {
      // Line is in old but not new = removed
      return LineChangeType.removed;
    } else {
      // Line is in both or in neither = unchanged
      return LineChangeType.unchanged;
    }
  }

  /// Creates Sets from old and new strings for efficient lookup
  ///
  /// Lines are trimmed before being added to the set
  static ({Set<String> oldSet, Set<String> newSet}) createLineSets({
    required String oldString,
    required String newString,
  }) {
    final oldSet = oldString.split('\n').map((l) => l.trim()).toSet();
    final newSet = newString.split('\n').map((l) => l.trim()).toSet();
    return (oldSet: oldSet, newSet: newSet);
  }
}
