import 'dart:async';
import 'package:claude_sdk/claude_sdk.dart' show ClaudeStatus;
import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_core/vide_core.dart';

class RunningAgentsBar extends StatelessComponent {
  const RunningAgentsBar({
    super.key,
    required this.agents,
    this.selectedIndex = 0,
  });

  final List<AgentMetadata> agents;
  final int selectedIndex;

  @override
  Component build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < agents.length; i++)
          _RunningAgentBarItem(
            agent: agents[i],
            isSelected: i == selectedIndex,
          ),
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
  static const _spinnerFrames = [
    '⠋',
    '⠙',
    '⠹',
    '⠸',
    '⠼',
    '⠴',
    '⠦',
    '⠧',
    '⠇',
    '⠏',
  ];

  Timer? _spinnerTimer;
  int _spinnerIndex = 0;
  AgentStatus? _lastInferredStatus;

  void _startSpinner() {
    if (_spinnerTimer != null) return; // Already running
    _spinnerTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      setState(() {
        _spinnerIndex = (_spinnerIndex + 1) % _spinnerFrames.length;
      });
    });
  }

  void _stopSpinner() {
    _spinnerTimer?.cancel();
    _spinnerTimer = null;
  }

  void _updateSpinnerForStatus(AgentStatus status) {
    final wasWorking = _lastInferredStatus == AgentStatus.working;
    final isWorking = status == AgentStatus.working;

    if (isWorking && !wasWorking) {
      _startSpinner();
    } else if (!isWorking && wasWorking) {
      _stopSpinner();
    } else if (isWorking && _spinnerTimer == null) {
      // Handle initial mount with working status
      _startSpinner();
    }

    _lastInferredStatus = status;
  }

  @override
  void dispose() {
    _stopSpinner();
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

  Color _getIndicatorColor(AgentStatus status, VideStatusColors statusColors) {
    return switch (status) {
      AgentStatus.working => statusColors.working,
      AgentStatus.waitingForAgent => statusColors.waitingForAgent,
      AgentStatus.waitingForUser => statusColors.waitingForUser,
      AgentStatus.idle => statusColors.idle,
    };
  }

  Color _getIndicatorTextColor(AgentStatus status, VideThemeData theme) {
    // Use contrasting text color based on indicator background
    return switch (status) {
      AgentStatus.waitingForAgent => Colors.black,
      _ => theme.base.onSurface,
    };
  }

  String _buildAgentDisplayName(AgentMetadata agent) {
    if (agent.taskName != null && agent.taskName!.isNotEmpty) {
      return '${agent.name} - ${agent.taskName}';
    }
    return agent.name;
  }

  /// Infer the actual status based on both explicit status and Claude's processing state.
  /// This provides safeguards against agents forgetting to call setAgentStatus.
  AgentStatus _inferActualStatus(
    AgentStatus explicitStatus,
    ClaudeStatus claudeStatus,
  ) {
    // If Claude is actively processing/thinking/responding, agent is definitely working
    if (claudeStatus == ClaudeStatus.processing ||
        claudeStatus == ClaudeStatus.thinking ||
        claudeStatus == ClaudeStatus.responding) {
      return AgentStatus.working;
    }

    // If Claude is ready/completed but agent claims to be working, override to idle
    // This handles cases where agent forgot to call setAgentStatus("idle")
    if ((claudeStatus == ClaudeStatus.ready ||
            claudeStatus == ClaudeStatus.completed) &&
        explicitStatus == AgentStatus.working) {
      return AgentStatus.idle;
    }

    // Otherwise trust the explicit status
    return explicitStatus;
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    final explicitStatus = context.watch(
      agentStatusProvider(component.agent.id),
    );

    // Get Claude's processing status from the stream
    final claudeStatusAsync = context.watch(
      claudeStatusProvider(component.agent.id),
    );
    final claudeStatus = claudeStatusAsync.valueOrNull ?? ClaudeStatus.ready;

    // Infer actual status - use Claude's status to correct agent status if needed
    final status = _inferActualStatus(explicitStatus, claudeStatus);

    // Start/stop spinner based on status changes (only runs when status is 'working')
    _updateSpinnerForStatus(status);

    final indicatorColor = _getIndicatorColor(status, theme.status);
    final indicatorTextColor = _getIndicatorTextColor(status, theme);
    final statusIndicator = _getStatusIndicator(status);

    return Padding(
      padding: EdgeInsets.only(right: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(color: indicatorColor),
            child: Text(
              statusIndicator,
              style: TextStyle(color: indicatorTextColor),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(color: theme.base.surface),
            child: Text(
              _buildAgentDisplayName(component.agent),
              style: TextStyle(
                color: theme.base.onSurface,
                fontWeight: component.isSelected ? FontWeight.bold : null,
                decoration: component.isSelected
                    ? TextDecoration.underline
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
