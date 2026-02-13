import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_core/vide_core.dart'
    show
        GitBranch,
        GitRepository,
        GitStatus,
        GitWorktree,
        gitStatusStreamProvider;
import 'package:vide_cli/modules/git/git_branch_indicator.dart';
import 'package:vide_cli/modules/git/models/git_sidebar_models.dart';

/// Builds the list of navigable items for the GitSidebar.
///
/// Extracted from GitSidebar to reduce file size. Reads state but
/// never mutates it. All state is passed in via constructor.
class GitSidebarItemBuilder {
  // Quick action state
  final QuickActionState branchActionState;
  final QuickActionState worktreeActionState;

  // Expansion state
  final bool showAllBranches;
  final String? expandedBranchName;
  final bool actionsExpanded;
  final Set<String> expandedWorktreeActions;

  // Multi-repo state
  final List<GitRepository>? childRepos;
  final bool? isMultiRepoMode;
  final Map<String, List<GitBranch>> repoBranches;
  final Map<String, List<GitWorktree>> repoWorktrees;
  final Map<String, int> repoCommitsAheadOfMain;
  final Map<String, bool> repoActionsExpanded;
  final Map<String, String?> repoExpandedBranchName;
  final Map<String, QuickActionState> repoBranchActionState;
  final Map<String, QuickActionState> repoWorktreeActionState;

  // Cached data
  final List<GitBranch>? cachedBranches;
  final List<GitWorktree>? cachedWorktrees;
  final int? commitsAheadOfMain;
  final bool branchesLoading;

  // Component properties
  final String repoPath;

  // Callbacks for state queries
  final String? Function() findCurrentWorktreePath;
  final bool Function(String) isWorktreeExpanded;
  final bool Function(String) isRepoExpanded;
  final Future<void> Function() loadBranchesAndWorktrees;

  static const int initialBranchCount = 5;

  const GitSidebarItemBuilder({
    required this.branchActionState,
    required this.worktreeActionState,
    required this.showAllBranches,
    required this.expandedBranchName,
    required this.actionsExpanded,
    required this.expandedWorktreeActions,
    required this.childRepos,
    required this.isMultiRepoMode,
    required this.repoBranches,
    required this.repoWorktrees,
    required this.repoCommitsAheadOfMain,
    required this.repoActionsExpanded,
    required this.repoExpandedBranchName,
    required this.repoBranchActionState,
    required this.repoWorktreeActionState,
    required this.cachedBranches,
    required this.cachedWorktrees,
    required this.commitsAheadOfMain,
    required this.branchesLoading,
    required this.repoPath,
    required this.findCurrentWorktreePath,
    required this.isWorktreeExpanded,
    required this.isRepoExpanded,
    required this.loadBranchesAndWorktrees,
  });

  /// Builds a flat list of all changed files with their statuses from git status.
  List<ChangedFile> buildChangedFiles(GitStatus? gitStatus) {
    if (gitStatus == null) return [];

    final files = <ChangedFile>[];
    final seenPaths = <String>{};

    // Add staged files first
    for (final path in gitStatus.stagedFiles) {
      if (!seenPaths.contains(path)) {
        files.add(ChangedFile(path: path, status: 'staged'));
        seenPaths.add(path);
      }
    }

    // Add modified files
    for (final path in gitStatus.modifiedFiles) {
      if (!seenPaths.contains(path)) {
        files.add(ChangedFile(path: path, status: 'modified'));
        seenPaths.add(path);
      }
    }

    // Add untracked files
    for (final path in gitStatus.untrackedFiles) {
      if (!seenPaths.contains(path)) {
        files.add(ChangedFile(path: path, status: 'untracked'));
        seenPaths.add(path);
      }
    }

    // Sort alphabetically by path
    files.sort((a, b) => a.path.compareTo(b.path));

    return files;
  }

