import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_core/vide_core.dart';

class RunningAgentsBar extends StatelessComponent {
  const RunningAgentsBar({
    super.key,
    required this.agents,
    this.selectedIndex = 0,
  });

  final List<VideAgent> agents;
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
  final VideAgent agent;
  final bool isSelected;

  const _RunningAgentBarItem({required this.agent, required this.isSelected});

  @override
  State<_RunningAgentBarItem> createState() => _RunningAgentBarItemState();
}

class _RunningAgentBarItemState extends State<_RunningAgentBarItem>
    with SingleTickerProviderStateMixin {
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

  late AnimationController _spinnerController;
  VideAgentStatus? _lastInferredStatus;

  /// Derive spinner index from animation controller value (0.0-1.0)
  int get _spinnerIndex =>
      (_spinnerController.value * _spinnerFrames.length).floor() %
      _spinnerFrames.length;

  @override
  void initState() {
    super.initState();
    _spinnerController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..addListener(() => setState(() {}));
  }

  void _updateSpinnerForStatus(VideAgentStatus status) {
    final wasWorking = _lastInferredStatus == VideAgentStatus.working;
    final isWorking = status == VideAgentStatus.working;

    if (isWorking && !wasWorking) {
      _spinnerController.repeat();
    } else if (!isWorking && wasWorking) {
      _spinnerController
        ..stop()
        ..reset();
    } else if (isWorking && !_spinnerController.isAnimating) {
      // Handle initial mount with working status
      _spinnerController.repeat();
    }

    _lastInferredStatus = status;
  }

  @override
  void dispose() {
    _spinnerController.dispose();
    super.dispose();
  }

  String _getStatusIndicator(VideAgentStatus status) {
    return switch (status) {
      VideAgentStatus.working => _spinnerFrames[_spinnerIndex],
      VideAgentStatus.waitingForAgent => '…',
      VideAgentStatus.waitingForUser => '?',
      VideAgentStatus.idle => '✓',
    };
  }

  Color _getIndicatorColor(VideAgentStatus status, VideStatusColors statusColors) {
    return switch (status) {
      VideAgentStatus.working => statusColors.working,
      VideAgentStatus.waitingForAgent => statusColors.waitingForAgent,
      VideAgentStatus.waitingForUser => statusColors.waitingForUser,
      VideAgentStatus.idle => statusColors.idle,
    };
  }

  Color _getIndicatorTextColor(VideAgentStatus status, VideThemeData theme) {
    // Use contrasting text color based on indicator background
    return switch (status) {
      VideAgentStatus.waitingForAgent => Colors.black,
      _ => theme.base.onSurface,
    };
  }

  String _buildAgentDisplayName(VideAgent agent) {
    if (agent.taskName != null && agent.taskName!.isNotEmpty) {
      return '${agent.name} - ${agent.taskName}';
    }
    return agent.name;
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    // Status comes from VideAgent which is rebuilt via videSessionAgentsProvider
    // (a StreamProvider on session.stateStream). The data layer already derives
    // the correct status from agentStatusProvider, so no override logic needed.
    final status = component.agent.status;

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
