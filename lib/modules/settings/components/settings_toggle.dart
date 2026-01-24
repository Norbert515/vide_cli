import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_cli/constants/text_opacity.dart';

/// Toggle switch component for settings.
class SettingsToggle extends StatelessComponent {
  final bool value;
  final bool focused;

  const SettingsToggle({required this.value, this.focused = false, super.key});

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    if (value) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('●', style: TextStyle(color: theme.base.primary)),
          Text(
            '━━',
            style: TextStyle(color: theme.base.primary.withOpacity(0.5)),
          ),
          Text(
            '○',
            style: TextStyle(
              color: theme.base.outline.withOpacity(TextOpacity.disabled),
            ),
          ),
        ],
      );
    } else {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '○',
            style: TextStyle(
              color: theme.base.outline.withOpacity(TextOpacity.disabled),
            ),
          ),
          Text(
            '━━',
            style: TextStyle(
              color: theme.base.outline.withOpacity(TextOpacity.separator),
            ),
          ),
          Text(
            '●',
            style: TextStyle(
              color: theme.base.outline.withOpacity(TextOpacity.secondary),
            ),
          ),
        ],
      );
    }
  }
}

/// A toggle setting item with label, description, and toggle switch.
class SettingsToggleItem extends StatelessComponent {
  final String label;
  final String description;
  final bool value;
  final bool isSelected;
  final VoidCallback onTap;

  const SettingsToggleItem({
    required this.label,
    required this.description,
    required this.value,
    required this.isSelected,
    required this.onTap,
    super.key,
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
            SettingsToggle(value: value, focused: isSelected),
            SizedBox(width: 2),
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
          ],
        ),
      ),
    );
  }
}
