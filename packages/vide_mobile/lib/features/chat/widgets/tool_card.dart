import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/vide_colors.dart';
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
    final videColors = Theme.of(context).extension<VideThemeColors>()!;
    final hasResult = widget.result != null;
    final isError = widget.result?.isError ?? false;

    final statusColor = isError
        ? videColors.error
        : hasResult
            ? videColors.success
            : videColors.accent;

    final statusContainerColor = isError
        ? videColors.errorContainer
        : hasResult
            ? videColors.successContainer
            : videColors.accentSubtle;

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
            left: BorderSide(color: statusColor, width: 3),
          ),
        ),
        child: InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: VideRadius.smAll,
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
                        color: statusContainerColor,
                        borderRadius: VideRadius.smAll,
                      ),
                      child: Icon(
                        isError
                            ? Icons.error_outline
                            : hasResult
                                ? Icons.check_circle_outline
                                : Icons.sync,
                        size: 18,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.toolUse.toolName,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          if (widget.toolUse.agentName != null)
                            Text(
                              'by ${widget.toolUse.agentName}',
                              style: TextStyle(
                                fontSize: 12,
                                color: videColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: videColors.textSecondary,
                    ),
                  ],
                ),
                if (_isExpanded) ...[
                  const SizedBox(height: 12),
                  Divider(height: 1, color: colorScheme.outlineVariant),
                  const SizedBox(height: 12),
                  Text(
                    'Input',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: videColors.accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _JsonView(json: widget.toolUse.input),
                  if (hasResult) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Result',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isError ? videColors.error : videColors.success,
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
        borderRadius: VideRadius.smAll,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(
          prettyJson,
          style: TextStyle(
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
    final videColors = Theme.of(context).extension<VideThemeColors>()!;
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
            ? videColors.errorContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: VideRadius.smAll,
        border: Border.all(
          color: result.isError
              ? videColors.error.withValues(alpha: 0.3)
              : colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              displayText,
              style: TextStyle(
                fontSize: 12,
                color:
                    result.isError ? videColors.error : colorScheme.onSurface,
              ),
            ),
          ),
          if (isTruncated) ...[
            const SizedBox(height: 4),
            Text(
              '(truncated)',
              style: TextStyle(
                fontSize: 12,
                color: videColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
