import 'dart:io';

import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_core/vide_core.dart'
    show
        TeamFrameworkLoader,
        TeamFrameworkAssetInitializer,
        videConfigManagerProvider;
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/main.dart' show ideModeEnabledProvider;
import 'package:vide_cli/modules/agent_network/state/vide_session_providers.dart';
import 'package:vide_cli/modules/settings/components/section_header.dart';
import 'package:vide_cli/modules/settings/components/settings_toggle.dart';

/// General settings content (team selection, IDE mode, streaming).
class GeneralSettingsSection extends StatefulComponent {
  final bool focused;
  final VoidCallback onExit;

  const GeneralSettingsSection({
    required this.focused,
    required this.onExit,
    super.key,
  });

  @override
  State<GeneralSettingsSection> createState() => _GeneralSettingsSectionState();
}

class _GeneralSettingsSectionState extends State<GeneralSettingsSection> {
  List<String> _availableTeams = [];
  bool _teamsLoading = true;
  int _selectedIndex = 0;

  // Settings items: [0] = IDE mode toggle, [1] = Streaming toggle, [2+] = team items
  int get _totalItems => 2 + _availableTeams.length;

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    await TeamFrameworkAssetInitializer.initialize();

    final workingDir = Directory.current.path;
    final loader = TeamFrameworkLoader(workingDirectory: workingDir);
    final teams = await loader.loadTeams();

    final teamList = teams.keys.toList()..sort();

    setState(() {
      _availableTeams = teamList;
      _teamsLoading = false;
      // Start with IDE mode selected (index 0)
      _selectedIndex = 0;
    });
  }

  void _handleKeyEvent(KeyboardEvent event) {
    if (!component.focused) return;

    if (event.logicalKey == LogicalKey.arrowUp ||
        event.logicalKey == LogicalKey.keyK) {
      if (_selectedIndex > 0) {
        setState(() => _selectedIndex--);
      }
    } else if (event.logicalKey == LogicalKey.arrowDown ||
        event.logicalKey == LogicalKey.keyJ) {
      if (_selectedIndex < _totalItems - 1) {
        setState(() => _selectedIndex++);
      }
    } else if (event.logicalKey == LogicalKey.arrowLeft ||
        event.logicalKey == LogicalKey.escape) {
      component.onExit();
    } else if (event.logicalKey == LogicalKey.enter ||
        event.logicalKey == LogicalKey.space) {
      _toggleCurrentItem();
    }
  }

  void _toggleCurrentItem() {
    if (_selectedIndex == 0) {
      // Toggle IDE mode
      final container = ProviderScope.containerOf(context);
      final configManager = container.read(videConfigManagerProvider);
      final settings = configManager.readGlobalSettings();
      final newValue = !settings.ideModeEnabled;
      configManager.writeGlobalSettings(
        settings.copyWith(ideModeEnabled: newValue),
      );
      container.read(ideModeEnabledProvider.notifier).state = newValue;
      setState(() {}); // Rebuild to show new state
    } else if (_selectedIndex == 1) {
      // Toggle streaming
      final configManager = context.read(videConfigManagerProvider);
      final settings = configManager.readGlobalSettings();
      configManager.writeGlobalSettings(
        settings.copyWith(enableStreaming: !settings.enableStreaming),
      );
      setState(() {}); // Rebuild to show new state
    } else {
      // Select team
      final teamIndex =
          _selectedIndex - 2; // Account for IDE mode and Streaming
      if (teamIndex < _availableTeams.length) {
        final selectedTeam = _availableTeams[teamIndex];
        context.read(currentTeamProvider.notifier).state = selectedTeam;
        setState(() {}); // Rebuild to show selection
      }
    }
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    final configManager = context.read(videConfigManagerProvider);
    final settings = configManager.readGlobalSettings();
    final ideModeEnabled = settings.ideModeEnabled;
    final streamingEnabled = settings.enableStreaming;
    final currentTeam = context.watch(currentTeamProvider);

    return Focusable(
      focused: component.focused,
      onKeyEvent: (event) {
        _handleKeyEvent(event);
        return true;
      },
      child: Padding(
        padding: EdgeInsets.all(3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: 'General Settings'),
            SizedBox(height: 2),

            // IDE Mode toggle
            SettingsToggleItem(
              label: 'IDE Mode',
              description: 'Show agent sidebar',
              value: ideModeEnabled,
              isSelected: component.focused && _selectedIndex == 0,
              onTap: () {
                setState(() => _selectedIndex = 0);
                _toggleCurrentItem();
              },
            ),

            SizedBox(height: 1),

            // Streaming toggle
            SettingsToggleItem(
              label: 'Streaming',
              description: 'Stream responses in real-time',
              value: streamingEnabled,
              isSelected: component.focused && _selectedIndex == 1,
              onTap: () {
                setState(() => _selectedIndex = 1);
                _toggleCurrentItem();
              },
            ),

            SizedBox(height: 3),

            // Team selection header
            SectionHeader(title: 'Team Selection'),
            SizedBox(height: 1),
            Text(
              'Choose the agent team for new sessions',
              style: TextStyle(
                color: theme.base.onSurface.withOpacity(TextOpacity.secondary),
              ),
            ),
            SizedBox(height: 2),

            // Team list
            if (_teamsLoading)
              Text(
                'Loading teams...',
                style: TextStyle(
                  color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
                ),
              )
            else if (_availableTeams.isEmpty)
              Text(
                'No teams available',
                style: TextStyle(
                  color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _availableTeams.length,
                  itemBuilder: (context, index) {
                    final team = _availableTeams[index];
                    final isCurrentTeam = team == currentTeam;
                    final itemIndex =
                        index + 2; // Account for IDE mode and Streaming

                    return _TeamListItem(
                      team: team,
                      isCurrentTeam: isCurrentTeam,
                      isSelected:
                          component.focused && _selectedIndex == itemIndex,
                      onTap: () {
                        setState(() => _selectedIndex = itemIndex);
                        _toggleCurrentItem();
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Individual team item in the list.
class _TeamListItem extends StatelessComponent {
  final String team;
  final bool isCurrentTeam;
  final bool isSelected;
  final VoidCallback onTap;

  const _TeamListItem({
    required this.team,
    required this.isCurrentTeam,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 1, vertical: 0.5),
        decoration: BoxDecoration(
          color: isSelected ? theme.base.primary.withOpacity(0.2) : null,
        ),
        child: Row(
          children: [
            Text(
              isCurrentTeam ? '◉ ' : '○ ',
              style: TextStyle(
                color: isCurrentTeam
                    ? theme.base.primary
                    : theme.base.onSurface.withOpacity(TextOpacity.secondary),
              ),
            ),
            Expanded(
              child: Text(
                team,
                style: TextStyle(
                  color: theme.base.onSurface,
                  fontWeight: isCurrentTeam ? FontWeight.bold : null,
                ),
              ),
            ),
            if (isCurrentTeam)
              Text(
                'current',
                style: TextStyle(
                  color: theme.base.primary.withOpacity(TextOpacity.secondary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
