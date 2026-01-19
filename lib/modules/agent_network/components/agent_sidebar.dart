import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_core/api.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/modules/agent_network/state/vide_session_providers.dart';

/// A sidebar component that displays the current team and list of agents.
///
/// Shows:
/// - Current team name at the top
/// - List of all agents with their status indicators
/// - Agent name and optional task name
/// - Status indicator (⠋ working, … waiting-for-agent, ? waiting-for-user, ✓ idle)
///
/// Supports keyboard navigation:
/// - Arrow UP/DOWN or K/J: Navigate agents
/// - Enter/Space: Select agent
/// - Escape or Right Arrow: Exit sidebar
/// - Tab: Jump to team selector (if available)
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
  List<_SidebarItem> _buildItems() {
    final networkState = context.read(agentNetworkManagerProvider);
    final spawnedAgents = networkState.agents;

    // Standard team roles - always show these slots
    const teamRoles = ['lead', 'researcher', 'implementer', 'planner', 'tester'];

    // Map spawned agents to their roles (by type)
    final agentsByRole = <String, List<AgentMetadata>>{};
    for (final agent in spawnedAgents) {
      final role = _agentTypeToRole(agent.type);
      agentsByRole.putIfAbsent(role, () => []).add(agent);
    }

    // Build list of all items: role slots (empty or with agents)
    final items = <_SidebarItem>[];
    for (final role in teamRoles) {
      final agentsInRole = agentsByRole[role] ?? [];
      if (agentsInRole.isEmpty) {
        // Empty slot for this role
        items.add(_SidebarItem.emptyRole(role));
      } else {
        // Show all agents in this role
        for (final agent in agentsInRole) {
          items.add(_SidebarItem.agent(agent, role));
        }
      }
    }
    return items;
  }

  void _handleKeyEvent(KeyboardEvent event) {
    final items = _buildItems();

    if (items.isEmpty) return;

    if (event.logicalKey == LogicalKey.escape) {
      component.onExitRight?.call();
    } else if (event.logicalKey == LogicalKey.arrowRight) {
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
        final item = items[_selectedIndex];
        if (item.agent != null) {
          // Select spawned agent
          context.read(selectedAgentIdProvider.notifier).state = item.agent!.id;
          component.onSelectAgent?.call(item.agent!.id);
        } else if (item.role != null) {
          // Select empty role slot
          component.onSelectRole?.call(item.role!);
        }
      }
    }
  }

  String _getStatusIndicator(AgentStatus status, double animationValue) {
    return switch (status) {
      AgentStatus.working =>
        _spinnerFrames[(animationValue * _spinnerFrames.length).floor() %
            _spinnerFrames.length],
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
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 1)}…';
  }

  /// Build an empty role slot (role not yet spawned)
  Component _buildEmptyRoleSlot(
    int index,
    String role,
    bool isSelected,
    bool isHovered,
    VideThemeData theme,
  ) {
    final bgColor = isSelected
        ? theme.base.primary.withOpacity(0.3)
        : isHovered
            ? theme.base.outline.withOpacity(0.1)
            : Color.fromARGB(0, 0, 0, 0);

    final textOpacity = isSelected ? 0.7 : 0.4;
    final indicator = isSelected ? '>' : ' ';

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = null),
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedIndex = index);
          component.onSelectRole?.call(role);
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 0, vertical: 0.5),
          decoration: BoxDecoration(color: bgColor),
          child: Row(
            children: [
              Text(
                indicator,
                style: TextStyle(
                  color: theme.base.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: theme.base.outline.withOpacity(0.3),
                ),
                child: Text(
                  '○',
                  style: TextStyle(color: theme.base.onSurface.withOpacity(0.5)),
                ),
              ),
              SizedBox(width: 1),
              Expanded(
                child: Text(
                  role,
                  style: TextStyle(
                    color: theme.base.onSurface.withOpacity(textOpacity),
                    fontStyle: FontStyle.italic,
                    fontWeight: isSelected ? FontWeight.bold : null,
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

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    final isCollapsed = _currentWidth < component.width / 2;
    final currentTeam = context.watch(currentTeamProvider);

    return Focusable(
      focused: component.focused,
      onKeyEvent: (event) {
        _handleKeyEvent(event);
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
                    child: _buildExpandedContent(context, theme, currentTeam),
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
              'A',
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
  ) {
    // Watch for changes to trigger rebuild
    context.watch(agentNetworkManagerProvider);
    final selectedAgentId = context.watch(selectedAgentIdProvider);

    // Build items using shared helper
    final items = _buildItems();

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.toInt() - 2;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 1),
            // Team header
            Container(
              padding: EdgeInsets.symmetric(horizontal: 1, vertical: 1),
              decoration: BoxDecoration(
                color: theme.base.outline.withOpacity(0.1),
              ),
              child: Text(
                'Team: $currentTeam',
                style: TextStyle(
                  color: theme.base.onSurface,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
              ),
            ),
            SizedBox(height: 1),
            // Team members list - always show all roles
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isSelected = _selectedIndex == index;

                  final isHovered = _hoveredIndex == index;

                  if (item.agent != null) {
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
                  } else {
                    return _buildEmptyRoleSlot(
                      index,
                      item.role!,
                      isSelected,
                      isHovered,
                      theme,
                    );
                  }
                },
              ),
            ),
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

  /// Map agent type to team role
  String _agentTypeToRole(String agentType) {
    return switch (agentType) {
      'main' => 'lead',
      'contextCollection' => 'researcher',
      'implementation' => 'implementer',
      'planning' => 'planner',
      'flutterTester' => 'tester',
      _ => agentType, // fallback to agentType itself
    };
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
      displayName = '$displayName - ${agent.taskName}';
    }
    displayName = _truncateText(displayName, availableWidth - 4);

    // Get spinner frame if working
    int spinnerFrame = 0;
    if (actualStatus == AgentStatus.working) {
      // Animate spinner based on time
      final now = DateTime.now();
      final ms = now.millisecondsSinceEpoch;
      spinnerFrame = ((ms / 100).toInt() % _spinnerFrames.length);
    }

    final statusIndicator = _getStatusIndicator(
      actualStatus,
      spinnerFrame.toDouble(),
    );

    final bgColor = isSelected
        ? theme.base.primary.withOpacity(0.3)
        : isHovered
        ? theme.base.outline.withOpacity(0.1)
        : Color.fromARGB(0, 0, 0, 0);

    final textColor = isSelected
        ? theme.base.primary
        : theme.base.onSurface.withOpacity(0.7);

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
          padding: EdgeInsets.symmetric(horizontal: 0, vertical: 0.5),
          decoration: BoxDecoration(color: bgColor),
          child: Row(
            children: [
              Text(
                isSelected ? '>' : ' ',
                style: TextStyle(
                  color: theme.base.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(color: actualStatusColor),
                child: Text(
                  statusIndicator,
                  style: TextStyle(color: theme.base.onSurface),
                ),
              ),
              SizedBox(width: 1),
              Expanded(
                child: Text(
                  displayName,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: isSelected ? FontWeight.bold : null,
                    decoration: isSelectedById
                        ? TextDecoration.underline
                        : null,
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
}

/// Helper class for sidebar items - either an empty role slot or a spawned agent
class _SidebarItem {
  final AgentMetadata? agent;
  final String? role;

  _SidebarItem.emptyRole(this.role) : agent = null;
  _SidebarItem.agent(this.agent, this.role);
}
