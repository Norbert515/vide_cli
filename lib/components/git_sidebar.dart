import 'dart:async';

import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_core/mcp/git/git_client.dart';
import 'package:vide_core/mcp/git/git_models.dart';
import 'package:vide_core/mcp/git/git_providers.dart';
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
  changesHeader,
  file,
  branchesHeader,
  branch,
  showMoreBranches,
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

  const NavigableItem({
    required this.type,
    required this.name,
    this.fullPath,
    this.status,
    this.fileCount = 0,
    this.isExpanded = false,
    this.isLastInSection = false,
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

  const GitSidebar({
    required this.focused,
    required this.expanded,
    this.onExitRight,
    required this.repoPath,
    this.width = 30,
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

  // Changes section state
  bool _changesExpanded = false;

  // Branches section state
  bool _branchesExpanded = false;
  bool _showAllBranches = false;
  List<GitBranch>? _cachedBranches;
  List<GitWorktree>? _cachedWorktrees;
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
  List<ChangedFile> _buildChangedFiles(BuildContext context) {
    final gitStatusAsync = context.watch(
      gitStatusStreamProvider(component.repoPath),
    );
    final gitStatus = gitStatusAsync.valueOrNull;
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

  /// Builds the complete list of navigable items including section headers.
  /// This is the unified navigation model for keyboard navigation.
  List<NavigableItem> _buildNavigableItems(BuildContext context) {
    final items = <NavigableItem>[];
    final changedFiles = _buildChangedFiles(context);

    // 1. Changes header (always present)
    items.add(
      NavigableItem(
        type: NavigableItemType.changesHeader,
        name: 'Changes',
        fileCount: changedFiles.length,
        isExpanded: _changesExpanded,
      ),
    );

    // 2. File items (if Changes is expanded)
    if (_changesExpanded) {
      for (var i = 0; i < changedFiles.length; i++) {
        final file = changedFiles[i];
        final isLast = i == changedFiles.length - 1;
        items.add(
          NavigableItem(
            type: NavigableItemType.file,
            name: file.path,
            fullPath: file.path,
            status: file.status,
            isLastInSection: isLast,
          ),
        );
      }
    }

    // 3. Branches header (always present)
    items.add(
      NavigableItem(
        type: NavigableItemType.branchesHeader,
        name: 'Branches',
        isExpanded: _branchesExpanded,
      ),
    );

    // 4. Branch items (if Branches is expanded)
    if (_branchesExpanded && _cachedBranches != null && !_branchesLoading) {
      final branches = _cachedBranches!;
      final displayCount = _showAllBranches
          ? branches.length
          : _initialBranchCount.clamp(0, branches.length);

      final hasShowMore =
          !_showAllBranches && branches.length > _initialBranchCount;

      for (var i = 0; i < displayCount; i++) {
        final isLast = i == displayCount - 1 && !hasShowMore;
        items.add(
          NavigableItem(
            type: NavigableItemType.branch,
            name: branches[i].name,
            isLastInSection: isLast,
          ),
        );
      }

      // Show more option
      if (hasShowMore) {
        items.add(
          NavigableItem(
            type: NavigableItemType.showMoreBranches,
            name: 'Show more (${branches.length - _initialBranchCount})',
            isLastInSection: true,
          ),
        );
      }
    }

    return items;
  }

  void _handleKeyEvent(
    KeyboardEvent event,
    BuildContext context,
    List<NavigableItem> items,
  ) {
    if (items.isEmpty) return;

    if (event.logicalKey == LogicalKey.escape) {
      // First check if file preview is open - close it first
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

  /// Activates an item (used for both keyboard and mouse click).
  void _activateItem(NavigableItem item, BuildContext context) {
    switch (item.type) {
      case NavigableItemType.changesHeader:
        _toggleChangesSection();
        break;
      case NavigableItemType.file:
        final fullFilePath = '${component.repoPath}/${item.fullPath}';
        context.read(filePreviewPathProvider.notifier).state = fullFilePath;
        // Focus stays on sidebar - ESC will close file preview first
        break;
      case NavigableItemType.branchesHeader:
        _toggleBranchesSection();
        break;
      case NavigableItemType.branch:
        // TODO: Could checkout branch or show branch details
        break;
      case NavigableItemType.showMoreBranches:
        setState(() => _showAllBranches = true);
        break;
    }
  }

  /// Loads branches and worktrees when branches section is expanded.
  Future<void> _loadBranchesAndWorktrees() async {
    if (_branchesLoading) return;

    setState(() {
      _branchesLoading = true;
    });

    try {
      final client = GitClient(workingDirectory: component.repoPath);
      final branches = await client.branches();
      final worktrees = await client.worktreeList();

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
        _branchesLoading = false;
      });
    } catch (e) {
      setState(() {
        _branchesLoading = false;
      });
    }
  }

  /// Toggles the changes section expansion.
  void _toggleChangesSection() {
    setState(() {
      _changesExpanded = !_changesExpanded;
    });
  }

  /// Toggles the branches section expansion.
  void _toggleBranchesSection() {
    setState(() {
      _branchesExpanded = !_branchesExpanded;
      if (_branchesExpanded && _cachedBranches == null) {
        _loadBranchesAndWorktrees();
      }
    });
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
    final changedFiles = _buildChangedFiles(context);

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
                      changedFiles.length,
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
    int totalChanges,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Available width for content (subtract padding)
        final availableWidth =
            constraints.maxWidth.toInt() - 2; // 1 padding on each side

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Branch name header (static, always visible)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: theme.base.outline.withOpacity(0.3),
              ),
              child: Row(
                children: [
                  Text('', style: TextStyle(color: _vsCodeAccentColor)),
                  SizedBox(width: 1),
                  Expanded(
                    child: Text(
                      _ellipsize(
                        gitStatus?.branch ?? 'Loading...',
                        availableWidth - 3,
                      ), // -3 for icon and space
                      style: TextStyle(
                        color: theme.base.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Spacer after header
            SizedBox(height: 1),

            // Scrollable content - all navigable items
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
                    ),
                ],
              ),
            ),

            // Navigation hint at bottom (no border, just padding)
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

  /// Truncates text with ellipsis if it exceeds maxWidth characters.
  String _ellipsize(String text, int maxWidth) {
    if (maxWidth <= 3) return text.length <= maxWidth ? text : '...';
    if (text.length <= maxWidth) return text;
    return '${text.substring(0, maxWidth - 3)}...';
  }

  /// Builds a row for any navigable item type.
  Component _buildNavigableItemRow(
    BuildContext context,
    NavigableItem item,
    int index,
    VideThemeData theme,
    int availableWidth,
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
  ) {
    switch (item.type) {
      case NavigableItemType.changesHeader:
        return _buildChangesHeaderRow(
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
      case NavigableItemType.branchesHeader:
        return _buildBranchesHeaderRow(
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

  /// Builds the Changes section header row.
  Component _buildChangesHeaderRow(
    NavigableItem item,
    bool isSelected,
    bool isHovered,
    VideThemeData theme,
    int availableWidth,
  ) {
    final highlight = isSelected || isHovered;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1),
      decoration: highlight
          ? BoxDecoration(
              color: theme.base.primary.withOpacity(isSelected ? 0.3 : 0.15),
            )
          : null,
      child: Row(
        children: [
          Text(
            item.isExpanded ? '▾' : '▸',
            style: TextStyle(
              color: theme.base.onSurface.withOpacity(TextOpacity.secondary),
            ),
          ),
          SizedBox(width: 1),
          Text(
            'Changes',
            style: TextStyle(
              color: theme.base.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          // Push badge to the right
          Expanded(child: SizedBox()),
          if (item.fileCount > 0)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: _vsCodeModifiedColor.withOpacity(0.2),
              ),
              child: Text(
                '${item.fileCount}',
                style: TextStyle(
                  color: _vsCodeModifiedColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Builds a file row matching the mockup style exactly.
  Component _buildFileRow(
    NavigableItem item,
    bool isSelected,
    bool isHovered,
    VideThemeData theme,
    int availableWidth,
  ) {
    final statusDot = _getStatusDot(item.status);
    final dotColor = _getStatusColor(item.status, theme);
    final fileName = item.name.split('/').last;
    final highlight = isSelected || isHovered;
    // Tree connector: ╰ for last item, │ for others
    final connector = item.isLastInSection ? '╰' : '│';

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
            Text(connector, style: TextStyle(color: theme.base.outline)),
            SizedBox(width: 1),
            Text(statusDot, style: TextStyle(color: dotColor)),
            SizedBox(width: 1),
            Expanded(
              child: Text(
                fileName,
                style: TextStyle(color: theme.base.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the Branches section header row.
  Component _buildBranchesHeaderRow(
    NavigableItem item,
    bool isSelected,
    bool isHovered,
    VideThemeData theme,
    int availableWidth,
  ) {
    final highlight = isSelected || isHovered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Empty line spacer between sections
        SizedBox(height: 1),
        // Header
        Container(
          padding: EdgeInsets.symmetric(horizontal: 1),
          decoration: highlight
              ? BoxDecoration(
                  color: theme.base.primary.withOpacity(
                    isSelected ? 0.3 : 0.15,
                  ),
                )
              : null,
          child: Row(
            children: [
              Text(
                item.isExpanded ? '▾' : '▸',
                style: TextStyle(
                  color: theme.base.onSurface.withOpacity(TextOpacity.secondary),
                ),
              ),
              SizedBox(width: 1),
              Text(
                'Branches',
                style: TextStyle(
                  color: theme.base.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        // Loading indicator (not navigable, shown inline)
        if (item.isExpanded && _branchesLoading)
          Container(
            padding: EdgeInsets.only(left: 3),
            child: Text(
              'Loading...',
              style: TextStyle(
                color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
              ),
            ),
          ),
      ],
    );
  }

  /// Builds a branch row with current branch indicator.
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
    final currentIndicator = isCurrent ? '●' : ' ';
    final highlight = isSelected || isHovered;

    // Account for "  ● " prefix (4 chars) and potential " W" suffix (2 chars)
    final maxBranchNameWidth = availableWidth - 4 - (isWorktree ? 2 : 0);
    final displayName = _ellipsize(item.name, maxBranchNameWidth);

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
              currentIndicator,
              style: TextStyle(
                color: isCurrent ? theme.base.success : theme.base.outline,
              ),
            ),
            SizedBox(width: 1),
            Expanded(
              child: Text(
                displayName + (isWorktree ? ' W' : ''),
                style: TextStyle(
                  color: isCurrent
                      ? theme.base.primary
                      : theme.base.onSurface.withOpacity(TextOpacity.secondary),
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                ),
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
                _ellipsize(item.name, availableWidth - 5),
                style: TextStyle(
                  color: theme.base.primary.withOpacity(TextOpacity.secondary),
                ),
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
