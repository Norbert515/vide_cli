import 'dart:async';

import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:vide_core/mcp/git/git_client.dart';
import 'package:vide_core/mcp/git/git_models.dart';
import 'package:vide_core/mcp/git/git_providers.dart';
import 'package:vide_cli/components/git_branch_indicator.dart';
import 'package:vide_cli/main.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_cli/constants/text_opacity.dart';

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
  commitPushAction, // "Commit & push" action for branches with changes
  mergeToMainAction, // "Merge to main" action for clean branches ahead of main
  switchWorktreeAction, // "Switch to worktree" action for non-current worktrees
  noChangesPlaceholder, // "No changes" placeholder when worktree is clean
  divider, // Visual separator line
  branchSectionLabel, // "Other Branches"
  branch, // Expandable branch item
  branchCheckoutAction, // "Checkout" action under expanded branch
  branchWorktreeAction, // "Create worktree" action under expanded branch
  showMoreBranches,
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
  final String repoPath;
  final int width;
  final void Function(String message)? onSendMessage;
  final void Function(String path)? onSwitchWorktree;

  const GitSidebar({
    required this.focused,
    required this.expanded,
    this.onExitRight,
    required this.repoPath,
    this.width = 30,
    this.onSendMessage,
    this.onSwitchWorktree,
    super.key,
  });

  @override
  State<GitSidebar> createState() => _GitSidebarState();
}

class _GitSidebarState extends State<GitSidebar> {
  int _selectedIndex = 0;
  int? _hoveredIndex;
  final _scrollController = ScrollController();

  // Animation state
  double _currentWidth = 5.0;
  Timer? _animationTimer;

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

  /// Check if a worktree is expanded. Current worktree expanded by default, others collapsed.
  bool _isWorktreeExpanded(String worktreePath) {
    return _worktreeExpansionState[worktreePath] ??
        (worktreePath == component.repoPath);
  }

  /// Toggle the expansion state of a worktree.
  void _toggleWorktreeExpansion(String worktreePath) {
    setState(() {
      final current = _isWorktreeExpanded(worktreePath);
      _worktreeExpansionState[worktreePath] = !current;
    });
  }
  List<GitBranch>? _cachedBranches;
  List<GitWorktree>? _cachedWorktrees;
  int? _commitsAheadOfMain; // Commits in current branch not in main
  bool _branchesLoading = false;
  static const int _initialBranchCount = 5;

  static const double _collapsedWidth = 5.0;
  static const double _expandedWidth = 30.0;
  static const int _animationSteps = 8;
  static const Duration _animationStepDuration = Duration(milliseconds: 20);

  @override
  void initState() {
    super.initState();
    _currentWidth = component.expanded ? _expandedWidth : _collapsedWidth;
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
      // Reset selection to current worktree
      _selectedIndex = 2;
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
    _animationTimer?.cancel();

    final startWidth = _currentWidth;
    final delta = (targetWidth - startWidth) / _animationSteps;
    var step = 0;

    _animationTimer = Timer.periodic(_animationStepDuration, (timer) {
      step++;
      if (step >= _animationSteps) {
        timer.cancel();
        setState(() => _currentWidth = targetWidth);
      } else {
        setState(() => _currentWidth = startWidth + (delta * step));
      }
    });
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
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
      orElse: () => GitBranch(name: '', isCurrent: false, isRemote: false, lastCommit: ''),
    );
    if (mainBranch != null && mainBranch.name.isNotEmpty && mainBranch.name != currentBranch) {
      options.add(mainBranch.name);
    }

    // Add "Other..." option if there are more branches
    final otherBranches = _cachedBranches?.where(
      (b) => !b.isRemote && b.name != currentBranch && b.name != 'main' && b.name != 'master'
    ).toList() ?? [];
    if (otherBranches.isNotEmpty) {
      options.add('Other...');
    }

