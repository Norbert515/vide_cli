import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/modules/settings/settings_category.dart';
import 'package:vide_cli/modules/settings/components/settings_sidebar.dart';
import 'package:vide_cli/modules/settings/sections/general_settings_section.dart';
import 'package:vide_cli/modules/settings/sections/appearance_section.dart';
import 'package:vide_cli/modules/settings/sections/server_section.dart';
import 'package:vide_cli/modules/settings/sections/mcp_servers_section.dart';
import 'package:vide_cli/modules/settings/sections/permissions_section.dart';
import 'package:vide_cli/modules/settings/sections/about_section.dart';

/// A popup overlay wrapper for the settings dialog.
///
/// Displays the settings content in a centered popup overlay.
/// Use the static [show] method to display the dialog.
/// Press ESC to close the popup.
class SettingsPopup extends StatelessComponent {
  const SettingsPopup({super.key});

  /// Shows the settings popup dialog using nocterm's Navigator.showDialog() API.
  /// The dialog sizes itself responsively based on available screen space.
  static Future<void> show(BuildContext context) {
    return Navigator.of(context).showDialog(
      builder: (context) => const SettingsPopup(),
      barrierDismissible: true,
    );
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Size dialog to ~80% of screen, with min/max bounds
        final dialogWidth = (constraints.maxWidth * 0.8).clamp(50.0, 100.0);
        final dialogHeight = (constraints.maxHeight * 0.8).clamp(20.0, 40.0);

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Main dialog container with rounded borders
            Container(
              width: dialogWidth,
              height: dialogHeight - 2, // Reserve space for footer
              decoration: BoxDecoration(
                color: theme.base.surface,
                border: BoxBorder.all(
                  color: theme.base.primary,
                  style: BoxBorderStyle.rounded,
                ),
                title: BorderTitle(
                  text: '⚙ Settings',
                  alignment: TitleAlignment.center,
                  style: TextStyle(
                    color: theme.base.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              child: SettingsDialog(onClose: () => Navigator.of(context).pop()),
            ),
            // Footer outside the box
            SizedBox(width: dialogWidth, child: _NavigationFooter()),
          ],
        );
      },
    );
  }
}

/// Footer showing navigation hints, displayed outside the dialog box.
class _NavigationFooter extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    return Padding(
      padding: EdgeInsets.only(top: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('↑↓ ', style: TextStyle(color: theme.base.primary)),
          Text(
            'navigate  ',
            style: TextStyle(
              color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
            ),
          ),
          Text('→ ', style: TextStyle(color: theme.base.primary)),
          Text(
            'enter section  ',
            style: TextStyle(
              color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
            ),
          ),
          Text('Tab ', style: TextStyle(color: theme.base.primary)),
          Text(
            'switch  ',
            style: TextStyle(
              color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
            ),
          ),
          Text('Esc ', style: TextStyle(color: theme.base.primary)),
          Text(
            'close',
            style: TextStyle(
              color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
            ),
          ),
        ],
      ),
    );
  }
}

/// A comprehensive settings dialog with category navigation.
class SettingsDialog extends StatefulComponent {
  final VoidCallback? onClose;

  const SettingsDialog({this.onClose, super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  SettingsCategory _selectedCategory = SettingsCategory.general;
  bool _sidebarFocused = true;
  int _sidebarIndex = 0;

  /// Returns true if the event was handled, false to let it bubble up.
  bool _handleKeyEvent(KeyboardEvent event) {
    if (_sidebarFocused) {
      return _handleSidebarNavigation(event);
    }
    // Content sections handle their own key events via their Focusable
    return false;
  }

  /// Returns true if the event was handled.
  bool _handleSidebarNavigation(KeyboardEvent event) {
    final categories = SettingsCategory.values;

    if (event.logicalKey == LogicalKey.arrowUp ||
        event.logicalKey == LogicalKey.keyK) {
      if (_sidebarIndex > 0) {
        setState(() {
          _sidebarIndex--;
          _selectedCategory = categories[_sidebarIndex];
        });
      }
      return true;
    } else if (event.logicalKey == LogicalKey.arrowDown ||
        event.logicalKey == LogicalKey.keyJ) {
      if (_sidebarIndex < categories.length - 1) {
        setState(() {
          _sidebarIndex++;
          _selectedCategory = categories[_sidebarIndex];
        });
      }
      return true;
    } else if (event.logicalKey == LogicalKey.arrowRight ||
        event.logicalKey == LogicalKey.enter ||
        event.logicalKey == LogicalKey.tab) {
      setState(() => _sidebarFocused = false);
      return true;
    } else if (event.logicalKey == LogicalKey.escape) {
      // Close the dialog when ESC is pressed in sidebar
      component.onClose?.call();
      return true;
    }

    return false;
  }

  void _handleContentExit() {
    setState(() => _sidebarFocused = true);
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    return Focusable(
      focused: true,
      onKeyEvent: (event) {
        return _handleKeyEvent(event);
      },
      child: Column(
        children: [
          // Main content: sidebar + content area
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category sidebar
                SettingsSidebar(
                  selectedCategory: _selectedCategory,
                  selectedIndex: _sidebarIndex,
                  focused: _sidebarFocused,
                  onCategorySelected: (category, index) {
                    setState(() {
                      _selectedCategory = category;
                      _sidebarIndex = index;
                    });
                  },
                ),

                // Vertical divider
                Container(
                  width: 1,
                  decoration: BoxDecoration(
                    color: theme.base.outline.withOpacity(
                      TextOpacity.separator,
                    ),
                  ),
                ),

                // Content area
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Component _buildContent() {
    switch (_selectedCategory) {
      case SettingsCategory.general:
        return GeneralSettingsSection(
          focused: !_sidebarFocused,
          onExit: _handleContentExit,
        );
      case SettingsCategory.appearance:
        return AppearanceSection(
          focused: !_sidebarFocused,
          onExit: _handleContentExit,
        );
      case SettingsCategory.server:
        return ServerSection(
          focused: !_sidebarFocused,
          onExit: _handleContentExit,
        );
      case SettingsCategory.mcpServers:
        return McpServersSection(
          focused: !_sidebarFocused,
          onExit: _handleContentExit,
        );
      case SettingsCategory.permissions:
        return PermissionsSection(
          focused: !_sidebarFocused,
          onExit: _handleContentExit,
        );
      case SettingsCategory.about:
        return AboutSection(
          focused: !_sidebarFocused,
          onExit: _handleContentExit,
        );
    }
  }
}
