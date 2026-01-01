import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/theme/theme.dart';

/// Indicator that shows when a message is queued during processing.
///
/// Displays the queued message text (truncated if too long) and provides
/// a hint for how to clear it.
class QueueIndicator extends StatelessComponent {
  final String queuedText;
  final VoidCallback onClear;

  const QueueIndicator({
    required this.queuedText,
    required this.onClear,
    super.key,
  });

  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    final truncatedText = _truncateText(queuedText.replaceAll('\n', ' '), 60);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1),
      child: Row(
        children: [
          Text(
            '⏳ Queued: ',
            style: TextStyle(
              color: theme.base.warning.withOpacity(TextOpacity.secondary),
            ),
          ),
          Text(
            '"$truncatedText"',
            style: TextStyle(
              color: theme.base.onSurface.withOpacity(TextOpacity.secondary),
            ),
          ),
          SizedBox(width: 2),
          Text(
            '[ESC to clear]',
            style: TextStyle(
              color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
            ),
          ),
        ],
      ),
    );
  }
}