  /// Gets the list of base branch options for quick actions.
  List<String> _getBaseBranchOptions(String currentBranch) {
    final options = <String>[];

    // Current branch first
    options.add(currentBranch);

    // Main branch (if different from current)
    final mainBranch = cachedBranches?.firstWhere(
      (b) => b.name == 'main' || b.name == 'master',
      orElse: () => GitBranch(
        name: '',
        isCurrent: false,
        isRemote: false,
        lastCommit: '',
      ),
    );
    if (mainBranch != null &&
        mainBranch.name.isNotEmpty &&
        mainBranch.name != currentBranch) {
      options.add(mainBranch.name);
    }

    // Add "Other..." option if there are more branches
    final otherBranches =
        cachedBranches
            ?.where(
              (b) =>
                  !b.isRemote &&
                  b.name != currentBranch &&
                  b.name != 'main' &&
                  b.name != 'master',
            )
            .toList() ??
        [];
    if (otherBranches.isNotEmpty) {
      options.add('Other...');
    }

    return options;
  }

  /// Gets the list of base branch options for quick actions in multi-repo mode.
  List<String> _getRepoBranchOptions(String repoPath, GitStatus? status) {
    final options = <String>[];

    // Current branch first
    if (status?.branch != null) {
      options.add(status!.branch);
    }

    // Main/master if different from current
    final branches = repoBranches[repoPath] ?? [];
    for (final branch in branches) {
      if ((branch.name == 'main' || branch.name == 'master') &&
          branch.name != status?.branch) {
        options.add(branch.name);
        break;
      }
    }

    // Add "Other..." option if there are more branches
    final otherBranches = branches
        .where(
          (b) =>
              !b.isRemote &&
              b.name != status?.branch &&
              b.name != 'main' &&
              b.name != 'master',
        )
        .toList();
    if (otherBranches.isNotEmpty) {
      options.add('Other...');
    }

    return options;
  }

