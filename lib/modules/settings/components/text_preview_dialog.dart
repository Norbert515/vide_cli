import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_cli/constants/text_opacity.dart';

/// A dialog that displays scrollable text content.
///
/// Similar to [FilePreviewOverlay] but takes a title and content string
/// instead of a file path. No syntax highlighting — just plain scrollable text.
///
/// ESC closes the dialog. Up/Down/j/k scroll. PageUp/PageDown for fast scrolling.
class TextPreviewDialog extends StatefulComponent {
  final String title;
  final String content;
  final VoidCallback onClose;

  const TextPreviewDialog({
    required this.title,
    required this.content,
    required this.onClose,
    super.key,
  });

  @override
  State<TextPreviewDialog> createState() => _TextPreviewDialogState();
}

class _TextPreviewDialogState extends State<TextPreviewDialog> {
  final _scrollController = ScrollController();

  bool _handleKeyEvent(LogicalKey key) {
    switch (key) {
      case LogicalKey.escape:
        component.onClose();
        return true;
      case LogicalKey.arrowUp:
      case LogicalKey.keyK:
        _scrollController.scrollUp();
        return true;
      case LogicalKey.arrowDown:
      case LogicalKey.keyJ:
        _scrollController.scrollDown();
        return true;
      case LogicalKey.pageUp:
        _scrollController.pageUp();
        return true;
      case LogicalKey.pageDown:
        _scrollController.pageDown();
        return true;
      default:
        return false;
    }
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    final lines = component.content.split('\n');

    return LayoutBuilder(
      builder: (context, constraints) {
        final dialogWidth = (constraints.maxWidth * 0.8).clamp(50.0, 120.0);
        final dialogHeight = (constraints.maxHeight * 0.8).clamp(15.0, 40.0);

        return Center(
          child: KeyboardListener(
            onKeyEvent: _handleKeyEvent,
            autofocus: true,
            child: Container(
              width: dialogWidth,
              height: dialogHeight,
              decoration: BoxDecoration(
                color: theme.base.surface,
                border: BoxBorder.all(
                  color: theme.base.primary,
                  style: BoxBorderStyle.rounded,
                ),
                title: BorderTitle(
                  text: ' ${component.title} ',
                  alignment: TitleAlignment.left,
                  style: TextStyle(
                    color: theme.base.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // Header with close hint
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 1),
                    child: Row(
                      children: [
                        Expanded(child: SizedBox()),
                        Text(
                          'ESC to close',
                          style: TextStyle(
                            color: theme.base.onSurface.withOpacity(
                              TextOpacity.tertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Scrollable content
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 1),
                      child: ListView(
                        controller: _scrollController,
                        children: [
                          for (final line in lines)
                            Text(
                              line.isEmpty ? ' ' : line,
                              style: TextStyle(color: theme.syntax.plain),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
