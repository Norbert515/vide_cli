import 'package:flutter/material.dart';
import 'package:vide_client/vide_client.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/vide_colors.dart';

/// Inline indicator for ExitPlanMode results.
/// Shows green "Plan accepted" or red "Plan rejected" with feedback.
class PlanResultIndicator extends StatelessWidget {
  final ToolContent tool;

  const PlanResultIndicator({super.key, required this.tool});

  @override
  Widget build(BuildContext context) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;

    // While waiting for result, show nothing
    if (tool.result == null) {
      return const SizedBox.shrink();
    }

    final isError = tool.isError;
    final color = isError ? videColors.error : videColors.success;
    final icon = isError ? Icons.cancel_outlined : Icons.check_circle;
    final label = isError
        ? 'Plan rejected: ${tool.result ?? 'User rejected the plan'}'
        : 'Plan accepted';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: VideSpacing.sm,
        vertical: VideSpacing.xs,
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card displayed inline when the main agent spawns a sub-agent.
class SpawnAgentCard extends StatelessWidget {
  final ToolContent tool;
  final List<VideAgent> agents;
  final ValueChanged<String>? onTap;

  const SpawnAgentCard({
    super.key,
    required this.tool,
    required this.agents,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;
    final colorScheme = Theme.of(context).colorScheme;

    final agentName = tool.toolInput['name'] as String? ?? 'Agent';
    final agentType = tool.toolInput['agentType'] as String? ?? '';

    final matchingAgent = agents
        .cast<VideAgent?>()
        .firstWhere((a) => a!.name == agentName, orElse: () => null);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: VideSpacing.sm,
        vertical: VideSpacing.xs,
      ),
      child: GestureDetector(
        onTap:
            matchingAgent != null ? () => onTap?.call(matchingAgent.id) : null,
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: VideRadius.smAll,
            border: Border.all(color: videColors.glassBorder, width: 1),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: VideSpacing.md,
            vertical: 12,
          ),
          child: Row(
            children: [
              Icon(Icons.arrow_forward_rounded,
                  size: 18, color: videColors.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agentName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: videColors.accent,
                      ),
                    ),
                    if (agentType.isNotEmpty)
                      Text(
                        agentType,
                        style: TextStyle(
                          fontSize: 12,
                          color: videColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (matchingAgent != null)
                Icon(Icons.chevron_right,
                    size: 18, color: videColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