  /// Builds the complete list of navigable items including section headers.
  List<NavigableItem> buildNavigableItems(BuildContext context) {
    // Check if we're in multi-repo mode
    if (isMultiRepoMode == true && childRepos != null) {
      return _buildMultiRepoItems(context);
    }

    final items = <NavigableItem>[];

    // Get current branch for base options
    final gitStatusAsync = context.watch(gitStatusStreamProvider(repoPath));
    final currentBranch = gitStatusAsync.valueOrNull?.branch ?? 'main';

    // New branch action with optional branch selection
    items.add(
      NavigableItem(
        type: NavigableItemType.newBranchAction,
        name: '+ New branch...',
        isExpanded: branchActionState != QuickActionState.collapsed,
      ),
    );

    // Show branch options if selecting base branch for new branch
    if (branchActionState == QuickActionState.selectingBaseBranch) {
      for (final branch in _getBaseBranchOptions(currentBranch)) {
        items.add(
          NavigableItem(
            type: NavigableItemType.baseBranchOption,
            name: branch,
            fullPath: 'branch', // Marker for which action this belongs to
          ),
        );
      }
    }

    // New worktree action with optional branch selection
    items.add(
      NavigableItem(
        type: NavigableItemType.newWorktreeAction,
        name: '+ New worktree...',
        isExpanded: worktreeActionState != QuickActionState.collapsed,
      ),
    );

    // Show branch options if selecting base branch for new worktree
    if (worktreeActionState == QuickActionState.selectingBaseBranch) {
      for (final branch in _getBaseBranchOptions(currentBranch)) {
        items.add(
          NavigableItem(
            type: NavigableItemType.baseBranchOption,
            name: branch,
            fullPath: 'worktree', // Marker for which action this belongs to
          ),
        );
      }
    }

    // Always include current worktree first (even if no worktrees cached yet)
    // Resolve the actual worktree path - CWD might be a subdirectory
    final resolvedCurrentPath = findCurrentWorktreePath() ?? repoPath;
    final gitStatus = gitStatusAsync.valueOrNull;

    // Check if resolved path is a worktree
    final isCurrentWorktreeAsync = context.watch(
      isWorktreeProvider(resolvedCurrentPath),
    );
    final isCurrentPathWorktree = isCurrentWorktreeAsync.valueOrNull ?? false;

    // Get main repo path to identify which worktrees are actual worktrees
    final mainRepoPathAsync = context.watch(
      mainRepoPathProvider(resolvedCurrentPath),
    );
    final mainRepoPath = mainRepoPathAsync.valueOrNull;

    // Ensure worktrees are loaded
    if (cachedBranches == null && !branchesLoading) {
      loadBranchesAndWorktrees();
    }

    // Build current worktree section
    items.addAll(
      _buildWorktreeSection(
        context,
        path: resolvedCurrentPath,
        branch: gitStatus?.branch ?? 'Loading...',
        isCurrentWorktree: true,
        isWorktree: isCurrentPathWorktree,
        gitStatus: gitStatus,
      ),
    );

    // Add other worktrees
    if (cachedWorktrees != null) {
      for (final worktree in cachedWorktrees!) {
        if (worktree.path == resolvedCurrentPath) continue; // Skip current

        // Only watch status if expanded (lazy loading)
        final isExpanded = isWorktreeExpanded(worktree.path);
        GitStatus? wtStatus;
        if (isExpanded) {
          final statusAsync = context.watch(
            gitStatusStreamProvider(worktree.path),
          );
          wtStatus = statusAsync.valueOrNull;
        }

        // Determine if this entry is a worktree (not the main repo)
        final isWorktree =
            mainRepoPath != null && worktree.path != mainRepoPath;

        items.addAll(
          _buildWorktreeSection(
            context,
            path: worktree.path,
            branch: worktree.branch,
            isCurrentWorktree: false,
            isWorktree: isWorktree,
            gitStatus: wtStatus,
          ),
        );
      }
    }

    // Add divider and "Other Branches" section
    if (cachedBranches != null) {
      final worktreeBranches =
          cachedWorktrees?.map((w) => w.branch).toSet() ?? {};
      worktreeBranches.add(gitStatus?.branch ?? '');

      final otherBranches = cachedBranches!
          .where((b) => !worktreeBranches.contains(b.name) && !b.isRemote)
          .toList();

      // Find main branch (main or master) - show it first if it's in other branches
      final mainBranchName = otherBranches.any((b) => b.name == 'main')
          ? 'main'
          : otherBranches.any((b) => b.name == 'master')
          ? 'master'
          : null;

      // Sort: main/master first, then alphabetically
      if (mainBranchName != null) {
        otherBranches.sort((a, b) {
          if (a.name == mainBranchName) return -1;
          if (b.name == mainBranchName) return 1;
          return a.name.compareTo(b.name);
        });
      }

      if (otherBranches.isNotEmpty) {
        items.add(NavigableItem(type: NavigableItemType.divider, name: ''));
        items.add(
          NavigableItem(
            type: NavigableItemType.branchSectionLabel,
            name: 'Other Branches',
          ),
        );

        final displayCount = showAllBranches
            ? otherBranches.length
            : initialBranchCount.clamp(0, otherBranches.length);

        for (var i = 0; i < displayCount; i++) {
          final branchName = otherBranches[i].name;
          final isExpanded = expandedBranchName == branchName;

          items.add(
            NavigableItem(
              type: NavigableItemType.branch,
              name: branchName,
              isExpanded: isExpanded,
              isLastInSection: i == displayCount - 1 && !isExpanded,
            ),
          );

          // Add action items if this branch is expanded
          if (isExpanded) {
            items.add(
              NavigableItem(
                type: NavigableItemType.branchCheckoutAction,
                name: 'Checkout',
                fullPath: branchName, // Store branch name for the action
              ),
            );
            items.add(
              NavigableItem(
                type: NavigableItemType.branchWorktreeAction,
                name: 'Create worktree',
                fullPath: branchName, // Store branch name for the action
                isLastInSection: i == displayCount - 1,
              ),
            );
          }
        }

        if (!showAllBranches && otherBranches.length > initialBranchCount) {
          items.add(
            NavigableItem(
              type: NavigableItemType.showMoreBranches,
              name: 'Show more (${otherBranches.length - initialBranchCount})',
              isLastInSection: true,
            ),
          );
        }
      }
    }

    return items;
  }