    return options;
  }

  /// Builds the complete list of navigable items including section headers.
  /// This is the unified navigation model for keyboard navigation.
  List<NavigableItem> _buildNavigableItems(BuildContext context) {
    final items = <NavigableItem>[];

    // Get current branch for base options
    final gitStatusAsync =
        context.watch(gitStatusStreamProvider(component.repoPath));
    final currentBranch = gitStatusAsync.valueOrNull?.branch ?? 'main';

    // New branch action with optional branch selection
    items.add(NavigableItem(
      type: NavigableItemType.newBranchAction,
      name: '+ New branch...',
      isExpanded: _branchActionState != QuickActionState.collapsed,
    ));

    // Show branch options if selecting base branch for new branch
    if (_branchActionState == QuickActionState.selectingBaseBranch) {
      for (final branch in _getBaseBranchOptions(currentBranch)) {
        items.add(NavigableItem(
          type: NavigableItemType.baseBranchOption,
          name: branch,
          fullPath: 'branch', // Marker for which action this belongs to
        ));
      }
    }

    // New worktree action with optional branch selection
    items.add(NavigableItem(
      type: NavigableItemType.newWorktreeAction,
      name: '+ New worktree...',
      isExpanded: _worktreeActionState != QuickActionState.collapsed,
    ));

    // Show branch options if selecting base branch for new worktree
    if (_worktreeActionState == QuickActionState.selectingBaseBranch) {
      for (final branch in _getBaseBranchOptions(currentBranch)) {
        items.add(NavigableItem(
          type: NavigableItemType.baseBranchOption,
          name: branch,
          fullPath: 'worktree', // Marker for which action this belongs to
        ));
      }
    }

    // Always include current worktree first (even if no worktrees cached yet)
    final currentWorktreePath = component.repoPath;
    final gitStatus = gitStatusAsync.valueOrNull;

    // Check if current path is a worktree
    final isCurrentWorktreeAsync = context.watch(isWorktreeProvider(currentWorktreePath));
    final isCurrentPathWorktree = isCurrentWorktreeAsync.valueOrNull ?? false;

    // Get main repo path to identify which worktrees are actual worktrees
    final mainRepoPathAsync = context.watch(mainRepoPathProvider(currentWorktreePath));
    final mainRepoPath = mainRepoPathAsync.valueOrNull;

    // Ensure worktrees are loaded
    if (_cachedBranches == null && !_branchesLoading) {
      _loadBranchesAndWorktrees();
    }

    // Build current worktree section
    items.addAll(_buildWorktreeSection(
      context,
      path: currentWorktreePath,
      branch: gitStatus?.branch ?? 'Loading...',
      isCurrentWorktree: true,
      isWorktree: isCurrentPathWorktree,
      gitStatus: gitStatus,
    ));

    // Add other worktrees
    if (_cachedWorktrees != null) {
      for (final worktree in _cachedWorktrees!) {
        if (worktree.path == currentWorktreePath) continue; // Skip current

        // Only watch status if expanded (lazy loading)
        final isExpanded = _isWorktreeExpanded(worktree.path);
        GitStatus? wtStatus;
        if (isExpanded) {
          final statusAsync =
              context.watch(gitStatusStreamProvider(worktree.path));
          wtStatus = statusAsync.valueOrNull;
        }

        // Determine if this entry is a worktree (not the main repo)
        final isWorktree = mainRepoPath != null && worktree.path != mainRepoPath;

        items.addAll(_buildWorktreeSection(
          context,
          path: worktree.path,
          branch: worktree.branch,
          isCurrentWorktree: false,
          isWorktree: isWorktree,
          gitStatus: wtStatus,
        ));
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
        items.add(NavigableItem(
          type: NavigableItemType.branchSectionLabel,
          name: 'Other Branches',
        ));

        final displayCount = _showAllBranches
            ? otherBranches.length
            : _initialBranchCount.clamp(0, otherBranches.length);

        for (var i = 0; i < displayCount; i++) {
          final branchName = otherBranches[i].name;
          final isExpanded = _expandedBranchName == branchName;

          items.add(NavigableItem(
            type: NavigableItemType.branch,
            name: branchName,
            isExpanded: isExpanded,
            isLastInSection: i == displayCount - 1 && !isExpanded,
          ));

          // Add action items if this branch is expanded
          if (isExpanded) {
            items.add(NavigableItem(
              type: NavigableItemType.branchCheckoutAction,
              name: 'Checkout',
              fullPath: branchName, // Store branch name for the action
            ));
            items.add(NavigableItem(
              type: NavigableItemType.branchWorktreeAction,
              name: 'Create worktree',
              fullPath: branchName, // Store branch name for the action
              isLastInSection: i == displayCount - 1,
            ));
          }
        }

        if (!_showAllBranches && otherBranches.length > _initialBranchCount) {
          items.add(NavigableItem(
            type: NavigableItemType.showMoreBranches,
            name: 'Show more (${otherBranches.length - _initialBranchCount})',
            isLastInSection: true,
          ));
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
    items.add(NavigableItem(
      type: NavigableItemType.worktreeHeader,
      name: branch,
      worktreePath: path,
      isExpanded: isExpanded,
      isWorktree: isWorktree,
    ));

    if (!isExpanded) return items;

    // For non-current worktrees, add "Switch to" action first
    if (!isCurrentWorktree) {
      items.add(NavigableItem(
        type: NavigableItemType.switchWorktreeAction,
        name: 'Switch to this worktree',
        worktreePath: path,
      ));
    }

    // File items directly under the header (no "Changes" label)
    final changedFiles = _buildChangedFiles(gitStatus);

    // Add "Commit & push" action if there are changes (current worktree only)
    if (isCurrentWorktree && changedFiles.isNotEmpty) {
      items.add(NavigableItem(
        type: NavigableItemType.commitPushAction,
        name: 'Commit & push',
        worktreePath: path,
        isLastInSection: false,
      ));
    }

    // Add "Merge to main" action if branch is clean, ahead of main, and not main/master
    final isMainBranch = branch == 'main' || branch == 'master';
    final isClean = changedFiles.isEmpty;
    final isAheadOfMain = (_commitsAheadOfMain ?? 0) > 0;
    if (isCurrentWorktree && isClean && isAheadOfMain && !isMainBranch) {
      items.add(NavigableItem(
        type: NavigableItemType.mergeToMainAction,
        name: 'Merge to main',
        worktreePath: path,
        fullPath: branch, // Store current branch name for merge
      ));
    }

    if (changedFiles.isNotEmpty) {
      for (var i = 0; i < changedFiles.length; i++) {
        items.add(NavigableItem(
          type: NavigableItemType.file,
          name: changedFiles[i].path,
          fullPath: changedFiles[i].path,
          status: changedFiles[i].status,
          worktreePath: path,
          isLastInSection: i == changedFiles.length - 1,
        ));
      }
    } else if (!isAheadOfMain || isMainBranch) {
      // Show "No changes" placeholder when worktree is clean and not showing merge action
      items.add(NavigableItem(
        type: NavigableItemType.noChangesPlaceholder,
        name: 'No changes',
        worktreePath: path,
        isLastInSection: true,
      ));
    }

    return items;
  }

  /// Check if we're in name input mode for either action
  bool get _isEnteringName =>
      _branchActionState == QuickActionState.enteringName ||
      _worktreeActionState == QuickActionState.enteringName;

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
      // Right arrow always exits sidebar
      component.onExitRight?.call();
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
        _branchActionState = QuickActionState.collapsed;
        _worktreeActionState = QuickActionState.collapsed;
        _activeInputType = null;
        _selectedBaseBranch = null;
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
    if (_inputBuffer.isEmpty) {
      setState(() {
        _branchActionState = QuickActionState.collapsed;
        _worktreeActionState = QuickActionState.collapsed;
        _activeInputType = null;
        _selectedBaseBranch = null;
      });
      return;
    }

    final newBranchName = _inputBuffer.trim();
    final baseBranch = _selectedBaseBranch;
    final client = GitClient(workingDirectory: component.repoPath);

    try {
      if (_activeInputType == NavigableItemType.newBranchAction) {
        // Create and checkout new branch from base
        // First checkout base branch if different from current
        if (baseBranch != null) {
          await client.checkout(baseBranch);
        }
        await client.checkout(newBranchName, create: true);
      } else if (_activeInputType == NavigableItemType.newWorktreeAction) {
        // Create worktree with new branch from base
        // Path: ../reponame-branchname
        final repoName = p.basename(component.repoPath);
        final worktreePath =
            p.join(p.dirname(component.repoPath), '$repoName-$newBranchName');
        // Use base branch as the starting point
        await client.worktreeAdd(
          worktreePath,
          branch: newBranchName,
          createBranch: true,
          baseBranch: baseBranch,
        );
      }

      // Refresh branches/worktrees
      _cachedBranches = null;
      _cachedWorktrees = null;
      await _loadBranchesAndWorktrees();
    } catch (e) {
      // TODO: Show error to user
    }

    setState(() {
      _branchActionState = QuickActionState.collapsed;
      _worktreeActionState = QuickActionState.collapsed;
      _activeInputType = null;
      _selectedBaseBranch = null;
      _inputBuffer = '';
    });
  }

  /// Checkout a branch from the "Other Branches" list.
  Future<void> _checkoutBranch(String branchName) async {
    final client = GitClient(workingDirectory: component.repoPath);

    try {
      await client.checkout(branchName);

      // Refresh branches/worktrees to reflect the change
      _cachedBranches = null;
      _cachedWorktrees = null;
      await _loadBranchesAndWorktrees();
    } catch (e) {
      // TODO: Show error to user (e.g., uncommitted changes)
    }
  }

  /// Create a worktree from an existing branch.
  Future<void> _createWorktreeFromBranch(String branchName) async {
    final client = GitClient(workingDirectory: component.repoPath);

    try {
      // Create worktree path: ../reponame-branchname
      final repoName = p.basename(component.repoPath);
      final worktreePath =
          p.join(p.dirname(component.repoPath), '$repoName-$branchName');

      // Create worktree with existing branch (don't create new branch)
      await client.worktreeAdd(
        worktreePath,
        branch: branchName,
        createBranch: false,
      );

      // Refresh branches/worktrees to reflect the change
      _cachedBranches = null;
      _cachedWorktrees = null;
      await _loadBranchesAndWorktrees();
    } catch (e) {
      // TODO: Show error to user
    }
  }

  /// Merge current branch to main: checkout main, merge feature branch, then checkout back.
  Future<void> _mergeToMain(String featureBranch) async {
    final client = GitClient(workingDirectory: component.repoPath);

    // Determine the main branch name (main or master)
    final mainBranch = _cachedBranches?.any((b) => b.name == 'main') == true
        ? 'main'
        : 'master';

    try {
      // 1. Checkout main
      await client.checkout(mainBranch);

      // 2. Merge the feature branch
      await client.merge(featureBranch);

      // Refresh branches/worktrees to reflect the change
      _cachedBranches = null;
      _cachedWorktrees = null;
      await _loadBranchesAndWorktrees();
    } catch (e) {
      // TODO: Show error to user (e.g., merge conflicts)
      // Try to go back to the feature branch on failure
      try {
        await client.checkout(featureBranch);
      } catch (_) {}
    }
  }

  /// Activates an item (used for both keyboard and mouse click).
  void _activateItem(NavigableItem item, BuildContext context) {
    switch (item.type) {
      case NavigableItemType.newBranchAction:
        setState(() {
          if (_branchActionState == QuickActionState.collapsed) {
            // Expand to show branch options
            _branchActionState = QuickActionState.selectingBaseBranch;
            _worktreeActionState = QuickActionState.collapsed; // Collapse other
          } else {
            // Collapse if already expanded
            _branchActionState = QuickActionState.collapsed;
          }
        });
        break;
      case NavigableItemType.newWorktreeAction:
        setState(() {
          if (_worktreeActionState == QuickActionState.collapsed) {
            // Expand to show branch options
            _worktreeActionState = QuickActionState.selectingBaseBranch;
            _branchActionState = QuickActionState.collapsed; // Collapse other
          } else {
            // Collapse if already expanded
            _worktreeActionState = QuickActionState.collapsed;
          }
        });
        break;
      case NavigableItemType.baseBranchOption:
        // User selected a base branch - go to input mode
        final isForBranch = item.fullPath == 'branch';
        if (item.name == 'Other...') {
          // TODO: Show full branch list picker
          // For now, just use current branch
          return;
        }
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
      case NavigableItemType.mergeToMainAction:
        // Merge current branch to main
        _mergeToMain(item.fullPath!);
        break;
      case NavigableItemType.switchWorktreeAction:
        // Switch to the worktree
        component.onSwitchWorktree?.call(item.worktreePath!);
        break;
      case NavigableItemType.branch:
        // Toggle branch expansion to show/hide actions
        setState(() {
          if (_expandedBranchName == item.name) {
            _expandedBranchName = null; // Collapse if already expanded
          } else {
            _expandedBranchName = item.name; // Expand this branch
          }
        });
        break;
      case NavigableItemType.branchCheckoutAction:
        // Checkout the branch
        _checkoutBranch(item.fullPath!);
        setState(() => _expandedBranchName = null); // Collapse after action
        break;
      case NavigableItemType.branchWorktreeAction:
        // Create a worktree from this branch
        _createWorktreeFromBranch(item.fullPath!);
        setState(() => _expandedBranchName = null); // Collapse after action
        break;
      case NavigableItemType.showMoreBranches:
        setState(() => _showAllBranches = true);
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
        decoration: BoxDecoration(
          color: theme.base.surface,
        ),
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
        // Header area matching expanded state (no bottom border)
        Container(
          padding: EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: theme.base.outline.withOpacity(0.3),
          ),
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
                    color:
                        theme.base.onSurface.withOpacity(TextOpacity.disabled),
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
        return _buildQuickActionRow(
          item,
          isSelected,
          isHovered,
          theme,
          availableWidth,
        );
      case NavigableItemType.baseBranchOption:
        return _buildBaseBranchOptionRow(
          item,
          isSelected,
          isHovered,
          theme,
          availableWidth,
        );
      case NavigableItemType.worktreeHeader:
        return _buildWorktreeHeaderRow(
          context,
          item,
          isSelected,
          isHovered,
          theme,
          availableWidth,
        );
      case NavigableItemType.changesSectionLabel:
        return _buildChangesSectionLabelRow(
          item,
          isSelected,
          isHovered,
          theme,
          availableWidth,
        );
      case NavigableItemType.file:
        return _buildFileRow(
          item,
          isSelected,
          isHovered,
          theme,
          availableWidth,
        );
      case NavigableItemType.commitPushAction:
        return _buildCommitPushActionRow(
          item,
          isSelected,
          isHovered,
          theme,
          availableWidth,
        );
      case NavigableItemType.mergeToMainAction:
        return _buildMergeToMainActionRow(
          item,
          isSelected,
          isHovered,
          theme,
          availableWidth,
        );
      case NavigableItemType.switchWorktreeAction:
        return _buildSwitchWorktreeActionRow(
          item,
          isSelected,
          isHovered,
          theme,
          availableWidth,
        );
      case NavigableItemType.noChangesPlaceholder:
        return _buildNoChangesPlaceholderRow(
          item,
          isSelected,
          isHovered,
          theme,
          availableWidth,
        );
      case NavigableItemType.divider:
        return _buildDividerRow(theme, availableWidth);
      case NavigableItemType.branchSectionLabel:
        return _buildBranchSectionLabelRow(
          item,
          isSelected,
          isHovered,
          theme,
          availableWidth,
        );
      case NavigableItemType.branch:
        return _buildBranchRow(
          item,
          isSelected,
          isHovered,
          theme,
          availableWidth,
        );
      case NavigableItemType.branchCheckoutAction:
        return _buildBranchActionRow(
          item,
          isSelected,
          isHovered,
          theme,
          availableWidth,
          icon: '→',
        );
      case NavigableItemType.branchWorktreeAction:
        return _buildBranchActionRow(
          item,
          isSelected,
          isHovered,
          theme,
          availableWidth,
          icon: '⎇',
        );
      case NavigableItemType.showMoreBranches:
        return _buildShowMoreBranchesRow(
          item,
          isSelected,
          isHovered,
          theme,
          availableWidth,
        );
    }
  }

  /// Builds a quick action row (+ New branch..., + New worktree...).
  Component _buildQuickActionRow(
    NavigableItem item,
    bool isSelected,
    bool isHovered,
    VideThemeData theme,
    int availableWidth,
  ) {
    final highlight = isSelected || isHovered;
    final isBranchAction = item.type == NavigableItemType.newBranchAction;
    final actionState = isBranchAction ? _branchActionState : _worktreeActionState;
    final isEnteringName = actionState == QuickActionState.enteringName &&
        _activeInputType == item.type;
    final isExpanded = actionState != QuickActionState.collapsed;

    // Determine display text based on state
    String displayText;
    if (isEnteringName) {
      // Show input mode with selected base branch
      final actionName = isBranchAction ? 'branch' : 'worktree';
      displayText = '  $actionName: $_inputBuffer│'; // │ is cursor
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
  Component _buildBaseBranchOptionRow(
    NavigableItem item,
    bool isSelected,
    bool isHovered,
    VideThemeData theme,
    int availableWidth,
  ) {
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
  Component _buildWorktreeHeaderRow(
    BuildContext context,
    NavigableItem item,
    bool isSelected,
    bool isHovered,
    VideThemeData theme,
    int availableWidth,
  ) {
    final isExpanded = item.isExpanded;
    final expandIcon = isExpanded ? '▾' : '▸';
    final highlight = isSelected || isHovered;
    final isCurrentWorktree = item.worktreePath == component.repoPath;
    final isWorktree = item.isWorktree;

    // Get git status for ahead/behind indicators and change count
    final gitStatusAsync =
        context.watch(gitStatusStreamProvider(item.worktreePath!));
    final gitStatus = gitStatusAsync.valueOrNull;

    // Count total changes
    final changeCount = gitStatus != null
        ? gitStatus.modifiedFiles.length +
            gitStatus.stagedFiles.length +
            gitStatus.untrackedFiles.length
        : 0;

    // Current worktree uses primary color, others use default
    final branchColor =
        isCurrentWorktree ? theme.base.primary : theme.base.onSurface;

    // Show branch icon: ⎇ for worktrees,  for main repo
    final branchIcon = isWorktree ? '⎇' : '';

    return Column(
      children: [
        SizedBox(height: 1), // Top padding outside selection
        Container(
          decoration: highlight
              ? BoxDecoration(
                  color:
                      theme.base.primary.withOpacity(isSelected ? 0.3 : 0.15),
                )
              : BoxDecoration(color: theme.base.outline.withOpacity(0.3)),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 1),
            child: Row(
              children: [
                Text(expandIcon, style: TextStyle(color: branchColor)),
                SizedBox(width: 1),
                Text(branchIcon,
                    style: TextStyle(
                        color: isCurrentWorktree
                            ? theme.base.primary
                            : _vsCodeAccentColor)),
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
                    style: TextStyle(
                      color: _vsCodeModifiedColor,
                    ),
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
                      style: TextStyle(color: _vsCodeModifiedColor),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the "Changes (5)" label row.
  Component _buildChangesSectionLabelRow(
    NavigableItem item,
    bool isSelected,
    bool isHovered,
    VideThemeData theme,
    int availableWidth,
  ) {
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

  /// Builds a visual divider row.
  Component _buildDividerRow(VideThemeData theme, int availableWidth) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 1),
      child: Text(
        '─' * (availableWidth - 2),
        style: TextStyle(color: theme.base.outline.withOpacity(0.5)),
      ),
    );
  }

  /// Builds a file row with filename prominently displayed and path below.
  Component _buildFileRow(
    NavigableItem item,
    bool isSelected,
    bool isHovered,
    VideThemeData theme,
    int availableWidth,
  ) {
    final statusDot = _getStatusDot(item.status);
    final dotColor = _getStatusColor(item.status, theme);
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
  Component _buildCommitPushActionRow(
    NavigableItem item,
    bool isSelected,
    bool isHovered,
    VideThemeData theme,
    int availableWidth,
  ) {
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
            Text('↑', style: TextStyle(color: theme.base.success)),
            SizedBox(width: 1),
            Expanded(
              child: Text(
                item.name,
                style: TextStyle(
                  color: theme.base.success,
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

  /// Builds a "Merge to main" action row.
  Component _buildMergeToMainActionRow(
    NavigableItem item,
    bool isSelected,
    bool isHovered,
    VideThemeData theme,
    int availableWidth,
  ) {
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
            Text('⤵', style: TextStyle(color: theme.base.primary)),
            SizedBox(width: 1),
            Expanded(
              child: Text(
                item.name,
                style: TextStyle(
                  color: theme.base.primary,
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

  /// Builds a "Switch to worktree" action row.
  Component _buildSwitchWorktreeActionRow(
    NavigableItem item,
    bool isSelected,
    bool isHovered,
    VideThemeData theme,
    int availableWidth,
  ) {
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
                style: TextStyle(
                  color: theme.base.primary,
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

  /// Builds a "No changes" placeholder row.
  Component _buildNoChangesPlaceholderRow(
    NavigableItem item,
    bool isSelected,
    bool isHovered,
    VideThemeData theme,
    int availableWidth,
  ) {
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

  /// Builds a branch section label row ("Recent", "Other").
  Component _buildBranchSectionLabelRow(
    NavigableItem item,
    bool isSelected,
    bool isHovered,
    VideThemeData theme,
    int availableWidth,
  ) {
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
  Component _buildBranchRow(
    NavigableItem item,
    bool isSelected,
    bool isHovered,
    VideThemeData theme,
    int availableWidth,
  ) {
    final branch = _cachedBranches?.firstWhere(
      (b) => b.name == item.name,
      orElse: () => GitBranch(
        name: item.name,
        isCurrent: false,
        isRemote: false,
        lastCommit: '',
      ),
    );
    final isWorktree = _isWorktreeBranch(item.name);
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
              Text(
                '⎇ ',
                style: TextStyle(color: theme.base.primary),
              )
            else if (isCurrent)
              Text(
                '● ',
                style: TextStyle(color: theme.base.success),
              )
            else
              Text(
                '  ',
                style: TextStyle(color: theme.base.outline),
              ),
            Expanded(
              child: Text(
                item.name,
                style: TextStyle(
                  color: isCurrent
                      ? theme.base.primary
                      : isMainBranch
                          ? theme.base.onSurface
                          : theme.base.onSurface.withOpacity(TextOpacity.secondary),
                  fontWeight: (isCurrent || isMainBranch) ? FontWeight.bold : FontWeight.normal,
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
  Component _buildBranchActionRow(
    NavigableItem item,
    bool isSelected,
    bool isHovered,
    VideThemeData theme,
    int availableWidth, {
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
                style: TextStyle(
                  color: theme.base.primary,
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

  /// Builds the "Show more branches" row.
  Component _buildShowMoreBranchesRow(
    NavigableItem item,
    bool isSelected,
    bool isHovered,
    VideThemeData theme,
    int availableWidth,
  ) {
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

  /// Returns a colored dot indicator for file status.
  /// ● (filled) for staged/modified, ○ (hollow) for untracked.
  String _getStatusDot(String? status) {
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

  /// VS Code-style colors for git status (matching mockup aesthetic).
  static const _vsCodeStagedColor = Color(0xFF4EC9B0); // Teal/cyan
  static const _vsCodeModifiedColor = Color(0xFFDCDCAA); // Soft yellow
  static const _vsCodeAccentColor = Color(0xFFC586C0); // Purple/magenta for git icon

  Color _getStatusColor(String? status, VideThemeData theme) {
    switch (status) {
      case 'staged':
        return _vsCodeStagedColor;
      case 'modified':
        return _vsCodeModifiedColor;
      case 'untracked':
        return theme.base.onSurface.withOpacity(TextOpacity.secondary);
      default:
        return theme.base.onSurface;
    }
  }
}
