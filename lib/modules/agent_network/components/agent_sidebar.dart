import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_core/vide_core.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/modules/agent_network/state/vide_session_providers.dart';

/// A sidebar component that displays active agents.
///
/// Supports keyboard navigation:
/// - Arrow UP/DOWN or K/J: Navigate items
/// - Enter/Space: Select agent
/// - Escape or Right Arrow: Exit sidebar
class AgentSidebar extends StatefulComponent {
  final bool focused;
  final bool expanded;
  final int width;
  final VoidCallback? onExitRight;
  final void Function(String agentId)? onSelectAgent;

  const AgentSidebar({
    required this.focused,
    required this.expanded,
    this.width = 50,
    this.onExitRight,
    this.onSelectAgent,
    super.key,
  });

  @override
  State<AgentSidebar> createState() => _AgentSidebarState();
}

class _AgentSidebarState extends State<AgentSidebar>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 1;
  int? _hoveredIndex;
  final _scrollController = ScrollController();

  // Animation state
  static const Duration _animationDuration = Duration(milliseconds: 160);
  late AnimationController _animationController;
  late Animation<double> _widthAnimation;
  double _currentWidth = 5.0;

  static const double _collapsedWidth = 5.0;

  @override
  void initState() {
    super.initState();
    _currentWidth = component.expanded
        ? component.width.toDouble()
        : _collapsedWidth;

    // Initialize animation controller
    _animationController = AnimationController(
      duration: _animationDuration,
      vsync: this,
    );
    _widthAnimation = Tween<double>(
      begin: _currentWidth,
      end: _currentWidth,
    ).chain(CurveTween(curve: Curves.easeOut)).animate(_animationController);
    _animationController.addListener(() {
      setState(() {
        _currentWidth = _widthAnimation.value;
      });
    });
  }

  @override
  void didUpdateComponent(AgentSidebar old) {
    super.didUpdateComponent(old);
    // Animate based on expanded state
    if (component.expanded != old.expanded) {
      _animateToWidth(
        component.expanded ? component.width.toDouble() : _collapsedWidth,
      );
    }
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

  /// Build the list of sidebar items from current state, ordered as a
  /// depth-first tree based on [VideAgent.spawnedBy] relationships.
  List<_SidebarItem> _buildItems(List<VideAgent> spawnedAgents) {
    final items = <_SidebarItem>[];
    if (spawnedAgents.isEmpty) return items;

    items.add(_SidebarItem.header('Agents'));

    // Group agents by their parent ID
    final childrenOf = <String?, List<VideAgent>>{};
    for (final agent in spawnedAgents) {
      childrenOf.putIfAbsent(agent.spawnedBy, () => []).add(agent);
    }

    // Depth-first traversal emitting each agent with tree metadata
    void walk(String? parentId, int depth, List<bool> ancestorIsLast) {
      final children = childrenOf[parentId] ?? [];
      for (var i = 0; i < children.length; i++) {
        final agent = children[i];
        final isLast = i == children.length - 1;
        final myAncestorIsLast = [...ancestorIsLast, isLast];
        items.add(
          _SidebarItem.agent(
            agent,
            depth: depth,
            ancestorIsLast: myAncestorIsLast,
          ),
        );
        walk(agent.id, depth + 1, myAncestorIsLast);
      }
    }

    walk(null, 0, []);

    // If the tree walk didn't place all agents (e.g. orphans whose parent was
    // already terminated), append them at root level.
    final placed = items
        .where((i) => !i.isHeader)
        .map((i) => i.agent!.id)
        .toSet();
    for (final agent in spawnedAgents) {
      if (!placed.contains(agent.id)) {
        items.add(
          _SidebarItem.agent(agent, depth: 0, ancestorIsLast: const [false]),
        );
      }
    }

    return items;
  }

  void _handleKeyEvent(KeyboardEvent event, List<_SidebarItem> items) {
    // Filter to only selectable items (not headers)
    final selectableIndices = <int>[];
    for (var i = 0; i < items.length; i++) {
      if (!items[i].isHeader) {
        selectableIndices.add(i);
      }
    }

    if (selectableIndices.isEmpty) return;

    // Find current position in selectable items
    final currentSelectableIndex = selectableIndices.indexOf(_selectedIndex);
    final effectiveIndex = currentSelectableIndex == -1
        ? 0
        : currentSelectableIndex;

    if (event.logicalKey == LogicalKey.escape) {
      component.onExitRight?.call();
    } else if (event.logicalKey == LogicalKey.arrowRight) {
      component.onExitRight?.call();
    } else if (event.logicalKey == LogicalKey.arrowUp ||
        event.logicalKey == LogicalKey.keyK) {
      setState(() {
        final newIndex = (effectiveIndex - 1).clamp(
          0,
          selectableIndices.length - 1,
        );
        _selectedIndex = selectableIndices[newIndex];
        _scrollController.ensureIndexVisible(index: _selectedIndex);
      });
    } else if (event.logicalKey == LogicalKey.arrowDown ||
        event.logicalKey == LogicalKey.keyJ) {
      setState(() {
        final newIndex = (effectiveIndex + 1).clamp(
          0,
          selectableIndices.length - 1,
        );
        _selectedIndex = selectableIndices[newIndex];
        _scrollController.ensureIndexVisible(index: _selectedIndex);
      });
    } else if (event.logicalKey == LogicalKey.enter ||
        event.logicalKey == LogicalKey.space) {
      if (_selectedIndex < items.length) {
        final item = items[_selectedIndex];
        if (item.agent != null) {
          // Select spawned agent - just update the provider, keep focus in sidebar
          context.read(selectedAgentIdProvider.notifier).state = item.agent!.id;
          // Note: We intentionally don't call onSelectAgent here to keep focus in sidebar
        }
      }
    }
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    final isCollapsed = _currentWidth < component.width / 2;

    // Watch for agent changes - unified for both local and remote modes
    // The videSessionAgentsProvider watches session.stateStream which emits
    // whenever agents are spawned or terminated.
    final session = context.watch(currentVideSessionProvider);
    final agentsAsync = context.watch(videSessionAgentsProvider);
    final spawnedAgents =
        agentsAsync.valueOrNull ?? session?.state.agents ?? [];

    // Auto-select first agent if none selected
    final currentSelectedId = context.read(selectedAgentIdProvider);
    if (currentSelectedId == null && spawnedAgents.isNotEmpty) {
      // Schedule the state update for after build
      Future.microtask(() {
        context.read(selectedAgentIdProvider.notifier).state =
            spawnedAgents.first.id;
      });
    }

    // Build items once with current state
    final items = _buildItems(spawnedAgents);

    return Focusable(
      focused: component.focused,
      onKeyEvent: (event) {
        _handleKeyEvent(event, items);
        return true;
      },
      child: ClipRect(
        child: SizedBox(
          width: _currentWidth,
          child: isCollapsed
              ? _buildCollapsedIndicator(theme)
              : OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: component.width.toDouble(),
                  maxWidth: component.width.toDouble(),
                  child: _buildExpandedContent(context, theme, spawnedAgents),
                ),
        ),
      ),
    );
  }

  Component _buildCollapsedIndicator(VideThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(height: 1),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(color: theme.base.outline.withOpacity(0.3)),
          child: Center(
            child: Text(
              '≡',
              style: TextStyle(
                color: theme.base.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        Expanded(child: SizedBox()),
      ],
    );
  }

  Component _buildExpandedContent(
    BuildContext context,
    VideThemeData theme,
    List<VideAgent> spawnedAgents,
  ) {
    final selectedAgentId = context.watch(selectedAgentIdProvider);

    // Build items
    final items = _buildItems(spawnedAgents);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.toInt() - 4;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Items list
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: 1),
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isSelected = _selectedIndex == index;
                    final isHovered = _hoveredIndex == index;

                    if (item.isHeader) {
                      return _buildSectionHeader(item.headerText!, theme);
                    } else if (item.agent != null) {
                      final isSelectedById = selectedAgentId == item.agent!.id;
                      return _buildAgentRow(
                        index,
                        item,
                        isSelected,
                        isSelectedById,
                        isHovered,
                        theme,
                        availableWidth,
                      );
                    }
                    return SizedBox.shrink();
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Build a section header row
  Component _buildSectionHeader(String title, VideThemeData theme) {
    return Padding(
      padding: EdgeInsets.only(top: 1),
      child: Text(
        title,
        style: TextStyle(
          color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Component _buildAgentRow(
    int index,
    _SidebarItem item,
    bool isSelected,
    bool isSelectedById,
    bool isHovered,
    VideThemeData theme,
    int availableWidth,
  ) {
    final agent = item.agent!;
    return _AgentRowItem(
      agent: agent,
      depth: item.depth,
      ancestorIsLast: item.ancestorIsLast,
      isSelected: isSelected,
      isSelectedById: isSelectedById,
      isHovered: isHovered,
      isFocused: component.focused,
      availableWidth: availableWidth,
      onHoverEnter: () => setState(() => _hoveredIndex = index),
      onHoverExit: () => setState(() => _hoveredIndex = null),
      onTap: () {
        setState(() => _selectedIndex = index);
        context.read(selectedAgentIdProvider.notifier).state = agent.id;
        component.onSelectAgent?.call(agent.id);
      },
    );
  }
}

/// Stateful widget for individual agent rows with animated spinner
class _AgentRowItem extends StatefulComponent {
  final VideAgent agent;
  final int depth;
  final List<bool> ancestorIsLast;
  final bool isSelected;
  final bool isSelectedById;
  final bool isHovered;
  final bool isFocused;
  final int availableWidth;
  final VoidCallback? onHoverEnter;
  final VoidCallback? onHoverExit;
  final VoidCallback? onTap;

  const _AgentRowItem({
    required this.agent,
    this.depth = 0,
    this.ancestorIsLast = const [],
    required this.isSelected,
    required this.isSelectedById,
    required this.isHovered,
    required this.isFocused,
    required this.availableWidth,
    this.onHoverEnter,
    this.onHoverExit,
    this.onTap,
  });

  @override
  State<_AgentRowItem> createState() => _AgentRowItemState();
}

class _AgentRowItemState extends State<_AgentRowItem>
    with SingleTickerProviderStateMixin {
  static const _spinnerFrames = [
    '⠋',
    '⠙',
    '⠹',
    '⠸',
    '⠼',
    '⠴',
    '⠦',
    '⠧',
    '⠇',
    '⠏',
  ];

  late AnimationController _spinnerController;
  VideAgentStatus? _lastStatus;

  int get _spinnerIndex =>
      (_spinnerController.value * _spinnerFrames.length).floor() %
      _spinnerFrames.length;

  @override
  void initState() {
    super.initState();
    _spinnerController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _spinnerController.dispose();
    super.dispose();
  }

  void _updateSpinnerForStatus(VideAgentStatus status) {
    final wasWorking = _lastStatus == VideAgentStatus.working;
    final isWorking = status == VideAgentStatus.working;

    if (isWorking && !wasWorking) {
      _spinnerController.repeat();
    } else if (!isWorking && wasWorking) {
      _spinnerController
        ..stop()
        ..reset();
    } else if (isWorking && !_spinnerController.isAnimating) {
      // Handle initial mount with working status
      _spinnerController.repeat();
    }

    _lastStatus = status;
  }

  String _getStatusIndicator(VideAgentStatus status) {
    return switch (status) {
      VideAgentStatus.working => _spinnerFrames[_spinnerIndex],
      VideAgentStatus.waitingForAgent => '…',
      VideAgentStatus.waitingForUser => '?',
      VideAgentStatus.idle => '✓',
    };
  }

  Color _getStatusColor(VideAgentStatus status, VideStatusColors statusColors) {
    return switch (status) {
      VideAgentStatus.working => statusColors.working,
      VideAgentStatus.waitingForAgent => statusColors.waitingForAgent,
      VideAgentStatus.waitingForUser => statusColors.waitingForUser,
      VideAgentStatus.idle => statusColors.idle,
    };
  }

  /// Builds a box-drawing tree prefix based on depth and which ancestors
  /// were the last child at their level.
  ///
  /// Returns a record with separate tree-line and connector parts so they
  /// can be styled independently (tree lines dim, connector colored).
  ({String treeLine, String connector}) _buildTreePrefix(
    int depth,
    List<bool> ancestorIsLast,
  ) {
    if (depth == 0)
      return (treeLine: '', connector: '  '); // root agents: simple indent

    final buffer = StringBuffer();
    // For ancestor levels between root (index 0) and current, draw
    // continuation lines or blank space.
    for (var i = 1; i < depth; i++) {
      buffer.write(ancestorIsLast[i] ? '   ' : '│  ');
    }
    final treeLine = buffer.toString();
    final connector = ancestorIsLast[depth] ? '└─ ' : '├─ ';
    return (treeLine: treeLine, connector: connector);
  }

  String _truncateText(String text, int maxLength) {
    if (maxLength <= 3) return text.length <= maxLength ? text : '…';
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 1)}…';
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    // Status comes from VideAgent which is rebuilt via videSessionAgentsProvider
    // (a StreamProvider on session.stateStream). The data layer already derives
    // the correct status from agentStatusProvider, so no override logic needed.
    final actualStatus = component.agent.status;

    // Update spinner animation based on status
    _updateSpinnerForStatus(actualStatus);

    final actualStatusColor = _getStatusColor(actualStatus, theme.status);
    final statusIndicator = _getStatusIndicator(actualStatus);

    // Build tree prefix from depth and ancestor info
    final (:treeLine, :connector) = _buildTreePrefix(
      component.depth,
      component.ancestorIsLast,
    );

    // Build agent name with optional task
    String displayName = component.agent.name;
    if (component.agent.taskName != null &&
        component.agent.taskName!.isNotEmpty) {
      displayName = '${component.agent.taskName}';
    }
    // Account for tree prefix width + status indicator + spacing in truncation
    final prefixWidth = treeLine.length + connector.length;
    displayName = _truncateText(
      displayName,
      component.availableWidth - prefixWidth - 4,
    );

    final bgColor = component.isSelected && component.isFocused
        ? theme.base.primary.withOpacity(0.15)
        : component.isSelectedById
        ? theme.base.outline.withOpacity(0.1)
        : component.isHovered
        ? theme.base.outline.withOpacity(0.08)
        : null;

    final textColor = component.isSelected && component.isFocused
        ? theme.base.primary
        : component.isSelectedById
        ? theme.base.onSurface
        : theme.base.onSurface.withOpacity(TextOpacity.secondary);

    return MouseRegion(
      onEnter: (_) => component.onHoverEnter?.call(),
      onExit: (_) => component.onHoverExit?.call(),
      child: GestureDetector(
        onTap: () => component.onTap?.call(),
        child: Container(
          decoration: BoxDecoration(color: bgColor),
          child: Row(
            children: [
              // Tree lines: continuation lines + connector (dim/subtle)
              if (treeLine.isNotEmpty || connector.isNotEmpty)
                Text(
                  '$treeLine$connector',
                  style: TextStyle(
                    color: theme.base.outline.withOpacity(TextOpacity.tertiary),
                  ),
                ),
              // Status indicator (colored)
              Text(
                '$statusIndicator ',
                style: TextStyle(color: actualStatusColor),
              ),
              // Agent name
              Expanded(
                child: Text(
                  displayName,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: component.isSelectedById
                        ? FontWeight.bold
                        : null,
                  ),
                  maxLines: 1,
                ),
              ),
              // View indicator for currently viewed agent
              if (component.isSelectedById)
                Text(
                  '◀',
                  style: TextStyle(
                    color: theme.base.primary.withOpacity(TextOpacity.tertiary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper class for sidebar items
class _SidebarItem {
  final VideAgent? agent;
  final String? headerText;
  final bool isHeader;
  final int depth;

  /// For each depth level, whether the ancestor at that level was the last
  /// child of its parent. Used to decide between drawing `│` (continuation)
  /// or blank space in the tree prefix.
  final List<bool> ancestorIsLast;

  _SidebarItem.header(this.headerText)
    : agent = null,
      isHeader = true,
      depth = 0,
      ancestorIsLast = const [];

  _SidebarItem.agent(
    this.agent, {
    this.depth = 0,
    this.ancestorIsLast = const [],
  }) : headerText = null,
       isHeader = false;
}
