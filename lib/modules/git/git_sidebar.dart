import 'dart:io';

import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:vide_core/vide_core.dart'
    show GitClient, GitStatus, GitBranch, GitWorktree, GitRepository;
import 'package:vide_cli/modules/git/git_providers.dart';
import 'package:vide_cli/main.dart';
import 'package:vide_cli/modules/git/git_branch_indicator.dart';
import 'package:vide_cli/modules/git/models/git_sidebar_models.dart';
import 'package:vide_cli/modules/git/components/git_sidebar_item_rows.dart';
import 'package:vide_cli/modules/toast/toast_service.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_cli/constants/text_opacity.dart';

/// A sidebar component that displays git status information as a flat file list.
///
/// Shows:
/// - Current branch name at the top
/// - Flat list of changed files with status indicators (S=staged, M=modified, ?=untracked)
/// - Branches section (collapsible)
///
/// Supports keyboard navigation when focused.
class GitSidebar extends StatefulComponent {
  final bool focused;
  final bool expanded;
  final VoidCallback? onExitRight;
  final VoidCallback? onExitLeft;
  final String repoPath;
  final int width;
  final void Function(String message)? onSendMessage;
  final void Function(String path)? onSwitchWorktree;

  const GitSidebar({
    required this.focused,
    required this.expanded,
    this.onExitRight,
    this.onExitLeft,
    required this.repoPath,
    this.width = 30,
    this.onSendMessage,
    this.onSwitchWorktree,
    super.key,
  });

  @override
  State<GitSidebar> createState() => _GitSidebarState();
}

