import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:vide_client/vide_client.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/vide_colors.dart';

/// The height of the agent tab bar including padding.
const agentTabBarHeight = 44.0;

/// Tab bar showing one tab per agent as liquid glass chips.
///
/// Must be placed inside a [LiquidGlassLayer] to get refraction effects.
class AgentTabBar extends StatelessWidget {
  final List<VideAgent> agents;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const AgentTabBar({super.key, required this.agents, required this.selectedIndex, required this.onTabSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: agentTabBarHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: VideSpacing.sm),
        itemCount: agents.length,
        itemBuilder: (context, index) {
          final agent = agents[index];
          return _TabChip(
            label: agent.name,
            subtitle: agent.taskName,
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
  final String? subtitle;
  final bool isSelected;
  final Widget? statusIndicator;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    this.subtitle,
    required this.isSelected,
    this.statusIndicator,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (statusIndicator != null) ...[statusIndicator!, const SizedBox(width: 6)],
        Flexible(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? videColors.accent : videColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(fontSize: 10, color: videColors.textTertiary),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
            ],
          ),
        ),
      ],
    );

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: VideSpacing.xs, vertical: 6),
        child: LiquidGlass(
          shape: const LiquidRoundedSuperellipse(borderRadius: VideRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: VideSpacing.md),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// TUI-style status indicator using braille spinner for working,
/// and static characters for other states.
class _AgentStatusIndicator extends StatefulWidget {
  final VideAgentStatus status;

  const _AgentStatusIndicator({required this.status});

  @override
  State<_AgentStatusIndicator> createState() => _AgentStatusIndicatorState();
}

class _AgentStatusIndicatorState extends State<_AgentStatusIndicator> with SingleTickerProviderStateMixin {
  static const _brailleFrames = [
    '\u280B',
    '\u2819',
    '\u2839',
    '\u2838',
    '\u283C',
    '\u2834',
    '\u2826',
    '\u2827',
    '\u2807',
    '\u280F',
  ];

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(seconds: 1), vsync: this);
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
    if (widget.status == VideAgentStatus.working) {
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

    if (widget.status == VideAgentStatus.working) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final frameIndex = (_controller.value * _brailleFrames.length).floor() % _brailleFrames.length;
          return Text(_brailleFrames[frameIndex], style: TextStyle(fontSize: 13, color: videColors.accent));
        },
      );
    }

    final (char, color) = switch (widget.status) {
      VideAgentStatus.working => ('', videColors.accent),
      VideAgentStatus.waitingForAgent => ('\u2026', videColors.textSecondary),
      VideAgentStatus.waitingForUser => ('?', videColors.warning),
      VideAgentStatus.idle => ('\u2713', videColors.success),
    };

    return Text(char, style: TextStyle(fontSize: 13, color: color));
  }
}
