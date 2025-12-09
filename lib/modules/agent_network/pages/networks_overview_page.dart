import 'dart:io';
import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:claude_api/claude_api.dart';
import 'package:parott/modules/agent_network/network_execution_page.dart';
import 'package:parott/modules/agent_network/pages/networks_list_page.dart';
import 'package:parott/modules/agent_network/service/agent_network_manager.dart';
import 'package:parott/modules/agent_network/state/agent_networks_state_notifier.dart';
import 'package:parott/components/attachment_text_field.dart';
import 'package:parott/utils/project_detector.dart';
import 'package:parott/modules/setup/dart_mcp_manager.dart';
import 'package:path/path.dart' as path;

class NetworksOverviewPage extends StatefulComponent {
  const NetworksOverviewPage({super.key});

  @override
  State<NetworksOverviewPage> createState() => _NetworksOverviewPageState();
}

class _NetworksOverviewPageState extends State<NetworksOverviewPage> {
  ProjectType? projectType;
  DartMcpStatus? dartMcpStatus;

  @override
  void initState() {
    super.initState();
    _loadProjectInfo();
  }

  Future<void> _loadProjectInfo() async {
    final currentDir = Directory.current.path;
    final detectedType = ProjectDetector.detectProjectType(currentDir);

    DartMcpStatus? mcpStatus;
    if (detectedType == ProjectType.dart ||
        detectedType == ProjectType.flutter ||
        detectedType == ProjectType.nocterm) {
      mcpStatus = await DartMcpManager.getStatus(currentDir);
    }

    if (mounted) {
      setState(() {
        projectType = detectedType;
        dartMcpStatus = mcpStatus;
      });
    }
  }

  void _handleSubmit(Message message) async {
    final goal = message.text;

    // Start a new agent network with the goal
    final network = await context.read(agentNetworkManagerProvider.notifier).startNew(goal);

    // Update the networks list
    context.read(agentNetworksStateNotifierProvider.notifier).upsertNetwork(network);

    // Navigate to the execution page
    await NetworkExecutionPage.push(context, network.id);
  }

  @override
  Component build(BuildContext context) {
    // Get current directory name
    final currentDir = Directory.current.path;
    final dirName = path.basename(currentDir);

    return Focusable(
      focused: true,
      onKeyEvent: (event) {
        if (event.logicalKey == LogicalKey.tab) {
          NetworksListPage.push(context);
          return true;
        }
        return false;
      },
      child: Center(
        child: Container(
          padding: EdgeInsets.all(2),
          constraints: BoxConstraints(maxWidth: 120, maxHeight: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                dirName,
                style: TextStyle(decoration: TextDecoration.underline, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 1),
              // Project info badges
              if (projectType != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ProjectTypeBadge(projectType: projectType!),
                    if (dartMcpStatus != null) ...[SizedBox(width: 2), _McpStatusBadge(status: dartMcpStatus!)],
                  ],
                ),
                const SizedBox(height: 1),
              ],
              Container(
                child: AttachmentTextField(
                  focused: true,
                  placeholder: 'Describe your goal (you can attach images)',
                  onSubmit: _handleSubmit,
                ),
                padding: EdgeInsets.all(1),
              ),
              const SizedBox(height: 2),
              Text('Tab: past networks & settings | Enter: start', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Project type badge component
class _ProjectTypeBadge extends StatelessComponent {
  const _ProjectTypeBadge({required this.projectType});

  final ProjectType projectType;

  @override
  Component build(BuildContext context) {
    String label;
    Color bgColor;

    switch (projectType) {
      case ProjectType.flutter:
        label = 'Flutter';
        bgColor = Color(0xFF02569B); // Flutter blue
        break;
      case ProjectType.dart:
        label = 'Dart';
        bgColor = Color(0xFF0175C2); // Dart blue
        break;
      case ProjectType.nocterm:
        label = 'Nocterm';
        bgColor = Color(0xFF9B30FF); // Purple
        break;
      case ProjectType.unknown:
        label = 'Unknown';
        bgColor = Colors.grey;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(color: bgColor),
      child: Text(
        label,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// MCP status badge component
class _McpStatusBadge extends StatelessComponent {
  const _McpStatusBadge({required this.status});

  final DartMcpStatus status;

  @override
  Component build(BuildContext context) {
    Color bgColor;
    if (status.isFullyEnabled) {
      bgColor = Colors.green;
    } else if (status.canBeEnabled && !status.isMcpConfigured) {
      bgColor = Colors.yellow;
    } else {
      bgColor = Colors.red;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(color: Colors.grey),
          child: Text('Dart MCP', style: TextStyle(color: Colors.white)),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(color: bgColor),
          child: Text(
            status.statusMessage,
            style: TextStyle(
              color: bgColor == Colors.yellow ? Colors.black : Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
