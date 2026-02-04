import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/vide_colors.dart';
import '../../../domain/models/models.dart';

/// A minimal message block.
///
/// User messages get a subtle accent left border.
/// Agent messages have no border — just content.
class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final colorScheme = Theme.of(context).colorScheme;
    final videColors = Theme.of(context).extension<VideThemeColors>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: VideSpacing.sm,
        vertical: VideSpacing.xs,
      ),
      child: Container(
        decoration: BoxDecoration(
          border: isUser
              ? Border(left: BorderSide(color: videColors.accent, width: 3))
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: isUser
            ? Text(
                message.content,
                style: TextStyle(color: colorScheme.onSurface),
              )
            : MarkdownBody(
                data: message.content,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 14,
                  ),
                  code: TextStyle(
                    backgroundColor: colorScheme.surfaceContainerHigh,
                    fontSize: 13,
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: VideRadius.smAll,
                    border: Border.all(
                      color: colorScheme.outlineVariant,
                    ),
                  ),
                ),
                selectable: true,
                softLineBreak: true,
              ),
      ),
    );
  }
}

