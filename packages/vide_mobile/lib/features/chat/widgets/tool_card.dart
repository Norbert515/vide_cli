import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:vide_client/vide_client.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/vide_colors.dart';

/// Braille spinner for in-progress tool calls.
class _BrailleSpinner extends StatefulWidget {
  final Color color;

  const _BrailleSpinner({required this.color});

  @override
  State<_BrailleSpinner> createState() => _BrailleSpinnerState();
}

class _BrailleSpinnerState extends State<_BrailleSpinner>
    with SingleTickerProviderStateMixin {
  static const _frames = [
    '\u280B',
    '\u2819',
    '\u2839',
    '\u2838',
    '\u283C',
    '\u2834',
    '\u2826',
    '\u2827',
    '\u2807',
    '\u280F',
  ];

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final frameIndex =
            (_controller.value * _frames.length).floor() % _frames.length;
        return Text(
          _frames[frameIndex],
          style: TextStyle(fontSize: 12, color: widget.color),
        );
      },
    );
  }
}

/// A compact, dense card displaying a tool invocation.
/// Shows tool name + contextual subtitle. Tap opens full detail page.
class ToolCard extends StatelessWidget {
  final ToolContent tool;
  final VoidCallback? onTap;

  const ToolCard({
    super.key,
    required this.tool,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final videColors = Theme.of(context).extension<VideThemeColors>()!;
    final hasResult = tool.result != null;
    final isError = tool.isError;

    final statusColor = isError
        ? videColors.error
        : hasResult
            ? videColors.success
            : videColors.accent;

    final displayName = _toolDisplayName(tool.toolName);
    final subtitle = _toolSubtitle(tool);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: VideSpacing.sm,
        vertical: 2,
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: VideRadius.smAll,
            border: Border(
              left: BorderSide(color: statusColor, width: 2),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Icon(
                _statusIcon(hasResult, isError),
                size: 14,
                color: statusColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: videColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (!hasResult)
                _BrailleSpinner(color: videColors.textTertiary)
              else
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: videColors.textTertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _statusIcon(bool hasResult, bool isError) {
    if (isError) return Icons.error_outline;
    if (hasResult) return Icons.check;
    return Icons.play_arrow;
  }
}

/// Extracts a human-friendly display name from a raw tool name.
String _toolDisplayName(String toolName) {
  // Strip MCP prefixes like "mcp__vide-agent__" or "mcp__flutter-runtime__"
  final mcpPrefix = RegExp(r'^mcp__[^_]+__');
  final stripped = toolName.replaceFirst(mcpPrefix, '');
  return stripped;
}

/// Extracts a contextual subtitle from the tool input.
String? _toolSubtitle(ToolContent tool) {
  final input = tool.toolInput;
  final toolName = _toolDisplayName(tool.toolName);

  switch (toolName) {
    case 'Read':
      return input['file_path'] as String?;
    case 'Edit':
      return input['file_path'] as String?;
    case 'Write':
      return input['file_path'] as String?;
    case 'Bash':
      final cmd = input['command'] as String?;
      return cmd;
    case 'Grep':
      final pattern = input['pattern'] as String?;
      final path = input['path'] as String?;
      if (pattern != null && path != null) return '"$pattern" in $path';
      return pattern != null ? '"$pattern"' : null;
    case 'Glob':
      return input['pattern'] as String?;
    case 'WebFetch':
      return input['url'] as String?;
    case 'WebSearch':
      return input['query'] as String?;
    case 'TodoWrite':
      return null;
    case 'Task':
      return input['description'] as String?;
    case 'NotebookEdit':
      return input['notebook_path'] as String?;
    default:
      // For unknown tools, try common field names
      return input['file_path'] as String? ??
          input['command'] as String? ??
          input['pattern'] as String? ??
          input['query'] as String? ??
          input['description'] as String?;
  }
}

/// Full-screen detail view for a tool invocation.
class ToolDetailScreen extends StatelessWidget {
  final ToolContent tool;

  const ToolDetailScreen({
    super.key,
    required this.tool,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final videColors = Theme.of(context).extension<VideThemeColors>()!;
    final hasResult = tool.result != null;
    final isError = tool.isError;

    final statusColor = isError
        ? videColors.error
        : hasResult
            ? videColors.success
            : videColors.accent;

    final displayName = _toolDisplayName(tool.toolName);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(displayName),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(VideSpacing.md),
        children: [
          _SectionLabel(
            label: 'Input',
            color: videColors.accent,
          ),
          const SizedBox(height: 4),
          _CodeBlock(
            text: const JsonEncoder.withIndent('  ').convert(tool.toolInput),
            backgroundColor: colorScheme.surfaceContainerHighest,
            borderColor: colorScheme.outlineVariant,
            textColor: colorScheme.onSurface,
          ),
          if (hasResult) ...[
            const SizedBox(height: VideSpacing.md),
            _SectionLabel(
              label: isError ? 'Error' : 'Result',
              color: isError ? videColors.error : videColors.success,
            ),
            const SizedBox(height: 4),
            _CodeBlock(
              text: _formatResult(tool.result),
              backgroundColor: isError
                  ? videColors.errorContainer
                  : colorScheme.surfaceContainerHighest,
              borderColor: isError
                  ? videColors.error.withValues(alpha: 0.3)
                  : colorScheme.outlineVariant,
              textColor: isError ? videColors.error : colorScheme.onSurface,
            ),
          ],
        ],
      ),
    );
  }

  String _formatResult(dynamic resultData) {
    if (resultData is Map || resultData is List) {
      return const JsonEncoder.withIndent('  ').convert(resultData);
    }
    return resultData?.toString() ?? 'null';
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;

  const _SectionLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  final String text;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;

  const _CodeBlock({
    required this.text,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: VideRadius.smAll,
        border: Border.all(color: borderColor),
      ),
      child: SelectableText(
        text,
        style: TextStyle(
          fontSize: 12,
          color: textColor,
        ),
      ),
    );
  }
}
