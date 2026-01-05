import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/modules/setup/dart_mcp_manager.dart';

/// Dialog to help users set up Dart MCP server
class DartMcpSetupDialog extends StatelessComponent {
  const DartMcpSetupDialog({super.key, required this.status});

  final DartMcpStatus status;

  @override
  Component build(BuildContext context) {
    return Center(
      child: Container(
        width: 80,
        padding: EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.black,
          border: BoxBorder.all(color: Colors.cyan),
        ),
        child: _buildContent(context),
      ),
    );
  }

  Component _buildContent(BuildContext context) {
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
              color: Colors.cyan,
            ),
          ),
          SizedBox(height: 1),
          _buildStatusSection(),
          SizedBox(height: 1),
          if (status.canBeEnabled && !status.isMcpConfigured) ...[
            _buildSetupInstructions(),
            SizedBox(height: 1),
          ],
          Text('Press any key to close', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Component _buildStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Status:', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 1),
        _statusLine('Dart SDK', status.isDartSdkAvailable),
        _statusLine('Dart Project', status.isDartProjectDetected),
        _statusLine('MCP Configured', status.isMcpConfigured),
      ],
    );
  }

  Component _statusLine(String label, bool isOk) {
    return Row(
      children: [
        Text(
          isOk ? '✓' : '✗',
          style: TextStyle(
            color: isOk ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(width: 1),
        Text(label),
      ],
    );
  }

  Component _buildSetupInstructions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Setup Instructions:',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.yellow),
        ),
        SizedBox(height: 1),
        Text('To enable Dart MCP, run one of these commands:'),
        SizedBox(height: 1),
        Container(
          padding: EdgeInsets.all(1),
          decoration: BoxDecoration(color: Color(0xFF1E1E1E)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '# User-wide (recommended):',
                style: TextStyle(color: Colors.grey),
              ),
              Text(
                DartMcpManager.getUserScopeCommand(),
                style: TextStyle(color: Colors.green),
              ),
              SizedBox(height: 1),
              Text(
                '# Project-only (team shared):',
                style: TextStyle(color: Colors.grey),
              ),
              Text(
                DartMcpManager.getProjectScopeCommand(),
                style: TextStyle(color: Colors.green),
              ),
            ],
          ),
        ),
        SizedBox(height: 1),
        Text(
          'After running the command, restart Claude Code.',
          style: TextStyle(color: Colors.yellow),
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
