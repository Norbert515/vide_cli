import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_core/vide_core.dart' show videConfigManagerProvider;
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/modules/settings/components/section_header.dart';
import 'package:vide_cli/modules/settings/components/settings_toggle.dart';

/// Permissions settings content.
class PermissionsSection extends StatefulComponent {
  final bool focused;
  final VoidCallback onExit;

  const PermissionsSection({
    required this.focused,
    required this.onExit,
    super.key,
  });

  @override
  State<PermissionsSection> createState() => _PermissionsSectionState();
}

class _PermissionsSectionState extends State<PermissionsSection> {
  int _selectedIndex = 0;
  static const int _totalItems = 1; // Just the toggle for now

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
    final container = ProviderScope.containerOf(context);
    final configManager = container.read(videConfigManagerProvider);
    final settings = configManager.readGlobalSettings();

    if (_selectedIndex == 0) {
      // Toggle dangerously skip permissions
      final newValue = !settings.dangerouslySkipPermissions;
      configManager.writeGlobalSettings(
        settings.copyWith(dangerouslySkipPermissions: newValue),
      );
      setState(() {}); // Rebuild to show new state
    }
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    final configManager = context.read(videConfigManagerProvider);
    final settings = configManager.readGlobalSettings();
    final skipPermissions = settings.dangerouslySkipPermissions;

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
            SectionHeader(title: 'Permissions'),
            SizedBox(height: 1),
            Text(
              'Configure tool access permissions',
              style: TextStyle(
                color: theme.base.onSurface.withOpacity(TextOpacity.secondary),
              ),
            ),
            SizedBox(height: 3),

            // Dangerously skip permissions toggle
            SettingsToggleItem(
              label: 'Dangerously Skip Permissions',
              description: 'Skip ALL permission checks (sandboxed envs only)',
              value: skipPermissions,
              isSelected: component.focused && _selectedIndex == 0,
              onTap: () {
                setState(() => _selectedIndex = 0);
                _toggleCurrentItem();
              },
            ),

            // Warning box when enabled
            if (skipPermissions) ...[
              SizedBox(height: 2),
              Container(
                padding: EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: theme.base.error.withOpacity(0.1),
                  border: BoxBorder.all(
                    color: theme.base.error.withOpacity(0.5),
                    style: BoxBorderStyle.rounded,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚠ WARNING',
                      style: TextStyle(
                        color: theme.base.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'All permission checks are disabled!',
                      style: TextStyle(
                        color: theme.base.error.withOpacity(0.9),
                      ),
                    ),
                    Text(
                      'Only use in sandboxed environments (Docker, VMs).',
                      style: TextStyle(
                        color: theme.base.error.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            SizedBox(height: 3),

            // Coming soon section
            Container(
              padding: EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: theme.base.outlineVariant.withOpacity(0.2),
                border: BoxBorder.all(
                  color: theme.base.outlineVariant,
                  style: BoxBorderStyle.rounded,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'More Coming Soon',
                    style: TextStyle(
                      color: theme.base.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Additional permission management will allow you to:',
                    style: TextStyle(
                      color: theme.base.onSurface.withOpacity(
                        TextOpacity.secondary,
                      ),
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    '• View and edit allow/deny lists',
                    style: TextStyle(
                      color: theme.base.onSurface.withOpacity(
                        TextOpacity.secondary,
                      ),
                    ),
                  ),
                  Text(
                    '• Configure file path permissions',
                    style: TextStyle(
                      color: theme.base.onSurface.withOpacity(
                        TextOpacity.secondary,
                      ),
                    ),
                  ),
                  Text(
                    '• Manage bash command permissions',
                    style: TextStyle(
                      color: theme.base.onSurface.withOpacity(
                        TextOpacity.secondary,
                      ),
                    ),
                  ),
                  Text(
                    '• Set up web domain restrictions',
                    style: TextStyle(
                      color: theme.base.onSurface.withOpacity(
                        TextOpacity.secondary,
                      ),
                    ),
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
