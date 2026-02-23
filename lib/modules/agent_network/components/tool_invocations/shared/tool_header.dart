import 'package:agent_sdk/agent_sdk.dart';
import 'package:nocterm/nocterm.dart';
import 'package:path/path.dart' as p;
import 'package:vide_cli/theme/theme.dart';

/// Shared utilities for tool invocation renderers.
///
/// Provides the common header row (● ToolName → param), parameter extraction,
/// and file path formatting used by [DefaultRenderer], [DiffRenderer], and
/// [TerminalOutputRenderer].
mixin ToolHeaderMixin on StatefulComponent {
  AgentToolInvocation get invocation;
  String get workingDirectory;

  /// Builds the standard tool header: ● ToolName → param
  Component buildToolHeader(
    BuildContext context, {
    required Color statusColor,
  }) {
    final theme = VideTheme.of(context);
    final dim = theme.base.onSurface.withOpacity(0.5);

    return Row(
      children: [
        Text('● ', style: TextStyle(color: statusColor)),
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
              getParameterValue(),
              style: TextStyle(color: dim),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }

  /// Returns the most meaningful parameter value for compact display.
  String getParameterValue() {
    if (invocation is AgentFileOperationToolInvocation) {
      return formatFilePath(
        (invocation as AgentFileOperationToolInvocation).filePath,
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

  /// Formats a file path relative to the working directory when shorter.
  String formatFilePath(String filePath) {
    if (workingDirectory.isEmpty) return filePath;

    try {
      final relative = p.relative(filePath, from: workingDirectory);
      return relative.length < filePath.length ? relative : filePath;
    } catch (_) {
      return filePath;
    }
  }

  /// Returns the status color based on the invocation's result state.
  Color getStatusColor(VideThemeData theme) {
    if (!invocation.hasResult) return theme.status.inProgress;
    if (invocation.isError) return theme.status.error;
    return theme.status.completed;
  }
}
