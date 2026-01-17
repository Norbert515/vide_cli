/// Models and enums for the GitSidebar component.

/// Represents a changed file with its status.
class ChangedFile {
  final String path;
  final String status; // 'staged', 'modified', 'untracked'

  const ChangedFile({required this.path, required this.status});
}

/// Type of navigable item for unified keyboard navigation.
enum NavigableItemType {
  newBranchAction, // "+ New branch from..." quick action
  newWorktreeAction, // "+ New worktree from..." quick action
  baseBranchOption, // Branch option when selecting base branch
  worktreeHeader, // Collapsible worktree header with branch name
  changesSectionLabel, // "Changes" label (not collapsible)
  file,
  actionsHeader, // Expandable "Actions" header
  commitPushAction, // "Commit & push" action for branches with changes
  syncAction, // "Sync" action for branches ahead/behind remote
  mergeToMainAction, // "Merge to main" action for clean branches ahead of main
  pullAction, // "Pull" action - pull from remote
  pushAction, // "Push" action - push to remote
  fetchAction, // "Fetch" action - fetch from remote
  switchWorktreeAction, // "Switch to worktree" action for non-current worktrees
  worktreeCopyPathAction, // "Copy path" action for worktrees
  worktreeRemoveAction, // "Remove worktree" action for worktrees
  worktreeActionsHeader, // Expandable "Actions" header for non-current worktrees
  noChangesPlaceholder, // "No changes" placeholder when worktree is clean
  divider, // Visual separator line
  branchSectionLabel, // "Other Branches"
  branch, // Expandable branch item
  branchCheckoutAction, // "Checkout" action under expanded branch
  branchWorktreeAction, // "Create worktree" action under expanded branch
  showMoreBranches,
  repoHeader, // Collapsible repository header for multi-repo mode
}

/// State of the quick action flow
enum QuickActionState {
  collapsed, // Just showing the action label
  selectingBaseBranch, // Expanded to show branch options
  enteringName, // Typing the new branch/worktree name
}

/// Unified navigable item for keyboard navigation across all sections.
class NavigableItem {
  final NavigableItemType type;
  final String name;
  final String? fullPath;
  final String? status;
  final int fileCount;
  final bool isExpanded;
  final bool isLastInSection;
  final String? worktreePath; // For associating items with their worktree
  final bool isWorktree; // True if this is a worktree (not the main repo)

  const NavigableItem({
    required this.type,
    required this.name,
    this.fullPath,
    this.status,
    this.fileCount = 0,
    this.isExpanded = false,
    this.isLastInSection = false,
    this.worktreePath,
    this.isWorktree = false,
  });
}
