/// Default context window size for Claude models (200k tokens).
const int kClaudeContextWindowSize = 200000;

/// A horizontal progress bar showing context window usage.
///
/// Displays as a bar that fills from left to right with the token count
/// displayed in the middle. Color coded based on usage:
/// - Green (0-60%): healthy
/// - Yellow/Orange (60-85%): getting full
/// - Red (85%+): critical
/*class ContextUsageBar extends StatelessComponent {
  const ContextUsageBar({
    super.key,
    required this.usedTokens,
    this.maxTokens = kClaudeContextWindowSize,
  });

  /// Number of tokens currently used (input tokens fill the context window).
  final int usedTokens;

  /// Maximum tokens available in the context window.
  final int maxTokens;

  /// Formats a token count for display (e.g., 45000 -> "45k", 200000 -> "200k").
  static String formatTokenCount(int tokens) {
    if (tokens >= 1000) {
      final k = tokens / 1000;
      if (k >= 100) {
        return '${k.round()}k';
      } else if (k >= 10) {
        return '${k.round()}k';
      } else {
        final formatted = k.toStringAsFixed(1);
        if (formatted.endsWith('.0')) {
          return '${k.round()}k';
        }
        return '${formatted}k';
      }
    }
    return tokens.toString();
  }

  Color _getBarColor(double percentage) {
    if (percentage >= 0.85) {
      return Colors.red;
    } else if (percentage >= 0.60) {
      return Colors.yellow;
    } else {
      return Colors.green;
    }
  }

  Color _getTextColor(double percentage) {
    // Yellow background needs black text for readability
    if (percentage >= 0.60 && percentage < 0.85) {
      return Colors.black;
    }
    return Colors.white;
  }

  @override
  Component build(BuildContext context) {
    final percentage = maxTokens > 0 ? (usedTokens / maxTokens).clamp(0.0, 1.0) : 0.0;
    final barColor = _getBarColor(percentage);
    final textColor = _getTextColor(percentage);

    // Format the label
    final usedStr = formatTokenCount(usedTokens);
    final maxStr = formatTokenCount(maxTokens);
    final label = '$usedStr / $maxStr';

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final filledWidth = (percentage * width).round().clamp(0, width);

        // Calculate where to place the label (centered)
        final labelStart =
            ((width - label.length) / 2).round().clamp(0, width - label.length);
        final labelEnd = (labelStart + label.length).clamp(0, width);

        // Build each character of the bar
        final children = <Component>[];

        for (int i = 0; i < width; i++) {
          final isFilled = i < filledWidth;
          final isLabel = i >= labelStart && i < labelEnd;

          Color bgColor;
          Color fgColor;
          String char;

          if (isLabel) {
            char = label[i - labelStart.toInt()];
            if (isFilled) {
              bgColor = barColor;
              fgColor = textColor;
            } else {
              bgColor = Colors.grey.withOpacity(0.3);
              fgColor = Colors.white;
            }
          } else {
            char = ' ';
            if (isFilled) {
              bgColor = barColor;
              fgColor = textColor;
            } else {
              bgColor = Colors.grey.withOpacity(0.3);
              fgColor = Colors.white;
            }
          }

          children.add(
            Container(
              decoration: BoxDecoration(color: bgColor),
              child: Text(char, style: TextStyle(color: fgColor)),
            ),
          );
        }

        return Row(children: children);
      },
    );
  }
}*/