  /// Builds items for a single worktree section (header + files).
  List<NavigableItem> _buildWorktreeSection(
    BuildContext context, {
    required String path,
    required String branch,
    required bool isCurrentWorktree,
    required bool isWorktree,
    GitStatus? gitStatus,
  }) {
    final items = <NavigableItem>[];
    final isExpanded = isWorktreeExpanded(path);

    // Worktree header
    items.add(
      NavigableItem(
        type: NavigableItemType.worktreeHeader,
        name: branch,
        worktreePath: path,
        isExpanded: isExpanded,
        isWorktree: isWorktree,
      ),
    );

    if (!isExpanded) return items;

    // For non-current worktrees, add collapsible Actions header
    if (!isCurrentWorktree) {
      final worktreeActionsExpanded = expandedWorktreeActions.contains(path);
      items.add(
        NavigableItem(
          type: NavigableItemType.worktreeActionsHeader,
          name: 'Actions',
          worktreePath: path,
          isExpanded: worktreeActionsExpanded,
        ),
      );

      // Only show actions if expanded
      if (worktreeActionsExpanded) {
        items.add(
          NavigableItem(
            type: NavigableItemType.switchWorktreeAction,
            name: 'Switch to this worktree',
            worktreePath: path,
          ),
        );
        items.add(
          NavigableItem(
            type: NavigableItemType.worktreeCopyPathAction,
            name: 'Copy path',
            worktreePath: path,
          ),
        );
        items.add(
          NavigableItem(
            type: NavigableItemType.worktreeRemoveAction,
            name: 'Remove worktree',
            worktreePath: path,
          ),
        );
      }
    }

    // File items directly under the header (no "Changes" label)
    final changedFiles = buildChangedFiles(gitStatus);

    // For current worktree, add Actions menu before changed files
    if (isCurrentWorktree) {
      // Add Actions header
      items.add(
        NavigableItem(
          type: NavigableItemType.actionsHeader,
          name: 'Actions',
          worktreePath: path,
          isExpanded: actionsExpanded,
        ),
      );

      // Add child actions if expanded
      if (actionsExpanded) {
        // Conditional: "Commit & push" - only when there are changes
        if (changedFiles.isNotEmpty) {
          items.add(
            NavigableItem(
              type: NavigableItemType.commitPushAction,
              name: 'Commit & push',
              worktreePath: path,
            ),
          );
        }

        // Conditional: "Sync" - only when ahead or behind remote
        final ahead = gitStatus?.ahead ?? 0;
        final behind = gitStatus?.behind ?? 0;
        if (ahead > 0 || behind > 0) {
          final syncLabel = behind > 0 && ahead > 0
              ? 'Sync (\u2193$behind \u2191$ahead)'
              : behind > 0
              ? 'Sync (\u2193$behind)'
              : 'Sync (\u2191$ahead)';
          items.add(
            NavigableItem(
              type: NavigableItemType.syncAction,
              name: syncLabel,
              worktreePath: path,
            ),
          );
        }

        // Conditional: "Merge to main" - only when clean, ahead of main, not on main/master
        final isMainBranch = branch == 'main' || branch == 'master';
        final isClean = changedFiles.isEmpty;
        final isAheadOfMain = (commitsAheadOfMain ?? 0) > 0;
        if (isClean && isAheadOfMain && !isMainBranch) {
          items.add(
            NavigableItem(
              type: NavigableItemType.mergeToMainAction,
              name: 'Merge to main',
              worktreePath: path,
              fullPath: branch, // Store current branch name for merge
            ),
          );
        }

        // Always visible actions
        items.add(
          NavigableItem(
            type: NavigableItemType.pullAction,
            name: 'Pull',
            worktreePath: path,
          ),
        );

        items.add(
          NavigableItem(
            type: NavigableItemType.pushAction,
            name: 'Push',
            worktreePath: path,
          ),
        );

        items.add(
          NavigableItem(
            type: NavigableItemType.fetchAction,
            name: 'Fetch',
            worktreePath: path,
          ),
        );
      }
    }

    if (changedFiles.isNotEmpty) {
      for (var i = 0; i < changedFiles.length; i++) {
        final file = changedFiles[i];
        items.add(
          NavigableItem(
            type: NavigableItemType.file,
            name: file.path,
            fullPath: file.path,
            status: file.status,
            worktreePath: path,
            isLastInSection: i == changedFiles.length - 1,
          ),
        );
      }
    } else if (!isCurrentWorktree ||
        ((!((actionsExpanded &&
            ((commitsAheadOfMain ?? 0) > 0 &&
                branch != 'main' &&
                branch != 'master')))))) {
      // Show "No changes" placeholder when:
      // - Not current worktree, or
      // - Current worktree and not showing merge action in expanded actions
      final isMainBranch = branch == 'main' || branch == 'master';
      final isAheadOfMain = (commitsAheadOfMain ?? 0) > 0;
      if (!isAheadOfMain || isMainBranch || !isCurrentWorktree) {
        items.add(
          NavigableItem(
            type: NavigableItemType.noChangesPlaceholder,
            name: 'No changes',
            worktreePath: path,
            isLastInSection: true,
          ),
        );
      }
    }

    return items;
  }

