import 'package:nocterm/nocterm.dart';
import 'package:path/path.dart' as p;
import 'package:vide_core/vide_core.dart' show GitBranch, GitStatus;
import 'package:vide_cli/modules/git/models/git_sidebar_models.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_cli/constants/text_opacity.dart';

/// Returns the staged file color appropriate for the theme brightness.
Color getStagedColor(VideThemeData theme) {
  return theme.base.brightness == Brightness.light
      ? const Color(0x2E8B7A) // Dark teal for light bg
      : const Color(0x4EC9B0); // Bright teal for dark bg
}

/// Returns the modified file color appropriate for the theme brightness.
Color getModifiedColor(VideThemeData theme) {
  return theme.base.brightness == Brightness.light
      ? const Color(0xB5994D) // Dark goldenrod for light bg
      : const Color(0xDCDCAA); // Soft yellow for dark bg
}

/// Returns the git accent color appropriate for the theme brightness.
Color getAccentColor(VideThemeData theme) {
  return theme.base.brightness == Brightness.light
      ? const Color(0x9B4D96) // Dark magenta for light bg
      : const Color(0xC586C0); // Light magenta for dark bg
}

/// Returns a colored dot indicator for file status.
/// ● (filled) for staged/modified, ○ (hollow) for untracked.
String getStatusDot(String? status) {
  switch (status) {
    case 'staged':
    case 'modified':
      return '●';
    case 'untracked':
      return '○';
    default:
      return ' ';
  }
}

/// Returns the color for a file status indicator.
Color getStatusColor(String? status, VideThemeData theme) {
  switch (status) {
    case 'staged':
      return getStagedColor(theme);
    case 'modified':
      return getModifiedColor(theme);
    case 'untracked':
      return theme.base.onSurface.withOpacity(TextOpacity.secondary);
    default:
      return theme.base.onSurface;
  }
}

/// Builds a quick action row (+ New branch..., + New worktree...).
Component buildQuickActionRow({
  required NavigableItem item,
  required bool isSelected,
  required bool isHovered,
  required VideThemeData theme,
  required int availableWidth,
  required QuickActionState branchActionState,
  required QuickActionState worktreeActionState,
  required NavigableItemType? activeInputType,
  required String inputBuffer,
  required Map<String, QuickActionState> repoBranchActionState,
  required Map<String, QuickActionState> repoWorktreeActionState,
  required Map<String, NavigableItemType?> repoActiveInputType,
}) {
  final highlight = isSelected || isHovered;
  final repoPath = item.worktreePath;
  final isBranchAction = item.type == NavigableItemType.newBranchAction;

  // Determine action state based on single-repo or multi-repo mode
  QuickActionState actionState;
  bool isEnteringName;
  bool isExpanded;

  if (repoPath != null) {
    // Multi-repo mode
    actionState = isBranchAction
        ? (repoBranchActionState[repoPath] ?? QuickActionState.collapsed)
        : (repoWorktreeActionState[repoPath] ?? QuickActionState.collapsed);
    isEnteringName =
        actionState == QuickActionState.enteringName &&
        repoActiveInputType[repoPath] == item.type;
    isExpanded = actionState != QuickActionState.collapsed;
  } else {
    // Single-repo mode
    actionState = isBranchAction ? branchActionState : worktreeActionState;
    isEnteringName =
        actionState == QuickActionState.enteringName &&
        activeInputType == item.type;
    isExpanded = actionState != QuickActionState.collapsed;
  }

  // Determine display text based on state
  String displayText;
  if (isEnteringName) {
    // Show input mode with selected base branch
    final actionName = isBranchAction ? 'branch' : 'worktree';
    displayText = '  $actionName: $inputBuffer│'; // │ is cursor
  } else if (isExpanded) {
    // Show expanded state with collapse indicator
    final actionName = isBranchAction ? 'New branch' : 'New worktree';
    displayText = '▾ $actionName from...';
  } else {
    // Show collapsed state
    final actionName = isBranchAction ? 'New branch' : 'New worktree';
    displayText = '▸ $actionName...';
  }

  return Container(
    decoration: highlight
        ? BoxDecoration(
            color: theme.base.primary.withOpacity(isSelected ? 0.3 : 0.15),
          )
        : null,
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 1),
      child: Text(
        displayText,
        style: TextStyle(
          color: isEnteringName
              ? theme.base.primary
              : theme.base.onSurface.withOpacity(TextOpacity.secondary),
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    ),
  );
}

