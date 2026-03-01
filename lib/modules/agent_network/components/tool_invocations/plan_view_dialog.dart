import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/theme/theme.dart';

/// Read-only dialog for viewing a plan's full content.
///
/// Shown when the user clicks on a "Plan accepted" chip in the chat history.
/// Displays the plan as scrollable markdown with ESC to close.
class PlanViewDialog extends StatefulComponent {
  final String planContent;

  const PlanViewDialog({required this.planContent, super.key});

  /// Shows the plan view dialog.
  static Future<void> show(
    BuildContext context, {
    required String planContent,
  }) {
    return Navigator.of(context).showDialog(
      builder: (context) => PlanViewDialog(planContent: planContent),
      barrierDismissible: true,
      width: 80,
      height: 30,
    );
  }

  @override
  State<PlanViewDialog> createState() => _PlanViewDialogState();
}

class _PlanViewDialogState extends State<PlanViewDialog> {
  final _scrollController = ScrollController();

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    return Focusable(
      focused: true,
      onKeyEvent: (event) {
        final key = event.logicalKey;
        if (key == LogicalKey.escape) {
          Navigator.of(context).pop();
          return true;
        }
        if (key == LogicalKey.arrowDown) {
          _scrollController.scrollDown();
          return true;
        }
        if (key == LogicalKey.arrowUp) {
          _scrollController.scrollUp();
          return true;
        }
        if (key == LogicalKey.pageDown) {
          _scrollController.pageDown();
          return true;
        }
        if (key == LogicalKey.pageUp) {
          _scrollController.pageUp();
          return true;
        }
        return false;
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.base.surface,
          border: BoxBorder.all(color: theme.base.outline),
        ),
        padding: EdgeInsets.symmetric(horizontal: 1),
        child: Column(
          children: [
            // Title bar
            Row(
              children: [
                Text(
                  'Plan',
                  style: TextStyle(
                    color: theme.base.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(child: SizedBox()),
                Text(
                  'Esc to close',
                  style: TextStyle(color: theme.base.outline),
                ),
              ],
            ),
            SizedBox(height: 1),
            // Scrollable plan content
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                thumbColor: theme.base.primary,
                trackColor: theme.base.outlineVariant,
                child: ListView(
                  lazy: false,
                  controller: _scrollController,
                  children: [
                    MarkdownText(
                      component.planContent,
                      styleSheet: theme.markdownStyleSheet,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
