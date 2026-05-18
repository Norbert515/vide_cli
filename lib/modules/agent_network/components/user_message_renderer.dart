import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_core/vide_core.dart';

/// Renders a user message: chevron + text, with optional attachment indicators.
class UserMessageRenderer extends StatelessComponent {
  final ConversationEntry entry;

  /// Locally tracked attachments keyed by message text, used as fallback
  /// when [AttachmentContent] is not present in the entry.
  final Map<String, List<AgentAttachment>> sentAttachments;

  const UserMessageRenderer({
    required this.entry,
    this.sentAttachments = const {},
    super.key,
  });

  static String _formatAttachment(AgentAttachment attachment, int index) {
    final label = switch (attachment.type) {
      'image' => 'Image',
      'document' => 'Document',
      _ => attachment.type,
    };
    return '\u{1F4CE} $label #${index + 1}';
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    // Resolve attachments from entry content or locally tracked
    List<AgentAttachment>? attachments;
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
          padding: EdgeInsets.symmetric(horizontal: 1, vertical: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (attachments != null && attachments.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: 1),
                  child: Row(
                    children: [
                      for (final (i, attachment) in attachments.indexed) ...[
                        if (i > 0) SizedBox(width: 2),
                        Text(
                          _formatAttachment(attachment, i),
                          style: TextStyle(
                            color: theme.base.onSurface.withOpacity(TextOpacity.secondary),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('\u25b8 ', style: TextStyle(color: theme.base.primary)),
                  Expanded(
                    child: Text(entry.text, style: TextStyle(color: theme.base.onSurface)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
