import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_core/vide_core.dart' show videConfigManagerProvider;
import 'package:vide_cli/modules/settings/components/settings_card.dart';
import 'package:vide_cli/modules/setup/theme_selector.dart';

/// Appearance settings content (theme selection).
class AppearanceSection extends StatefulComponent {
  final bool focused;
  final VoidCallback onExit;

  const AppearanceSection({
    required this.focused,
    required this.onExit,
    super.key,
  });

  @override
  State<AppearanceSection> createState() => _AppearanceSectionState();
}

class _AppearanceSectionState extends State<AppearanceSection> {
  int _selectedIndex = 0;

  int get _totalOptions => ThemeOption.all.length + 1; // +1 for auto

  @override
  void initState() {
    super.initState();
    _initializeSelection();
  }

  void _initializeSelection() {
    final themeId = context.read(themeSettingProvider);
    if (themeId == null) {
      _selectedIndex = 0; // Auto
    } else {
      final themeIndex = ThemeOption.all.indexWhere((t) => t.id == themeId);
      _selectedIndex = themeIndex >= 0 ? themeIndex + 1 : 0;
    }
  }

  bool _handleKeyEvent(KeyboardEvent event) {
    if (!component.focused) return false;

    if (event.logicalKey == LogicalKey.arrowUp ||
        event.logicalKey == LogicalKey.keyK) {
      if (_selectedIndex > 0) {
        setState(() => _selectedIndex--);
        _applyTheme();
      }
      return true;
    } else if (event.logicalKey == LogicalKey.arrowDown ||
        event.logicalKey == LogicalKey.keyJ) {
      if (_selectedIndex < _totalOptions - 1) {
        setState(() => _selectedIndex++);
        _applyTheme();
      }
      return true;
    } else if (event.logicalKey == LogicalKey.arrowLeft ||
        event.logicalKey == LogicalKey.escape) {
      component.onExit();
      return true;
    } else if (event.logicalKey == LogicalKey.enter ||
        event.logicalKey == LogicalKey.space) {
      _applyTheme();
      return true;
    }

    return false;
  }

  void _applyTheme() {
    final String? themeId;
    if (_selectedIndex == 0) {
      themeId = null;
    } else {
      themeId = ThemeOption.all[_selectedIndex - 1].id;
    }

    context.read(themeSettingProvider.notifier).state = themeId;
    final configManager = context.read(videConfigManagerProvider);
    configManager.setTheme(themeId);
  }

  @override
  Component build(BuildContext context) {
    final currentThemeId = context.watch(themeSettingProvider);

    return Focusable(
      focused: component.focused,
      onKeyEvent: _handleKeyEvent,
      child: Padding(
        padding: EdgeInsets.only(top: 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsCard(
              title: 'Theme',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Auto option
                  _RadioListItem(
                    displayName: 'Auto',
                    description: 'Match terminal',
                    isSelected: component.focused && _selectedIndex == 0,
                    isCurrent: currentThemeId == null,
                    onTap: () {
                      setState(() => _selectedIndex = 0);
                      _applyTheme();
                    },
                  ),

                  // Theme options
                  for (int i = 0; i < ThemeOption.all.length; i++)
                    _RadioListItem(
                      displayName: ThemeOption.all[i].displayName,
                      description: ThemeOption.all[i].description,
                      isSelected: component.focused && _selectedIndex == i + 1,
                      isCurrent: currentThemeId == ThemeOption.all[i].id,
                      onTap: () {
                        setState(() => _selectedIndex = i + 1);
                        _applyTheme();
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual radio item in a settings list - compact single-line format.
class _RadioListItem extends StatelessComponent {
  final String displayName;
  final String description;
  final bool isSelected;
  final bool isCurrent;
  final VoidCallback onTap;

  const _RadioListItem({
    required this.displayName,
    required this.description,
    required this.isSelected,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: isSelected ? theme.base.primary.withOpacity(0.2) : null,
        ),
        child: Row(
          children: [
            Text(
              isCurrent ? '\u25c9 ' : '\u25cb ',
              style: TextStyle(
                color: isCurrent
                    ? theme.base.primary
                    : theme.base.onSurface.withOpacity(TextOpacity.secondary),
              ),
            ),
            SizedBox(
              width: 12,
              child: Text(
                displayName,
                style: TextStyle(
                  color: theme.base.onSurface,
                  fontWeight: isCurrent ? FontWeight.bold : null,
                ),
              ),
            ),
            Text(
              description,
              style: TextStyle(
                color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
