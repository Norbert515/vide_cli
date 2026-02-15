/// Extracts the diff section for a single file from a full `git diff` output.
///
/// [fullDiff] is the complete diff output (may contain multiple files).
/// [relativePath] is the file path relative to the repo root.
String filterDiffForFile(String fullDiff, String relativePath) {
  final lines = fullDiff.split('\n');
  final buffer = StringBuffer();
  var inTargetSection = false;

  for (final line in lines) {
    if (line.startsWith('diff --git ')) {
      inTargetSection = line.contains('a/$relativePath') &&
          line.contains('b/$relativePath');
    }
    if (inTargetSection) {
      buffer.writeln(line);
    }
  }

  return buffer.toString().trimRight();
}

/// Converts an absolute file path to a relative path by stripping the root prefix.
String toRelativePath(String filePath, String rootPath) {
  if (filePath.length > rootPath.length && filePath.startsWith(rootPath)) {
    return filePath.substring(rootPath.length + 1);
  }
  return filePath;
}
