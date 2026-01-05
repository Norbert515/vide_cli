import 'package:nocterm/nocterm.dart';
import 'package:claude_sdk/claude_sdk.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_core/vide_core.dart';
import 'package:path/path.dart' as p;
import 'default_renderer.dart';

/// Renderer for terminal/bash output tool invocations.
/// Shows collapsed preview (last 3 lines) by default, expandable to full output (max 8 lines).
class TerminalOutputRenderer extends StatefulComponent {
  final ToolInvocation invocation;
  final String workingDirectory;
  final String executionId;
  final AgentId agentId;

  const TerminalOutputRenderer({
    required this.invocation,
    required this.workingDirectory,
    required this.executionId,
    required this.agentId,
    super.key,
  });

  @override
  State<TerminalOutputRenderer> createState() => _TerminalOutputRendererState();
}

class _TerminalOutputRendererState extends State<TerminalOutputRenderer> {
  bool isExpanded = false;

  /// Regex to match ANSI escape sequences (color codes, etc.)
  static final _ansiRegex = RegExp(r'\x1b\[[0-9;]*m');

  /// Strip ANSI escape codes from text to prevent incorrect width calculations
  String _stripAnsi(String text) => text.replaceAll(_ansiRegex, '');

  /// Process carriage returns to simulate terminal behavior.
  /// When a line contains \r, only the text after the last \r is shown
  /// (simulating how terminals overwrite the current line).
  String _processCarriageReturns(String text) {
    // Split by newlines first, then process each line for carriage returns
    final lines = text.split('\n');
    final processedLines = <String>[];

    for (final line in lines) {
      if (line.contains('\r')) {
        // Take only the content after the last carriage return
        final segments = line.split('\r');
        final lastSegment = segments.last;
        if (lastSegment.trim().isNotEmpty) {
          processedLines.add(lastSegment);
        }
      } else if (line.trim().isNotEmpty) {
        processedLines.add(line);
      }
    }

    return processedLines.join('\n');
  }

  @override
  Component build(BuildContext context) {
    // Fallback to DefaultRenderer if no result or error
    if (!component.invocation.hasResult || component.invocation.isError) {
      return DefaultRenderer(
        invocation: component.invocation,
        workingDirectory: component.workingDirectory,
        executionId: component.executionId,
        agentId: component.agentId,
      );
    }

    // Parse output - process carriage returns first to handle terminal overwrites
    final resultContent = component.invocation.resultContent ?? '';
    final processedContent = _processCarriageReturns(resultContent);
    final lines = processedContent
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();

    // If no lines, fallback to default
    if (lines.isEmpty) {
      return DefaultRenderer(
        invocation: component.invocation,
        workingDirectory: component.workingDirectory,
        executionId: component.executionId,
        agentId: component.agentId,
      );
    }

    return GestureDetector(
      onTap: () => setState(() => isExpanded = !isExpanded),
      child: Container(
        padding: EdgeInsets.only(bottom: 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tool header with name and params
            _buildHeader(),
            // Terminal output
            _buildOutput(lines),
          ],
        ),
      ),
    );
  }

  Component _buildHeader() {
    final statusColor = _getStatusColor();
    return Row(
      children: [
        // Status indicator
        Text('●', style: TextStyle(color: statusColor)),
        SizedBox(width: 1),
        // Tool name
        Text(
          component.invocation.displayName,
          style: TextStyle(color: Colors.white),
        ),
        if (component.invocation.parameters.isNotEmpty) ...[
          Flexible(
            child: Text(
              '(${_getParameterPreview()}',
              style: TextStyle(
                color: Colors.white.withOpacity(TextOpacity.tertiary),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          Text(
            ')',
            style: TextStyle(
              color: Colors.white.withOpacity(TextOpacity.tertiary),
            ),
          ),
        ],
      ],
    );
  }

  Component _buildOutput(List<String> lines) {
    // Show last 3 lines when collapsed (so user sees most recent output)
    final displayLines = isExpanded
        ? lines
        : (lines.length > 3 ? lines.sublist(lines.length - 3) : lines);
    final hasMore = lines.length > 3;

    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF1E1E1E), // Dark terminal background
      ),
      padding: EdgeInsets.all(1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Render output lines
          if (isExpanded && lines.length > 8)
            // Scrollable container for expanded state with many lines
            Container(
              constraints: BoxConstraints(maxHeight: 8),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [for (final line in displayLines) _buildLine(line)],
                ),
              ),
            )
          else
            // Direct render for collapsed or small expanded state
            for (final line in displayLines) _buildLine(line),

          // Show line count if collapsed with more lines
          if (!isExpanded && hasMore)
            Text(
              '(${lines.length} total)',
              style: TextStyle(color: Colors.white.withOpacity(0.4)),
            ),

          // Show line count if expanded and exceeds 8 lines
          if (isExpanded && lines.length > 8)
            Text(
              '(${lines.length} total)',
              style: TextStyle(color: Colors.white.withOpacity(0.4)),
            ),
        ],
      ),
    );
  }

  Component _buildLine(String line) {
    return Text(
      _stripAnsi(line),
      style: TextStyle(
        color: Color(0xFFD4D4D4), // Terminal text color
      ),
    );
  }

  Color _getStatusColor() {
    if (!component.invocation.hasResult) {
      return Color(0xFFE5C07B); // Yellow - pending
    }
    return component.invocation.isError
        ? Color(0xFFE06C75) // Red - error
        : Color(0xFF98C379); // Green - success
  }

  String _getParameterPreview() {
    final params = component.invocation.parameters;
    if (params.isEmpty) return '';

    final firstKey = params.keys.first;
    final value = params[firstKey];
    String valueStr = value.toString();

    // Format file paths
    if (firstKey == 'file_path') {
      // Use typed invocation for file path formatting if available
      if (component.invocation is FileOperationToolInvocation) {
        final typed = component.invocation as FileOperationToolInvocation;
        valueStr = typed.getRelativePath(component.workingDirectory);
      } else {
        valueStr = _formatFilePath(valueStr);
      }
    }

    return '$firstKey: $valueStr';
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
}
