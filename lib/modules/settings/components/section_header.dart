import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/theme/theme.dart';

/// Section header with horizontal rules.
class SectionHeader extends StatelessComponent {
  final String title;

  const SectionHeader({required this.title, super.key});

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    return Row(
      children: [
        Text(
          '─── ',
          style: TextStyle(
            color: theme.base.outlineVariant,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            color: theme.base.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        Expanded(
          child: Text(
            ' ─────────────────────────────────────────',
            style: TextStyle(
              color: theme.base.outlineVariant,
            ),
            overflow: TextOverflow.clip,
          ),
        ),
      ],
    );
  }
}
