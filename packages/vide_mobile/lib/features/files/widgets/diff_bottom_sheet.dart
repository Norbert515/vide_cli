import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/vide_colors.dart';

class DiffBottomSheet extends StatelessWidget {
  final String fileName;
  final String diff;

  const DiffBottomSheet({
    super.key,
    required this.fileName,
    required this.diff,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final videColors = Theme.of(context).extension<VideThemeColors>()!;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        final lines = diff.split('\n');

        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(VideRadius.lg),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.all(VideSpacing.md),
                child: Row(
                  children: [
                    Icon(
                      Icons.difference_outlined,
                      size: 18,
                      color: videColors.accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fileName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: colorScheme.outlineVariant),
              // Diff content
              Expanded(
                child: diff.isEmpty
                    ? Center(
                        child: Text(
                          'No diff available',
                          style: TextStyle(color: videColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(VideSpacing.sm),
                        itemCount: lines.length,
                        itemBuilder: (context, index) {
                          return _DiffLine(
                            line: lines[index],
                            videColors: videColors,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DiffLine extends StatelessWidget {
  final String line;
  final VideThemeColors videColors;

  const _DiffLine({required this.line, required this.videColors});

  @override
  Widget build(BuildContext context) {
    final Color textColor;
    final Color? bgColor;

    if (line.startsWith('+')) {
      textColor = videColors.success;
      bgColor = videColors.successContainer;
    } else if (line.startsWith('-')) {
      textColor = videColors.error;
      bgColor = videColors.errorContainer;
    } else if (line.startsWith('@@')) {
      textColor = videColors.info;
      bgColor = videColors.infoContainer;
    } else if (line.startsWith('diff ') || line.startsWith('index ')) {
      textColor = videColors.textTertiary;
      bgColor = null;
    } else {
      textColor = Theme.of(context).colorScheme.onSurface;
      bgColor = null;
    }

    return Container(
      width: double.infinity,
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: SelectableText(
        line,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 12,
          color: textColor,
          height: 1.5,
        ),
      ),
    );
  }
}
