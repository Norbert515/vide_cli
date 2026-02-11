import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_cli/constants/text_opacity.dart';

/// A text input setting item with label and description on left, value on right.
class SettingsTextInput extends StatelessComponent {
  final String label;
  final String description;
  final String value;
  final bool isSelected;
  final bool isEditing;
  final TextEditingController? controller;
  final VoidCallback onTap;
  final ValueChanged<String>? onSubmitted;

  const SettingsTextInput({
    required this.label,
    required this.description,
    required this.value,
    required this.isSelected,
    required this.onTap,
    this.isEditing = false,
    this.controller,
    this.onSubmitted,
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
            if (isEditing && controller != null)
              SizedBox(
                width: 20,
                child: TextField(
                  controller: controller,
                  focused: true,
                  onSubmitted: onSubmitted,
                  style: TextStyle(color: theme.base.primary),
                ),
              )
            else
              Text(value, style: TextStyle(color: theme.base.primary)),
          ],
        ),
      ),
    );
  }
}
