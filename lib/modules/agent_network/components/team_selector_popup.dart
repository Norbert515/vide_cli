import 'dart:io';

import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/modules/agent_network/state/vide_session_providers.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_core/vide_core.dart' show TeamFrameworkLoader, TeamFrameworkAssetInitializer;

/// A popup dialog for selecting the team to use for new sessions.
class TeamSelectorPopup extends StatefulComponent {
  const TeamSelectorPopup({super.key});

  /// Shows the team selector popup dialog.
  /// Returns the selected team name, or null if cancelled.
  static Future<String?> show(BuildContext context) {
    return Navigator.of(context).showDialog<String?>(
      builder: (context) => const TeamSelectorPopup(),
      barrierDismissible: true,
    );
  }

  @override
  State<TeamSelectorPopup> createState() => _TeamSelectorPopupState();
}

class _TeamSelectorPopupState extends State<TeamSelectorPopup> {
  List<String> _availableTeams = [];
  bool _loading = true;
  int _selectedIndex = 0;

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
    final currentTeam = context.read(currentTeamProvider);

    // Find the current team's index
    var initialIndex = teamList.indexOf(currentTeam);
    if (initialIndex < 0) initialIndex = 0;

    setState(() {
      _availableTeams = teamList;
      _loading = false;
      _selectedIndex = initialIndex;
    });
  }

  void _selectTeam() {
    if (_availableTeams.isEmpty) return;

    final selectedTeam = _availableTeams[_selectedIndex];
    context.read(currentTeamProvider.notifier).state = selectedTeam;
    Navigator.of(context).pop(selectedTeam);
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    final currentTeam = context.watch(currentTeamProvider);

    return Focusable(
      focused: true,
      onKeyEvent: (event) {
        if (event.logicalKey == LogicalKey.escape) {
          Navigator.of(context).pop(null);
          return true;
        }
        if (event.logicalKey == LogicalKey.arrowUp || event.logicalKey == LogicalKey.keyK) {
          if (_selectedIndex > 0) {
            setState(() => _selectedIndex--);
          }
          return true;
        }
        if (event.logicalKey == LogicalKey.arrowDown || event.logicalKey == LogicalKey.keyJ) {
          if (_selectedIndex < _availableTeams.length - 1) {
            setState(() => _selectedIndex++);
          }
          return true;
        }
        if (event.logicalKey == LogicalKey.enter || event.logicalKey == LogicalKey.space) {
          _selectTeam();
          return true;
        }
        return false;
      },
      child: Center(
        child: Container(
          width: 40,
          constraints: BoxConstraints(maxHeight: 15),
          decoration: BoxDecoration(
            color: theme.base.surface,
            border: BoxBorder.all(color: theme.base.primary, style: BoxBorderStyle.rounded),
            title: BorderTitle(
              text: 'Select Team',
              alignment: TitleAlignment.center,
              style: TextStyle(color: theme.base.primary, fontWeight: FontWeight.bold),
            ),
          ),
          child: _loading
              ? Center(
                  child: Text(
                    'Loading teams...',
                    style: TextStyle(color: theme.base.onSurface.withOpacity(TextOpacity.secondary)),
                  ),
                )
              : _availableTeams.isEmpty
                  ? Center(
                      child: Text(
                        'No teams found',
                        style: TextStyle(color: theme.base.onSurface.withOpacity(TextOpacity.secondary)),
                      ),
                    )
                  : Padding(
                      padding: EdgeInsets.symmetric(vertical: 1),
                      child: ListView.builder(
                        itemCount: _availableTeams.length,
                        itemBuilder: (context, index) {
                          final team = _availableTeams[index];
                          final isSelected = index == _selectedIndex;
                          final isCurrent = team == currentTeam;

                          return Container(
                            padding: EdgeInsets.symmetric(horizontal: 2),
                            decoration: isSelected
                                ? BoxDecoration(color: theme.base.primary.withOpacity(0.3))
                                : null,
                            child: Row(
                              children: [
                                Text(
                                  isSelected ? '>' : ' ',
                                  style: TextStyle(color: theme.base.primary),
                                ),
                                SizedBox(width: 1),
                                Expanded(
                                  child: Text(
                                    team,
                                    style: TextStyle(
                                      color: isSelected
                                          ? theme.base.onSurface
                                          : theme.base.onSurface.withOpacity(TextOpacity.secondary),
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isCurrent)
                                  Text(
                                    ' (current)',
                                    style: TextStyle(
                                      color: theme.base.primary.withOpacity(TextOpacity.secondary),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ),
    );
  }
}
