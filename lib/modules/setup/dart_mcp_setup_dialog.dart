import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_cli/modules/setup/dart_mcp_manager.dart';

/// Dialog to help users set up Dart MCP server
class DartMcpSetupDialog extends StatelessComponent {
  const DartMcpSetupDialog({super.key, required this.status});

  final DartMcpStatus status;

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    return Center(
      child: Container(
        width: 80,
        padding: EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: theme.base.surface,
          border: BoxBorder.all(color: theme.base.primary),
        ),
        child: _buildContent(context, theme),
      ),
    );
  }

  Component _buildContent(BuildContext context, VideThemeData theme) {
    return KeyboardListener(
      autofocus: true,
      onKeyEvent: (key) {
        Navigator.of(context).pop();
        return true;
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dart MCP Setup',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
              color: theme.base.primary,
            ),
          ),
          SizedBox(height: 1),
          _buildStatusSection(theme),
          SizedBox(height: 1),
          if (status.canBeEnabled && !status.isMcpConfigured) ...[
            _buildSetupInstructions(theme),
            SizedBox(height: 1),
          ],
          Text('Press any key to close', style: TextStyle(color: theme.base.outline)),
        ],
      ),
    );
  }

  Component _buildStatusSection(VideThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Status:', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 1),
        _statusLine('Dart SDK', status.isDartSdkAvailable, theme),
        _statusLine('Dart Project', status.isDartProjectDetected, theme),
        _statusLine('MCP Configured', status.isMcpConfigured, theme),
      ],
    );
  }

  Component _statusLine(String label, bool isOk, VideThemeData theme) {
    return Row(
      children: [
        Text(
          isOk ? '✓' : '✗',
          style: TextStyle(
            color: isOk ? theme.base.success : theme.base.error,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(width: 1),
        Text(label),
      ],
    );
  }

  Component _buildSetupInstructions(VideThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Setup Instructions:',
          style: TextStyle(fontWeight: FontWeight.bold, color: theme.base.warning),
        ),
        SizedBox(height: 1),
        Text('To enable Dart MCP, run one of these commands:'),
        SizedBox(height: 1),
        Container(
          padding: EdgeInsets.all(1),
          decoration: BoxDecoration(color: theme.base.background),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '# User-wide (recommended):',
                style: TextStyle(color: theme.base.outline),
              ),
              Text(
                DartMcpManager.getUserScopeCommand(),
                style: TextStyle(color: theme.base.success),
              ),
              SizedBox(height: 1),
              Text(
                '# Project-only (team shared):',
                style: TextStyle(color: theme.base.outline),
              ),
              Text(
                DartMcpManager.getProjectScopeCommand(),
                style: TextStyle(color: theme.base.success),
              ),
            ],
          ),
        ),
        SizedBox(height: 1),
        Text(
          'After running the command, restart Claude Code.',
          style: TextStyle(color: theme.base.warning),
        ),
      ],
    );
  }

  static void show(BuildContext context, DartMcpStatus status) {
    Navigator.of(context).push(
      PageRoute(
        builder: (context) => DartMcpSetupDialog(status: status),
        settings: RouteSettings(),
      ),
    );
  }
}