/// Builds a base branch option row (shown when selecting which branch to base from).
Component buildBaseBranchOptionRow({
  required NavigableItem item,
  required bool isSelected,
  required bool isHovered,
  required VideThemeData theme,
  required int availableWidth,
}) {
  final highlight = isSelected || isHovered;
  final isOther = item.name == 'Other...';

  return Container(
    decoration: highlight
        ? BoxDecoration(
            color: theme.base.primary.withOpacity(isSelected ? 0.3 : 0.15),
          )
        : null,
    child: Padding(
      padding: EdgeInsets.only(left: 3), // Indent under parent action
      child: Row(
        children: [
          Text(
            isOther ? '…' : '',
            style: TextStyle(
              color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
            ),
          ),
          SizedBox(width: isOther ? 1 : 2),
          Expanded(
            child: Text(
              item.name,
              style: TextStyle(
                color: isOther
                    ? theme.base.onSurface.withOpacity(TextOpacity.tertiary)
                    : theme.base.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Builds a worktree header row (collapsible section for each worktree).
Component buildWorktreeHeaderRow({
  required NavigableItem item,
  required bool isSelected,
  required bool isHovered,
  required VideThemeData theme,
  required int availableWidth,
  required GitStatus? gitStatus,
  required bool isCurrentWorktree,
}) {
  final isExpanded = item.isExpanded;
  final expandIcon = isExpanded ? '▾' : '▸';
  final highlight = isSelected || isHovered;
  final isWorktree = item.isWorktree;

  // Count total changes
  final changeCount = gitStatus != null
      ? gitStatus.modifiedFiles.length +
            gitStatus.stagedFiles.length +
            gitStatus.untrackedFiles.length
      : 0;

  // Current worktree uses primary color, others use default
  final branchColor = isCurrentWorktree
      ? theme.base.primary
      : theme.base.onSurface;

  // Show branch icon: ⎇ for worktrees,  for main repo
  final branchIcon = isWorktree ? '⎇' : '';

  return Column(
    children: [
      SizedBox(height: 1), // Top padding outside selection
      Container(
        decoration: highlight
            ? BoxDecoration(
                color: theme.base.primary.withOpacity(isSelected ? 0.3 : 0.15),
              )
            : BoxDecoration(color: theme.base.outlineVariant),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 1),
          child: Row(
            children: [
              Text(expandIcon, style: TextStyle(color: branchColor)),
              SizedBox(width: 1),
              Text(
                branchIcon,
                style: TextStyle(
                  color: isCurrentWorktree
                      ? theme.base.primary
                      : getAccentColor(theme),
                ),
              ),
              SizedBox(width: 1),
              Expanded(
                child: Text(
                  item.name,
                  style: TextStyle(
                    color: branchColor,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              // Show change count when collapsed (and has changes)
              if (!isExpanded && changeCount > 0)
                Text(
                  ' $changeCount',
                  style: TextStyle(color: getModifiedColor(theme)),
                ),
              // Ahead/behind indicators
              if (gitStatus != null) ...[
                if (gitStatus.ahead > 0)
                  Text(
                    ' ↑${gitStatus.ahead}',
                    style: TextStyle(color: theme.base.success),
                  ),
                if (gitStatus.behind > 0)
                  Text(
                    ' ↓${gitStatus.behind}',
                    style: TextStyle(color: getModifiedColor(theme)),
                  ),
              ],
            ],
          ),
        ),
      ),
    ],
  );
}

/// Builds the "Actions" header row (expandable).
Component buildActionsHeaderRow({
  required NavigableItem item,
  required bool isSelected,
  required bool isHovered,
  required VideThemeData theme,
  required int availableWidth,
  required bool actionsExpanded,
  required bool isMultiRepoMode,
  required Map<String, bool> repoActionsExpanded,
}) {
  final highlight = isSelected || isHovered;
  // Use per-repo expansion state in multi-repo mode
  final repoPath = item.worktreePath;
  final isExpanded = (repoPath != null && isMultiRepoMode)
      ? (repoActionsExpanded[repoPath] ?? false)
      : actionsExpanded;
  final arrow = isExpanded ? '▾' : '▸';

  return Container(
    decoration: highlight
        ? BoxDecoration(
            color: theme.base.primary.withOpacity(isSelected ? 0.3 : 0.15),
          )
        : null,
    child: Padding(
      padding: EdgeInsets.only(left: 2),
      child: Row(
        children: [
          Text(
            '$arrow Actions',
            style: TextStyle(
              color: theme.base.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Builds the "Actions" header row for non-current worktrees (expandable).
Component buildWorktreeActionsHeaderRow({
  required NavigableItem item,
  required bool isSelected,
  required bool isHovered,
  required VideThemeData theme,
  required int availableWidth,
}) {
  final highlight = isSelected || isHovered;
  final isExpanded = item.isExpanded;
  final arrow = isExpanded ? '▾' : '▸';

  return Container(
    decoration: highlight
        ? BoxDecoration(
            color: theme.base.primary.withOpacity(isSelected ? 0.3 : 0.15),
          )
        : null,
    child: Padding(
      padding: EdgeInsets.only(left: 2),
      child: Row(
        children: [
          Text(
            '$arrow Actions',
            style: TextStyle(
              color: theme.base.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Builds the "Changes (5)" label row.
Component buildChangesSectionLabelRow({
  required NavigableItem item,
  required bool isSelected,
  required bool isHovered,
  required VideThemeData theme,
  required int availableWidth,
}) {
  final highlight = isSelected || isHovered;
  final countDisplay = item.fileCount > 0 ? ' (${item.fileCount})' : '';

  return Container(
    decoration: highlight
        ? BoxDecoration(
            color: theme.base.primary.withOpacity(isSelected ? 0.3 : 0.15),
          )
        : null,
    child: Padding(
      padding: EdgeInsets.only(left: 2),
      child: Text(
        '${item.name}$countDisplay',
        style: TextStyle(
          color: theme.base.onSurface.withOpacity(TextOpacity.secondary),
        ),
      ),
    ),
  );
}

/// Builds a repository header row for multi-repo mode.
Component buildRepoHeaderRow({
  required NavigableItem item,
  required bool isSelected,
  required bool isHovered,
  required VideThemeData theme,
  required int availableWidth,
  required GitStatus? status,
}) {
  final isExpanded = item.isExpanded;
  final expandIcon = isExpanded ? '▾' : '▸';
  final highlight = isSelected || isHovered;

  // Use fileCount from NavigableItem for collapsed count
  // Fall back to live count if expanded
  final changeCount = isExpanded && status != null
      ? status.modifiedFiles.length +
            status.stagedFiles.length +
            status.untrackedFiles.length
      : item.fileCount;

  return Column(
    children: [
      SizedBox(height: 1), // Top padding outside selection
      Container(
        decoration: highlight
            ? BoxDecoration(
                color: theme.base.primary.withOpacity(isSelected ? 0.3 : 0.15),
              )
            : BoxDecoration(color: theme.base.outlineVariant),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 1),
          child: Row(
            children: [
              Text(expandIcon, style: TextStyle(color: theme.base.onSurface)),
              SizedBox(width: 1),
              Text('', style: TextStyle(color: getAccentColor(theme))),
              SizedBox(width: 1),
              Flexible(
                flex: 2,
                child: Text(
                  item.name,
                  style: TextStyle(
                    color: theme.base.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              // Show branch info
              if (status != null) ...[
                Flexible(
                  flex: 1,
                  child: Text(
                    ' ${status.branch}',
                    style: TextStyle(
                      color: theme.base.onSurface.withOpacity(
                        TextOpacity.secondary,
                      ),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
              // Ahead/behind indicators
              if (status != null &&
                  (status.ahead > 0 || status.behind > 0)) ...[
                if (status.behind > 0)
                  Text(
                    ' ↓${status.behind}',
                    style: TextStyle(color: getModifiedColor(theme)),
                  ),
                if (status.ahead > 0)
                  Text(
                    ' ↑${status.ahead}',
                    style: TextStyle(color: theme.base.success),
                  ),
              ],
              // Show change count when collapsed (and has changes)
              if (!isExpanded && changeCount > 0)
                Text(
                  ' $changeCount',
                  style: TextStyle(color: getModifiedColor(theme)),
                ),
            ],
          ),
        ),
      ),
    ],
  );
}

/// Builds a visual divider row.
Component buildDividerRow({
  required VideThemeData theme,
  required int availableWidth,
}) {
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: 1),
    child: Text(
      '─' * (availableWidth - 2),
      style: TextStyle(color: theme.base.outlineVariant),
    ),
  );
}

/// Builds a file row with filename prominently displayed.
Component buildFileRow({
  required NavigableItem item,
  required bool isSelected,
  required bool isHovered,
  required VideThemeData theme,
  required int availableWidth,
}) {
  final statusDot = getStatusDot(item.status);
  final dotColor = getStatusColor(item.status, theme);
  final fileName = p.basename(item.name);
  final highlight = isSelected || isHovered;

  return Container(
    decoration: highlight
        ? BoxDecoration(
            color: theme.base.primary.withOpacity(isSelected ? 0.3 : 0.15),
          )
        : null,
    child: Padding(
      padding: EdgeInsets.only(left: 2),
      child: Row(
        children: [
          Text(statusDot, style: TextStyle(color: dotColor)),
          SizedBox(width: 1),
          Expanded(
            child: Text(
              fileName,
              style: TextStyle(color: theme.base.onSurface),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Builds a "Commit & push" action row.
Component buildCommitPushActionRow({
  required NavigableItem item,
  required bool isSelected,
  required bool isHovered,
  required VideThemeData theme,
  required int availableWidth,
}) {
  final highlight = isSelected || isHovered;

  return Container(
    decoration: highlight
        ? BoxDecoration(
            color: theme.base.primary.withOpacity(isSelected ? 0.3 : 0.15),
          )
        : null,
    child: Padding(
      padding: EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Text('↑', style: TextStyle(color: theme.base.success)),
          SizedBox(width: 1),
          Expanded(
            child: Text(
              item.name,
              style: TextStyle(color: theme.base.success),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Builds a "Sync" action row.
Component buildSyncActionRow({
  required NavigableItem item,
  required bool isSelected,
  required bool isHovered,
  required VideThemeData theme,
  required int availableWidth,
  required String? loadingAction,
}) {
  final highlight = isSelected || isHovered;
  final isLoading = loadingAction == 'sync';

  return Container(
    decoration: highlight
        ? BoxDecoration(
            color: theme.base.primary.withOpacity(isSelected ? 0.3 : 0.15),
          )
        : null,
    child: Padding(
      padding: EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Text('⟳', style: TextStyle(color: theme.base.primary)),
          SizedBox(width: 1),
          Expanded(
            child: Text(
              isLoading ? 'Syncing...' : item.name,
              style: TextStyle(color: theme.base.primary),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Builds a "Merge to main" action row.
Component buildMergeToMainActionRow({
  required NavigableItem item,
  required bool isSelected,
  required bool isHovered,
  required VideThemeData theme,
  required int availableWidth,
  required String? loadingAction,
}) {
  final highlight = isSelected || isHovered;
  final isLoading = loadingAction == 'merge';

  return Container(
    decoration: highlight
        ? BoxDecoration(
            color: theme.base.primary.withOpacity(isSelected ? 0.3 : 0.15),
          )
        : null,
    child: Padding(
      padding: EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Text(
            isLoading ? '⟳' : '⤵',
            style: TextStyle(color: theme.base.primary),
          ),
          SizedBox(width: 1),
          Expanded(
            child: Text(
              isLoading ? 'Merging...' : item.name,
              style: TextStyle(color: theme.base.primary),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Builds a "Pull" action row.
Component buildPullActionRow({
  required NavigableItem item,
  required bool isSelected,
  required bool isHovered,
  required VideThemeData theme,
  required int availableWidth,
  required String? loadingAction,
}) {
  final highlight = isSelected || isHovered;
  final isLoading = loadingAction == 'pull';

  return Container(
    decoration: highlight
        ? BoxDecoration(
            color: theme.base.primary.withOpacity(isSelected ? 0.3 : 0.15),
          )
        : null,
    child: Padding(
      padding: EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Text(
            isLoading ? '⟳ ' : '↓ ',
            style: TextStyle(color: theme.base.primary),
          ),
          Text(
            isLoading ? 'Pulling...' : 'Pull',
            style: TextStyle(color: theme.base.onSurface),
          ),
        ],
      ),
    ),
  );
}

/// Builds a "Push" action row.
Component buildPushActionRow({
  required NavigableItem item,
  required bool isSelected,
  required bool isHovered,
  required VideThemeData theme,
  required int availableWidth,
  required String? loadingAction,
}) {
  final highlight = isSelected || isHovered;
  final isLoading = loadingAction == 'push';

  return Container(
    decoration: highlight
        ? BoxDecoration(
            color: theme.base.primary.withOpacity(isSelected ? 0.3 : 0.15),
          )
        : null,
    child: Padding(
      padding: EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Text(
            isLoading ? '⟳ ' : '↑ ',
            style: TextStyle(color: theme.base.primary),
          ),
          Text(
            isLoading ? 'Pushing...' : 'Push',
            style: TextStyle(color: theme.base.onSurface),
          ),
        ],
      ),
    ),
  );
}

/// Builds a "Fetch" action row.
Component buildFetchActionRow({
  required NavigableItem item,
  required bool isSelected,
  required bool isHovered,
  required VideThemeData theme,
  required int availableWidth,
  required String? loadingAction,
}) {
  final highlight = isSelected || isHovered;
  final isLoading = loadingAction == 'fetch';

  return Container(
    decoration: highlight
        ? BoxDecoration(
            color: theme.base.primary.withOpacity(isSelected ? 0.3 : 0.15),
          )
        : null,
    child: Padding(
      padding: EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Text(
            isLoading ? '⟳ ' : '⚡ ',
            style: TextStyle(color: theme.base.primary),
          ),
          Text(
            isLoading ? 'Fetching...' : 'Fetch',
            style: TextStyle(color: theme.base.onSurface),
          ),
        ],
      ),
    ),
  );
}

/// Builds a "Switch to worktree" action row.
Component buildSwitchWorktreeActionRow({
  required NavigableItem item,
  required bool isSelected,
  required bool isHovered,
  required VideThemeData theme,
  required int availableWidth,
}) {
  final highlight = isSelected || isHovered;

  return Container(
    decoration: highlight
        ? BoxDecoration(
            color: theme.base.primary.withOpacity(isSelected ? 0.3 : 0.15),
          )
        : null,
    child: Padding(
      padding: EdgeInsets.only(left: 2),
      child: Row(
        children: [
          Text('→', style: TextStyle(color: theme.base.primary)),
          SizedBox(width: 1),
          Expanded(
            child: Text(
              item.name,
              style: TextStyle(color: theme.base.primary),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Builds a "Copy path" action row for worktrees.
Component buildWorktreeCopyPathActionRow({
  required NavigableItem item,
  required bool isSelected,
  required bool isHovered,
  required VideThemeData theme,
  required int availableWidth,
}) {
  final highlight = isSelected || isHovered;

  return Container(
    decoration: highlight
        ? BoxDecoration(
            color: theme.base.primary.withOpacity(isSelected ? 0.3 : 0.15),
          )
        : null,
    child: Padding(
      padding: EdgeInsets.only(left: 2),
      child: Row(
        children: [
          Text('⎘', style: TextStyle(color: theme.base.primary)),
          SizedBox(width: 1),
          Expanded(
            child: Text(
              item.name,
              style: TextStyle(color: theme.base.primary),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Builds a "Remove worktree" action row.
Component buildWorktreeRemoveActionRow({
  required NavigableItem item,
  required bool isSelected,
  required bool isHovered,
  required VideThemeData theme,
  required int availableWidth,
  required String? loadingAction,
}) {
  final highlight = isSelected || isHovered;
  final isLoading = loadingAction == 'remove';

  return Container(
    decoration: highlight
        ? BoxDecoration(
            color: theme.base.primary.withOpacity(isSelected ? 0.3 : 0.15),
          )
        : null,
    child: Padding(
      padding: EdgeInsets.only(left: 2),
      child: Row(
        children: [
          Text(
            isLoading ? '⟳' : '✕',
            style: TextStyle(color: theme.base.error),
          ),
          SizedBox(width: 1),
          Expanded(
            child: Text(
              isLoading ? 'Removing...' : item.name,
              style: TextStyle(color: theme.base.error),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Builds a "No changes" placeholder row.
Component buildNoChangesPlaceholderRow({
  required NavigableItem item,
  required bool isSelected,
  required bool isHovered,
  required VideThemeData theme,
  required int availableWidth,
}) {
  final highlight = isSelected || isHovered;

  return Container(
    decoration: highlight
        ? BoxDecoration(
            color: theme.base.primary.withOpacity(isSelected ? 0.3 : 0.15),
          )
        : null,
    child: Padding(
      padding: EdgeInsets.only(left: 2),
      child: Text(
        item.name,
        style: TextStyle(
          color: theme.base.onSurface.withOpacity(TextOpacity.disabled),
          fontStyle: FontStyle.italic,
        ),
      ),
    ),
  );
}

/// Builds a branch section label row ("Other Branches").
Component buildBranchSectionLabelRow({
  required NavigableItem item,
  required bool isSelected,
  required bool isHovered,
  required VideThemeData theme,
  required int availableWidth,
}) {
  final highlight = isSelected || isHovered;
  return Container(
    decoration: highlight
        ? BoxDecoration(
            color: theme.base.primary.withOpacity(isSelected ? 0.3 : 0.15),
          )
        : null,
    child: Padding(
      padding: EdgeInsets.only(left: 2),
      child: Text(
        item.name,
        style: TextStyle(
          color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
        ),
      ),
    ),
  );
}

/// Builds a branch row with worktree indicator prefix.
Component buildBranchRow({
  required NavigableItem item,
  required bool isSelected,
  required bool isHovered,
  required VideThemeData theme,
  required int availableWidth,
  required List<GitBranch>? cachedBranches,
  required bool Function(String) isWorktreeBranch,
}) {
  final branch = cachedBranches?.firstWhere(
    (b) => b.name == item.name,
    orElse: () => GitBranch(
      name: item.name,
      isCurrent: false,
      isRemote: false,
      lastCommit: '',
    ),
  );
  final isWorktree = isWorktreeBranch(item.name);
  final isCurrent = branch?.isCurrent == true;
  final isMainBranch = item.name == 'main' || item.name == 'master';
  final highlight = isSelected || isHovered;
  final isExpanded = item.isExpanded;

  return Container(
    decoration: highlight
        ? BoxDecoration(
            color: theme.base.primary.withOpacity(isSelected ? 0.3 : 0.15),
          )
        : null,
    child: Padding(
      padding: EdgeInsets.only(left: 2),
      child: Row(
        children: [
          // Expand/collapse indicator
          Text(
            isExpanded ? '▾' : '▸',
            style: TextStyle(
              color: theme.base.onSurface.withOpacity(TextOpacity.secondary),
            ),
          ),
          // Worktree indicator
          if (isWorktree)
            Text('⎇ ', style: TextStyle(color: theme.base.primary))
          else if (isCurrent)
            Text('● ', style: TextStyle(color: theme.base.success))
          else
            Text('  ', style: TextStyle(color: theme.base.outline)),
          Expanded(
            child: Text(
              item.name,
              style: TextStyle(
                color: isCurrent
                    ? theme.base.primary
                    : isMainBranch
                    ? theme.base.onSurface
                    : theme.base.onSurface.withOpacity(TextOpacity.secondary),
                fontWeight: (isCurrent || isMainBranch)
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Builds a branch action row (Checkout, Create worktree).
Component buildBranchActionRow({
  required NavigableItem item,
  required bool isSelected,
  required bool isHovered,
  required VideThemeData theme,
  required int availableWidth,
  required String icon,
}) {
  final highlight = isSelected || isHovered;

  return Container(
    decoration: highlight
        ? BoxDecoration(
            color: theme.base.primary.withOpacity(isSelected ? 0.3 : 0.15),
          )
        : null,
    child: Padding(
      padding: EdgeInsets.only(left: 4), // Extra indent for action items
      child: Row(
        children: [
          Text(icon, style: TextStyle(color: theme.base.primary)),
          SizedBox(width: 1),
          Expanded(
            child: Text(
              item.name,
              style: TextStyle(color: theme.base.primary),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Builds the "Show more branches" row.
Component buildShowMoreBranchesRow({
  required NavigableItem item,
  required bool isSelected,
  required bool isHovered,
  required VideThemeData theme,
  required int availableWidth,
}) {
  final highlight = isSelected || isHovered;

  return Container(
    decoration: highlight
        ? BoxDecoration(
            color: theme.base.primary.withOpacity(isSelected ? 0.3 : 0.15),
          )
        : null,
    child: Padding(
      padding: EdgeInsets.only(left: 2),
      child: Row(
        children: [
          Text('…', style: TextStyle(color: theme.base.primary)),
          SizedBox(width: 1),
          Expanded(
            child: Text(
              item.name,
              style: TextStyle(
                color: theme.base.primary.withOpacity(TextOpacity.secondary),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    ),
  );
}
