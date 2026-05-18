import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/modules/setup/theme_selector.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_core/vide_core.dart';

/// Page for changing theme settings with live preview.
class ThemeSettingsPage extends StatefulComponent {
  const ThemeSettingsPage({super.key});

  static Future<void> push(BuildContext context) {
    return Navigator.of(context).push(
      PageRoute(
        builder: (context) => const ThemeSettingsPage(),
        settings: RouteSettings(),
      ),
    );
  }

  @override
  State<ThemeSettingsPage> createState() => _ThemeSettingsPageState();
}

class _ThemeSettingsPageState extends State<ThemeSettingsPage> {
  TuiThemeData? _previewTheme;

  @override
  Component build(BuildContext context) {
    // Get current theme setting
    final currentThemeId = context.watch(themeSettingProvider);

    Component content = _buildContent(context, currentThemeId);

    // Apply preview theme if set
    if (_previewTheme != null) {
      content = TuiTheme(
        data: _previewTheme!,
        child: VideTheme(
          data: VideThemeData.fromBrightness(_previewTheme!),
          child: content,
        ),
      );
    }

    return content;
  }

  Component _buildContent(BuildContext context, String? currentThemeId) {
    final theme = VideTheme.of(context);

    return Center(
      child: Container(
        decoration: BoxDecoration(
          border: BoxBorder.all(color: theme.base.outline),
        ),
        padding: EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Theme Settings',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.base.primary,
              ),
            ),
            SizedBox(height: 1),
            Text(
              'Preview changes in real-time',
              style: TextStyle(
                color: theme.base.onSurface.withOpacity(TextOpacity.secondary),
              ),
            ),
            SizedBox(height: 2),
            ThemeSelector(
              initialThemeId: currentThemeId,
              onThemeSelected: (themeId) {
                // Save the theme and update provider
                context.read(themeSettingProvider.notifier).state = themeId;

                // Also persist to config
                final configManager = context.read(videConfigManagerProvider);
                configManager.setTheme(themeId);

                // Navigate back
                Navigator.of(context).pop();
              },
              onPreviewTheme: (previewTheme) {
                setState(() {
                  _previewTheme = previewTheme;
                });
              },
              onCancel: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
