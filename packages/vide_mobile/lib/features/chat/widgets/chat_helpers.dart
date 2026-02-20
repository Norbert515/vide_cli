import 'package:flutter/material.dart';
import 'package:vide_client/vide_client.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/vide_colors.dart';

/// Whether [tool] should be hidden from the message list.
///
/// Hides internal tools that are not useful to show the user:
/// plan mode entry, task naming, agent status, todo writes, and
/// plan file writes.
bool isHiddenTool(ToolContent tool) {
  final name = tool.toolName;
  if (name == 'EnterPlanMode' ||
      name == 'mcp__vide-agent__setTaskName' ||
      name == 'mcp__vide-agent__setAgentTaskName' ||
      name == 'mcp__vide-task-management__setTaskName' ||
      name == 'mcp__vide-task-management__setAgentTaskName' ||
      name == 'mcp__vide-agent__setAgentStatus' ||
      name == 'TodoWrite') {
    return true;
  }
  // Hide Write tool targeting Claude's plans directory
  if (name == 'Write') {
    final filePath = tool.toolInput['file_path'] as String?;
    if (filePath != null && filePath.contains('.claude/plans/')) {
      return true;
    }
  }
  return false;
}

/// Whether [tool] is a spawn-agent tool invocation.
bool isSpawnAgentTool(ToolContent tool) {
  return tool.toolName == 'mcp__vide-agent__spawnAgent';
}

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

/// Strips MCP prefixes like "mcp__vide-agent__" from tool names.
///
/// Exported for use by other packages that need to display tool names.
String toolDisplayName(String toolName) {
  final mcpPrefix = RegExp(r'^mcp__[^_]+__');
  return toolName.replaceFirst(mcpPrefix, '');
}

/// Extracts a contextual subtitle from the tool input.
///
/// Accepts raw [toolName] and [input] so it can be used for both
/// [ToolContent] objects and [PermissionRequestEvent]s.
String? toolSubtitle(String toolName, Map<String, dynamic> input) {
  final name = toolDisplayName(toolName);

  switch (name) {
    case 'Read':
    case 'Edit':
    case 'Write':
      return input['file_path'] as String?;
    case 'Bash':
      return input['command'] as String?;
    case 'Grep':
      final pattern = input['pattern'] as String?;
      final path = input['path'] as String?;
      if (pattern != null && path != null) return '"$pattern" in $path';
      return pattern != null ? '"$pattern"' : null;
    case 'Glob':
      return input['pattern'] as String?;
    case 'WebFetch':
      return input['url'] as String?;
    case 'WebSearch':
      return input['query'] as String?;
    case 'TodoWrite':
      return null;
    case 'Task':
      return input['description'] as String?;
    case 'NotebookEdit':
      return input['notebook_path'] as String?;
    default:
      return input['file_path'] as String? ??
          input['command'] as String? ??
          input['pattern'] as String? ??
          input['query'] as String? ??
          input['description'] as String?;
  }
}
