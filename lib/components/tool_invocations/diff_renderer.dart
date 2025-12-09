import 'package:nocterm/nocterm.dart';
import 'package:claude_api/claude_api.dart';
import 'package:parott/modules/agent_network/models/agent_id.dart';
import 'package:path/path.dart' as p;
import 'shared/code_diff.dart';
import 'default_renderer.dart';
import '../../utils/syntax_highlighter.dart';

/// Renderer for Write/Edit/MultiEdit tool invocations with successful results.
/// Shows code diffs with syntax highlighting.
class DiffRenderer extends StatefulComponent {
  final ToolInvocation invocation;
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
  late final List<DiffLine> _cachedDiffLines;
  late final String? _cachedFormattedPath;
  late final bool _shouldUseFallback;

  @override
  void initState() {
    super.initState();

    // Get the file path from typed invocation
    if (component.invocation is WriteToolInvocation) {
      final typed = component.invocation as WriteToolInvocation;
      _cachedFormattedPath = typed.getRelativePath(component.workingDirectory);
    } else if (component.invocation is EditToolInvocation) {
      final typed = component.invocation as EditToolInvocation;
      _cachedFormattedPath = typed.getRelativePath(component.workingDirectory);
    } else {
      _cachedFormattedPath = null;
    }

    // Create diff lines
    _cachedDiffLines = _createDiffLines();

    // Check if we should use fallback
    _shouldUseFallback = _cachedDiffLines.isEmpty;
  }

  @override
  Component build(BuildContext context) {
    // If no diff lines could be created, fall back to default renderer
    if (_shouldUseFallback) {
      return DefaultRenderer(
        invocation: component.invocation,
        workingDirectory: component.workingDirectory,
        executionId: component.executionId,
        agentId: component.agentId,
      );
    }

    // Determine status color
    final statusColor = component.invocation.isError ? Colors.red : Colors.green;
    final statusIndicator = component.invocation.isError ? '●' : '●';

    return Container(
      padding: EdgeInsets.only(bottom: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tool header
          _buildHeader(statusColor, statusIndicator),

          // Diff view
          Container(
            padding: EdgeInsets.only(left: 2),
            child: CodeDiff(fileName: _cachedFormattedPath, lines: _cachedDiffLines),
          ),
        ],
      ),
    );
  }

  Component _buildHeader(Color statusColor, String statusIndicator) {
    final params = component.invocation.parameters;

    return Row(
      children: [
        // Status indicator
        Text(statusIndicator, style: TextStyle(color: statusColor)),
        SizedBox(width: 1),
        // Tool name
        Text(component.invocation.displayName, style: TextStyle(color: Colors.white)),
        if (params.isNotEmpty) ...[
          Flexible(
            child: Text(
              '(${_getParameterPreview()}',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          Text(')', style: TextStyle(color: Colors.white.withOpacity(0.5))),
        ],
      ],
    );
  }

  String _formatFilePath(String filePath) {
    if (component.workingDirectory.isEmpty) return filePath;

    try {
      final relative = p.relative(filePath, from: component.workingDirectory);
      // Only use relative if it's actually shorter (file is within working dir)
      return relative.length < filePath.length ? relative : filePath;
    } catch (e) {
      return filePath; // Fallback on error
    }
  }

  List<DiffLine> _createDiffLines() {
    if (component.invocation is WriteToolInvocation) {
      final typed = component.invocation as WriteToolInvocation;
      final language = SyntaxHighlighter.detectLanguage(typed.filePath);
      return _parseWriteToolResult(typed, language);
    } else if (component.invocation is EditToolInvocation) {
      final typed = component.invocation as EditToolInvocation;
      final language = SyntaxHighlighter.detectLanguage(typed.filePath);
      return _parseEditResult(typed, language);
    }

    return [];
  }

  List<DiffLine> _parseWriteToolResult(WriteToolInvocation invocation, String? language) {
    // For Write tool, show all lines as added
    final lines = invocation.content.split('\n');
    return List.generate(
      lines.length,
      (i) => DiffLine(lineNumber: i + 1, type: DiffLineType.added, content: lines[i], language: language),
    );
  }

  List<DiffLine> _parseEditResult(EditToolInvocation invocation, String? language) {
    final lines = <DiffLine>[];
    final resultContent = component.invocation.resultContent ?? '';

    // Only process if result contains cat -n output
    if (!resultContent.contains('cat -n')) {
      return [];
    }

    final resultLines = resultContent.split('\n');

    // Split old and new strings into lines for comparison
    final oldLines = invocation.oldString.split('\n');
    final newLines = invocation.newString.split('\n');

    for (final line in resultLines) {
      // Skip non-content lines
      if (line.isEmpty || !RegExp(r'^\s*\d+→').hasMatch(line)) {
        continue;
      }

      // Parse line number and content
      final match = RegExp(r'^\s*(\d+)→(.*)').firstMatch(line);
      if (match != null) {
        final lineNumber = int.tryParse(match.group(1)!);
        final content = match.group(2)!;

        // Determine if this line was part of the change
        DiffLineType lineType = DiffLineType.unchanged;

        // Check if content matches any line in newString (added/modified)
        bool isInNew = newLines.any((newLine) => content.trim() == newLine.trim());
        // Check if content matches any line in oldString (removed/modified)
        bool isInOld = oldLines.any((oldLine) => content.trim() == oldLine.trim());

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

        lines.add(DiffLine(lineNumber: lineNumber, type: lineType, content: content, language: language));
      }
    }

    return lines;
  }

  String _getParameterPreview() {
    final params = component.invocation.parameters;
    if (params.isEmpty) return '';

    final firstKey = params.keys.first;
    final value = params[firstKey];
    String valueStr = value.toString();

    // Format file paths
    if (firstKey == 'file_path') {
      valueStr = _formatFilePath(valueStr);
    }

    return '$firstKey: $valueStr';
  }
}
