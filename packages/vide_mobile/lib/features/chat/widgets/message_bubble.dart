import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/vide_colors.dart';
import '../../../domain/models/models.dart';

/// A terminal-style message block.
///
/// User messages use `>` prefix with accent left border.
/// Agent messages use `$` prefix with info-colored left border.
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

    final borderColor = isUser ? videColors.accent : videColors.info;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: VideSpacing.sm,
        vertical: VideSpacing.xs,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: VideRadius.smAll,
          border: Border(
            left: BorderSide(color: borderColor, width: 3),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: prefix + name + timestamp
            Row(
              children: [
                Text(
                  isUser ? '>' : '\$',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: borderColor,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isUser ? 'you' : (message.agentName ?? message.agentType),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    fontSize: 11,
                    color: videColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Content
            if (isUser)
              Text(
                message.content,
                style: TextStyle(color: colorScheme.onSurface),
              )
            else
              MarkdownBody(
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
            if (message.isStreaming) ...[
              const SizedBox(height: 4),
              const _BlinkingCursor(),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

/// Blinking block cursor for streaming messages.
class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: VideDurations.cursorBlink,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _controller.value > 0.5 ? 1.0 : 0.0,
          child: Text(
            '\u2588',
            style: TextStyle(
              fontSize: 14,
              color: videColors.accent,
              height: 1,
            ),
          ),
        );
      },
    );
  }
}
