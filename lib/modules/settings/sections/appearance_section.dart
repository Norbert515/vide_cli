import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_core/vide_core.dart' show videConfigManagerProvider;
import 'package:vide_cli/modules/settings/components/section_header.dart';
import 'package:vide_cli/modules/setup/theme_selector.dart';

/// Appearance settings content (theme selection with live preview).
class AppearanceSection extends StatefulComponent {
  final bool focused;
  final VoidCallback onExit;

  const AppearanceSection({required this.focused, required this.onExit, super.key});

  @override
  State<AppearanceSection> createState() => _AppearanceSectionState();
}

class _AppearanceSectionState extends State<AppearanceSection> {
  int _selectedIndex = 0;
  TuiThemeData? _previewTheme;

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

    if (event.logicalKey == LogicalKey.arrowUp || event.logicalKey == LogicalKey.keyK) {
      if (_selectedIndex > 0) {
        setState(() => _selectedIndex--);
        _applyPreview();
      }
    } else if (event.logicalKey == LogicalKey.arrowDown || event.logicalKey == LogicalKey.keyJ) {
      if (_selectedIndex < _totalOptions - 1) {
        setState(() => _selectedIndex++);
        _applyPreview();
      }
    } else if (event.logicalKey == LogicalKey.arrowLeft || event.logicalKey == LogicalKey.escape) {
      // Clear preview and restore original theme when exiting
      setState(() => _previewTheme = null);
      component.onExit();
    } else if (event.logicalKey == LogicalKey.enter || event.logicalKey == LogicalKey.space) {
      _confirmSelection();
    }
  }

  void _applyPreview() {
    setState(() {
      if (_selectedIndex == 0) {
        // For auto, use the detected theme (dark as fallback)
        _previewTheme = TuiThemeData.dark;
      } else {
        final option = ThemeOption.all[_selectedIndex - 1];
        _previewTheme = option.themeData;
      }
    });
  }

  void _confirmSelection() {
    final String? themeId;
    if (_selectedIndex == 0) {
      themeId = null;
    } else {
      themeId = ThemeOption.all[_selectedIndex - 1].id;
    }

    // Save the theme
    context.read(themeSettingProvider.notifier).state = themeId;
    final configManager = context.read(videConfigManagerProvider);
    configManager.setTheme(themeId);

    // Clear preview (the actual theme change will be applied)
    setState(() => _previewTheme = null);
  }

  @override
  Component build(BuildContext context) {
    final currentThemeId = context.watch(themeSettingProvider);

    Component content = _buildContent(context, currentThemeId);

    // Apply preview theme if set
    if (_previewTheme != null) {
      content = TuiTheme(
        data: _previewTheme!,
        child: VideTheme(
          data: VideThemeData.fromBrightness(_previewTheme!),
          child: content,
        ),
      );
    }

    return content;
  }

  Component _buildContent(BuildContext context, String? currentThemeId) {
    final theme = VideTheme.of(context);

    return Focusable(
      focused: component.focused,
      onKeyEvent: (event) {
        _handleKeyEvent(event);
        return true;
      },
      child: Padding(
        padding: EdgeInsets.all(3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Theme selection list
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(title: 'Theme'),
                  SizedBox(height: 1),
                  Text(
                    'Select a color theme for the interface',
                    style: TextStyle(color: theme.base.onSurface.withOpacity(TextOpacity.secondary)),
                  ),
                  SizedBox(height: 2),

                  // Auto option
                  _ThemeListItem(
                    displayName: 'Auto',
                    description: 'Match terminal brightness',
                    isSelected: component.focused && _selectedIndex == 0,
                    isCurrent: currentThemeId == null,
                    onTap: () {
                      setState(() => _selectedIndex = 0);
                      _applyPreview();
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
                        _applyPreview();
                      },
                    ),

                  SizedBox(height: 2),
                  Text(
                    'Press Enter to apply theme',
                    style: TextStyle(color: theme.base.onSurface.withOpacity(TextOpacity.tertiary)),
                  ),
                ],
              ),
            ),

            // Preview panel
            SizedBox(width: 2),
            Container(
              padding: EdgeInsets.all(1),
              decoration: BoxDecoration(
                border: BoxBorder.all(
                  color: theme.base.outline.withOpacity(TextOpacity.separator),
                  style: BoxBorderStyle.rounded,
                ),
              ),
              child: const ThemePreview(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual theme item in the list.
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
        padding: EdgeInsets.symmetric(horizontal: 1, vertical: 0.5),
        decoration: BoxDecoration(
          color: isSelected ? theme.base.primary.withOpacity(0.2) : null,
        ),
        child: Row(
          children: [
            Text(
              isCurrent ? '◉ ' : '○ ',
              style: TextStyle(
                color: isCurrent ? theme.base.primary : theme.base.onSurface.withOpacity(TextOpacity.secondary),
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
            Expanded(
              child: Text(
                description,
                style: TextStyle(color: theme.base.onSurface.withOpacity(TextOpacity.secondary)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isCurrent)
              Text(
                'current',
                style: TextStyle(color: theme.base.primary.withOpacity(TextOpacity.secondary)),
              ),
          ],
        ),
      ),
    );
  }
}
