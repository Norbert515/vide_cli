import 'package:agent_sdk/agent_sdk.dart';
import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/theme/theme.dart';

import 'plan_view_dialog.dart';

/// Renders ExitPlanMode tool results with a plan content preview.
///
/// Shows "Plan accepted" (green) or "Plan rejected: reason" (red).
/// When a plan is accepted and plan content is available, displays the first
/// few lines as a dimmed preview. Clicking opens the full plan in a dialog.
class PlanAcceptedRenderer extends StatefulComponent {
  final AgentToolInvocation invocation;
  final String? planContent;

  const PlanAcceptedRenderer({
    required this.invocation,
    this.planContent,
    super.key,
  });

  @override
  State<PlanAcceptedRenderer> createState() => _PlanAcceptedRendererState();
}

class _PlanAcceptedRendererState extends State<PlanAcceptedRenderer> {
  bool isHovered = false;

  @override
  Component build(BuildContext context) {
    // While waiting for user response, show nothing (dialog handles it)
    if (!component.invocation.hasResult) {
      return SizedBox();
    }

    final theme = VideTheme.of(context);

    if (component.invocation.isError) {
      return _buildRejected(theme);
    }

    return _buildAccepted(context, theme);
  }

  Component _buildRejected(VideThemeData theme) {
    final reason =
        component.invocation.resultContent ?? 'User rejected the plan';
    return Container(
      padding: EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('\u25c7 ', style: TextStyle(color: theme.base.error)),
          Expanded(
            child: Text(
              'Plan rejected: $reason',
              style: TextStyle(color: theme.base.error),
            ),
          ),
        ],
      ),
    );
  }

  Component _buildAccepted(BuildContext context, VideThemeData theme) {
    final planContent = component.planContent;
    final hasPreview = planContent != null && planContent.trim().isNotEmpty;

    final header = Container(
      padding: EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Text('\u25c6 ', style: TextStyle(color: theme.base.success)),
          Text(
            'Plan accepted',
            style: TextStyle(
              color: theme.base.success,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );

    if (!hasPreview) return header;

    // Extract first 3 non-empty lines for preview
    final previewLines = planContent
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .take(3)
        .toList();
    final totalLines =
        planContent.split('\n').where((l) => l.trim().isNotEmpty).length;
    final hasMore = totalLines > 3;

    final bgColor = isHovered
        ? theme.base.surface.withOpacity(0.8)
        : theme.base.surface.withOpacity(0.5);
    final dimText = theme.base.onSurface.withOpacity(0.4);

    return MouseRegion(
      onEnter: (_) {
        if (mounted) setState(() => isHovered = true);
      },
      onExit: (_) {
        if (mounted) setState(() => isHovered = false);
      },
      child: GestureDetector(
        onTap: () => PlanViewDialog.show(context, planContent: planContent),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            Container(
              decoration: BoxDecoration(color: bgColor),
              padding: EdgeInsets.all(1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in previewLines)
                    Text(line, style: TextStyle(color: dimText)),
                  if (hasMore)
                    Text(
                      '($totalLines lines \u2014 click to view)',
                      style: TextStyle(
                        color: dimText,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
