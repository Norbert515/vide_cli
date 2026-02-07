import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/services/core_providers.dart';
import 'package:vide_cli/modules/settings/components/section_header.dart';
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

  // We add 'auto' as the first option
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

  void _handleKeyEvent(KeyboardEvent event) {
    if (!component.focused) return;

    if (event.logicalKey == LogicalKey.arrowUp ||
        event.logicalKey == LogicalKey.keyK) {
      if (_selectedIndex > 0) {
        setState(() => _selectedIndex--);
        _applyTheme();
      }
    } else if (event.logicalKey == LogicalKey.arrowDown ||
        event.logicalKey == LogicalKey.keyJ) {
      if (_selectedIndex < _totalOptions - 1) {
        setState(() => _selectedIndex++);
        _applyTheme();
      }
    } else if (event.logicalKey == LogicalKey.arrowLeft ||
        event.logicalKey == LogicalKey.escape) {
      component.onExit();
    } else if (event.logicalKey == LogicalKey.enter ||
        event.logicalKey == LogicalKey.space) {
      _applyTheme();
    }
  }

  void _applyTheme() {
    final String? themeId;
    if (_selectedIndex == 0) {
      themeId = null;
    } else {
      themeId = ThemeOption.all[_selectedIndex - 1].id;
    }

    // Save and apply the theme immediately
    context.read(themeSettingProvider.notifier).state = themeId;
    final configManager = context.read(videConfigManagerProvider);
    configManager.setTheme(themeId);
  }

  @override
  Component build(BuildContext context) {
    final currentThemeId = context.watch(themeSettingProvider);
    final theme = VideTheme.of(context);

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
            SectionHeader(title: 'Theme'),
            SizedBox(height: 1),
            Text(
              'Select a color theme for the interface',
              style: TextStyle(
                color: theme.base.onSurface.withOpacity(TextOpacity.secondary),
              ),
            ),
            SizedBox(height: 2),

            // Auto option
            _ThemeListItem(
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
              _ThemeListItem(
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
    );
  }
}

/// Individual theme item in the list - compact single-line format.
class _ThemeListItem extends StatelessComponent {
  final String displayName;
  final String description;
  final bool isSelected;
  final bool isCurrent;
  final VoidCallback onTap;

  const _ThemeListItem({
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
              isCurrent ? '◉ ' : '○ ',
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
