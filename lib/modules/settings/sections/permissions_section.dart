import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/modules/settings/components/section_header.dart';

/// Permissions settings content (mocked).
class PermissionsSection extends StatelessComponent {
  final bool focused;
  final VoidCallback onExit;

  const PermissionsSection({required this.focused, required this.onExit, super.key});

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    return Focusable(
      focused: focused,
      onKeyEvent: (event) {
        if (event.logicalKey == LogicalKey.arrowLeft || event.logicalKey == LogicalKey.escape) {
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
            SectionHeader(title: 'Permissions'),
            SizedBox(height: 1),
            Text(
              'Configure tool access permissions',
              style: TextStyle(color: theme.base.onSurface.withOpacity(TextOpacity.secondary)),
            ),
            SizedBox(height: 3),

            // Mocked content
            Container(
              padding: EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: theme.base.outline.withOpacity(0.05),
                border: BoxBorder.all(
                  color: theme.base.outline.withOpacity(TextOpacity.separator),
                  style: BoxBorderStyle.rounded,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Coming Soon',
                    style: TextStyle(color: theme.base.primary, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Permission management will allow you to:',
                    style: TextStyle(color: theme.base.onSurface.withOpacity(TextOpacity.secondary)),
                  ),
                  SizedBox(height: 1),
                  Text(
                    '• View and edit allow/deny lists',
                    style: TextStyle(color: theme.base.onSurface.withOpacity(TextOpacity.secondary)),
                  ),
                  Text(
                    '• Configure file path permissions',
                    style: TextStyle(color: theme.base.onSurface.withOpacity(TextOpacity.secondary)),
                  ),
                  Text(
                    '• Manage bash command permissions',
                    style: TextStyle(color: theme.base.onSurface.withOpacity(TextOpacity.secondary)),
                  ),
                  Text(
                    '• Set up web domain restrictions',
                    style: TextStyle(color: theme.base.onSurface.withOpacity(TextOpacity.secondary)),
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
