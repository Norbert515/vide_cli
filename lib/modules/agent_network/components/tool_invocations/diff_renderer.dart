import 'package:agent_sdk/agent_sdk.dart';
import 'package:nocterm/nocterm.dart';
import 'package:vide_core/vide_core.dart' show AgentId;
import 'shared/code_diff.dart';
import 'shared/syntax_highlighter.dart';
import 'shared/tool_header.dart';
import 'package:vide_cli/theme/theme.dart';

/// Renderer for Write/Edit/MultiEdit tool invocations with successful results.
/// Shows code diffs with syntax highlighting.
class DiffRenderer extends StatefulComponent {
  final AgentToolInvocation invocation;
  final String workingDirectory;
  final String executionId;
  final AgentId agentId;

  const DiffRenderer({
    required this.invocation,
    required this.workingDirectory,
    required this.executionId,
    required this.agentId,
    super.key,
  });

  @override
  State<DiffRenderer> createState() => _DiffRendererState();
}

class _DiffRendererState extends State<DiffRenderer> {
  // Pre-compiled regex patterns to avoid creating RegExp objects in loops
  static final _lineValidationRegex = RegExp(r'^\s*\d+→');
  static final _lineParseRegex = RegExp(r'^\s*(\d+)→(.*)');

  late final List<DiffLine> _rawDiffLines;
  late final String? _cachedFormattedPath;
  late final bool _shouldUseFallback;
  late final String? _language;

  // Cached diff lines with pre-computed syntax highlighting
  List<DiffLine>? _cachedHighlightedLines;

  @override
  void initState() {
    super.initState();

    final fileOp = component.invocation is AgentFileOperationToolInvocation
        ? component.invocation as AgentFileOperationToolInvocation
        : null;
    final filePath = fileOp?.filePath;
    if (filePath != null && filePath.isNotEmpty) {
      _cachedFormattedPath = ToolHeader.formatFilePath(filePath, component.workingDirectory);
      _language = SyntaxHighlighter.detectLanguage(filePath);
    } else {
      _cachedFormattedPath = null;
      _language = null;
    }

    // Create diff lines (without highlights - those require theme from context)
    _rawDiffLines = _createDiffLines();

    // Check if we should use fallback
    _shouldUseFallback = _rawDiffLines.isEmpty;
  }

  /// Get diff lines with pre-computed syntax highlighting.
  /// Highlights are computed lazily on first access since they require theme from context.
  List<DiffLine> _getHighlightedLines(BuildContext context) {
    if (_cachedHighlightedLines != null) {
      return _cachedHighlightedLines!;
    }

    // No language detected, return raw lines
    final language = _language;
    if (language == null) {
      _cachedHighlightedLines = _rawDiffLines;
      return _cachedHighlightedLines!;
    }

    final theme = VideTheme.of(context);

    // Pre-compute syntax highlighting for all lines
    _cachedHighlightedLines = _rawDiffLines.map((line) {
      // Determine background color based on line type
      Color? backgroundColor;
      switch (line.type) {
        case DiffLineType.added:
          backgroundColor = theme.diff.addedBackground;
          break;
        case DiffLineType.removed:
          backgroundColor = theme.diff.removedBackground;
          break;
        case DiffLineType.unchanged:
        case DiffLineType.header:
          backgroundColor = null;
          break;
      }

      // Compute highlighted content
      final highlightedContent = SyntaxHighlighter.highlightCode(
        line.content,
        language,
        backgroundColor: backgroundColor,
        syntaxColors: theme.syntax,
      );

      return DiffLine(
        lineNumber: line.lineNumber,
        type: line.type,
        content: line.content,
        language: line.language,
        highlightedContent: highlightedContent,
      );
    }).toList();

    return _cachedHighlightedLines!;
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    // If no diff lines could be created, fall back to just the header
    if (_shouldUseFallback) {
      return ToolHeader(invocation: component.invocation, workingDirectory: component.workingDirectory);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tool header
        ToolHeader(
          invocation: component.invocation,
          workingDirectory: component.workingDirectory,
          statusColor: ToolHeader.getStatusColor(component.invocation, theme),
        ),

        // Diff view (with pre-computed syntax highlighting)
        Container(
          padding: EdgeInsets.only(left: 2),
          child: CodeDiff(fileName: _cachedFormattedPath, lines: _getHighlightedLines(context)),
        ),
      ],
    );
  }

  List<DiffLine> _createDiffLines() {
    final invocation = component.invocation;

    if (invocation is AgentWriteToolInvocation) {
      return _parseWriteToolResult(invocation.content);
    } else if (invocation is AgentEditToolInvocation) {
      return _parseEditResult(invocation.oldString, invocation.newString);
    }

    return [];
  }

  List<DiffLine> _parseWriteToolResult(String content) {
    // For Write tool, show all lines as added
    final lines = content.split('\n');
    return List.generate(lines.length, (i) => DiffLine(lineNumber: i + 1, type: DiffLineType.added, content: lines[i]));
  }

  List<DiffLine> _parseEditResult(String oldString, String newString) {
    final lines = <DiffLine>[];
    final resultContent = component.invocation.resultContent ?? '';

    // Only process if result contains cat -n output
    if (!resultContent.contains('cat -n')) {
      return [];
    }

    final resultLines = resultContent.split('\n');

    // Use Sets for O(1) lookup instead of O(n) list iteration
    final oldSet = oldString.split('\n').map((l) => l.trim()).toSet();
    final newSet = newString.split('\n').map((l) => l.trim()).toSet();

    for (final line in resultLines) {
      // Skip non-content lines (using pre-compiled regex)
      if (line.isEmpty || !_lineValidationRegex.hasMatch(line)) {
        continue;
      }

      // Parse line number and content (using pre-compiled regex)
      final match = _lineParseRegex.firstMatch(line);
      if (match != null) {
        final lineNumber = int.tryParse(match.group(1)!);
        final content = match.group(2)!;
        final trimmedContent = content.trim();

        // Determine if this line was part of the change
        DiffLineType lineType = DiffLineType.unchanged;

        // O(1) Set lookups instead of O(n) list iteration
        bool isInNew = newSet.contains(trimmedContent);
        bool isInOld = oldSet.contains(trimmedContent);

        if (isInNew && !isInOld) {
          // Line is in new but not old = added
          lineType = DiffLineType.added;
        } else if (!isInNew && isInOld) {
          // Line is in old but not new = removed (shouldn't normally appear in cat -n output)
          lineType = DiffLineType.removed;
        } else if (isInNew && isInOld) {
          // Line is in both = unchanged
          lineType = DiffLineType.unchanged;
        }

        lines.add(DiffLine(lineNumber: lineNumber, type: lineType, content: content));
      }
    }

    return lines;
  }
}
