import 'package:flutter/material.dart';
import 'package:vide_client/vide_client.dart';

import '../../../core/theme/vide_colors.dart';

enum FileGitStatus { modified, staged, untracked, none }

class FileListTile extends StatelessWidget {
  final FileEntry entry;
  final String rootPath;
  final GitStatusInfo? gitStatus;
  final VoidCallback? onTap;

  const FileListTile({
    super.key,
    required this.entry,
    required this.rootPath,
    this.gitStatus,
    this.onTap,
  });

  FileGitStatus _getFileGitStatus() {
    if (gitStatus == null) return FileGitStatus.none;
    if (entry.path.length <= rootPath.length) return FileGitStatus.none;

    // Get relative path from root
    final relativePath = entry.path.startsWith(rootPath)
        ? entry.path.substring(rootPath.length + 1)
        : entry.path;

    if (gitStatus!.stagedFiles.contains(relativePath)) {
      return FileGitStatus.staged;
    }
    if (gitStatus!.modifiedFiles.contains(relativePath)) {
      return FileGitStatus.modified;
    }
    if (gitStatus!.untrackedFiles.contains(relativePath)) {
      return FileGitStatus.untracked;
    }

    // Check if any changed file starts with this directory's relative path
    if (entry.isDirectory) {
      final dirPrefix = '$relativePath/';
      final hasChangedChildren =
          gitStatus!.allChangedFiles.any((f) => f.startsWith(dirPrefix));
      if (hasChangedChildren) return FileGitStatus.modified;
    }

    return FileGitStatus.none;
  }

  @override
  Widget build(BuildContext context) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final fileStatus = _getFileGitStatus();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              entry.isDirectory
                  ? Icons.folder
                  : Icons.insert_drive_file_outlined,
              size: 20,
              color: entry.isDirectory
                  ? videColors.accent
                  : videColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                entry.name,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (fileStatus != FileGitStatus.none)
              _StatusBadge(status: fileStatus, videColors: videColors),
            if (entry.isDirectory)
              Icon(
                Icons.chevron_right,
                size: 18,
                color: videColors.textTertiary,
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final FileGitStatus status;
  final VideThemeColors videColors;

  const _StatusBadge({required this.status, required this.videColors});

  @override
  Widget build(BuildContext context) {
    final (String label, Color color) = switch (status) {
      FileGitStatus.modified => ('M', videColors.warning),
      FileGitStatus.staged => ('A', videColors.success),
      FileGitStatus.untracked => ('?', videColors.textSecondary),
      FileGitStatus.none => ('', Colors.transparent),
    };

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        width: 20,
        height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}
