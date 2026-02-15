import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vide_client/vide_client.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/vide_colors.dart';
import '../../data/repositories/server_registry.dart';
import '../files/utils/diff_utils.dart';
import '../files/widgets/diff_bottom_sheet.dart';
import 'git_state.dart';

class GitScreen extends ConsumerWidget {
  final String sessionId;
  final String workingDirectory;

  const GitScreen({
    super.key,
    required this.sessionId,
    required this.workingDirectory,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gitNotifierProvider(workingDirectory));
    final notifier = ref.read(gitNotifierProvider(workingDirectory).notifier);
    final videColors = Theme.of(context).extension<VideThemeColors>()!;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Git'),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? _ErrorView(
                  error: state.error!,
                  onRetry: () => notifier.refresh(),
                )
              : RefreshIndicator(
                  onRefresh: () => notifier.refresh(),
                  child: ListView(
                    children: [
                      if (state.status != null)
                        _BranchHeader(status: state.status!),
                      if (state.status != null && state.status!.hasChanges) ...[
                        _ChangesSection(
                          status: state.status!,
                          repoPath: workingDirectory,
                          onStage: (files) => notifier.stageFiles(files),
                          onFileTap: (relativePath, {required bool staged}) =>
                              _showDiff(
                            context,
                            ref,
                            relativePath,
                            staged: staged,
                          ),
                        ),
                      ],
                      if (state.commits.isNotEmpty)
                        _CommitsSection(commits: state.commits),
                      if (state.status != null &&
                          !state.status!.hasChanges &&
                          state.commits.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              'No changes or commits',
                              style: TextStyle(
                                color: videColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Future<void> _showDiff(
    BuildContext context,
    WidgetRef ref,
    String relativePath, {
    bool staged = false,
  }) async {
    final registry = ref.read(serverRegistryProvider.notifier);
    final connected = registry.connectedEntries;
    if (connected.isEmpty) return;
    final client = connected.first.client;
    if (client == null) return;

    final fullDiff = await client.gitDiff(workingDirectory, staged: staged);
    final fileDiff = filterDiffForFile(fullDiff, relativePath);

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DiffBottomSheet(
        fileName: relativePath.split('/').last,
        diff: fileDiff,
      ),
    );
  }

}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: colorScheme.error),
          const SizedBox(height: 16),
          Text('Failed to load git status',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(error,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _BranchHeader extends StatelessWidget {
  final GitStatusInfo status;

  const _BranchHeader({required this.status});

  @override
  Widget build(BuildContext context) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VideSpacing.md,
        vertical: VideSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.commit, size: 20, color: videColors.accent),
          const SizedBox(width: 8),
          Text(
            status.branch,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          if (status.ahead > 0)
            _SyncBadge(
              icon: Icons.arrow_upward,
              count: status.ahead,
              color: videColors.success,
              label: 'to push',
            ),
          if (status.ahead > 0 && status.behind > 0) const SizedBox(width: 8),
          if (status.behind > 0)
            _SyncBadge(
              icon: Icons.arrow_downward,
              count: status.behind,
              color: videColors.warning,
              label: 'to pull',
            ),
        ],
      ),
    );
  }
}

class _SyncBadge extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;
  final String label;

  const _SyncBadge({
    required this.icon,
    required this.count,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(VideRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$count $label',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangesSection extends StatelessWidget {
  final GitStatusInfo status;
  final String repoPath;
  final void Function(List<String> files) onStage;
  final void Function(String relativePath, {required bool staged}) onFileTap;

  const _ChangesSection({
    required this.status,
    required this.repoPath,
    required this.onStage,
    required this.onFileTap,
  });

  @override
  Widget build(BuildContext context) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;

    final unstaged = [...status.modifiedFiles, ...status.untrackedFiles];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (status.stagedFiles.isNotEmpty) ...[
          _SectionHeader(
            title: 'Staged Changes',
            count: status.stagedFiles.length,
            color: videColors.success,
          ),
          ...status.stagedFiles.map(
            (file) => _ChangeFileTile(
              fileName: file,
              status: 'A',
              statusColor: videColors.success,
              onTap: () => onFileTap(file, staged: true),
            ),
          ),
        ],
        if (unstaged.isNotEmpty) ...[
          _SectionHeader(
            title: 'Unstaged Changes',
            count: unstaged.length,
            color: videColors.warning,
            action: TextButton.icon(
              onPressed: () => onStage(unstaged),
              icon: Icon(Icons.add, size: 16, color: videColors.accent),
              label: Text(
                'Stage All',
                style: TextStyle(fontSize: 12, color: videColors.accent),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          ...status.modifiedFiles.map(
            (file) => _ChangeFileTile(
              fileName: file,
              status: 'M',
              statusColor: videColors.warning,
              onTap: () => onFileTap(file, staged: false),
              trailing: IconButton(
                icon: Icon(Icons.add, size: 18, color: videColors.accent),
                onPressed: () => onStage([file]),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Stage',
              ),
            ),
          ),
          ...status.untrackedFiles.map(
            (file) => _ChangeFileTile(
              fileName: file,
              status: '?',
              statusColor: videColors.textSecondary,
              onTap: () => onFileTap(file, staged: false),
              trailing: IconButton(
                icon: Icon(Icons.add, size: 18, color: videColors.accent),
                onPressed: () => onStage([file]),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Stage',
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final Widget? action;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.color,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        VideSpacing.md,
        VideSpacing.md,
        VideSpacing.md,
        VideSpacing.xs,
      ),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(VideRadius.pill),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          const Spacer(),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class _ChangeFileTile extends StatelessWidget {
  final String fileName;
  final String status;
  final Color statusColor;
  final VoidCallback onTap;
  final Widget? trailing;

  const _ChangeFileTile({
    required this.fileName,
    required this.status,
    required this.statusColor,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                fileName,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface,
                  fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _CommitsSection extends StatelessWidget {
  final List<GitCommitInfo> commits;

  const _CommitsSection({required this.commits});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            VideSpacing.md,
            VideSpacing.md,
            VideSpacing.md,
            VideSpacing.xs,
          ),
          child: Text(
            'Recent Commits',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        ...commits.map(
          (commit) => _CommitTile(commit: commit),
        ),
      ],
    );
  }
}

class _CommitTile extends StatelessWidget {
  final GitCommitInfo commit;

  const _CommitTile({required this.commit});

  String _relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${diff.inDays ~/ 7}w ago';
    return '${diff.inDays ~/ 30}mo ago';
  }

  @override
  Widget build(BuildContext context) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            commit.hash.length >= 7
                ? commit.hash.substring(0, 7)
                : commit.hash,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              color: videColors.accent,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  commit.message,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${commit.author} · ${_relativeTime(commit.date)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: videColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
