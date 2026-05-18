import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_cli/constants/text_opacity.dart';

/// A bordered card wrapper for grouping related settings.
///
/// Renders as:
/// ```
/// ╭─ Title ──────────────╮
/// │ [child content]      │
/// ╰──────────────────────╯
/// ```
class SettingsCard extends StatelessComponent {
  final String title;
  final Component child;

  const SettingsCard({required this.title, required this.child, super.key});

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: BoxBorder.all(
          color: theme.base.outlineVariant,
          style: BoxBorderStyle.rounded,
        ),
        title: BorderTitle(
          text: ' $title ',
          alignment: TitleAlignment.left,
          style: TextStyle(
            color: theme.base.onSurface.withOpacity(TextOpacity.secondary),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 1),
        child: child,
      ),
    );
  }
}
