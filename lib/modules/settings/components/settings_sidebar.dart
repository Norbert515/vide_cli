import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/modules/settings/settings_category.dart';

/// Sidebar showing settings categories with left accent bar.
class SettingsSidebar extends StatelessComponent {
  final SettingsCategory selectedCategory;
  final int selectedIndex;
  final bool focused;
  final void Function(SettingsCategory category, int index) onCategorySelected;

  const SettingsSidebar({
    required this.selectedCategory,
    required this.selectedIndex,
    required this.focused,
    required this.onCategorySelected,
    super.key,
  });

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    final categories = SettingsCategory.values;

    return SizedBox(
      width: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 2),
          for (int i = 0; i < categories.length; i++)
            GestureDetector(
              onTap: () => onCategorySelected(categories[i], i),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 1, vertical: 0.5),
                decoration: BoxDecoration(
                  color: i == selectedIndex && focused
                      ? theme.base.primary.withOpacity(0.2)
                      : i == selectedIndex
                      ? theme.base.outline.withOpacity(0.1)
                      : null,
                ),
                child: Row(
                  children: [
                    // Left accent bar for selected item
                    Text(
                      i == selectedIndex ? '┃ ' : '  ',
                      style: TextStyle(
                        color: focused && i == selectedIndex
                            ? theme.base.primary
                            : theme.base.outline.withOpacity(
                                TextOpacity.separator,
                              ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        categories[i].label,
                        style: TextStyle(
                          color: i == selectedIndex
                              ? (focused
                                    ? theme.base.primary
                                    : theme.base.onSurface)
                              : theme.base.onSurface.withOpacity(
                                  TextOpacity.secondary,
                                ),
                          fontWeight: i == selectedIndex
                              ? FontWeight.bold
                              : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
