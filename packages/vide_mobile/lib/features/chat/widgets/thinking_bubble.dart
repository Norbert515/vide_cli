import 'package:flutter/material.dart';
import 'package:vide_client/vide_client.dart';

import '../../../core/theme/tokens.dart';

/// A collapsible bubble that renders model thinking/reasoning content.
///
/// Displayed dimmed and collapsed by default so it doesn't dominate the
/// conversation, but can be expanded to inspect the full reasoning.
class ThinkingBubble extends StatefulWidget {
  final ThinkingContent content;

  const ThinkingBubble({super.key, required this.content});

  @override
  State<ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<ThinkingBubble> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: VideSpacing.sm,
        vertical: VideSpacing.xs,
      ),
      child: GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _expanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 16,
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Thinking',
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 4),
                Text(
                  widget.content.text,
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
