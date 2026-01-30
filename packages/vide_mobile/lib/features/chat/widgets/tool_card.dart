import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../domain/models/models.dart';

/// A collapsible card displaying tool use and result.
class ToolCard extends StatefulWidget {
  final ToolUse toolUse;
  final ToolResult? result;

  const ToolCard({
    super.key,
    required this.toolUse,
    this.result,
  });

  @override
  State<ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<ToolCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasResult = widget.result != null;
    final isError = widget.result?.isError ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isError
                            ? colorScheme.errorContainer
                            : hasResult
                                ? Colors.green.withValues(alpha: 0.1)
                                : colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isError
                            ? Icons.error_outline
                            : hasResult
                                ? Icons.check_circle_outline
                                : Icons.sync,
                        size: 18,
                        color: isError
                            ? colorScheme.error
                            : hasResult
                                ? Colors.green
                                : colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.toolUse.toolName,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (widget.toolUse.agentName != null)
                            Text(
                              'by ${widget.toolUse.agentName}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                if (_isExpanded) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Text(
                    'Input',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _JsonView(json: widget.toolUse.input),
                  if (hasResult) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Result',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: isError ? colorScheme.error : Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _ResultView(result: widget.result!),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _JsonView extends StatelessWidget {
  final Map<String, dynamic> json;

  const _JsonView({required this.json});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const encoder = JsonEncoder.withIndent('  ');
    final prettyJson = encoder.convert(json);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(
          prettyJson,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  final ToolResult result;

  const _ResultView({required this.result});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final resultData = result.result;

    String displayText;
    if (resultData is Map || resultData is List) {
      displayText = const JsonEncoder.withIndent('  ').convert(resultData);
    } else {
      displayText = resultData?.toString() ?? 'null';
    }

    // Truncate long results
    const maxLength = 500;
    final isTruncated = displayText.length > maxLength;
    if (isTruncated) {
      displayText = '${displayText.substring(0, maxLength)}...';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: result.isError
            ? colorScheme.errorContainer.withValues(alpha: 0.3)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: result.isError
            ? Border.all(color: colorScheme.error.withValues(alpha: 0.3))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              displayText,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: result.isError ? colorScheme.error : colorScheme.onSurface,
              ),
            ),
          ),
          if (isTruncated) ...[
            const SizedBox(height: 4),
            Text(
              '(truncated)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
