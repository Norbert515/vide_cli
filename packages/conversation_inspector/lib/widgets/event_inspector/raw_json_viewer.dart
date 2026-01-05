import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A widget that displays JSON with syntax highlighting.
class RawJsonViewer extends StatelessWidget {
  final Map<String, dynamic> json;
  final bool expanded;
  final VoidCallback? onToggle;

  const RawJsonViewer({
    super.key,
    required this.json,
    this.expanded = false,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (!expanded) {
      return InkWell(
        onTap: onToggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Icon(
                Icons.chevron_right,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                'Show raw JSON',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final prettyJson = const JsonEncoder.withIndent('  ').convert(json);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            InkWell(
              onTap: onToggle,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.expand_more,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Hide raw JSON',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: prettyJson));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('JSON copied to clipboard'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              tooltip: 'Copy JSON',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade800),
          ),
          child: SelectableText.rich(
            _buildHighlightedJson(prettyJson),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  TextSpan _buildHighlightedJson(String json) {
    final spans = <TextSpan>[];
    final lines = json.split('\n');

    for (int i = 0; i < lines.length; i++) {
      if (i > 0) {
        spans.add(const TextSpan(text: '\n'));
      }
      spans.addAll(_highlightLine(lines[i]));
    }

    return TextSpan(children: spans);
  }

  List<TextSpan> _highlightLine(String line) {
    final spans = <TextSpan>[];
    final keyPattern = RegExp(r'^(\s*)(".*?")(:)');

    // Check for key pattern first
    final keyMatch = keyPattern.firstMatch(line);
    if (keyMatch != null) {
      // Add leading whitespace
      spans.add(TextSpan(
        text: keyMatch.group(1),
        style: const TextStyle(color: Colors.white),
      ));
      // Add key
      spans.add(TextSpan(
        text: keyMatch.group(2),
        style: const TextStyle(color: Color(0xFF9CDCFE)),
      ));
      // Add colon
      spans.add(TextSpan(
        text: keyMatch.group(3),
        style: const TextStyle(color: Colors.white),
      ));

      // Process the rest of the line
      final rest = line.substring(keyMatch.end);
      spans.addAll(_highlightValue(rest));
    } else {
      // Process as value
      spans.addAll(_highlightValue(line));
    }

    return spans;
  }

  List<TextSpan> _highlightValue(String text) {
    final spans = <TextSpan>[];
    int currentIndex = 0;

    while (currentIndex < text.length) {
      // Try to match patterns
      Match? bestMatch;
      String? matchType;
      int bestStart = text.length;

      // Check for string
      final stringMatch = RegExp(r'"(?:[^"\\]|\\.)*"').firstMatch(text.substring(currentIndex));
      if (stringMatch != null && currentIndex + stringMatch.start < bestStart) {
        bestMatch = stringMatch;
        matchType = 'string';
        bestStart = currentIndex + stringMatch.start;
      }

      // Check for number
      final numberMatch = RegExp(r'\b-?\d+\.?\d*\b').firstMatch(text.substring(currentIndex));
      if (numberMatch != null && currentIndex + numberMatch.start < bestStart) {
        bestMatch = numberMatch;
        matchType = 'number';
        bestStart = currentIndex + numberMatch.start;
      }

      // Check for bool/null
      final boolMatch = RegExp(r'\b(true|false|null)\b').firstMatch(text.substring(currentIndex));
      if (boolMatch != null && currentIndex + boolMatch.start < bestStart) {
        bestMatch = boolMatch;
        matchType = 'bool';
        bestStart = currentIndex + boolMatch.start;
      }

      if (bestMatch != null) {
        // Add text before match
        if (bestStart > currentIndex) {
          spans.add(TextSpan(
            text: text.substring(currentIndex, bestStart),
            style: const TextStyle(color: Colors.white),
          ));
        }

        // Add matched text with color
        final matchText = text.substring(bestStart, bestStart + bestMatch.end - bestMatch.start);
        final color = switch (matchType) {
          'string' => const Color(0xFFCE9178),
          'number' => const Color(0xFFB5CEA8),
          'bool' => const Color(0xFF569CD6),
          _ => Colors.white,
        };

        spans.add(TextSpan(
          text: matchText,
          style: TextStyle(color: color),
        ));

        currentIndex = bestStart + bestMatch.end - bestMatch.start;
      } else {
        // No more matches, add rest of text
        spans.add(TextSpan(
          text: text.substring(currentIndex),
          style: const TextStyle(color: Colors.white),
        ));
        break;
      }
    }

    return spans;
  }
}
