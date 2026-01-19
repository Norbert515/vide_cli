import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_core/vide_core.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/modules/agent_network/state/vide_session_providers.dart';

/// A sidebar component that displays active agents and team composition.
///
/// Shows two sections:
/// 1. **Active Agents** - Currently running agents with their status
/// 2. **Team Roles** - Available roles from the team composition (dimmed)
///
/// Supports keyboard navigation:
/// - Arrow UP/DOWN or K/J: Navigate items
/// - Enter/Space: Select agent or role
/// - Escape or Right Arrow: Exit sidebar
class AgentSidebar extends StatefulComponent {
  final bool focused;
  final bool expanded;
  final int width;
  final VoidCallback? onExitRight;
  final void Function(String agentId)? onSelectAgent;
  final void Function(String role)? onSelectRole;

  const AgentSidebar({
    required this.focused,
    required this.expanded,
    this.width = 50,
    this.onExitRight,
    this.onSelectAgent,
    this.onSelectRole,
    super.key,
  });

  @override
  State<AgentSidebar> createState() => _AgentSidebarState();
}

class _AgentSidebarState extends State<AgentSidebar>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  int? _hoveredIndex;
  final _scrollController = ScrollController();

  // Animation state
  static const Duration _animationDuration = Duration(milliseconds: 160);
  late AnimationController _animationController;
  late Animation<double> _widthAnimation;
  double _currentWidth = 5.0;

  static const double _collapsedWidth = 5.0;

  // Spinner frames for working status
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

  /// Build the list of sidebar items from current state
  List<_SidebarItem> _buildItems(List<AgentMetadata> spawnedAgents, TeamDefinition? teamDef) {
    final items = <_SidebarItem>[];

    // Section 1: Active Agents (always show all spawned agents)
    if (spawnedAgents.isNotEmpty) {
      items.add(_SidebarItem.header('Active Agents'));
      for (final agent in spawnedAgents) {
        items.add(_SidebarItem.agent(agent));
      }
    }

    // Section 2: Team Composition (from team definition)
    if (teamDef != null) {
      // Get roles that have agents assigned (non-null values)
      final rolesWithAgents = teamDef.composition.entries
          .where((e) => e.value != null)
          .toList();

      if (rolesWithAgents.isNotEmpty) {
        items.add(_SidebarItem.header('Team Roles'));
        for (final entry in rolesWithAgents) {
          items.add(_SidebarItem.teamRole(entry.key, entry.value!));
        }
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
    final effectiveIndex = currentSelectableIndex == -1 ? 0 : currentSelectableIndex;

    if (event.logicalKey == LogicalKey.escape) {
      component.onExitRight?.call();
    } else if (event.logicalKey == LogicalKey.arrowRight) {
      component.onExitRight?.call();
    } else if (event.logicalKey == LogicalKey.arrowUp ||
        event.logicalKey == LogicalKey.keyK) {
      setState(() {
        final newIndex = (effectiveIndex - 1).clamp(0, selectableIndices.length - 1);
        _selectedIndex = selectableIndices[newIndex];
        _scrollController.ensureIndexVisible(index: _selectedIndex);
      });
    } else if (event.logicalKey == LogicalKey.arrowDown ||
        event.logicalKey == LogicalKey.keyJ) {
      setState(() {
        final newIndex = (effectiveIndex + 1).clamp(0, selectableIndices.length - 1);
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
        } else if (item.role != null) {
          // Select team role (this spawns an agent, so switching focus is fine)
          component.onSelectRole?.call(item.role!);
        }
      }
    }
  }

  String _getStatusIndicator(AgentStatus status, int spinnerFrame) {
    return switch (status) {
      AgentStatus.working => _spinnerFrames[spinnerFrame % _spinnerFrames.length],
      AgentStatus.waitingForAgent => '…',
      AgentStatus.waitingForUser => '?',
      AgentStatus.idle => '✓',
    };
  }

  Color _getStatusColor(AgentStatus status, VideStatusColors statusColors) {
    return switch (status) {
      AgentStatus.working => statusColors.working,
      AgentStatus.waitingForAgent => statusColors.waitingForAgent,
      AgentStatus.waitingForUser => statusColors.waitingForUser,
      AgentStatus.idle => statusColors.idle,
    };
  }

  String _truncateText(String text, int maxLength) {
    if (maxLength <= 3) return text.length <= maxLength ? text : '…';
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 1)}…';
  }

  /// Format role name for display (e.g., "thinker-creative" -> "Thinker Creative")
  String _formatRoleName(String role) {
    return role
        .split('-')
        .map((word) => word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    final isCollapsed = _currentWidth < component.width / 2;
    final currentTeam = context.watch(currentTeamProvider);
    final teamDefAsync = context.watch(currentTeamDefinitionProvider);
    final teamDef = teamDefAsync.valueOrNull;

    // Watch for agent changes at top level to trigger rebuild
    final networkState = context.watch(agentNetworkManagerProvider);
    final spawnedAgents = networkState.agents;

    // Auto-select first agent if none selected
    final currentSelectedId = context.read(selectedAgentIdProvider);
    if (currentSelectedId == null && spawnedAgents.isNotEmpty) {
      // Schedule the state update for after build
      Future.microtask(() {
        context.read(selectedAgentIdProvider.notifier).state = spawnedAgents.first.id;
      });
    }

    // Build items once with current state
    final items = _buildItems(spawnedAgents, teamDef);

    return Focusable(
      focused: component.focused,
      onKeyEvent: (event) {
        _handleKeyEvent(event, items);
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
                    minWidth: component.width.toDouble(),
                    maxWidth: component.width.toDouble(),
                    child: _buildExpandedContent(context, theme, currentTeam, teamDef, spawnedAgents),
                  ),
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
    String currentTeam,
    TeamDefinition? teamDef,
    List<AgentMetadata> spawnedAgents,
  ) {
    final selectedAgentId = context.watch(selectedAgentIdProvider);

    // Build items
    final items = _buildItems(spawnedAgents, teamDef);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.toInt() - 4;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Team header with border
            Container(
              padding: EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                border: BoxBorder(bottom: BorderSide(color: theme.base.outline.withOpacity(TextOpacity.separator))),
              ),
              child: Row(
                children: [
                  Text(
                    '┌ ',
                    style: TextStyle(color: theme.base.outline.withOpacity(TextOpacity.tertiary)),
                  ),
                  if (teamDef?.icon != null) ...[
                    Text(
                      '${teamDef!.icon} ',
                      style: TextStyle(color: theme.base.primary),
                    ),
                  ],
                  Text(
                    currentTeam,
                    style: TextStyle(
                      color: theme.base.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    ' ┐',
                    style: TextStyle(color: theme.base.outline.withOpacity(TextOpacity.tertiary)),
                  ),
                ],
              ),
            ),
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
                        item.agent!,
                        isSelected,
                        isSelectedById,
                        isHovered,
                        theme,
                        availableWidth,
                      );
                    } else if (item.role != null) {
                      return _buildTeamRoleRow(
                        index,
                        item.role!,
                        item.agentName!,
                        isSelected,
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
            // Footer with navigation hint
            Container(
              padding: EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                border: BoxBorder(top: BorderSide(color: theme.base.outline.withOpacity(TextOpacity.separator))),
              ),
              child: Row(
                children: [
                  if (component.focused) ...[
                    Text(
                      '↑↓',
                      style: TextStyle(color: theme.base.primary.withOpacity(TextOpacity.secondary)),
                    ),
                    Text(
                      ' nav ',
                      style: TextStyle(color: theme.base.onSurface.withOpacity(TextOpacity.disabled)),
                    ),
                    Text(
                      '→',
                      style: TextStyle(color: theme.base.primary.withOpacity(TextOpacity.secondary)),
                    ),
                    Text(
                      ' exit',
                      style: TextStyle(color: theme.base.onSurface.withOpacity(TextOpacity.disabled)),
                    ),
                  ] else ...[
                    Text(
                      '←',
                      style: TextStyle(color: theme.base.outline.withOpacity(TextOpacity.disabled)),
                    ),
                    Text(
                      ' focus',
                      style: TextStyle(color: theme.base.onSurface.withOpacity(TextOpacity.disabled)),
                    ),
                  ],
                ],
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

  /// Build a team role row (from team composition)
  Component _buildTeamRoleRow(
    int index,
    String role,
    String agentName,
    bool isSelected,
    bool isHovered,
    VideThemeData theme,
    int availableWidth,
  ) {
    final bgColor = isSelected && component.focused
        ? theme.base.primary.withOpacity(0.15)
        : isHovered
            ? theme.base.outline.withOpacity(0.08)
            : null;

    final displayRole = _formatRoleName(role);
    final displayAgent = _truncateText(agentName, availableWidth - displayRole.length - 6);

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = null),
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedIndex = index);
          component.onSelectRole?.call(role);
        },
        child: Container(
          decoration: BoxDecoration(color: bgColor),
          child: Row(
            children: [
              // Role indicator
              Text(
                '  ○ ',
                style: TextStyle(
                  color: theme.base.outline.withOpacity(TextOpacity.disabled),
                ),
              ),
              // Role name
              Text(
                displayRole,
                style: TextStyle(
                  color: isSelected && component.focused
                      ? theme.base.onSurface.withOpacity(TextOpacity.secondary)
                      : theme.base.onSurface.withOpacity(TextOpacity.disabled),
                ),
              ),
              // Agent name (dimmed)
              Expanded(
                child: Text(
                  ' → $displayAgent',
                  style: TextStyle(
                    color: theme.base.outline.withOpacity(TextOpacity.disabled),
                  ),
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Component _buildAgentRow(
    int index,
    AgentMetadata agent,
    bool isSelected,
    bool isSelectedById,
    bool isHovered,
    VideThemeData theme,
    int availableWidth,
  ) {
    // Get agent status
    final status = agent.status;

    // Infer actual status (similar to RunningAgentsBar)
    final claudeStatusAsync = context.watch(claudeStatusProvider(agent.id));
    final claudeStatus = claudeStatusAsync.valueOrNull ?? ClaudeStatus.ready;

    // Override status based on Claude processing state
    final actualStatus =
        (claudeStatus == ClaudeStatus.processing ||
            claudeStatus == ClaudeStatus.thinking ||
            claudeStatus == ClaudeStatus.responding)
        ? AgentStatus.working
        : ((claudeStatus == ClaudeStatus.ready ||
                  claudeStatus == ClaudeStatus.completed) &&
              status == AgentStatus.working)
        ? AgentStatus.idle
        : status;

    final actualStatusColor = _getStatusColor(actualStatus, theme.status);

    // Build agent name with optional task
    String displayName = agent.name;
    if (agent.taskName != null && agent.taskName!.isNotEmpty) {
      displayName = '${agent.taskName}';
    }
    displayName = _truncateText(displayName, availableWidth - 6);

    // Get spinner frame if working
    int spinnerFrame = 0;
    if (actualStatus == AgentStatus.working) {
      final now = DateTime.now();
      final ms = now.millisecondsSinceEpoch;
      spinnerFrame = (ms ~/ 100) % _spinnerFrames.length;
    }

    final statusIndicator = _getStatusIndicator(actualStatus, spinnerFrame);

    final bgColor = isSelected && component.focused
        ? theme.base.primary.withOpacity(0.15)
        : isSelectedById
            ? theme.base.outline.withOpacity(0.1)
            : isHovered
                ? theme.base.outline.withOpacity(0.08)
                : null;

    final textColor = isSelected && component.focused
        ? theme.base.primary
        : isSelectedById
            ? theme.base.onSurface
            : theme.base.onSurface.withOpacity(TextOpacity.secondary);

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = null),
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedIndex = index);
          context.read(selectedAgentIdProvider.notifier).state = agent.id;
          component.onSelectAgent?.call(agent.id);
        },
        child: Container(
          decoration: BoxDecoration(color: bgColor),
          child: Row(
            children: [
              // Status indicator with color
              Text(
                '  $statusIndicator ',
                style: TextStyle(color: actualStatusColor),
              ),
              // Agent name
              Expanded(
                child: Text(
                  displayName,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: isSelectedById ? FontWeight.bold : null,
                  ),
                  maxLines: 1,
                ),
              ),
              // View indicator for currently viewed agent
              if (isSelectedById)
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
  final AgentMetadata? agent;
  final String? role;
  final String? agentName;
  final String? headerText;
  final bool isHeader;

  _SidebarItem.header(this.headerText)
      : agent = null,
        role = null,
        agentName = null,
        isHeader = true;

  _SidebarItem.agent(this.agent)
      : role = null,
        agentName = null,
        headerText = null,
        isHeader = false;

  _SidebarItem.teamRole(this.role, this.agentName)
      : agent = null,
        headerText = null,
        isHeader = false;
}
