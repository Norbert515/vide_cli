import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_core/vide_core.dart'
    show
        VideLogger,
        teamFrameworkLoaderProvider,
        TeamDefinition,
        AgentPersonality;
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/modules/settings/components/text_preview_dialog.dart';
import 'package:vide_cli/theme/theme.dart';

/// Team settings: Agent browser with full system prompt viewing.
class TeamSettingsSection extends StatefulComponent {
  final bool focused;
  final VoidCallback onExit;

  const TeamSettingsSection({
    required this.focused,
    required this.onExit,
    super.key,
  });

  @override
  State<TeamSettingsSection> createState() => _TeamSettingsSectionState();
}

class _TeamSettingsSectionState extends State<TeamSettingsSection> {
  int _selectedIndex = 0;
  final _scrollController = ScrollController();

  Map<String, TeamDefinition>? _teams;
  Map<String, AgentPersonality>? _agents;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  TeamDefinition? get _activeTeam {
    final teams = _teams;
    if (teams == null) return null;
    return teams['enterprise'] ?? teams.values.firstOrNull;
  }

  int get _itemCount {
    final agentCount = _activeTeam?.agents.length ?? 0;
    return 1 + agentCount; // team def + agents
  }

  Future<void> _loadData() async {
    try {
      final teamLoader = context.read(teamFrameworkLoaderProvider);
      final teams = await teamLoader.loadTeams();
      final agents = await teamLoader.loadAgents();
      if (mounted) {
        setState(() {
          _teams = teams;
          _agents = agents;
          _selectedIndex = 0;
        });
      }
    } catch (e) {
      VideLogger.instance.error(
        'TeamSettingsSection',
        'Failed to load team data: $e',
      );
    }
  }

  bool _handleKeyEvent(KeyboardEvent event) {
    if (!component.focused) return false;

    if (event.logicalKey == LogicalKey.arrowUp ||
        event.logicalKey == LogicalKey.keyK) {
      if (_selectedIndex > 0) {
        setState(() {
          _selectedIndex--;
          _scrollController.ensureIndexVisible(index: _selectedIndex);
        });
      }
      return true;
    } else if (event.logicalKey == LogicalKey.arrowDown ||
        event.logicalKey == LogicalKey.keyJ) {
      if (_selectedIndex < _itemCount - 1) {
        setState(() {
          _selectedIndex++;
          _scrollController.ensureIndexVisible(index: _selectedIndex);
        });
      }
      return true;
    } else if (event.logicalKey == LogicalKey.arrowLeft) {
      component.onExit();
      return true;
    } else if (event.logicalKey == LogicalKey.escape) {
      component.onExit();
      return true;
    } else if (event.logicalKey == LogicalKey.enter ||
        event.logicalKey == LogicalKey.space) {
      _activateCurrentItem();
      return true;
    }

    return false;
  }

  void _activateCurrentItem() {
    if (_selectedIndex == 0) {
      _openTeamPrompt();
    } else {
      final agentIndex = _selectedIndex - 1;
      final agentNames = _activeTeam?.agents ?? [];
      if (agentIndex < agentNames.length) {
        _openAgentPrompt(agentNames[agentIndex]);
      }
    }
  }

  void _openTeamPrompt() {
    final activeTeam = _activeTeam;
    if (activeTeam == null) return;

    Navigator.of(context).showDialog(
      barrierDismissible: true,
      builder: (ctx) => TextPreviewDialog(
        title: 'Team: ${activeTeam.name}',
        content: activeTeam.content,
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  Future<void> _openAgentPrompt(String agentName) async {
    final teamLoader = context.read(teamFrameworkLoaderProvider);
    final config = await teamLoader.buildAgentConfiguration(
      agentName,
      teamName: 'enterprise',
    );
    if (config == null || !mounted) return;

    Navigator.of(context).showDialog(
      barrierDismissible: true,
      builder: (ctx) => TextPreviewDialog(
        title: agentName,
        content: config.systemPrompt,
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    return Focusable(
      focused: component.focused,
      onKeyEvent: _handleKeyEvent,
      child: _buildAgentsList(theme),
    );
  }

  Component _buildAgentsList(VideThemeData theme) {
    final activeTeam = _activeTeam;
    final agentNames = activeTeam?.agents ?? [];

    if (activeTeam == null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 1, horizontal: 1),
        child: Text(
          'Loading...',
          style: TextStyle(
            color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
          ),
        ),
      );
    }

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      thumbColor: theme.base.primary,
      trackColor: theme.base.outlineVariant,
      child: ListView(
        controller: _scrollController,
        children: [
          // Team definition item
          _AgentItem(
            label: '${activeTeam.icon ?? ''} Team: ${activeTeam.name}'.trim(),
            description: activeTeam.description,
            isSelected: component.focused && _selectedIndex == 0,
            onTap: () {
              setState(() => _selectedIndex = 0);
              _openTeamPrompt();
            },
          ),
          // Individual agent items
          for (var i = 0; i < agentNames.length; i++)
            _AgentItem(
              label:
                  _agents?[agentNames[i]]?.effectiveDisplayName ??
                  agentNames[i],
              description:
                  _agents?[agentNames[i]]?.shortDescription ??
                  _agents?[agentNames[i]]?.description ??
                  '',
              isSelected: component.focused && _selectedIndex == i + 1,
              onTap: () {
                setState(() => _selectedIndex = i + 1);
                _openAgentPrompt(agentNames[i]);
              },
            ),
        ],
      ),
    );
  }
}

/// A selectable agent item with label, description, and right arrow indicator.
class _AgentItem extends StatelessComponent {
  final String label;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _AgentItem({
    required this.label,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 1, vertical: 1),
        decoration: BoxDecoration(
          color: isSelected ? theme.base.primary.withOpacity(0.2) : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: theme.base.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (description.isNotEmpty)
                    Text(
                      description,
                      style: TextStyle(
                        color: theme.base.onSurface.withOpacity(
                          TextOpacity.secondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Text(
              '\u2192',
              style: TextStyle(
                color: isSelected ? theme.base.primary : theme.base.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
