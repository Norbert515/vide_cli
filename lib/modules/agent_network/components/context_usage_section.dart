import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/modules/agent_network/components/context_usage_bar.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_core/vide_core.dart';

/// Displays model name, context usage percentage, and /compact hint.
class ContextUsageSection extends StatelessComponent {
  final AgentConversationState? conversation;
  final String? model;

  const ContextUsageSection({
    required this.conversation,
    required this.model,
    super.key,
  });

  /// Formats a full model ID to a short display name.
  /// e.g., "claude-sonnet-4-5-20250929" -> "sonnet"
  static String formatModelName(String model) {
    final lower = model.toLowerCase();
    if (lower.contains('opus')) return 'opus';
    if (lower.contains('sonnet')) return 'sonnet';
    if (lower.contains('haiku')) return 'haiku';
    // Fallback: return last part before date suffix, or full name if short
    if (model.length <= 10) return model;
    // Try to extract meaningful part
    final parts = model.split('-');
    if (parts.length >= 2) return parts[1];
    return model;
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    final conv = conversation;

    final usedTokens = conv != null
        ? conv.currentContextInputTokens +
              conv.currentContextCacheReadTokens +
              conv.currentContextCacheCreationTokens
        : 0;
    final percentage = kClaudeContextWindowSize > 0
        ? (usedTokens / kClaudeContextWindowSize).clamp(0.0, 1.0)
        : 0.0;
    final isWarningZone = percentage >= kContextWarningThreshold;
    final isCautionZone = percentage >= kContextCautionThreshold;

    // Only show context usage when it's getting full (>= 60%)
    final showContextUsage = isCautionZone;

    // If nothing to show (no model, no context warning, no cost), return empty
    if (model == null &&
        !showContextUsage &&
        (conv == null || conv.totalCostUsd <= 0)) {
      return SizedBox();
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1),
      child: Row(
        children: [
          // Show model name
          if (model != null) ...[
            Text(
              formatModelName(model!),
              style: TextStyle(
                color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
              ),
            ),
          ],

          // Context usage indicator (only when >= caution threshold)
          if (showContextUsage) ...[
            if (model != null) SizedBox(width: 1),
            ContextUsageIndicator(usedTokens: usedTokens),
            SizedBox(width: 1),
            Text(
              'context',
              style: TextStyle(
                color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
              ),
            ),
          ],

          // Show /compact hint when in warning zone
          if (isWarningZone) ...[
            SizedBox(width: 1),
            Text(
              '(/compact)',
              style: TextStyle(color: theme.base.error.withOpacity(0.7)),
            ),
          ],
        ],
      ),
    );
  }
}
