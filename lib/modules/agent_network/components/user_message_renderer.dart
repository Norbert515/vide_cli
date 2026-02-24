import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_core/vide_core.dart';

/// Renders a user message: chevron + text, with optional attachment indicators.
class UserMessageRenderer extends StatelessComponent {
  final ConversationEntry entry;

  /// Locally tracked attachments keyed by message text, used as fallback
  /// when [AttachmentContent] is not present in the entry.
  final Map<String, List<VideAttachment>> sentAttachments;

  const UserMessageRenderer({
    required this.entry,
    this.sentAttachments = const {},
    super.key,
  });

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    // Resolve attachments from entry content or locally tracked
    List<VideAttachment>? attachments;
    for (final c in entry.content) {
      if (c is AttachmentContent) {
        attachments = c.attachments;
        break;
      }
    }
    attachments ??= sentAttachments[entry.text];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(color: theme.base.primary.withOpacity(0.05)),
          padding: EdgeInsets.symmetric(horizontal: 1),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('\u25b8 ', style: TextStyle(color: theme.base.primary)),
              Expanded(
                child: Text(entry.text, style: TextStyle(color: theme.base.onSurface)),
              ),
            ],
          ),
        ),
        if (attachments != null && attachments.isNotEmpty)
          for (final attachment in attachments)
            Text(
              '  [${attachment.type}: ${attachment.filePath ?? attachment.mimeType ?? 'inline'}]',
              style: TextStyle(color: theme.base.onSurface.withOpacity(TextOpacity.secondary)),
            ),
      ],
    );
  }
}
