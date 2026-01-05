import 'package:nocterm/nocterm.dart';
import 'package:claude_sdk/claude_sdk.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_core/vide_core.dart';
import 'package:path/path.dart' as p;

/// Default renderer for tool invocations.
/// Handles all tools that don't have specialized renderers.
class DefaultRenderer extends StatefulComponent {
  final ToolInvocation invocation;
  final String workingDirectory;
  final String executionId;
  final AgentId agentId;

  const DefaultRenderer({
    required this.invocation,
    required this.workingDirectory,
    required this.executionId,
    required this.agentId,
    super.key,
  });

  @override
  State<DefaultRenderer> createState() => _DefaultRendererState();
}

class _DefaultRendererState extends State<DefaultRenderer> {
  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    final hasResult = component.invocation.hasResult;

    final isError = component.invocation.isError;

    // Determine status color and indicator
    final Color statusColor;
    final String statusIndicator;

    if (!hasResult) {
      // Pending or in-progress (no result yet)
      statusColor = theme.status.inProgress;
      statusIndicator = '●';
    } else if (isError) {
      // Error, denied, or blocked by hook
      statusColor = theme.status.error;
      statusIndicator = '●';
    } else {
      // Successful completion
      statusColor = theme.status.completed;
      statusIndicator = '●';
    }

    final textColor = theme.base.onSurface;

    return Container(
      padding: EdgeInsets.only(bottom: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tool header with name and params
          Row(
            children: [
              // Status indicator
              Text(statusIndicator, style: TextStyle(color: statusColor)),
              SizedBox(width: 1),
              // Tool name
              Text(
                component.invocation.displayName,
                style: TextStyle(color: textColor),
              ),
              if (component.invocation.parameters.isNotEmpty) ...[
                Flexible(
                  child: Text(
                    '(${_getParameterPreview()}',
                    style: TextStyle(
                      color: textColor.withOpacity(TextOpacity.tertiary),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                Text(
                  ')',
                  style: TextStyle(
                    color: textColor.withOpacity(TextOpacity.tertiary),
                  ),
                ),
              ],
            ],
          ),

          // Result content
          if (hasResult && _shouldShowResultPreview())
            Container(
              padding: EdgeInsets.only(left: 2),
              child: _buildResultView(theme),
            ),
        ],
      ),
    );
  }

  bool _shouldShowResultPreview() {
    // Don't show result preview for Read and Grep tools
    return component.invocation.toolName != 'Read' &&
        component.invocation.toolName != 'Grep';
  }

  Component _buildResultView(VideThemeData theme) {
    final preview = _getResultPreview();
    final textColor = theme.base.onSurface;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '⎿  ',
          style: TextStyle(color: textColor.withOpacity(TextOpacity.secondary)),
        ),
        Expanded(
          child: Text(
            preview,
            style: TextStyle(
              color: textColor.withOpacity(TextOpacity.secondary),
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
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

  String _getResultPreview() {
    final content = component.invocation.resultContent ?? '';
    if (content.isEmpty) return 'Empty result';

    // For Read and Grep tools, don't show any preview
    if (component.invocation.toolName == 'Read' ||
        component.invocation.toolName == 'Grep') {
      return '';
    }

    final lines = content.split('\n');
    final firstLine = lines.first.trim();

    if (firstLine.isEmpty && lines.length > 1) {
      return lines.firstWhere(
        (line) => line.trim().isNotEmpty,
        orElse: () => 'Empty result',
      );
    }

    String preview = firstLine;
    if (lines.length > 1) {
      preview += ' (${lines.length} lines total)';
    }

    return preview;
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
