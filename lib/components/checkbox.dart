import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/theme/theme.dart';

/// A checkbox component with focus support for nocterm TUI
class Checkbox extends StatelessComponent {
  const Checkbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.focused,
    this.label,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final bool focused;
  final String? label;

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    return Focusable(
      focused: focused,
      onKeyEvent: (event) {
        if (event.logicalKey == LogicalKey.space ||
            event.logicalKey == LogicalKey.enter) {
          onChanged(!value);
          return true;
        }
        return false;
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 0),
            decoration: focused
                ? BoxDecoration(
                    border: BoxBorder.all(color: theme.base.primary),
                  )
                : null,
            child: Text(
              value ? '[X]' : '[ ]',
              style: TextStyle(
                color: focused
                    ? theme.base.primary
                    : theme.base.onSurface.withOpacity(TextOpacity.tertiary),
                fontWeight: focused ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (label != null) ...[
            const SizedBox(width: 1),
            Text(
              label!,
              style: TextStyle(
                color: focused
                    ? theme.base.onSurface
                    : theme.base.onSurface.withOpacity(TextOpacity.tertiary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
