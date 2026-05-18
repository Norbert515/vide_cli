import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/components/version_indicator.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/theme/theme.dart';

class BottomHintBar extends StatelessComponent {
  const BottomHintBar({super.key});

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(color: theme.base.surface),
      child: Row(
        children: [
          Text(
            'Tab',
            style: TextStyle(
              color: theme.base.onSurface.withOpacity(TextOpacity.secondary),
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            ': settings',
            style: TextStyle(
              color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
            ),
          ),
          const Spacer(),
          const VersionIndicator(),
        ],
      ),
    );
  }
}