  /// Builds navigable items for multi-repo mode.
  List<NavigableItem> _buildMultiRepoItems(BuildContext context) {
    final items = <NavigableItem>[];

    if (childRepos == null || childRepos!.isEmpty) {
      // Show empty state
      items.add(
        NavigableItem(
          type: NavigableItemType.noChangesPlaceholder,
          name: 'No git repositories found',
          isLastInSection: true,
        ),
      );
      return items;
    }

    for (final repo in childRepos!) {
      // Only watch status if expanded (lazy loading)
      GitStatus? status;
      if (isRepoExpanded(repo.path)) {
        final statusAsync = context.watch(gitStatusStreamProvider(repo.path));
        status = statusAsync.valueOrNull;
      }

      items.addAll(_buildRepoSection(context, repo, status));
    }

    return items;
  }

  /// Builds items for a single repository section in multi-repo mode.
  List<NavigableItem> _buildRepoSection(
    BuildContext context,
    GitRepository repo,
    GitStatus? status,
  ) {
    final items = <NavigableItem>[];
    final isExpanded = isRepoExpanded(repo.path);
    final branches = repoBranches[repo.path];
    final worktrees = repoWorktrees[repo.path];
    final commitsAhead = repoCommitsAheadOfMain[repo.path] ?? 0;

    // Calculate change count for collapsed header
    final changeCount =
        (status?.modifiedFiles.length ?? 0) +
        (status?.untrackedFiles.length ?? 0) +
        (status?.stagedFiles.length ?? 0);

    // Add repo header
    items.add(
      NavigableItem(
        type: NavigableItemType.repoHeader,
        name: repo.name,
        fullPath: repo.path,
        isExpanded: isExpanded,
        fileCount: changeCount,
      ),
    );

    if (!isExpanded) return items;

    // === QUICK ACTIONS (New branch, New worktree) ===
    final branchActionState =
        repoBranchActionState[repo.path] ?? QuickActionState.collapsed;
    final worktreeActionState =
        repoWorktreeActionState[repo.path] ?? QuickActionState.collapsed;

    // New branch action
    items.add(
      NavigableItem(
        type: NavigableItemType.newBranchAction,
        name: '+ New branch...',
        isExpanded: branchActionState != QuickActionState.collapsed,
        worktreePath: repo.path,
      ),
    );

    // Add base branch options if expanded
    if (branchActionState == QuickActionState.selectingBaseBranch) {
      final branchOptions = _getRepoBranchOptions(repo.path, status);
      for (final option in branchOptions) {
        items.add(
          NavigableItem(
            type: NavigableItemType.baseBranchOption,
            name: option,
            fullPath: 'branch', // Marker for which action this belongs to
            worktreePath: repo.path,
          ),
        );
      }
    }

    // New worktree action
    items.add(
      NavigableItem(
        type: NavigableItemType.newWorktreeAction,
        name: '+ New worktree...',
        isExpanded: worktreeActionState != QuickActionState.collapsed,
        worktreePath: repo.path,
      ),
    );

    // Add base branch options for worktree if expanded
    if (worktreeActionState == QuickActionState.selectingBaseBranch) {
      final branchOptions = _getRepoBranchOptions(repo.path, status);
      for (final option in branchOptions) {
        items.add(
          NavigableItem(
            type: NavigableItemType.baseBranchOption,
            name: option,
            fullPath: 'worktree', // Marker for which action this belongs to
            worktreePath: repo.path,
          ),
        );
      }
    }

    // === ACTIONS SECTION ===
    final repoActionsExpanded = this.repoActionsExpanded[repo.path] ?? false;
    items.add(
      NavigableItem(
        type: NavigableItemType.actionsHeader,
        name: 'Actions',
        isExpanded: repoActionsExpanded,
        worktreePath: repo.path,
      ),
    );

    if (repoActionsExpanded && status != null) {
      // Conditional: "Commit & push" - only when there are changes
      final changedFiles = buildChangedFiles(status);
      if (changedFiles.isNotEmpty) {
        items.add(
          NavigableItem(
            type: NavigableItemType.commitPushAction,
            name: 'Commit & push',
            worktreePath: repo.path,
          ),
        );
      }

      // Conditional: "Sync" - only when ahead or behind remote
      final ahead = status.ahead;
      final behind = status.behind;
      if (ahead > 0 || behind > 0) {
        final syncLabel = behind > 0 && ahead > 0
            ? 'Sync (\u2193$behind \u2191$ahead)'
            : behind > 0
            ? 'Sync (\u2193$behind)'
            : 'Sync (\u2191$ahead)';
        items.add(
          NavigableItem(
            type: NavigableItemType.syncAction,
            name: syncLabel,
            worktreePath: repo.path,
          ),
        );
      }

      // Conditional: "Merge to main" - only when clean, ahead of main, not on main/master
      final isMainBranch = status.branch == 'main' || status.branch == 'master';
      final isClean = !status.hasChanges;
      if (isClean && commitsAhead > 0 && !isMainBranch) {
        items.add(
          NavigableItem(
            type: NavigableItemType.mergeToMainAction,
            name: 'Merge to main',
            worktreePath: repo.path,
            fullPath: status.branch,
          ),
        );
      }

      // Always visible actions
      items.add(
        NavigableItem(
          type: NavigableItemType.pullAction,
          name: 'Pull',
          worktreePath: repo.path,
        ),
      );

      items.add(
        NavigableItem(
          type: NavigableItemType.pushAction,
          name: 'Push',
          worktreePath: repo.path,
        ),
      );

      items.add(
        NavigableItem(
          type: NavigableItemType.fetchAction,
          name: 'Fetch',
          worktreePath: repo.path,
        ),
      );
    }

    // === CHANGED FILES SECTION ===
    if (status != null) {
      final changedFiles = buildChangedFiles(status);
      if (changedFiles.isEmpty) {
        items.add(
          NavigableItem(
            type: NavigableItemType.noChangesPlaceholder,
            name: 'No changes',
            worktreePath: repo.path,
          ),
        );
      } else {
        for (final file in changedFiles) {
          items.add(
            NavigableItem(
              type: NavigableItemType.file,
              name: file.path,
              fullPath: file.path,
              status: file.status,
              worktreePath: repo.path,
            ),
          );
        }
      }
    }

    // === OTHER BRANCHES SECTION ===
    if (branches != null && branches.isNotEmpty) {
      // Filter out current branch and worktree branches
      final currentBranch = status?.branch;
      final worktreeBranches = worktrees?.map((w) => w.branch).toSet() ?? {};
      final otherBranches = branches
          .where(
            (b) =>
                b.name != currentBranch && !worktreeBranches.contains(b.name),
          )
          .toList();

      if (otherBranches.isNotEmpty) {
        items.add(
          NavigableItem(
            type: NavigableItemType.divider,
            name: '',
            worktreePath: repo.path,
          ),
        );
        items.add(
          NavigableItem(
            type: NavigableItemType.branchSectionLabel,
            name: 'Other Branches',
            worktreePath: repo.path,
          ),
        );

        // Show up to 5 branches initially
        final displayBranches = otherBranches.take(5).toList();
        final expandedBranch = repoExpandedBranchName[repo.path];

        for (final branch in displayBranches) {
          final isBranchExpanded = expandedBranch == branch.name;
          items.add(
            NavigableItem(
              type: NavigableItemType.branch,
              name: branch.name,
              isExpanded: isBranchExpanded,
              worktreePath: repo.path,
            ),
          );

          if (isBranchExpanded) {
            items.add(
              NavigableItem(
                type: NavigableItemType.branchCheckoutAction,
                name: 'Checkout',
                fullPath: branch.name,
                worktreePath: repo.path,
              ),
            );
            items.add(
              NavigableItem(
                type: NavigableItemType.branchWorktreeAction,
                name: 'Create worktree',
                fullPath: branch.name,
                worktreePath: repo.path,
              ),
            );
          }
        }

        // Show "Show more" if needed
        if (otherBranches.length > 5) {
          items.add(
            NavigableItem(
              type: NavigableItemType.showMoreBranches,
              name: 'Show more (${otherBranches.length - 5})',
              worktreePath: repo.path,
            ),
          );
        }
      }
    }

    return items;
  }
}
