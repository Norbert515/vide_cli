import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vide_client/vide_client.dart';
import 'package:vide_mobile/core/theme/tokens.dart';
import 'package:vide_mobile/core/theme/vide_colors.dart';
import 'package:vide_mobile/features/files/utils/diff_utils.dart';
import 'package:vide_mobile/features/files/widgets/diff_bottom_sheet.dart';

/// Git status and history view for the in-app SDK.
///
/// Uses [VideClient] directly (no Riverpod) to fetch git status, recent
/// commits, and diffs.
class GitView extends StatefulWidget {
  final VideClient client;
  final String workingDirectory;

  const GitView({
    super.key,
    required this.client,
    required this.workingDirectory,
  });

  @override
  State<GitView> createState() => _GitViewState();
}

class _GitViewState extends State<GitView> {
  GitStatusInfo? _status;
  List<GitCommitInfo> _commits = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        widget.client.gitStatus(widget.workingDirectory, detailed: true),
        widget.client.gitLog(widget.workingDirectory),
      ]);

      if (mounted) {
        setState(() {
          _status = results[0] as GitStatusInfo;
          _commits = results[1] as List<GitCommitInfo>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _stageFiles(List<String> files) async {
    try {
      await widget.client.gitStage(widget.workingDirectory, files);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to stage files: $e')),
      );
    }
  }

  Future<void> _showDiff(String relativePath, {bool staged = false}) async {
    final fullDiff =
        await widget.client.gitDiff(widget.workingDirectory, staged: staged);
    final fileDiff = filterDiffForFile(fullDiff, relativePath);

    if (!mounted) return;

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

  @override
  Widget build(BuildContext context) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: VideSpacing.sm,
            vertical: VideSpacing.xs,
          ),
          child: Row(
            children: [
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Git',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              GestureDetector(
                onTap: _load,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.refresh,
                    size: 20,
                    color: videColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline,
                                size: 32, color: colorScheme.error),
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              style: TextStyle(
                                color: videColors.textSecondary,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            FilledButton.tonal(
                              onPressed: _load,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        children: [
                          if (_status != null)
                            _BranchHeader(status: _status!),
                          if (_status != null && _status!.hasChanges)
                            _ChangesSection(
                              status: _status!,
                              onStage: _stageFiles,
                              onFileTap: _showDiff,
                              videColors: videColors,
                            ),
                          if (_commits.isNotEmpty)
                            _CommitsSection(
                              commits: _commits,
                              videColors: videColors,
                              colorScheme: colorScheme,
                            ),
                          if (_status != null &&
                              !_status!.hasChanges &&
                              _commits.isEmpty)
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
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Branch header
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Changes section
// ---------------------------------------------------------------------------

class _ChangesSection extends StatelessWidget {
  final GitStatusInfo status;
  final void Function(List<String> files) onStage;
  final void Function(String relativePath, {required bool staged}) onFileTap;
  final VideThemeColors videColors;

  const _ChangesSection({
    required this.status,
    required this.onStage,
    required this.onFileTap,
    required this.videColors,
  });

  @override
  Widget build(BuildContext context) {
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
              trailing: GestureDetector(
                onTap: () => onStage([file]),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.add, size: 18, color: videColors.accent),
                ),
              ),
            ),
          ),
          ...status.untrackedFiles.map(
            (file) => _ChangeFileTile(
              fileName: file,
              status: '?',
              statusColor: videColors.textSecondary,
              onTap: () => onFileTap(file, staged: false),
              trailing: GestureDetector(
                onTap: () => onStage([file]),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.add, size: 18, color: videColors.accent),
                ),
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

// ---------------------------------------------------------------------------
// Commits section
// ---------------------------------------------------------------------------

class _CommitsSection extends StatelessWidget {
  final List<GitCommitInfo> commits;
  final VideThemeColors videColors;
  final ColorScheme colorScheme;

  const _CommitsSection({
    required this.commits,
    required this.videColors,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
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
          (commit) => _CommitTile(
            commit: commit,
            videColors: videColors,
            colorScheme: colorScheme,
          ),
        ),
      ],
    );
  }
}

class _CommitTile extends StatelessWidget {
  final GitCommitInfo commit;
  final VideThemeColors videColors;
  final ColorScheme colorScheme;

  const _CommitTile({
    required this.commit,
    required this.videColors,
    required this.colorScheme,
  });

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
