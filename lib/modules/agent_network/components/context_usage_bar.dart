import 'package:nocterm/nocterm.dart';

/// Default context window size for Claude models (200k tokens).
const int kClaudeContextWindowSize = 200000;

/// Warning threshold (85%) - show warning indicator when above this
const double kContextWarningThreshold = 0.85;

/// Caution threshold (60%) - yellow zone starts here
const double kContextCautionThreshold = 0.60;

/// Formats a token count for display (e.g., 45000 -> "45k", 200000 -> "200k").
String formatTokenCount(int tokens) {
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

/// A horizontal progress bar showing context window usage.
///
/// Displays as a bar that fills from left to right with the token count
/// displayed in the middle. Color coded based on usage:
/// - Green (0-60%): healthy
/// - Yellow/Orange (60-85%): getting full
/// - Red (85%+): critical
class ContextUsageBar extends StatelessComponent {
  const ContextUsageBar({
    super.key,
    required this.usedTokens,
    this.maxTokens = kClaudeContextWindowSize,
  });

  /// Number of tokens currently used (context tokens fill the context window).
  final int usedTokens;

  /// Maximum tokens available in the context window.
  final int maxTokens;

  Color _getBarColor(double percentage) {
    if (percentage >= kContextWarningThreshold) {
      return Colors.red;
    } else if (percentage >= kContextCautionThreshold) {
      return Colors.yellow;
    } else {
      return Colors.green;
    }
  }

  Color _getTextColor(double percentage) {
    // Yellow background needs black text for readability
    if (percentage >= kContextCautionThreshold &&
        percentage < kContextWarningThreshold) {
      return Colors.black;
    }
    return Colors.white;
  }

  @override
  Component build(BuildContext context) {
    final percentage = maxTokens > 0
        ? (usedTokens / maxTokens).clamp(0.0, 1.0)
        : 0.0;
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
        final labelStart = ((width - label.length) / 2).round().clamp(
          0,
          width - label.length,
        );
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
}

/// A compact indicator showing context usage as a percentage with color coding.
class ContextUsageIndicator extends StatelessComponent {
  const ContextUsageIndicator({
    super.key,
    required this.usedTokens,
    this.maxTokens = kClaudeContextWindowSize,
    this.showWarning = true,
  });

  final int usedTokens;
  final int maxTokens;
  final bool showWarning;

  @override
  Component build(BuildContext context) {
    final percentage = maxTokens > 0
        ? (usedTokens / maxTokens).clamp(0.0, 1.0)
        : 0.0;
    final percentInt = (percentage * 100).round();

    Color textColor;
    if (percentage >= kContextWarningThreshold) {
      textColor = Colors.red;
    } else if (percentage >= kContextCautionThreshold) {
      textColor = Colors.yellow;
    } else {
      textColor = Colors.grey;
    }

    final warningIcon = showWarning && percentage >= kContextWarningThreshold
        ? '⚠ '
        : '';

    return Text('$warningIcon$percentInt%', style: TextStyle(color: textColor));
  }
}
