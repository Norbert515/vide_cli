import 'dart:io';

import 'package:nocterm/nocterm.dart';
import 'package:vide_core/vide_core.dart' show videVersion, githubOwner, githubRepo;
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/modules/settings/components/settings_card.dart';

/// About settings content with Info and Links cards.
class AboutSection extends StatelessComponent {
  final bool focused;
  final VoidCallback onExit;

  const AboutSection({
    required this.focused,
    required this.onExit,
    super.key,
  });

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
        return false;
      },
      child: Padding(
        padding: EdgeInsets.only(top: 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info card
            SettingsCard(
              title: 'Info',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AboutItem(label: 'Version', value: videVersion),
                  _AboutItem(
                    label: 'Platform',
                    value: Platform.operatingSystem,
                  ),
                  _AboutItem(
                    label: 'Dart',
                    value: Platform.version.split(' ').first,
                  ),
                  SizedBox(height: 1),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 1),
                    child: Text(
                      'Vide is an agentic development environment',
                      style: TextStyle(
                        color: theme.base.onSurface.withOpacity(
                          TextOpacity.secondary,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 1),
                    child: Text(
                      'built specifically for Flutter developers.',
                      style: TextStyle(
                        color: theme.base.onSurface.withOpacity(
                          TextOpacity.secondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 1),

            // Links card
            SettingsCard(
              title: 'Links',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 1),
                    child: Text(
                      'vide.dev',
                      style: TextStyle(color: theme.base.primary),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 1),
                    child: Text(
                      'github.com/$githubOwner/$githubRepo',
                      style: TextStyle(color: theme.base.primary),
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

/// Compact key-value display for About section.
class _AboutItem extends StatelessComponent {
  final String label;
  final String value;

  const _AboutItem({required this.label, required this.value});

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 1),
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
