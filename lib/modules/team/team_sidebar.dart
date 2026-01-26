import 'package:nocterm/nocterm.dart';
import 'package:vide_core/vide_core.dart' show TeamFrameworkLoader;
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_cli/constants/text_opacity.dart';

/// A sidebar component that displays team framework information.
///
/// Shows:
/// - Current team name and description
/// - Team composition (roles → agents)
/// - Process configuration (planning, review, testing, documentation levels)
/// - Communication configuration (verbosity, handoff detail, status updates)
/// - Quick team switcher
///
/// Supports keyboard navigation when focused.
class TeamSidebar extends StatefulComponent {
  final bool focused;
  final bool expanded;
  final VoidCallback? onExitRight;
  final String repoPath;
  final int width;
  final void Function(String teamName)? onSwitchTeam;

  const TeamSidebar({
    required this.focused,
    required this.expanded,
    this.onExitRight,
    required this.repoPath,
    this.width = 30,
    this.onSwitchTeam,
    super.key,
  });

  @override
  State<TeamSidebar> createState() => _TeamSidebarState();
}

class _TeamSidebarState extends State<TeamSidebar>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  int? _hoveredIndex;
  final _scrollController = ScrollController();

  // Animation state
  static const Duration _animationDuration = Duration(milliseconds: 160);
  late AnimationController _animationController;
  late Animation<double> _widthAnimation;
  double _currentWidth = 5.0;

  // Team data
  String _currentTeamName = 'vide';
  Map<String, dynamic>? _currentTeamData;
  List<String> _availableTeams = [];
  bool _teamsLoading = false;
  bool _showTeamList = false;

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
    _widthAnimation = Tween<double>(
      begin: _currentWidth,
      end: _currentWidth,
    ).chain(CurveTween(curve: Curves.easeOut)).animate(_animationController);
    _animationController.addListener(() {
      setState(() {
        _currentWidth = _widthAnimation.value;
      });
    });

    _initializeTeamFramework();
  }

  Future<void> _initializeTeamFramework() async {
    await _loadTeams();
  }

  Future<void> _loadTeams() async {
    setState(() => _teamsLoading = true);

    try {
      final loader = TeamFrameworkLoader(workingDirectory: component.repoPath);
      final teams = await loader.loadTeams();

      setState(() {
        _availableTeams = teams.keys.toList();
        _availableTeams.sort();
        _teamsLoading = false;
      });

      // Load the default team
      await _loadTeamData(_currentTeamName);
    } catch (e) {
      print('Error loading teams: $e');
      setState(() => _teamsLoading = false);
    }
  }

  Future<void> _loadTeamData(String teamName) async {
    try {
      final loader = TeamFrameworkLoader(workingDirectory: component.repoPath);
      final teamDef = await loader.getTeam(teamName);

      if (teamDef != null) {
        setState(() {
          _currentTeamName = teamName;
          _currentTeamData = {
            'name': teamDef.name,
            'description': teamDef.description,
            'icon': teamDef.icon,
            'mainAgent': teamDef.mainAgent,
            'agents': teamDef.agents,
            'process': teamDef.process,
            'communication': teamDef.communication,
          };
        });

        // Notify parent component of team switch
        component.onSwitchTeam?.call(teamName);
      }
    } catch (e) {
      print('Error loading team data for $teamName: $e');
    }
  }

  @override
  void didUpdateComponent(TeamSidebar old) {
    super.didUpdateComponent(old);
    // Animate based on expanded state
    if (component.expanded != old.expanded) {
      _animateToWidth(component.expanded ? _expandedWidth : _collapsedWidth);
    }
    // When repoPath changes, reload teams
    if (component.repoPath != old.repoPath) {
      _loadTeams();
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

  void _handleKeyEvent(KeyboardEvent event) {
    if (event.logicalKey == LogicalKey.escape) {
      if (_showTeamList) {
        setState(() => _showTeamList = false);
      } else {
        component.onExitRight?.call();
      }
    } else if (event.logicalKey == LogicalKey.arrowRight) {
      component.onExitRight?.call();
    } else if (event.logicalKey == LogicalKey.arrowUp ||
        event.logicalKey == LogicalKey.keyK) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1).clamp(
          0,
          _getNavigableItems().length - 1,
        );
        _scrollController.ensureIndexVisible(index: _selectedIndex);
      });
    } else if (event.logicalKey == LogicalKey.arrowDown ||
        event.logicalKey == LogicalKey.keyJ) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1).clamp(
          0,
          _getNavigableItems().length - 1,
        );
        _scrollController.ensureIndexVisible(index: _selectedIndex);
      });
    } else if (event.logicalKey == LogicalKey.enter ||
        event.logicalKey == LogicalKey.space) {
      _activateSelectedItem();
    }
  }

  List<String> _getNavigableItems() {
    if (_showTeamList) {
      return _availableTeams;
    }

    final items = <String>['Team: $_currentTeamName'];

    if (_currentTeamData != null) {
      items.add('Description');
      items.add('Composition');
      items.add('Process');
      items.add('Communication');
      items.add('');
      items.add('Switch Team');
    }

    return items;
  }

  void _activateSelectedItem() {
    if (_showTeamList && _selectedIndex < _availableTeams.length) {
      final selectedTeam = _availableTeams[_selectedIndex];
      _loadTeamData(selectedTeam);
      setState(() => _showTeamList = false);
      _selectedIndex = 0;
    } else if (!_showTeamList &&
        _selectedIndex == _getNavigableItems().length - 1) {
      setState(() => _showTeamList = true);
      _selectedIndex = 0;
    }
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    final isCollapsed = _currentWidth < _expandedWidth / 2;

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
                    minWidth: _expandedWidth,
                    maxWidth: _expandedWidth,
                    child: _buildExpandedContent(context, theme),
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
              '⚙',
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

  Component _buildExpandedContent(BuildContext context, VideThemeData theme) {
    final items = _getNavigableItems();

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.toInt() - 2;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 1),
            Expanded(
              child: ListView(
                controller: _scrollController,
                children: [
                  if (_showTeamList)
                    _buildTeamListContent(theme, availableWidth)
                  else
                    _buildTeamDetailContent(theme, availableWidth),
                  for (var i = 0; i < items.length; i++)
                    _buildItemRow(
                      i,
                      items[i],
                      component.focused && _selectedIndex == i,
                      _hoveredIndex == i,
                      theme,
                      availableWidth,
                    ),
                ],
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

  Component _buildTeamDetailContent(VideThemeData theme, int width) {
    final data = _currentTeamData;
    if (data == null) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 1, vertical: 1),
        child: Text(
          'Loading...',
          style: TextStyle(color: theme.base.onSurface),
        ),
      );
    }

    final content = <Component>[];

    // Team header
    content.add(
      Container(
        padding: EdgeInsets.symmetric(horizontal: 1, vertical: 1),
        decoration: BoxDecoration(color: theme.base.outline.withOpacity(0.1)),
        child: Text(
          '${data['icon'] ?? '⚙'} ${data['name']}',
          style: TextStyle(
            color: theme.base.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    // Description
    final desc = (data['description'] as String?) ?? 'No description';
    if (desc.isNotEmpty) {
      content.add(
        Container(
          padding: EdgeInsets.symmetric(horizontal: 1, vertical: 1),
          child: Text(
            desc,
            style: TextStyle(color: theme.base.onSurface.withOpacity(0.8)),
            maxLines: 3,
          ),
        ),
      );
    }

    content.add(SizedBox(height: 1));

    // Agents list
    final agents = data['agents'] as List<String>? ?? [];
    final mainAgentName = data['mainAgent'] as String?;

    content.add(
      Container(
        padding: EdgeInsets.only(left: 1),
        child: Text(
          'Team Agents:',
          style: TextStyle(
            color: theme.base.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    if (mainAgentName != null) {
      content.add(
        Container(
          padding: EdgeInsets.only(left: 2),
          child: Text(
            '• lead: $mainAgentName',
            style: TextStyle(color: theme.base.onSurface.withOpacity(0.8)),
          ),
        ),
      );
    }

    for (final agentType in agents) {
      content.add(
        Container(
          padding: EdgeInsets.only(left: 2),
          child: Text(
            '• $agentType',
            style: TextStyle(color: theme.base.onSurface.withOpacity(0.8)),
          ),
        ),
      );
    }

    return Column(children: content);
  }

  Component _buildTeamListContent(VideThemeData theme, int width) {
    if (_teamsLoading) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 1, vertical: 1),
        child: Text(
          'Loading teams...',
          style: TextStyle(color: theme.base.onSurface),
        ),
      );
    }

    final items = <Component>[];
    items.add(
      Container(
        padding: EdgeInsets.symmetric(horizontal: 1, vertical: 1),
        decoration: BoxDecoration(color: theme.base.outline.withOpacity(0.1)),
        child: Text(
          'Available Teams:',
          style: TextStyle(
            color: theme.base.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    for (final team in _availableTeams) {
      items.add(
        Container(
          padding: EdgeInsets.only(left: 1, top: 0.5, bottom: 0.5),
          child: Text('• $team', style: TextStyle(color: theme.base.onSurface)),
        ),
      );
    }

    return Column(children: items);
  }

  Component _buildItemRow(
    int index,
    String label,
    bool isSelected,
    bool isHovered,
    VideThemeData theme,
    int width,
  ) {
    if (label.isEmpty) {
      return SizedBox(height: 1);
    }

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
          _activateSelectedItem();
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 1, vertical: 0.5),
          decoration: BoxDecoration(color: bgColor),
          child: Text(label, style: TextStyle(color: textColor), maxLines: 1),
        ),
      ),
    );
  }
}
