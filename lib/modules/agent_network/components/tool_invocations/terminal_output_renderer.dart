import 'package:agent_sdk/agent_sdk.dart';
import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_core/vide_core.dart' show AgentId;
import 'package:path/path.dart' as p;
import 'default_renderer.dart';

/// Renderer for terminal/bash output tool invocations.
/// Shows collapsed preview (last 3 lines) by default, expandable to full output (max 8 lines).
class TerminalOutputRenderer extends StatefulComponent {
  final AgentToolInvocation invocation;
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
  bool isHovered = false;
  final ScrollController _scrollController = ScrollController();

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

    final theme = VideTheme.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1),
      child: MouseRegion(
        onEnter: (_) => setState(() => isHovered = true),
        onExit: (_) => setState(() => isHovered = false),
        child: GestureDetector(
          onTap: () => setState(() => isExpanded = !isExpanded),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_buildHeader(theme), _buildOutput(lines, theme)],
          ),
        ),
      ),
    );
  }

  Component _buildHeader(VideThemeData theme) {
    final statusColor = _getStatusColor(theme);
    final dim = theme.base.onSurface.withOpacity(0.5);
    return Row(
      children: [
        Text('\u25cf ', style: TextStyle(color: statusColor)),
        Text(
          component.invocation.displayName,
          style: TextStyle(color: dim, fontWeight: FontWeight.bold),
        ),
        if (component.invocation.parameters.isNotEmpty) ...[
          Text(
            ' \u2192 ',
            style: TextStyle(color: theme.base.onSurface.withOpacity(0.25)),
          ),
          Flexible(
            child: Text(
              _getParameterValue(),
              style: TextStyle(color: dim),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }

  Component _buildOutput(List<String> lines, VideThemeData theme) {
    // Show last 3 lines when collapsed (so user sees most recent output)
    final displayLines = isExpanded
        ? lines
        : (lines.length > 3 ? lines.sublist(lines.length - 3) : lines);
    final hasMore = lines.length > 3;

    final bgColor = isHovered
        ? theme.base.surface.withOpacity(0.8)
        : theme.base.surface.withOpacity(0.5);
    final dimText = theme.base.onSurface.withOpacity(0.4);

    return Container(
      decoration: BoxDecoration(color: bgColor),
      padding: EdgeInsets.all(1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Render output lines
          if (isExpanded && lines.length > 8)
            // Scrollable container for expanded state with many lines
            Container(
              constraints: BoxConstraints(maxHeight: 8),
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                thumbColor: theme.base.onSurface.withOpacity(0.3),
                trackColor: bgColor,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final line in displayLines) _buildLine(line, theme),
                    ],
                  ),
                ),
              ),
            )
          else
            // Direct render for collapsed or small expanded state
            for (final line in displayLines) _buildLine(line, theme),

          // Show line count if collapsed with more lines
          if (!isExpanded && hasMore)
            Text('(${lines.length} total)', style: TextStyle(color: dimText)),

          // Show line count if expanded and exceeds 8 lines
          if (isExpanded && lines.length > 8)
            Text('(${lines.length} total)', style: TextStyle(color: dimText)),
        ],
      ),
    );
  }

  Component _buildLine(String line, VideThemeData theme) {
    return Text(
      _stripAnsi(line),
      style: TextStyle(color: theme.base.onSurface.withOpacity(0.7)),
    );
  }

  Color _getStatusColor(VideThemeData theme) {
    if (!component.invocation.hasResult) {
      return theme.status.inProgress;
    }
    return component.invocation.isError
        ? theme.status.error
        : theme.status.completed;
  }

  String _getParameterValue() {
    final invocation = component.invocation;
    if (invocation is AgentFileOperationToolInvocation) {
      return _formatFilePath(invocation.filePath);
    }

    final params = invocation.parameters;
    if (params.isEmpty) return '';

    for (final key in ['pattern', 'command', 'query', 'url']) {
      if (params.containsKey(key)) {
        return params[key].toString();
      }
    }

    return params.values.first.toString();
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
