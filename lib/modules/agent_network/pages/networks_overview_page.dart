import 'dart:io';
import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:claude_api/claude_api.dart';
import 'package:vide_cli/modules/agent_network/network_execution_page.dart';
import 'package:vide_cli/modules/agent_network/pages/networks_list_page.dart';
import 'package:vide_core/vide_core.dart';
import 'package:vide_cli/modules/agent_network/state/agent_networks_state_notifier.dart';
import 'package:vide_cli/components/attachment_text_field.dart';
import 'package:path/path.dart' as path;

class NetworksOverviewPage extends StatefulComponent {
  const NetworksOverviewPage({super.key});

  @override
  State<NetworksOverviewPage> createState() => _NetworksOverviewPageState();
}

class _NetworksOverviewPageState extends State<NetworksOverviewPage> {
  ProjectType? projectType;

  @override
  void initState() {
    super.initState();
    _loadProjectInfo();
  }

  Future<void> _loadProjectInfo() async {
    final currentDir = Directory.current.path;
    final detectedType = ProjectDetector.detectProjectType(currentDir);

    if (mounted) {
      setState(() {
        projectType = detectedType;
      });
    }
  }

  void _handleSubmit(Message message) async {
    // Start a new agent network with the full message (preserves attachments)
    final network = await context.read(agentNetworkManagerProvider.notifier).startNew(message);

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
              // Project info badge
              if (projectType != null) ...[
                _ProjectTypeBadge(projectType: projectType!),
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

