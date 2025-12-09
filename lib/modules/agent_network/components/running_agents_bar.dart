import 'dart:async';
import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:parott/modules/agent_network/models/agent_metadata.dart';
import 'package:parott/modules/agent_network/models/agent_status.dart';
import 'package:parott/modules/agent_network/state/agent_status_manager.dart';

class RunningAgentsBar extends StatelessComponent {
  const RunningAgentsBar({super.key, required this.agents, this.selectedIndex = 0});

  final List<AgentMetadata> agents;
  final int selectedIndex;

  @override
  Component build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < agents.length; i++) _RunningAgentBarItem(agent: agents[i], isSelected: i == selectedIndex),
      ],
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

  @override
  Component build(BuildContext context) {
    final status = context.watch(agentStatusProvider(component.agent.id));
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
              component.agent.name,
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
