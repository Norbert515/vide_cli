import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/theme/theme.dart';

class TeamSelector extends StatefulComponent {
  final List<String> teams;
  final String currentTeam;
  final bool focused;
  final void Function(String team)? onTeamSelected;
  final void Function()? onUpEdge;
  final void Function()? onDownEdge;

  const TeamSelector({
    required this.teams,
    required this.currentTeam,
    this.focused = false,
    this.onTeamSelected,
    this.onUpEdge,
    this.onDownEdge,
    super.key,
  });

  @override
  State<TeamSelector> createState() => _TeamSelectorState();
}

class _TeamSelectorState extends State<TeamSelector> {
  int _selectedTeamIndex = 0;

  @override
  void initState() {
    super.initState();
    _syncSelectedIndex();
  }

  @override
  void didUpdateComponent(TeamSelector oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (!component.focused && oldComponent.focused) {
      _syncSelectedIndex();
    }
    if (component.currentTeam != oldComponent.currentTeam &&
        !component.focused) {
      _syncSelectedIndex();
    }
  }

  void _syncSelectedIndex() {
    final idx = component.teams.indexOf(component.currentTeam);
    setState(() {
      _selectedTeamIndex = idx >= 0 ? idx : 0;
    });
  }

  bool _handleKeyEvent(KeyboardEvent event) {
    if (component.teams.isEmpty) return false;

    if (event.logicalKey == LogicalKey.arrowLeft ||
        event.logicalKey == LogicalKey.keyH) {
      setState(() {
        _selectedTeamIndex--;
        if (_selectedTeamIndex < 0)
          _selectedTeamIndex = component.teams.length - 1;
      });
      return true;
    } else if (event.logicalKey == LogicalKey.arrowRight ||
        event.logicalKey == LogicalKey.keyL) {
      setState(() {
        _selectedTeamIndex++;
        if (_selectedTeamIndex >= component.teams.length)
          _selectedTeamIndex = 0;
      });
      return true;
    } else if (event.logicalKey == LogicalKey.arrowUp ||
        event.logicalKey == LogicalKey.keyK) {
      if (component.onUpEdge != null) {
        component.onUpEdge!();
        return true;
      }
      return false;
    } else if (event.logicalKey == LogicalKey.arrowDown ||
        event.logicalKey == LogicalKey.enter ||
        event.logicalKey == LogicalKey.escape) {
      if (_selectedTeamIndex < component.teams.length) {
        component.onTeamSelected?.call(component.teams[_selectedTeamIndex]);
      }
      component.onDownEdge?.call();
      return true;
    }
    return false;
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    if (component.teams.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayIndex = component.focused
        ? _selectedTeamIndex
        : component.teams
              .indexOf(component.currentTeam)
              .clamp(0, component.teams.length - 1);

    return Focusable(
      focused: component.focused,
      onKeyEvent: _handleKeyEvent,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (component.focused)
              Text('← ', style: TextStyle(color: theme.base.primary))
            else
              Text(
                '↑ ',
                style: TextStyle(
                  color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
                ),
              ),
            for (int i = 0; i < component.teams.length; i++) ...[
              if (i > 0)
                Text(
                  ' · ',
                  style: TextStyle(
                    color: theme.base.onSurface.withOpacity(
                      TextOpacity.tertiary,
                    ),
                  ),
                ),
              if (i == displayIndex)
                Text(
                  ' ${component.teams[i]} ',
                  style: TextStyle(
                    color: theme.base.background,
                    backgroundColor: theme.base.primary,
                  ),
                )
              else
                Text(
                  component.teams[i],
                  style: TextStyle(
                    color: theme.base.onSurface.withOpacity(
                      component.focused
                          ? TextOpacity.secondary
                          : TextOpacity.tertiary,
                    ),
                  ),
                ),
            ],
            if (component.focused)
              Text(' →', style: TextStyle(color: theme.base.primary)),
          ],
        ),
      ),
    );
  }
}
