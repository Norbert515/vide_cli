import 'dart:io';

import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:vide_core/vide_core.dart'
    show
        GitClient,
        GitStatus,
        GitBranch,
        GitWorktree,
        GitRepository,
        gitStatusStreamProvider;
import 'package:vide_cli/main.dart';
import 'package:vide_cli/modules/git/models/git_sidebar_models.dart';
import 'package:vide_cli/modules/git/components/git_sidebar_item_rows.dart';
import 'package:vide_cli/modules/git/builders/git_sidebar_item_builder.dart';
import 'package:vide_cli/modules/git/services/git_sidebar_operations.dart';
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

  // Git operations delegate
  late GitSidebarOperations _operations;

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

  static const double _collapsedWidth = 5.0;
  static const double _expandedWidth = 30.0;

  @override
  void initState() {
    super.initState();
    _currentWidth = component.expanded ? _expandedWidth : _collapsedWidth;

    _operations = GitSidebarOperations(
      onLoadingChanged: (action) => setState(() => _loadingAction = action),
      onSuccess: (msg) => context.read(toastProvider.notifier).success(msg),
      onError: (msg) => context.read(toastProvider.notifier).error(msg),
      onRefreshSingleRepo: () async {
        _cachedBranches = null;
        _cachedWorktrees = null;
        await _loadBranchesAndWorktrees();
      },
      onRefreshMultiRepo: _loadRepoBranchesAndWorktrees,
      isMultiRepoMode: () => _isMultiRepoMode == true,
      onSwitchWorktree: (path) => component.onSwitchWorktree?.call(path),
    );

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

  /// Creates a GitSidebarItemBuilder with the current state.
  GitSidebarItemBuilder _buildItemBuilder() {
    return GitSidebarItemBuilder(
      branchActionState: _branchActionState,
      worktreeActionState: _worktreeActionState,
      showAllBranches: _showAllBranches,
      expandedBranchName: _expandedBranchName,
      actionsExpanded: _actionsExpanded,
      expandedWorktreeActions: _expandedWorktreeActions,
      childRepos: _childRepos,
      isMultiRepoMode: _isMultiRepoMode,
      repoBranches: _repoBranches,
      repoWorktrees: _repoWorktrees,
      repoCommitsAheadOfMain: _repoCommitsAheadOfMain,
      repoActionsExpanded: _repoActionsExpanded,
      repoExpandedBranchName: _repoExpandedBranchName,
      repoBranchActionState: _repoBranchActionState,
      repoWorktreeActionState: _repoWorktreeActionState,
      cachedBranches: _cachedBranches,
      cachedWorktrees: _cachedWorktrees,
      commitsAheadOfMain: _commitsAheadOfMain,
      branchesLoading: _branchesLoading,
      repoPath: component.repoPath,
      findCurrentWorktreePath: _findCurrentWorktreePath,
      isWorktreeExpanded: _isWorktreeExpanded,
      isRepoExpanded: _isRepoExpanded,
      loadBranchesAndWorktrees: _loadBranchesAndWorktrees,
    );
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
          _operations.sync(repoPath);
        }
        break;
      case NavigableItemType.mergeToMainAction:
        // Merge current branch to main
        if (_loadingAction == null) {
          final repoPath = item.worktreePath ?? component.repoPath;
          _operations.mergeToMain(
            item.fullPath!,
            repoPath,
            _isMultiRepoMode == true
                ? _repoBranches[repoPath]
                : _cachedBranches,
          );
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
        if (_loadingAction == null) {
          _operations.removeWorktree(item.worktreePath!, component.repoPath);
        }
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
        _operations.checkoutBranch(item.fullPath!, checkoutRepoPath);
        if (item.worktreePath != null && _isMultiRepoMode == true) {
          setState(() => _repoExpandedBranchName[item.worktreePath!] = null);
        } else {
          setState(() => _expandedBranchName = null);
        }
        break;
      case NavigableItemType.branchWorktreeAction:
        // Create a worktree from this branch
        final wtRepoPath = item.worktreePath ?? component.repoPath;
        _operations.createWorktreeFromBranch(item.fullPath!, wtRepoPath);
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
          _operations.pull(pullRepoPath);
        }
        break;
      case NavigableItemType.pushAction:
        if (_loadingAction == null) {
          final pushRepoPath = item.worktreePath ?? component.repoPath;
          _operations.push(pushRepoPath);
        }
        break;
      case NavigableItemType.fetchAction:
        if (_loadingAction == null) {
          final fetchRepoPath = item.worktreePath ?? component.repoPath;
          _operations.fetch(fetchRepoPath);
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
    final itemBuilder = _buildItemBuilder();
    final navigableItems = itemBuilder.buildNavigableItems(context);

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
