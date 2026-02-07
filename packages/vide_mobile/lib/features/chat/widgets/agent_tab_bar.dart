import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/vide_colors.dart';
import '../../../domain/models/agent.dart';

/// Tab bar showing one tab per agent with TUI-style status indicators.
class AgentTabBar extends StatelessWidget {
  final List<Agent> agents;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const AgentTabBar({
    super.key,
    required this.agents,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: videColors.glassBorder,
            width: 1,
          ),
        ),
      ),
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: VideSpacing.sm),
        itemCount: agents.length,
        itemBuilder: (context, index) {
          final agent = agents[index];
          return _TabChip(
            label: agent.name,
            isSelected: index == selectedIndex,
            statusIndicator: _AgentStatusIndicator(status: agent.status),
            onTap: () => onTabSelected(index),
          );
        },
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Widget? statusIndicator;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.isSelected,
    this.statusIndicator,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: VideSpacing.xs,
          vertical: 6,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: VideSpacing.md,
        ),
        decoration: BoxDecoration(
          color: isSelected ? videColors.accentSubtle : Colors.transparent,
          borderRadius: VideRadius.mdAll,
          border: Border.all(
            color: isSelected
                ? videColors.accent.withValues(alpha: 0.3)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (statusIndicator != null) ...[
              statusIndicator!,
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? videColors.accent
                    : videColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// TUI-style status indicator using braille spinner for working,
/// and static characters for other states.
class _AgentStatusIndicator extends StatefulWidget {
  final AgentStatus status;

  const _AgentStatusIndicator({required this.status});

  @override
  State<_AgentStatusIndicator> createState() => _AgentStatusIndicatorState();
}

class _AgentStatusIndicatorState extends State<_AgentStatusIndicator>
    with SingleTickerProviderStateMixin {
  static const _brailleFrames = [
    '\u280B', '\u2819', '\u2839', '\u2838', '\u283C', '\u2834',
    '\u2826', '\u2827', '\u2807', '\u280F',
  ];

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _updateAnimation();
  }

  @override
  void didUpdateWidget(_AgentStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    if (widget.status == AgentStatus.working) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;

    if (widget.status == AgentStatus.working) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final frameIndex =
              (_controller.value * _brailleFrames.length).floor() %
                  _brailleFrames.length;
          return Text(
            _brailleFrames[frameIndex],
            style: TextStyle(
              fontSize: 13,
              color: videColors.accent,
            ),
          );
        },
      );
    }

    final (char, color) = switch (widget.status) {
      AgentStatus.working => ('', videColors.accent),
      AgentStatus.waitingForAgent => ('\u2026', videColors.textSecondary),
      AgentStatus.waitingForUser => ('?', videColors.warning),
      AgentStatus.idle => ('\u2713', videColors.success),
    };

    return Text(
      char,
      style: TextStyle(
        fontSize: 13,
        color: color,
      ),
    );
  }
}
