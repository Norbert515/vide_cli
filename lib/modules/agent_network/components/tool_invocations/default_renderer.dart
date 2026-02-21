import 'package:agent_sdk/agent_sdk.dart';
import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_core/vide_core.dart' show AgentId;
import 'package:path/path.dart' as p;

/// Default renderer for tool invocations.
/// Renders a compact single-line: ● ToolName → param
class DefaultRenderer extends StatefulComponent {
  final AgentToolInvocation invocation;
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

    // Determine status color
    final Color statusColor;
    if (!hasResult) {
      statusColor = theme.status.inProgress;
    } else if (isError) {
      statusColor = theme.status.error;
    } else {
      statusColor = theme.status.completed;
    }

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
            style: TextStyle(
              color: theme.base.onSurface.withOpacity(0.25),
            ),
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

  /// Returns the most meaningful parameter value for compact display.
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

    final value = params.values.first;
    return value.toString();
  }

  String _formatFilePath(String filePath) {
    if (component.workingDirectory.isEmpty) return filePath;

    try {
      final relative = p.relative(filePath, from: component.workingDirectory);
      return relative.length < filePath.length ? relative : filePath;
    } catch (e) {
      return filePath;
    }
  }
}
