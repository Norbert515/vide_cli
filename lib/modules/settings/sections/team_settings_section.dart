import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_core/vide_core.dart'
    show
        VideLogger,
        videConfigManagerProvider,
        teamFrameworkLoaderProvider,
        TeamDefinition,
        AgentPersonality;
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/modules/settings/components/settings_toggle.dart';
import 'package:vide_cli/modules/settings/components/text_preview_dialog.dart';
import 'package:vide_cli/theme/theme.dart';

enum _TeamTab { agents, experiments }

/// Team settings: Agent browser with full system prompt viewing, and experiment
/// feature flags. Uses a tab bar to separate agents from experiments.
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
  _TeamTab _activeTab = _TeamTab.agents;
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

  int get _currentTabItemCount {
    switch (_activeTab) {
      case _TeamTab.agents:
        final agentCount = _activeTeam?.agents.length ?? 0;
        return 1 + agentCount; // team def + agents
      case _TeamTab.experiments:
        return 4;
    }
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
      if (_selectedIndex < _currentTabItemCount - 1) {
        setState(() {
          _selectedIndex++;
          _scrollController.ensureIndexVisible(index: _selectedIndex);
        });
      }
      return true;
    } else if (event.logicalKey == LogicalKey.arrowRight) {
      _switchToNextTab();
      return true;
    } else if (event.logicalKey == LogicalKey.arrowLeft) {
      if (!_switchToPreviousTab()) {
        component.onExit();
      }
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

  void _switchToNextTab() {
    final tabs = _TeamTab.values;
    final currentIndex = tabs.indexOf(_activeTab);
    if (currentIndex < tabs.length - 1) {
      setState(() {
        _activeTab = tabs[currentIndex + 1];
        _selectedIndex = 0;
        _scrollController.jumpTo(0);
      });
    }
  }

  /// Returns true if it switched, false if already on the first tab.
  bool _switchToPreviousTab() {
    final tabs = _TeamTab.values;
    final currentIndex = tabs.indexOf(_activeTab);
    if (currentIndex > 0) {
      setState(() {
        _activeTab = tabs[currentIndex - 1];
        _selectedIndex = 0;
        _scrollController.jumpTo(0);
      });
      return true;
    }
    return false;
  }

  void _activateCurrentItem() {
    switch (_activeTab) {
      case _TeamTab.agents:
        if (_selectedIndex == 0) {
          _openTeamPrompt();
        } else {
          final agentIndex = _selectedIndex - 1;
          final agentNames = _activeTeam?.agents ?? [];
          if (agentIndex < agentNames.length) {
            _openAgentPrompt(agentNames[agentIndex]);
          }
        }
      case _TeamTab.experiments:
        _toggleExperiment(_selectedIndex);
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

  void _toggleExperiment(int experimentIndex) {
    final container = ProviderScope.containerOf(context);
    final configManager = container.read(videConfigManagerProvider);
    final settings = configManager.readGlobalSettings();

    switch (experimentIndex) {
      case 0:
        configManager.writeGlobalSettings(
          settings.copyWith(
            experimentAutoTeamSelection: !settings.experimentAutoTeamSelection,
          ),
        );
      case 1:
        configManager.writeGlobalSettings(
          settings.copyWith(
            experimentParallelAgents: !settings.experimentParallelAgents,
          ),
        );
      case 2:
        configManager.writeGlobalSettings(
          settings.copyWith(
            experimentAgentMemory: !settings.experimentAgentMemory,
          ),
        );
      case 3:
        configManager.writeGlobalSettings(
          settings.copyWith(
            experimentVerboseHandoffs: !settings.experimentVerboseHandoffs,
          ),
        );
    }
    setState(() {});
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    return Focusable(
      focused: component.focused,
      onKeyEvent: _handleKeyEvent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tab bar
          _TabBar(
            activeTab: _activeTab,
            focused: component.focused,
          ),

          // Tab content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 1),
              child: switch (_activeTab) {
                _TeamTab.agents => _buildAgentsTab(theme),
                _TeamTab.experiments => _buildExperimentsTab(theme),
              },
            ),
          ),
        ],
      ),
    );
  }

  Component _buildAgentsTab(VideThemeData theme) {
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
            label:
                '${activeTeam.icon ?? ''} Team: ${activeTeam.name}'.trim(),
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

  Component _buildExperimentsTab(VideThemeData theme) {
    final configManager = context.read(videConfigManagerProvider);
    final settings = configManager.readGlobalSettings();

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      thumbColor: theme.base.primary,
      trackColor: theme.base.outlineVariant,
      child: ListView(
        controller: _scrollController,
        children: [
          SettingsToggleItem(
            label: 'Auto Team Selection',
            description: 'Auto-select team based on task description',
            value: settings.experimentAutoTeamSelection,
            isSelected: component.focused && _selectedIndex == 0,
            onTap: () {
              setState(() => _selectedIndex = 0);
              _toggleExperiment(0);
            },
          ),
          SettingsToggleItem(
            label: 'Parallel Agents',
            description: 'Allow agents to work in parallel',
            value: settings.experimentParallelAgents,
            isSelected: component.focused && _selectedIndex == 1,
            onTap: () {
              setState(() => _selectedIndex = 1);
              _toggleExperiment(1);
            },
          ),
          SettingsToggleItem(
            label: 'Agent Memory',
            description: 'Enable persistent agent memory across sessions',
            value: settings.experimentAgentMemory,
            isSelected: component.focused && _selectedIndex == 2,
            onTap: () {
              setState(() => _selectedIndex = 2);
              _toggleExperiment(2);
            },
          ),
          SettingsToggleItem(
            label: 'Verbose Handoffs',
            description: 'Verbose handoff details between agents',
            value: settings.experimentVerboseHandoffs,
            isSelected: component.focused && _selectedIndex == 3,
            onTap: () {
              setState(() => _selectedIndex = 3);
              _toggleExperiment(3);
            },
          ),
        ],
      ),
    );
  }
}

/// Tab bar showing Agents and Experiments tabs.
class _TabBar extends StatelessComponent {
  final _TeamTab activeTab;
  final bool focused;

  const _TabBar({required this.activeTab, required this.focused});

  @override
  Component build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 1),
      child: Row(
        children: [
          _TabItem(
            label: 'Agents',
            isActive: activeTab == _TeamTab.agents,
            focused: focused,
          ),
          SizedBox(width: 1),
          _TabItem(
            label: 'Experiments',
            isActive: activeTab == _TeamTab.experiments,
            focused: focused,
          ),
        ],
      ),
    );
  }
}

/// A single tab item in the tab bar.
class _TabItem extends StatelessComponent {
  final String label;
  final bool isActive;
  final bool focused;

  const _TabItem({
    required this.label,
    required this.isActive,
    required this.focused,
  });

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    final color = isActive
        ? (focused ? theme.base.primary : theme.base.onSurface)
        : theme.base.onSurface.withOpacity(TextOpacity.tertiary);

    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: isActive ? FontWeight.bold : null,
          ),
        ),
        // Underline for active tab
        Text(
          isActive ? '\u2500' * label.length : ' ' * label.length,
          style: TextStyle(
            color: isActive && focused
                ? theme.base.primary
                : isActive
                    ? theme.base.outline
                    : null,
          ),
        ),
      ],
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
