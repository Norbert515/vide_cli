import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/vide_colors.dart';

class FileContentBottomSheet extends StatelessWidget {
  final String fileName;
  final String content;
  final bool isChanged;
  final VoidCallback? onViewDiff;

  const FileContentBottomSheet({
    super.key,
    required this.fileName,
    required this.content,
    this.isChanged = false,
    this.onViewDiff,
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
        final lines = content.split('\n');

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
                      Icons.insert_drive_file_outlined,
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
                    if (isChanged && onViewDiff != null)
                      TextButton.icon(
                        onPressed: onViewDiff,
                        icon: Icon(
                          Icons.difference_outlined,
                          size: 16,
                          color: videColors.warning,
                        ),
                        label: Text(
                          'Diff',
                          style: TextStyle(
                            fontSize: 12,
                            color: videColors.warning,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                  ],
                ),
              ),
              Divider(height: 1, color: colorScheme.outlineVariant),
              // File content
              Expanded(
                child: content.isEmpty
                    ? Center(
                        child: Text(
                          'Empty file',
                          style: TextStyle(color: videColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(VideSpacing.sm),
                        itemCount: lines.length,
                        itemBuilder: (context, index) {
                          return _ContentLine(
                            lineNumber: index + 1,
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

class _ContentLine extends StatelessWidget {
  final int lineNumber;
  final String line;
  final VideThemeColors videColors;

  const _ContentLine({
    required this.lineNumber,
    required this.line,
    required this.videColors,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 40,
          child: Text(
            '$lineNumber',
            textAlign: TextAlign.right,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              color: videColors.textTertiary,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SelectableText(
            line,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
