import 'dart:async';
import 'package:claude_api/claude_api.dart';
import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_cli/modules/agent_network/models/agent_metadata.dart';
import 'package:vide_cli/modules/agent_network/models/agent_status.dart';
import 'package:vide_cli/modules/agent_network/service/claude_manager.dart';
import 'package:vide_cli/modules/agent_network/state/agent_status_manager.dart';

class RunningAgentsBar extends StatelessComponent {
  const RunningAgentsBar({super.key, required this.agents, this.selectedIndex = 0});

  final List<AgentMetadata> agents;
  final int selectedIndex;

  /// Calculate the display width of an agent item (status indicator + name + padding).
  int _calculateAgentWidth(AgentMetadata agent) {
    final displayName = agent.taskName != null && agent.taskName!.isNotEmpty
        ? '${agent.name} - ${agent.taskName}'
        : agent.name;
    // Status indicator: 3 chars (1 char + 2 horizontal padding)
    // Name container: displayName.length + 2 horizontal padding
    // Right padding: 1
    return 3 + displayName.length + 2 + 1;
  }

  @override
  Component build(BuildContext context) {
    if (agents.isEmpty) {
      return Container();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final rows = <List<int>>[];
        var currentRow = <int>[];
        var currentRowWidth = 0;

        for (int i = 0; i < agents.length; i++) {
          final agentWidth = _calculateAgentWidth(agents[i]);

          // Check if this agent fits in the current row
          if (currentRowWidth + agentWidth <= maxWidth || currentRow.isEmpty) {
            currentRow.add(i);
            currentRowWidth += agentWidth;
          } else {
            // Start a new row
            rows.add(currentRow);
            currentRow = [i];
            currentRowWidth = agentWidth;
          }
        }

        // Add the last row if not empty
        if (currentRow.isNotEmpty) {
          rows.add(currentRow);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final row in rows)
              Row(
                children: [
                  for (final i in row)
                    Expanded(
                      child: _RunningAgentBarItem(
                        agent: agents[i],
                        isSelected: i == selectedIndex,
                      ),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _RunningAgentBarItem extends StatefulComponent {
  final AgentMetadata agent;
  final bool isSelected;

  const _RunningAgentBarItem({required this.agent, required this.isSelected});

  @override
  State<_RunningAgentBarItem> createState() => _RunningAgentBarItemState();
}

class _RunningAgentBarItemState extends State<_RunningAgentBarItem> {
  static const _spinnerFrames = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];

  Timer? _spinnerTimer;
  int _spinnerIndex = 0;

  @override
  void initState() {
    super.initState();
    _startSpinner();
  }

  void _startSpinner() {
    _spinnerTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      setState(() {
        _spinnerIndex = (_spinnerIndex + 1) % _spinnerFrames.length;
      });
    });
  }

  @override
  void dispose() {
    _spinnerTimer?.cancel();
    super.dispose();
  }

  String _getStatusIndicator(AgentStatus status) {
    return switch (status) {
      AgentStatus.working => _spinnerFrames[_spinnerIndex],
      AgentStatus.waitingForAgent => '…',
      AgentStatus.waitingForUser => '?',
      AgentStatus.idle => '✓',
    };
  }

  Color _getIndicatorColor(AgentStatus status) {
    return switch (status) {
      AgentStatus.working => Colors.cyan,
      AgentStatus.waitingForAgent => Colors.yellow,
      AgentStatus.waitingForUser => Colors.magenta,
      AgentStatus.idle => Colors.green,
    };
  }

  Color _getIndicatorTextColor(AgentStatus status) {
    return switch (status) {
      AgentStatus.waitingForAgent => Colors.black,
      _ => Colors.white,
    };
  }

  String _buildAgentDisplayName(AgentMetadata agent) {
    if (agent.taskName != null && agent.taskName!.isNotEmpty) {
      return '${agent.name} - ${agent.taskName}';
    }
    return agent.name;
  }

  /// Infer the actual status based on both explicit status and conversation state.
  /// This provides safeguards against agents forgetting to call setAgentStatus.
  AgentStatus _inferActualStatus(AgentStatus explicitStatus, Conversation? conversation) {
    if (conversation == null) {
      return explicitStatus;
    }

    // If conversation is processing, agent is definitely working
    if (conversation.isProcessing) {
      return AgentStatus.working;
    }

    // If conversation is idle but agent claims to be working, override to idle
    // This handles cases where agent forgot to call setAgentStatus("idle")
    if (conversation.state == ConversationState.idle && explicitStatus == AgentStatus.working) {
      return AgentStatus.idle;
    }

    // Otherwise trust the explicit status
    return explicitStatus;
  }

  @override
  Component build(BuildContext context) {
    final explicitStatus = context.watch(agentStatusProvider(component.agent.id));

    // Get the claude client to check conversation state
    final client = context.watch(claudeProvider(component.agent.id));
    final conversation = client?.currentConversation;

    // Infer actual status - override if conversation says we're idle but status says working
    final status = _inferActualStatus(explicitStatus, conversation);

    final indicatorColor = _getIndicatorColor(status);
    final indicatorTextColor = _getIndicatorTextColor(status);
    final statusIndicator = _getStatusIndicator(status);

    return Padding(
      padding: EdgeInsets.only(right: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(color: indicatorColor),
            child: Text(statusIndicator, style: TextStyle(color: indicatorTextColor)),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(color: Colors.grey),
            child: Text(
              _buildAgentDisplayName(component.agent),
              style: TextStyle(
                color: Colors.white,
                fontWeight: component.isSelected ? FontWeight.bold : null,
                decoration: component.isSelected ? TextDecoration.underline : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
