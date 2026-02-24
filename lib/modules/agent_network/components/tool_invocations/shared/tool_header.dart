import 'package:agent_sdk/agent_sdk.dart';
import 'package:nocterm/nocterm.dart';
import 'package:path/path.dart' as p;
import 'package:vide_cli/theme/theme.dart';

/// Renders the standard tool header: ● ToolName → param
class ToolHeader extends StatelessComponent {
  final AgentToolInvocation invocation;
  final String workingDirectory;
  final Color? statusColor;

  const ToolHeader({
    required this.invocation,
    required this.workingDirectory,
    this.statusColor,
    super.key,
  });

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    final dim = theme.base.onSurface.withOpacity(0.5);
    final effectiveStatusColor = statusColor ?? getStatusColor(invocation, theme);

    return Row(
      children: [
        Text('● ', style: TextStyle(color: effectiveStatusColor)),
        Text(
          invocation.displayName,
          style: TextStyle(color: dim, fontWeight: FontWeight.bold),
        ),
        if (invocation.parameters.isNotEmpty) ...[
          Text(
            ' → ',
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

  String _getParameterValue() {
    if (invocation is AgentFileOperationToolInvocation) {
      return formatFilePath(
        (invocation as AgentFileOperationToolInvocation).filePath,
        workingDirectory,
      );
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

  /// Returns the status color based on the invocation's result state.
  static Color getStatusColor(
    AgentToolInvocation invocation,
    VideThemeData theme,
  ) {
    if (!invocation.hasResult) return theme.status.inProgress;
    if (invocation.isError) return theme.status.error;
    return theme.status.completed;
  }

  /// Formats a file path relative to the working directory when shorter.
  static String formatFilePath(String filePath, String workingDirectory) {
    if (workingDirectory.isEmpty) return filePath;

    try {
      final relative = p.relative(filePath, from: workingDirectory);
      return relative.length < filePath.length ? relative : filePath;
    } catch (_) {
      return filePath;
    }
  }
}
