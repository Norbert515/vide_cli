import 'package:nocterm/nocterm.dart';
import 'package:nocterm/src/components/rich_text.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/utils/syntax_highlighter.dart';

enum DiffLineType { added, removed, unchanged, header }

class DiffLine {
  final int? lineNumber;
  final DiffLineType type;
  final String content;
  final String? language;

  const DiffLine({
    this.lineNumber,
    required this.type,
    required this.content,
    this.language,
  });
}

class CodeDiff extends StatelessComponent {
  final List<DiffLine> lines;
  final String? fileName;

  const CodeDiff({required this.lines, this.fileName, super.key});

  @override
  Component build(BuildContext context) {
    final children = <Component>[];

    // Calculate max line number width for alignment
    int maxLineNumber = 0;
    for (final line in lines) {
      if (line.lineNumber != null && line.lineNumber! > maxLineNumber) {
        maxLineNumber = line.lineNumber!;
      }
    }
    final lineNumberWidth = maxLineNumber.toString().length;

    // Add diff lines
    for (final line in lines) {
      children.add(_buildDiffLine(line, lineNumberWidth));
    }

    return Container(
      padding: EdgeInsets.symmetric(vertical: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Component _buildDiffLine(DiffLine line, int lineNumberWidth) {
    switch (line.type) {
      case DiffLineType.header:
        return Container(
          padding: EdgeInsets.symmetric(vertical: 1),
          child: Text(line.content, style: TextStyle(color: Colors.cyan)),
        );

      case DiffLineType.added:
        return _buildCodeLine(
          lineNumber: line.lineNumber,
          lineNumberWidth: lineNumberWidth,
          prefix: '+',
          content: line.content,
          prefixColor: Colors.green,
          contentColor: Colors.white,
          backgroundColor: Color(0xFF0D3D0D),
          language: line.language,
        );

      case DiffLineType.removed:
        return _buildCodeLine(
          lineNumber: line.lineNumber,
          lineNumberWidth: lineNumberWidth,
          prefix: '-',
          content: line.content,
          prefixColor: Colors.red,
          contentColor: Colors.white,
          backgroundColor: Color(0xFF3D0D0D),
          language: line.language,
        );

      case DiffLineType.unchanged:
        return _buildCodeLine(
          lineNumber: line.lineNumber,
          lineNumberWidth: lineNumberWidth,
          prefix: ' ',
          content: line.content,
          prefixColor: Colors.grey,
          contentColor: Colors.white,
          language: line.language,
        );
    }
  }

  Component _buildCodeLine({
    required int? lineNumber,
    required int lineNumberWidth,
    required String prefix,
    required String content,
    required Color prefixColor,
    required Color contentColor,
    Color? backgroundColor,
    String? language,
  }) {
    final lineNumberStr = lineNumber != null
        ? lineNumber.toString().padLeft(lineNumberWidth)
        : ' ' * lineNumberWidth;

    return Row(
      children: [
        // Line number
        Text(
          lineNumberStr,
          style: TextStyle(
            color: Colors.white.withOpacity(TextOpacity.tertiary),
          ),
        ),

        // Space between line number and prefix
        Text(' ', style: TextStyle()),

        // Diff prefix (+, -, or space)
        Text(
          prefix,
          style: TextStyle(
            color: prefixColor,
            backgroundColor: backgroundColor,
          ),
        ),

        // Space after prefix
        Text(' ', style: TextStyle(backgroundColor: backgroundColor)),

        // Code content with syntax highlighting
        Expanded(
          child: Container(
            child: language != null
                ? RichText(
                    text: SyntaxHighlighter.highlightCode(
                      content,
                      language,
                      backgroundColor: backgroundColor,
                    ),
                  )
                : Text(
                    content,
                    style: TextStyle(
                      color: contentColor,
                      backgroundColor: backgroundColor,
                    ),
                    overflow: TextOverflow.visible,
                  ),
          ),
        ),
      ],
    );
  }
}

// Helper class to parse unified diff format
class DiffParser {
  static List<DiffLine> parseUnifiedDiff(String diff) {
    final lines = <DiffLine>[];
    final diffLines = diff.split('\n');

    int addedLineNumber = 0;
    int removedLineNumber = 0;

    for (final line in diffLines) {
      if (line.startsWith('+++') || line.startsWith('---')) {
        // File headers
        lines.add(DiffLine(type: DiffLineType.header, content: line));
      } else if (line.startsWith('@@')) {
        // Hunk header - parse line numbers
        final match = RegExp(
          r'@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@',
        ).firstMatch(line);
        if (match != null) {
          removedLineNumber = int.parse(match.group(1)!);
          addedLineNumber = int.parse(match.group(2)!);
        }
        lines.add(DiffLine(type: DiffLineType.header, content: line));
      } else if (line.startsWith('+')) {
        lines.add(
          DiffLine(
            lineNumber: addedLineNumber++,
            type: DiffLineType.added,
            content: line.substring(1),
          ),
        );
      } else if (line.startsWith('-')) {
        lines.add(
          DiffLine(
            lineNumber: removedLineNumber++,
            type: DiffLineType.removed,
            content: line.substring(1),
          ),
        );
      } else if (line.startsWith(' ')) {
        lines.add(
          DiffLine(
            lineNumber: addedLineNumber++,
            type: DiffLineType.unchanged,
            content: line.substring(1),
          ),
        );
        removedLineNumber++;
      }
    }

    return lines;
  }

  // Helper to create a simple diff from old and new content
  static List<DiffLine> createSimpleDiff(
    String? oldContent,
    String newContent,
  ) {
    final lines = <DiffLine>[];

    if (oldContent == null || oldContent.isEmpty) {
      // New file - all lines are additions
      final newLines = newContent.split('\n');
      for (int i = 0; i < newLines.length; i++) {
        lines.add(
          DiffLine(
            lineNumber: i + 1,
            type: DiffLineType.added,
            content: newLines[i],
          ),
        );
      }
    } else {
      // For now, show a simple before/after diff
      // In a real implementation, you'd use a proper diff algorithm
      final oldLines = oldContent.split('\n');
      final newLines = newContent.split('\n');

      // Show removed lines
      for (int i = 0; i < oldLines.length; i++) {
        lines.add(
          DiffLine(
            lineNumber: i + 1,
            type: DiffLineType.removed,
            content: oldLines[i],
          ),
        );
      }

      // Show added lines
      for (int i = 0; i < newLines.length; i++) {
        lines.add(
          DiffLine(
            lineNumber: i + 1,
            type: DiffLineType.added,
            content: newLines[i],
          ),
        );
      }
    }

    return lines;
  }
}