class _GitSidebarState extends State<GitSidebar>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  int? _hoveredIndex;
  final _scrollController = ScrollController();

  // Animation state
  static const Duration _animationDuration = Duration(milliseconds: 160);
  late AnimationController _animationController;
  late Animation<double> _widthAnimation;
  double _currentWidth = 5.0;

  // Worktree expansion state (per-worktree collapse/expand)
  Map<String, bool> _worktreeExpansionState = {};
  bool _showAllBranches = false;

  // Branch expansion state (which branch in "Other Branches" is expanded to show actions)
  String? _expandedBranchName;

  // Quick action state
  QuickActionState _branchActionState = QuickActionState.collapsed;
  QuickActionState _worktreeActionState = QuickActionState.collapsed;
  String? _selectedBaseBranch; // The base branch selected for the action
  NavigableItemType? _activeInputType; // Which action is in input mode
  String _inputBuffer = '';

  // Actions menu expansion state
  bool _actionsExpanded = false;

  // Worktree actions expansion state (per-worktree)
  Set<String> _expandedWorktreeActions = {};

  // Loading state for git actions (e.g., 'pull', 'push', 'fetch', 'sync', 'merge')
  String? _loadingAction;

  // Multi-repo support
  List<GitRepository>? _childRepos;
  bool? _isMultiRepoMode;
  final Map<String, bool> _repoExpansionState = {};

  // Per-repo state management for multi-repo mode
  final Map<String, List<GitBranch>> _repoBranches = {};
  final Map<String, List<GitWorktree>> _repoWorktrees = {};
  final Map<String, int> _repoCommitsAheadOfMain = {};
  final Map<String, bool> _repoActionsExpanded = {};
  final Map<String, String?> _repoExpandedBranchName = {};

  // Per-repo quick action state for multi-repo mode
  final Map<String, QuickActionState> _repoBranchActionState = {};
  final Map<String, QuickActionState> _repoWorktreeActionState = {};
  final Map<String, String?> _repoSelectedBaseBranch = {};
  final Map<String, NavigableItemType?> _repoActiveInputType = {};
  String? _activeInputRepoPath; // Track which repo is in input mode

  /// Find which worktree path contains the current working directory.
  /// Returns the worktree path if CWD is within a worktree, or null if not found.
  String? _findCurrentWorktreePath() {
    if (_cachedWorktrees == null) return null;
    final cwd = component.repoPath;
    for (final wt in _cachedWorktrees!) {
      if (cwd == wt.path || cwd.startsWith('${wt.path}/')) {
        return wt.path;
      }
    }
    return null;
  }

  /// Check if a worktree is expanded. Current worktree expanded by default, others collapsed.
  bool _isWorktreeExpanded(String worktreePath) {
    final currentPath = _findCurrentWorktreePath() ?? component.repoPath;
    return _worktreeExpansionState[worktreePath] ??
        (worktreePath == currentPath);
  }

  /// Toggle the expansion state of a worktree.
  void _toggleWorktreeExpansion(String worktreePath) {
    setState(() {
      final current = _isWorktreeExpanded(worktreePath);
      _worktreeExpansionState[worktreePath] = !current;
    });
  }

  /// Check if a repo is expanded. Collapsed by default in multi-repo mode.
  bool _isRepoExpanded(String repoPath) {
    return _repoExpansionState[repoPath] ?? false;
  }

  /// Toggle the expansion state of a repository.
  void _toggleRepoExpansion(String repoPath) {
    final wasExpanded = _isRepoExpanded(repoPath);
    setState(() {
      _repoExpansionState[repoPath] = !wasExpanded;
    });

    // Load data when expanding (if not already loaded)
    if (!wasExpanded && !_repoBranches.containsKey(repoPath)) {
      _loadRepoBranchesAndWorktrees(repoPath);
    }
  }

  /// Loads branches and worktrees for a specific repository in multi-repo mode.
  Future<void> _loadRepoBranchesAndWorktrees(String repoPath) async {
    final client = GitClient(workingDirectory: repoPath);

    try {
      final branches = await client.branches();
      final worktrees = await client.worktreeList();

      // Get commits ahead of main for merge action visibility
      int commitsAhead = 0;
      final status = await client.status();
      if (status.branch != 'main' && status.branch != 'master') {
        try {
          final mainBranch = branches.any((b) => b.name == 'main')
              ? 'main'
              : 'master';
          commitsAhead = await client.getCommitsAheadOf(mainBranch);
        } catch (_) {}
      }

      // Sort branches: current first, then alphabetically
      branches.sort((a, b) {
        if (a.isCurrent && !b.isCurrent) return -1;
        if (!a.isCurrent && b.isCurrent) return 1;
        return a.name.compareTo(b.name);
      });

      // Filter out remote branches
      final localBranches = branches.where((b) => !b.isRemote).toList();

      setState(() {
        _repoBranches[repoPath] = localBranches;
        _repoWorktrees[repoPath] = worktrees;
        _repoCommitsAheadOfMain[repoPath] = commitsAhead;
      });
    } catch (e) {
      // Handle error - repo might not be accessible
    }
  }

  List<GitBranch>? _cachedBranches;
  List<GitWorktree>? _cachedWorktrees;
  int? _commitsAheadOfMain; // Commits in current branch not in main
  bool _branchesLoading = false;
  static const int _initialBranchCount = 5;

  static const double _collapsedWidth = 5.0;
  static const double _expandedWidth = 30.0;

  @override
  void initState() {
    super.initState();
    _currentWidth = component.expanded ? _expandedWidth : _collapsedWidth;

    // Initialize animation controller
    _animationController = AnimationController(
      duration: _animationDuration,
      vsync: this,
    );
    // Initialize animation (will be updated when animating)
    _widthAnimation = Tween<double>(
      begin: _currentWidth,
      end: _currentWidth,
    ).chain(CurveTween(curve: Curves.easeOut)).animate(_animationController);
    _animationController.addListener(() {
      setState(() {
        _currentWidth = _widthAnimation.value;
      });
    });

    // Detect repo mode and load branches/worktrees
    _detectRepoMode();
  }

  /// Detect whether we're in single-repo or multi-repo mode.
  Future<void> _detectRepoMode() async {
    final gitDir = Directory(p.join(component.repoPath, '.git'));
    if (await gitDir.exists()) {
      // Single repo mode (existing behavior)
      setState(() {
        _isMultiRepoMode = false;
      });
      _loadBranchesAndWorktrees();
    } else {
      // Check for child repos
      final childRepos = await _findChildRepos(component.repoPath);
      setState(() {
        _isMultiRepoMode = childRepos.isNotEmpty;
        _childRepos = childRepos;
      });
    }
  }

  /// Find git repositories in immediate subdirectories.
  Future<List<GitRepository>> _findChildRepos(String parentPath) async {
    final repos = <GitRepository>[];
    final parentDir = Directory(parentPath);

    if (!await parentDir.exists()) return repos;

    await for (final entity in parentDir.list(followLinks: false)) {
      if (entity is Directory) {
        final gitDir = Directory(p.join(entity.path, '.git'));
        if (await gitDir.exists()) {
          repos.add(
            GitRepository(path: entity.path, name: p.basename(entity.path)),
          );
        }
      }
    }

    repos.sort((a, b) => a.name.compareTo(b.name));
    return repos;
  }

  @override
  void didUpdateComponent(GitSidebar old) {
    super.didUpdateComponent(old);
    // Animate based on expanded state
    if (component.expanded != old.expanded) {
      _animateToWidth(component.expanded ? _expandedWidth : _collapsedWidth);
    }
    // When focus changes to true, select the current worktree
    if (component.focused && !old.focused) {
      _selectCurrentWorktree();
    }
    // When repoPath changes (worktree switch), clear cache and reload
    if (component.repoPath != old.repoPath) {
      _cachedBranches = null;
      _cachedWorktrees = null;
      _commitsAheadOfMain = null;
      _branchesLoading = false;
      _isMultiRepoMode = null;
      _childRepos = null;
      // Re-detect repo mode
      _detectRepoMode();
      // Reset selection
      _selectedIndex = 0;
    }
  }

  /// Select the current worktree in the navigation list.
  void _selectCurrentWorktree() {
    // Find index of current worktree (skip quick actions at top)
    // Quick actions are at index 0 and 1, current worktree header is at index 2
    setState(() {
      _selectedIndex = 2; // Index after the two quick action items
    });
  }

  void _animateToWidth(double targetWidth) {
    _widthAnimation = Tween<double>(
      begin: _currentWidth,
      end: targetWidth,
    ).chain(CurveTween(curve: Curves.easeOut)).animate(_animationController);
    _animationController.forward(from: 0);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Builds a flat list of all changed files with their statuses from git status.
  List<ChangedFile> _buildChangedFiles(dynamic gitStatus) {
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
    final mainBranch = _cachedBranches?.firstWhere(
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
        _cachedBranches
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
    final branches = _repoBranches[repoPath] ?? [];
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
  /// This is the unified navigation model for keyboard navigation.
  List<NavigableItem> _buildNavigableItems(BuildContext context) {
    // Check if we're in multi-repo mode
    if (_isMultiRepoMode == true && _childRepos != null) {
      return _buildMultiRepoItems(context);
    }

    final items = <NavigableItem>[];

    // Get current branch for base options
    final gitStatusAsync = context.watch(
      gitStatusStreamProvider(component.repoPath),
    );
    final currentBranch = gitStatusAsync.valueOrNull?.branch ?? 'main';

    // New branch action with optional branch selection
    items.add(
      NavigableItem(
        type: NavigableItemType.newBranchAction,
        name: '+ New branch...',
        isExpanded: _branchActionState != QuickActionState.collapsed,
      ),
    );

    // Show branch options if selecting base branch for new branch
    if (_branchActionState == QuickActionState.selectingBaseBranch) {
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
        isExpanded: _worktreeActionState != QuickActionState.collapsed,
      ),
    );

    // Show branch options if selecting base branch for new worktree
    if (_worktreeActionState == QuickActionState.selectingBaseBranch) {
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
    final resolvedCurrentPath =
        _findCurrentWorktreePath() ?? component.repoPath;
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
    if (_cachedBranches == null && !_branchesLoading) {
      _loadBranchesAndWorktrees();
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
    if (_cachedWorktrees != null) {
      for (final worktree in _cachedWorktrees!) {
        if (worktree.path == resolvedCurrentPath) continue; // Skip current

        // Only watch status if expanded (lazy loading)
        final isExpanded = _isWorktreeExpanded(worktree.path);
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
    if (_cachedBranches != null) {
      final worktreeBranches =
          _cachedWorktrees?.map((w) => w.branch).toSet() ?? {};
      worktreeBranches.add(gitStatus?.branch ?? '');

      final otherBranches = _cachedBranches!
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

        final displayCount = _showAllBranches
            ? otherBranches.length
            : _initialBranchCount.clamp(0, otherBranches.length);

        for (var i = 0; i < displayCount; i++) {
          final branchName = otherBranches[i].name;
          final isExpanded = _expandedBranchName == branchName;

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

        if (!_showAllBranches && otherBranches.length > _initialBranchCount) {
          items.add(
            NavigableItem(
              type: NavigableItemType.showMoreBranches,
              name: 'Show more (${otherBranches.length - _initialBranchCount})',
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
    final isExpanded = _isWorktreeExpanded(path);

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
      final worktreeActionsExpanded = _expandedWorktreeActions.contains(path);
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
    final changedFiles = _buildChangedFiles(gitStatus);

    // For current worktree, add Actions menu before changed files
    if (isCurrentWorktree) {
      // Add Actions header
      items.add(
        NavigableItem(
          type: NavigableItemType.actionsHeader,
          name: 'Actions',
          worktreePath: path,
          isExpanded: _actionsExpanded,
        ),
      );

      // Add child actions if expanded
      if (_actionsExpanded) {
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
              ? 'Sync (↓$behind ↑$ahead)'
              : behind > 0
              ? 'Sync (↓$behind)'
              : 'Sync (↑$ahead)';
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
        final isAheadOfMain = (_commitsAheadOfMain ?? 0) > 0;
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
        ((!(_actionsExpanded &&
            ((_commitsAheadOfMain ?? 0) > 0 &&
                branch != 'main' &&
                branch != 'master'))))) {
      // Show "No changes" placeholder when:
      // - Not current worktree, or
      // - Current worktree and not showing merge action in expanded actions
      final isMainBranch = branch == 'main' || branch == 'master';
      final isAheadOfMain = (_commitsAheadOfMain ?? 0) > 0;
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

    if (_childRepos == null || _childRepos!.isEmpty) {
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

    for (final repo in _childRepos!) {
      // Only watch status if expanded (lazy loading)
      GitStatus? status;
      if (_isRepoExpanded(repo.path)) {
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
    final isExpanded = _isRepoExpanded(repo.path);
    final branches = _repoBranches[repo.path];
    final worktrees = _repoWorktrees[repo.path];
    final commitsAhead = _repoCommitsAheadOfMain[repo.path] ?? 0;

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
        _repoBranchActionState[repo.path] ?? QuickActionState.collapsed;
    final worktreeActionState =
        _repoWorktreeActionState[repo.path] ?? QuickActionState.collapsed;

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
    final actionsExpanded = _repoActionsExpanded[repo.path] ?? false;
    items.add(
      NavigableItem(
        type: NavigableItemType.actionsHeader,
        name: 'Actions',
        isExpanded: actionsExpanded,
        worktreePath: repo.path,
      ),
    );

    if (actionsExpanded && status != null) {
      // Conditional: "Commit & push" - only when there are changes
      final changedFiles = _buildChangedFiles(status);
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
            ? 'Sync (↓$behind ↑$ahead)'
            : behind > 0
            ? 'Sync (↓$behind)'
            : 'Sync (↑$ahead)';
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
      final changedFiles = _buildChangedFiles(status);
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
        final expandedBranch = _repoExpandedBranchName[repo.path];

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

  /// Check if we're in name input mode for either action
  bool get _isEnteringName {
    // Check global state (single-repo mode)
    if (_branchActionState == QuickActionState.enteringName ||
        _worktreeActionState == QuickActionState.enteringName) {
      return true;
    }

    // Check per-repo states (multi-repo mode)
    for (final state in _repoBranchActionState.values) {
      if (state == QuickActionState.enteringName) return true;
    }
    for (final state in _repoWorktreeActionState.values) {
      if (state == QuickActionState.enteringName) return true;
    }

    return false;
  }

  void _handleKeyEvent(
    KeyboardEvent event,
    BuildContext context,
    List<NavigableItem> items,
  ) {
    if (items.isEmpty) return;

    // Handle input mode differently
    if (_isEnteringName) {
      _handleInputModeKey(event, context);
      return;
    }

    if (event.logicalKey == LogicalKey.escape) {
      // First check if quick action is expanded - collapse it first
      if (_branchActionState != QuickActionState.collapsed ||
          _worktreeActionState != QuickActionState.collapsed) {
        setState(() {
          _branchActionState = QuickActionState.collapsed;
          _worktreeActionState = QuickActionState.collapsed;
        });
        return;
      }
      // Then check if file preview is open - close it first
      final filePreviewPath = context.read(filePreviewPathProvider);
      if (filePreviewPath != null) {
        context.read(filePreviewPathProvider.notifier).state = null;
      } else {
        // No preview open - exit sidebar
        component.onExitRight?.call();
      }
    } else if (event.logicalKey == LogicalKey.arrowRight) {
      // Right arrow exits sidebar (for left-positioned sidebar)
      component.onExitRight?.call();
    } else if (event.logicalKey == LogicalKey.arrowLeft) {
      // Left arrow exits sidebar (for right-positioned sidebar)
      component.onExitLeft?.call();
    } else if (event.logicalKey == LogicalKey.arrowUp ||
        event.logicalKey == LogicalKey.keyK) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1).clamp(0, items.length - 1);
        _scrollController.ensureIndexVisible(index: _selectedIndex);
      });
    } else if (event.logicalKey == LogicalKey.arrowDown ||
        event.logicalKey == LogicalKey.keyJ) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1).clamp(0, items.length - 1);
        _scrollController.ensureIndexVisible(index: _selectedIndex);
      });
    } else if (event.logicalKey == LogicalKey.enter ||
        event.logicalKey == LogicalKey.space) {
      if (_selectedIndex < items.length) {
        _activateItem(items[_selectedIndex], context);
      }
    }
  }

  void _handleInputModeKey(KeyboardEvent event, BuildContext context) {
    if (event.logicalKey == LogicalKey.escape) {
      // Cancel input - go back to collapsed state
      setState(() {
        // Reset single-repo state
        _branchActionState = QuickActionState.collapsed;
        _worktreeActionState = QuickActionState.collapsed;
        _activeInputType = null;
        _selectedBaseBranch = null;
        // Reset multi-repo state
        if (_activeInputRepoPath != null) {
          _repoBranchActionState[_activeInputRepoPath!] =
              QuickActionState.collapsed;
          _repoWorktreeActionState[_activeInputRepoPath!] =
              QuickActionState.collapsed;
          _repoActiveInputType[_activeInputRepoPath!] = null;
          _repoSelectedBaseBranch[_activeInputRepoPath!] = null;
          _activeInputRepoPath = null;
        }
        _inputBuffer = '';
      });
    } else if (event.logicalKey == LogicalKey.enter) {
      // Execute action
      _executeQuickAction(context);
    } else if (event.logicalKey == LogicalKey.backspace) {
      setState(() {
        if (_inputBuffer.isNotEmpty) {
          _inputBuffer = _inputBuffer.substring(0, _inputBuffer.length - 1);
        }
      });
    } else if (event.character != null && event.character!.isNotEmpty) {
      // Add character to buffer
      setState(() {
        _inputBuffer += event.character!;
      });
    }
  }

  Future<void> _executeQuickAction(BuildContext context) async {
    // Determine if we're in multi-repo mode (has activeInputRepoPath)
    final repoPath = _activeInputRepoPath;

    if (_inputBuffer.isEmpty) {
      setState(() {
        // Reset single-repo state
        _branchActionState = QuickActionState.collapsed;
        _worktreeActionState = QuickActionState.collapsed;
        _activeInputType = null;
        _selectedBaseBranch = null;
        // Reset multi-repo state
        if (repoPath != null) {
          _repoBranchActionState[repoPath] = QuickActionState.collapsed;
          _repoWorktreeActionState[repoPath] = QuickActionState.collapsed;
          _repoActiveInputType[repoPath] = null;
          _repoSelectedBaseBranch[repoPath] = null;
          _activeInputRepoPath = null;
        }
      });
      return;
    }

    final newBranchName = _inputBuffer.trim();

    // Determine the target repo path and related state
    final targetRepoPath = repoPath ?? component.repoPath;
    final baseBranch = repoPath != null
        ? _repoSelectedBaseBranch[repoPath]
        : _selectedBaseBranch;
    final activeType = repoPath != null
        ? _repoActiveInputType[repoPath]
        : _activeInputType;

    final client = GitClient(workingDirectory: targetRepoPath);

    try {
      if (activeType == NavigableItemType.newBranchAction) {
        // Create and checkout new branch from base
        // First checkout base branch if different from current
        if (baseBranch != null) {
          await client.checkout(baseBranch);
        }
        await client.checkout(newBranchName, create: true);
      } else if (activeType == NavigableItemType.newWorktreeAction) {
        // Create worktree with new branch from base
        // Path: ../reponame-branchname
        final repoName = p.basename(targetRepoPath);
        final worktreePath = p.join(
          p.dirname(targetRepoPath),
          '$repoName-$newBranchName',
        );
        // Use base branch as the starting point
        await client.worktreeAdd(
          worktreePath,
          branch: newBranchName,
          createBranch: true,
          baseBranch: baseBranch,
        );

        // Auto-switch to the new worktree (only for single-repo mode)
        if (repoPath == null) {
          component.onSwitchWorktree?.call(worktreePath);
        }
      }

      // Refresh branches/worktrees
      if (repoPath != null) {
        await _loadRepoBranchesAndWorktrees(repoPath);
      } else {
        _cachedBranches = null;
        _cachedWorktrees = null;
        await _loadBranchesAndWorktrees();
      }
    } catch (e) {
      // TODO: Show error to user
    }

    setState(() {
      // Reset single-repo state
      _branchActionState = QuickActionState.collapsed;
      _worktreeActionState = QuickActionState.collapsed;
      _activeInputType = null;
      _selectedBaseBranch = null;
      // Reset multi-repo state
      if (repoPath != null) {
        _repoBranchActionState[repoPath] = QuickActionState.collapsed;
        _repoWorktreeActionState[repoPath] = QuickActionState.collapsed;
        _repoActiveInputType[repoPath] = null;
        _repoSelectedBaseBranch[repoPath] = null;
        _activeInputRepoPath = null;
      }
      _inputBuffer = '';
    });
  }

  /// Checkout a branch from the "Other Branches" list.
  Future<void> _checkoutBranch(String branchName, String repoPath) async {
    final client = GitClient(workingDirectory: repoPath);

    try {
      await client.checkout(branchName);

      // Refresh branches/worktrees to reflect the change
      if (_isMultiRepoMode == true) {
        await _loadRepoBranchesAndWorktrees(repoPath);
      } else {
        _cachedBranches = null;
        _cachedWorktrees = null;
        await _loadBranchesAndWorktrees();
      }
    } catch (e) {
      // TODO: Show error to user (e.g., uncommitted changes)
    }
  }

  /// Create a worktree from an existing branch.
  Future<void> _createWorktreeFromBranch(
    String branchName,
    String repoPath,
  ) async {
    final client = GitClient(workingDirectory: repoPath);

    try {
      // Create worktree path: ../reponame-branchname
      final repoName = p.basename(repoPath);
      final worktreePath = p.join(p.dirname(repoPath), '$repoName-$branchName');

      // Create worktree with existing branch (don't create new branch)
      await client.worktreeAdd(
        worktreePath,
        branch: branchName,
        createBranch: false,
      );

      // Auto-switch to the new worktree (only for single-repo mode)
      if (_isMultiRepoMode != true) {
        component.onSwitchWorktree?.call(worktreePath);
      }

      // Refresh branches/worktrees to reflect the change
      if (_isMultiRepoMode == true) {
        await _loadRepoBranchesAndWorktrees(repoPath);
      } else {
        _cachedBranches = null;
        _cachedWorktrees = null;
        await _loadBranchesAndWorktrees();
      }
    } catch (e) {
      // TODO: Show error to user
    }
  }

  /// Merge current branch to main: checkout main, merge feature branch, then checkout back.
  Future<void> _mergeToMain(String featureBranch, String repoPath) async {
    setState(() => _loadingAction = 'merge');

    final client = GitClient(workingDirectory: repoPath);
    final toastNotifier = context.read(toastProvider.notifier);

    // Determine the main branch name (main or master)
    final branches = _isMultiRepoMode == true
        ? _repoBranches[repoPath]
        : _cachedBranches;
    final mainBranch = branches?.any((b) => b.name == 'main') == true
        ? 'main'
        : 'master';

    try {
      // 1. Checkout main
      await client.checkout(mainBranch);

      // 2. Merge the feature branch
      await client.merge(featureBranch);

      toastNotifier.success('Merged to main successfully');

      // Refresh branches/worktrees to reflect the change
      if (_isMultiRepoMode == true) {
        await _loadRepoBranchesAndWorktrees(repoPath);
      } else {
        _cachedBranches = null;
        _cachedWorktrees = null;
        await _loadBranchesAndWorktrees();
      }
    } catch (e) {
      toastNotifier.error('Merge failed: ${e.toString()}');
      // Try to go back to the feature branch on failure
      try {
        await client.checkout(featureBranch);
      } catch (_) {}
    } finally {
      setState(() => _loadingAction = null);
    }
  }

  /// Sync with remote: pull --rebase then push.
  Future<void> _sync(String repoPath) async {
    setState(() => _loadingAction = 'sync');

    final client = GitClient(workingDirectory: repoPath);
    final toastNotifier = context.read(toastProvider.notifier);

    try {
      // Pull with rebase first (IntelliJ style)
      await client.pull(rebase: true);

      // Then push local commits
      await client.push();

      toastNotifier.success('Synced successfully');

      // Refresh to reflect the updated state
      if (_isMultiRepoMode == true) {
        await _loadRepoBranchesAndWorktrees(repoPath);
      } else {
        _cachedBranches = null;
        _cachedWorktrees = null;
        await _loadBranchesAndWorktrees();
      }
    } catch (e) {
      toastNotifier.error('Sync failed: ${e.toString()}');
    } finally {
      setState(() => _loadingAction = null);
    }
  }

  /// Pull from remote.
  Future<void> _pull(String repoPath) async {
    setState(() => _loadingAction = 'pull');

    final client = GitClient(workingDirectory: repoPath);
    final toastNotifier = context.read(toastProvider.notifier);

    try {
      await client.pull();
      toastNotifier.success('Pulled successfully');

      // Refresh to reflect the updated state
      if (_isMultiRepoMode == true) {
        await _loadRepoBranchesAndWorktrees(repoPath);
      } else {
        _cachedBranches = null;
        _cachedWorktrees = null;
        await _loadBranchesAndWorktrees();
      }
    } catch (e) {
      toastNotifier.error('Pull failed: ${e.toString()}');
    } finally {
      setState(() => _loadingAction = null);
    }
  }

  /// Push to remote.
  Future<void> _push(String repoPath) async {
    setState(() => _loadingAction = 'push');

    final client = GitClient(workingDirectory: repoPath);
    final toastNotifier = context.read(toastProvider.notifier);

    try {
      await client.push();
      toastNotifier.success('Pushed successfully');

      // Refresh to reflect the updated state
      if (_isMultiRepoMode == true) {
        await _loadRepoBranchesAndWorktrees(repoPath);
      } else {
        _cachedBranches = null;
        _cachedWorktrees = null;
        await _loadBranchesAndWorktrees();
      }
    } catch (e) {
      toastNotifier.error('Push failed: ${e.toString()}');
    } finally {
      setState(() => _loadingAction = null);
    }
  }

  /// Fetch from remote.
  Future<void> _fetch(String repoPath) async {
    setState(() => _loadingAction = 'fetch');

    final client = GitClient(workingDirectory: repoPath);
    final toastNotifier = context.read(toastProvider.notifier);

    try {
      await client.fetch();
      toastNotifier.success('Fetched successfully');

      // Refresh to reflect the updated state
      if (_isMultiRepoMode == true) {
        await _loadRepoBranchesAndWorktrees(repoPath);
      } else {
        _cachedBranches = null;
        _cachedWorktrees = null;
        await _loadBranchesAndWorktrees();
      }
    } catch (e) {
      toastNotifier.error('Fetch failed: ${e.toString()}');
    } finally {
      setState(() => _loadingAction = null);
    }
  }

  /// Remove a worktree.
  Future<void> _removeWorktree(String worktreePath) async {
    setState(() => _loadingAction = 'remove');

    final client = GitClient(workingDirectory: component.repoPath);
    final toastNotifier = context.read(toastProvider.notifier);

    try {
      await client.worktreeRemove(worktreePath);
      toastNotifier.success('Worktree removed');

      // Refresh to reflect the updated state
      _cachedWorktrees = null;
      await _loadBranchesAndWorktrees();
    } catch (e) {
      toastNotifier.error('Failed to remove worktree: ${e.toString()}');
    } finally {
      setState(() => _loadingAction = null);
    }
  }

  /// Activates an item (used for both keyboard and mouse click).
  void _activateItem(NavigableItem item, BuildContext context) {
    switch (item.type) {
      case NavigableItemType.newBranchAction:
        final repoPath = item.worktreePath;
        if (repoPath != null) {
          // Multi-repo mode
          setState(() {
            final currentState =
                _repoBranchActionState[repoPath] ?? QuickActionState.collapsed;
            if (currentState == QuickActionState.collapsed) {
              _repoBranchActionState[repoPath] =
                  QuickActionState.selectingBaseBranch;
              _repoWorktreeActionState[repoPath] =
                  QuickActionState.collapsed; // Collapse other
            } else {
              _repoBranchActionState[repoPath] = QuickActionState.collapsed;
            }
          });
        } else {
          // Single-repo mode
          setState(() {
            if (_branchActionState == QuickActionState.collapsed) {
              _branchActionState = QuickActionState.selectingBaseBranch;
              _worktreeActionState =
                  QuickActionState.collapsed; // Collapse other
            } else {
              _branchActionState = QuickActionState.collapsed;
            }
          });
        }
        break;
      case NavigableItemType.newWorktreeAction:
        final wtRepoPath = item.worktreePath;
        if (wtRepoPath != null) {
          // Multi-repo mode
          setState(() {
            final currentState =
                _repoWorktreeActionState[wtRepoPath] ??
                QuickActionState.collapsed;
            if (currentState == QuickActionState.collapsed) {
              _repoWorktreeActionState[wtRepoPath] =
                  QuickActionState.selectingBaseBranch;
              _repoBranchActionState[wtRepoPath] =
                  QuickActionState.collapsed; // Collapse other
            } else {
              _repoWorktreeActionState[wtRepoPath] = QuickActionState.collapsed;
            }
          });
        } else {
          // Single-repo mode
          setState(() {
            if (_worktreeActionState == QuickActionState.collapsed) {
              _worktreeActionState = QuickActionState.selectingBaseBranch;
              _branchActionState = QuickActionState.collapsed; // Collapse other
            } else {
              _worktreeActionState = QuickActionState.collapsed;
            }
          });
        }
        break;
      case NavigableItemType.baseBranchOption:
        // User selected a base branch - go to input mode
        final isForBranch = item.fullPath == 'branch';
        if (item.name == 'Other...') {
          // TODO: Show full branch list picker
          // For now, just use current branch
          return;
        }
        final optionRepoPath = item.worktreePath;
        if (optionRepoPath != null) {
          // Multi-repo mode
          setState(() {
            _repoSelectedBaseBranch[optionRepoPath] = item.name;
            _repoActiveInputType[optionRepoPath] = isForBranch
                ? NavigableItemType.newBranchAction
                : NavigableItemType.newWorktreeAction;
            if (isForBranch) {
              _repoBranchActionState[optionRepoPath] =
                  QuickActionState.enteringName;
            } else {
              _repoWorktreeActionState[optionRepoPath] =
                  QuickActionState.enteringName;
            }
            _activeInputRepoPath = optionRepoPath;
            _inputBuffer = '';
          });
        } else {
          // Single-repo mode
          setState(() {
            _selectedBaseBranch = item.name;
            _activeInputType = isForBranch
                ? NavigableItemType.newBranchAction
                : NavigableItemType.newWorktreeAction;
            if (isForBranch) {
              _branchActionState = QuickActionState.enteringName;
            } else {
              _worktreeActionState = QuickActionState.enteringName;
            }
            _inputBuffer = '';
          });
        }
        break;
      case NavigableItemType.worktreeHeader:
        // Always toggle expansion - switching is done via dedicated action
        _toggleWorktreeExpansion(item.worktreePath!);
        break;
      case NavigableItemType.changesSectionLabel:
      case NavigableItemType.branchSectionLabel:
      case NavigableItemType.divider:
      case NavigableItemType.noChangesPlaceholder:
        // Labels, dividers, and placeholders are not activatable
        break;
      case NavigableItemType.file:
        final basePath = item.worktreePath ?? component.repoPath;
        final fullFilePath = '$basePath/${item.fullPath}';
        context.read(filePreviewPathProvider.notifier).state = fullFilePath;
        // Focus stays on sidebar - ESC will close file preview first
        break;
      case NavigableItemType.commitPushAction:
        // Send "commit and push" message to the chat
        component.onSendMessage?.call('commit and push');
        break;
      case NavigableItemType.syncAction:
        // Sync with remote (pull --rebase, then push)
        if (_loadingAction == null) {
          final repoPath = item.worktreePath ?? component.repoPath;
          _sync(repoPath);
        }
        break;
      case NavigableItemType.mergeToMainAction:
        // Merge current branch to main
        if (_loadingAction == null) {
          final repoPath = item.worktreePath ?? component.repoPath;
          _mergeToMain(item.fullPath!, repoPath);
        }
        break;
      case NavigableItemType.switchWorktreeAction:
        // Switch to the worktree
        component.onSwitchWorktree?.call(item.worktreePath!);
        break;
      case NavigableItemType.worktreeCopyPathAction:
        // Copy worktree path to clipboard
        ClipboardManager.copy(item.worktreePath!);
        context
            .read(toastProvider.notifier)
            .success('Path copied to clipboard');
        break;
      case NavigableItemType.worktreeRemoveAction:
        // Remove the worktree
        if (_loadingAction == null) _removeWorktree(item.worktreePath!);
        break;
      case NavigableItemType.branch:
        // Toggle branch expansion to show/hide actions
        final repoPath = item.worktreePath;
        if (repoPath != null && _isMultiRepoMode == true) {
          // Multi-repo mode
          setState(() {
            final current = _repoExpandedBranchName[repoPath];
            _repoExpandedBranchName[repoPath] = current == item.name
                ? null
                : item.name;
          });
        } else {
          // Single-repo mode
          setState(() {
            if (_expandedBranchName == item.name) {
              _expandedBranchName = null; // Collapse if already expanded
            } else {
              _expandedBranchName = item.name; // Expand this branch
            }
          });
        }
        break;
      case NavigableItemType.branchCheckoutAction:
        // Checkout the branch
        final checkoutRepoPath = item.worktreePath ?? component.repoPath;
        _checkoutBranch(item.fullPath!, checkoutRepoPath);
        if (item.worktreePath != null && _isMultiRepoMode == true) {
          setState(() => _repoExpandedBranchName[item.worktreePath!] = null);
        } else {
          setState(() => _expandedBranchName = null);
        }
        break;
      case NavigableItemType.branchWorktreeAction:
        // Create a worktree from this branch
        final wtRepoPath = item.worktreePath ?? component.repoPath;
        _createWorktreeFromBranch(item.fullPath!, wtRepoPath);
        if (item.worktreePath != null && _isMultiRepoMode == true) {
          setState(() => _repoExpandedBranchName[item.worktreePath!] = null);
        } else {
          setState(() => _expandedBranchName = null);
        }
        break;
      case NavigableItemType.showMoreBranches:
        setState(() => _showAllBranches = true);
        break;
      case NavigableItemType.actionsHeader:
        final actionsRepoPath = item.worktreePath;
        if (actionsRepoPath != null && _isMultiRepoMode == true) {
          // Multi-repo mode
          setState(() {
            _repoActionsExpanded[actionsRepoPath] =
                !(_repoActionsExpanded[actionsRepoPath] ?? false);
          });
        } else {
          // Single-repo mode
          setState(() {
            _actionsExpanded = !_actionsExpanded;
          });
        }
        break;
      case NavigableItemType.pullAction:
        if (_loadingAction == null) {
          final pullRepoPath = item.worktreePath ?? component.repoPath;
          _pull(pullRepoPath);
        }
        break;
      case NavigableItemType.pushAction:
        if (_loadingAction == null) {
          final pushRepoPath = item.worktreePath ?? component.repoPath;
          _push(pushRepoPath);
        }
        break;
      case NavigableItemType.fetchAction:
        if (_loadingAction == null) {
          final fetchRepoPath = item.worktreePath ?? component.repoPath;
          _fetch(fetchRepoPath);
        }
        break;
      case NavigableItemType.worktreeActionsHeader:
        // Toggle expansion state for this worktree's actions
        setState(() {
          final path = item.worktreePath!;
          if (_expandedWorktreeActions.contains(path)) {
            _expandedWorktreeActions.remove(path);
          } else {
            _expandedWorktreeActions.add(path);
          }
        });
        break;
      case NavigableItemType.repoHeader:
        // Toggle repository expansion in multi-repo mode
        _toggleRepoExpansion(item.fullPath!);
        break;
    }
  }

  /// Loads branches and worktrees on initialization.
  Future<void> _loadBranchesAndWorktrees() async {
    if (_branchesLoading) return;

    setState(() {
      _branchesLoading = true;
    });

    try {
      final client = GitClient(workingDirectory: component.repoPath);
      final branches = await client.branches();
      final worktrees = await client.worktreeList();

      // Check commits ahead of main (try 'main' first, then 'master')
      int commitsAhead = await client.getCommitsAheadOf('main');
      if (commitsAhead == 0) {
        // Try master if main didn't work or has 0 commits
        commitsAhead = await client.getCommitsAheadOf('master');
      }

      // Sort branches: current first, then alphabetically
      branches.sort((a, b) {
        if (a.isCurrent && !b.isCurrent) return -1;
        if (!a.isCurrent && b.isCurrent) return 1;
        return a.name.compareTo(b.name);
      });

      // Filter out remote branches
      final localBranches = branches.where((b) => !b.isRemote).toList();

      setState(() {
        _cachedBranches = localBranches;
        _cachedWorktrees = worktrees;
        _commitsAheadOfMain = commitsAhead;
        _branchesLoading = false;
      });
    } catch (e) {
      setState(() {
        _cachedBranches = []; // Prevent infinite retry loop
        _cachedWorktrees = [];
        _branchesLoading = false;
      });
    }
  }

  /// Checks if a branch is checked out in a worktree.
  bool _isWorktreeBranch(String branchName) {
    if (_cachedWorktrees == null) return false;
    return _cachedWorktrees!.any((w) => w.branch == branchName);
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    final gitStatusAsync = context.watch(
      gitStatusStreamProvider(component.repoPath),
    );
    final gitStatus = gitStatusAsync.valueOrNull;
    final navigableItems = _buildNavigableItems(context);

    // Clamp selected index to valid range
    if (navigableItems.isNotEmpty && _selectedIndex >= navigableItems.length) {
      _selectedIndex = navigableItems.length - 1;
    }

    final isCollapsed = _currentWidth < _expandedWidth / 2;

    return Focusable(
      focused: component.focused,
      onKeyEvent: (event) {
        _handleKeyEvent(event, context, navigableItems);
        return true;
      },
      child: Container(
        decoration: BoxDecoration(color: theme.base.surface),
        child: ClipRect(
          child: SizedBox(
            width: _currentWidth,
            child: isCollapsed
                ? _buildCollapsedIndicator(theme)
                : OverflowBox(
                    alignment: Alignment.topLeft,
                    minWidth: _expandedWidth,
                    maxWidth: _expandedWidth,
                    child: _buildExpandedContent(
                      context,
                      theme,
                      gitStatus,
                      navigableItems,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  /// Builds the collapsed indicator (just expand arrow, minimal).
  Component _buildCollapsedIndicator(VideThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Top padding to align with main content
        SizedBox(height: 1),
        // Header area matching expanded state (no bottom border)
        Container(
          padding: EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(color: theme.base.outline.withOpacity(0.3)),
          child: Center(
            child: Text(
              '›',
              style: TextStyle(
                color: theme.base.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        // Fill remaining space
        Expanded(child: SizedBox()),
      ],
    );
  }

  /// Builds the sidebar content (always at full width, clipping handles animation).
  Component _buildExpandedContent(
    BuildContext context,
    VideThemeData theme,
    dynamic gitStatus,
    List<NavigableItem> items,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Available width for content (subtract padding)
        final availableWidth =
            constraints.maxWidth.toInt() - 2; // 1 padding on each side

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top padding to align with main content
            SizedBox(height: 1),
            // All navigable items in ListView (including branch headers)
            Expanded(
              child: ListView(
                controller: _scrollController,
                children: [
                  for (var i = 0; i < items.length; i++)
                    _buildNavigableItemRow(
                      context,
                      items[i],
                      i,
                      theme,
                      availableWidth,
                      gitStatus,
                    ),
                ],
              ),
            ),
            // Navigation hint at bottom
            if (component.focused)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 1),
                child: Text(
                  '→ to exit',
                  style: TextStyle(
                    color: theme.base.onSurface.withOpacity(
                      TextOpacity.disabled,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Builds a row for any navigable item type.
  Component _buildNavigableItemRow(
    BuildContext context,
    NavigableItem item,
    int index,
    VideThemeData theme,
    int availableWidth,
    dynamic gitStatus,
  ) {
    final isSelected = component.focused && _selectedIndex == index;
    final isHovered = _hoveredIndex == index;

    // Wrap with mouse region for hover and click
    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = null),
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedIndex = index);
          _activateItem(item, context);
        },
        child: _buildItemContent(
          item,
          isSelected,
          isHovered,
          theme,
          availableWidth,
          gitStatus,
        ),
      ),
    );
  }

  /// Builds the content for a navigable item row.
  Component _buildItemContent(
    NavigableItem item,
    bool isSelected,
    bool isHovered,
    VideThemeData theme,
    int availableWidth,
    dynamic gitStatus,
  ) {
    switch (item.type) {
      case NavigableItemType.newBranchAction:
      case NavigableItemType.newWorktreeAction:
        return buildQuickActionRow(
          item: item,
          isSelected: isSelected,
          isHovered: isHovered,
          theme: theme,
          availableWidth: availableWidth,
          branchActionState: _branchActionState,
          worktreeActionState: _worktreeActionState,
          activeInputType: _activeInputType,
          inputBuffer: _inputBuffer,
          repoBranchActionState: _repoBranchActionState,
          repoWorktreeActionState: _repoWorktreeActionState,
          repoActiveInputType: _repoActiveInputType,
        );
      case NavigableItemType.baseBranchOption:
        return buildBaseBranchOptionRow(
          item: item,
          isSelected: isSelected,
          isHovered: isHovered,
          theme: theme,
          availableWidth: availableWidth,
        );
      case NavigableItemType.worktreeHeader:
        // Resolve actual worktree path - CWD might be a subdirectory
        final resolvedCurrentPath =
            _findCurrentWorktreePath() ?? component.repoPath;
        return buildWorktreeHeaderRow(
          item: item,
          isSelected: isSelected,
          isHovered: isHovered,
          theme: theme,
          availableWidth: availableWidth,
          gitStatus: gitStatus as GitStatus?,
          isCurrentWorktree: item.worktreePath == resolvedCurrentPath,
        );
      case NavigableItemType.changesSectionLabel:
        return buildChangesSectionLabelRow(
          item: item,
          isSelected: isSelected,
          isHovered: isHovered,
          theme: theme,
          availableWidth: availableWidth,
        );
      case NavigableItemType.file:
        return buildFileRow(
          item: item,
          isSelected: isSelected,
          isHovered: isHovered,
          theme: theme,
          availableWidth: availableWidth,
        );
      case NavigableItemType.actionsHeader:
        return buildActionsHeaderRow(
          item: item,
          isSelected: isSelected,
          isHovered: isHovered,
          theme: theme,
          availableWidth: availableWidth,
          actionsExpanded: _actionsExpanded,
          isMultiRepoMode: _isMultiRepoMode == true,
          repoActionsExpanded: _repoActionsExpanded,
        );
      case NavigableItemType.commitPushAction:
        return buildCommitPushActionRow(
          item: item,
          isSelected: isSelected,
          isHovered: isHovered,
          theme: theme,
          availableWidth: availableWidth,
        );
      case NavigableItemType.syncAction:
        return buildSyncActionRow(
          item: item,
          isSelected: isSelected,
          isHovered: isHovered,
          theme: theme,
          availableWidth: availableWidth,
          loadingAction: _loadingAction,
        );
      case NavigableItemType.mergeToMainAction:
        return buildMergeToMainActionRow(
          item: item,
          isSelected: isSelected,
          isHovered: isHovered,
          theme: theme,
          availableWidth: availableWidth,
          loadingAction: _loadingAction,
        );
      case NavigableItemType.pullAction:
        return buildPullActionRow(
          item: item,
          isSelected: isSelected,
          isHovered: isHovered,
          theme: theme,
          availableWidth: availableWidth,
          loadingAction: _loadingAction,
        );
      case NavigableItemType.pushAction:
        return buildPushActionRow(
          item: item,
          isSelected: isSelected,
          isHovered: isHovered,
          theme: theme,
          availableWidth: availableWidth,
          loadingAction: _loadingAction,
        );
      case NavigableItemType.fetchAction:
        return buildFetchActionRow(
          item: item,
          isSelected: isSelected,
          isHovered: isHovered,
          theme: theme,
          availableWidth: availableWidth,
          loadingAction: _loadingAction,
        );
      case NavigableItemType.switchWorktreeAction:
        return buildSwitchWorktreeActionRow(
          item: item,
          isSelected: isSelected,
          isHovered: isHovered,
          theme: theme,
          availableWidth: availableWidth,
        );
      case NavigableItemType.worktreeCopyPathAction:
        return buildWorktreeCopyPathActionRow(
          item: item,
          isSelected: isSelected,
          isHovered: isHovered,
          theme: theme,
          availableWidth: availableWidth,
        );
      case NavigableItemType.worktreeRemoveAction:
        return buildWorktreeRemoveActionRow(
          item: item,
          isSelected: isSelected,
          isHovered: isHovered,
          theme: theme,
          availableWidth: availableWidth,
          loadingAction: _loadingAction,
        );
      case NavigableItemType.worktreeActionsHeader:
        return buildWorktreeActionsHeaderRow(
          item: item,
          isSelected: isSelected,
          isHovered: isHovered,
          theme: theme,
          availableWidth: availableWidth,
        );
      case NavigableItemType.noChangesPlaceholder:
        return buildNoChangesPlaceholderRow(
          item: item,
          isSelected: isSelected,
          isHovered: isHovered,
          theme: theme,
          availableWidth: availableWidth,
        );
      case NavigableItemType.divider:
        return buildDividerRow(theme: theme, availableWidth: availableWidth);
      case NavigableItemType.branchSectionLabel:
        return buildBranchSectionLabelRow(
          item: item,
          isSelected: isSelected,
          isHovered: isHovered,
          theme: theme,
          availableWidth: availableWidth,
        );
      case NavigableItemType.branch:
        return buildBranchRow(
          item: item,
          isSelected: isSelected,
          isHovered: isHovered,
          theme: theme,
          availableWidth: availableWidth,
          cachedBranches: _cachedBranches,
          isWorktreeBranch: _isWorktreeBranch,
        );
      case NavigableItemType.branchCheckoutAction:
        return buildBranchActionRow(
          item: item,
          isSelected: isSelected,
          isHovered: isHovered,
          theme: theme,
          availableWidth: availableWidth,
          icon: '→',
        );
      case NavigableItemType.branchWorktreeAction:
        return buildBranchActionRow(
          item: item,
          isSelected: isSelected,
          isHovered: isHovered,
          theme: theme,
          availableWidth: availableWidth,
          icon: '⎇',
        );
      case NavigableItemType.showMoreBranches:
        return buildShowMoreBranchesRow(
          item: item,
          isSelected: isSelected,
          isHovered: isHovered,
          theme: theme,
          availableWidth: availableWidth,
        );
      case NavigableItemType.repoHeader:
        // Watch status for repo header
        GitStatus? status;
        if (item.fullPath != null) {
          final statusAsync = context.watch(
            gitStatusStreamProvider(item.fullPath!),
          );
          status = statusAsync.valueOrNull;
        }
        return buildRepoHeaderRow(
          item: item,
          isSelected: isSelected,
          isHovered: isHovered,
          theme: theme,
          availableWidth: availableWidth,
          status: status,
        );
    }
  }
}
