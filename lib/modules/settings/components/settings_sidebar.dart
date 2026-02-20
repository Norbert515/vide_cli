import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/modules/settings/settings_category.dart';

/// Sidebar with box border and diamond marker for selected category.
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
      width: 24,
      child: Container(
        decoration: BoxDecoration(
          border: BoxBorder.all(
            color: theme.base.outlineVariant,
            style: BoxBorderStyle.rounded,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < categories.length; i++) ...[
                GestureDetector(
                  onTap: () => onCategorySelected(categories[i], i),
                  child: Container(
                    padding: EdgeInsets.only(left: 1, right: 1),
                    decoration: BoxDecoration(
                      color: i == selectedIndex && focused
                          ? theme.base.primary.withOpacity(0.25)
                          : i == selectedIndex
                          ? theme.base.outlineVariant.withOpacity(0.4)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Text(
                          i == selectedIndex ? '\u25c6 ' : '  ',
                          style: TextStyle(
                            color: i == selectedIndex && focused
                                ? theme.base.primary
                                : theme.base.outline.withOpacity(
                                    TextOpacity.secondary,
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
                // Spacing between items (except after last)
                if (i < categories.length - 1) SizedBox(height: 1),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
