import 'package:agent_sdk/agent_sdk.dart';
import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_core/vide_core.dart' show AgentId;
import 'shared/tool_header.dart';

/// Default renderer for tool invocations.
/// Renders a compact single-line: ● ToolName → param
class DefaultRenderer extends StatefulComponent with ToolHeaderMixin {
  @override
  final AgentToolInvocation invocation;
  @override
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
    return component.buildToolHeader(
      context,
      statusColor: component.getStatusColor(theme),
    );
  }
}
