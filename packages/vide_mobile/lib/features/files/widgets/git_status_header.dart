import 'package:flutter/material.dart';
import 'package:vide_client/vide_client.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/vide_colors.dart';

class GitStatusHeader extends StatelessWidget {
  final GitStatusInfo gitStatus;

  const GitStatusHeader({super.key, required this.gitStatus});

  @override
  Widget build(BuildContext context) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final changedCount = gitStatus.allChangedFiles.length;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VideSpacing.md,
        vertical: VideSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.commit, size: 16, color: videColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            gitStatus.branch,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
          if (gitStatus.ahead > 0 || gitStatus.behind > 0) ...[
            const SizedBox(width: 8),
            if (gitStatus.ahead > 0)
              _Badge(
                text: '↑${gitStatus.ahead}',
                color: videColors.success,
              ),
            if (gitStatus.behind > 0) ...[
              const SizedBox(width: 4),
              _Badge(
                text: '↓${gitStatus.behind}',
                color: videColors.warning,
              ),
            ],
          ],
          const Spacer(),
          if (changedCount > 0)
            Text(
              '$changedCount changed',
              style: TextStyle(
                fontSize: 12,
                color: videColors.warning,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(VideRadius.pill),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
