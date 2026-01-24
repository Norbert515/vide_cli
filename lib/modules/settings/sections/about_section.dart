import 'dart:io';

import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/modules/settings/components/section_header.dart';

/// About settings content.
class AboutSection extends StatelessComponent {
  final bool focused;
  final VoidCallback onExit;

  const AboutSection({required this.focused, required this.onExit, super.key});

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    return Focusable(
      focused: focused,
      onKeyEvent: (event) {
        if (event.logicalKey == LogicalKey.arrowLeft ||
            event.logicalKey == LogicalKey.escape) {
          onExit();
          return true;
        }
        return true;
      },
      child: Padding(
        padding: EdgeInsets.all(3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: 'About Vide'),
            SizedBox(height: 3),

            _AboutItem(label: 'Version', value: '0.1.0'),
            _AboutItem(label: 'Platform', value: Platform.operatingSystem),
            _AboutItem(label: 'Dart', value: Platform.version.split(' ').first),
            SizedBox(height: 3),

            Text(
              'Vide is an agentic development environment',
              style: TextStyle(
                color: theme.base.onSurface.withOpacity(TextOpacity.secondary),
              ),
            ),
            Text(
              'built specifically for Flutter developers.',
              style: TextStyle(
                color: theme.base.onSurface.withOpacity(TextOpacity.secondary),
              ),
            ),
            SizedBox(height: 3),

            SectionHeader(title: 'Links'),
            SizedBox(height: 2),
            Text(
              '• Documentation: docs.vide.dev',
              style: TextStyle(color: theme.base.primary),
            ),
            Text(
              '• GitHub: github.com/vide-dev/vide',
              style: TextStyle(color: theme.base.primary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple key-value display for About section.
class _AboutItem extends StatelessComponent {
  final String label;
  final String value;

  const _AboutItem({required this.label, required this.value});

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: 1),
      child: Row(
        children: [
          SizedBox(
            width: 12,
            child: Text(
              label,
              style: TextStyle(
                color: theme.base.onSurface.withOpacity(TextOpacity.secondary),
              ),
            ),
          ),
          Text(value, style: TextStyle(color: theme.base.onSurface)),
        ],
      ),
    );
  }
}
