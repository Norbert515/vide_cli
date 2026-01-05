import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/theme/theme.dart';

/// A chat preview showing a realistic conversation with code and diff.
class ThemePreview extends StatelessComponent {
  const ThemePreview({super.key});

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preview',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.base.primary,
          ),
        ),
        SizedBox(height: 1),
        // User message
        Text(
          'You',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.base.secondary,
          ),
        ),
        Text(
          'Add dark mode to the app',
          style: TextStyle(color: theme.base.onSurface),
        ),
        SizedBox(height: 1),
        // Claude response with code
        Text(
          'Claude',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.base.primary,
          ),
        ),
        Text(
          "I'll update the theme config:",
          style: TextStyle(color: theme.base.onSurface),
        ),
        SizedBox(height: 1),
        // Code block
        _codeLine(theme, [
          _token('final', theme.syntax.keyword),
          _token(' ', theme.syntax.plain),
          _token('theme', theme.syntax.variable),
          _token(' = ', theme.syntax.plain),
          _token('ThemeData', theme.syntax.type),
          _token('(', theme.syntax.plain),
        ]),
        _codeLine(theme, [
          _token('  brightness', theme.syntax.variable),
          _token(': ', theme.syntax.plain),
          _token('Brightness', theme.syntax.type),
          _token('.', theme.syntax.plain),
          _token('dark', theme.syntax.variable),
          _token(',', theme.syntax.plain),
        ]),
        _codeLine(theme, [
          _token('  ', theme.syntax.plain),
          _token('// Dark mode enabled', theme.syntax.comment),
        ]),
        _codeLine(theme, [_token(');', theme.syntax.plain)]),
        SizedBox(height: 1),
        // Diff
        Container(
          color: theme.diff.removedBackground,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('- ', style: TextStyle(color: theme.diff.removedPrefix)),
              Text(
                'brightness: light',
                style: TextStyle(color: theme.base.onSurface),
              ),
            ],
          ),
        ),
        Container(
          color: theme.diff.addedBackground,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('+ ', style: TextStyle(color: theme.diff.addedPrefix)),
              Text(
                'brightness: dark',
                style: TextStyle(color: theme.base.onSurface),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Component _codeLine(VideThemeData theme, List<Component> tokens) {
    return Row(mainAxisSize: MainAxisSize.min, children: tokens);
  }

  Component _token(String text, Color color) {
    return Text(text, style: TextStyle(color: color));
  }
}

/// Available theme options with display names and descriptions
class ThemeOption {
  final String id;
  final String displayName;
  final String description;
  final TuiThemeData themeData;

  const ThemeOption({
    required this.id,
    required this.displayName,
    required this.description,
    required this.themeData,
  });

  static const List<ThemeOption> all = [
    ThemeOption(
      id: 'dark',
      displayName: 'Dark',
      description: 'Default dark theme',
      themeData: TuiThemeData.dark,
    ),
    ThemeOption(
      id: 'light',
      displayName: 'Light',
      description: 'Clean light theme',
      themeData: TuiThemeData.light,
    ),
    ThemeOption(
      id: 'nord',
      displayName: 'Nord',
      description: 'Arctic blue palette',
      themeData: TuiThemeData.nord,
    ),
    ThemeOption(
      id: 'dracula',
      displayName: 'Dracula',
      description: 'Vibrant purple theme',
      themeData: TuiThemeData.dracula,
    ),
    ThemeOption(
      id: 'catppuccinMocha',
      displayName: 'Catppuccin',
      description: 'Warm cozy palette',
      themeData: TuiThemeData.catppuccinMocha,
    ),
    ThemeOption(
      id: 'gruvboxDark',
      displayName: 'Gruvbox',
      description: 'Retro warm tones',
      themeData: TuiThemeData.gruvboxDark,
    ),
  ];

  /// Get a ThemeOption by its ID, returns null for 'auto' or unknown IDs
  static ThemeOption? byId(String? id) {
    if (id == null) return null;
    try {
      return all.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get TuiThemeData by theme ID
  static TuiThemeData? getThemeData(String? themeId) {
    return byId(themeId)?.themeData;
  }
}

/// A theme selection widget with live preview.
///
/// When the user navigates to a theme option, it's applied immediately
/// so they can see the preview. The [onThemeChanged] callback is called
/// with the theme ID (or null for auto-detect) and the selected theme data.
class ThemeSelector extends StatefulComponent {
  final String? initialThemeId;
  final void Function(String? themeId) onThemeSelected;
  final void Function(TuiThemeData previewTheme) onPreviewTheme;
  final VoidCallback? onCancel;

  const ThemeSelector({
    super.key,
    this.initialThemeId,
    required this.onThemeSelected,
    required this.onPreviewTheme,
    this.onCancel,
  });

  @override
  State<ThemeSelector> createState() => _ThemeSelectorState();
}

class _ThemeSelectorState extends State<ThemeSelector> {
  late int _selectedIndex;

  // We add 'auto' as the first option
  static const int _autoOptionIndex = 0;
  int get _totalOptions => ThemeOption.all.length + 1; // +1 for auto

  @override
  void initState() {
    super.initState();
    // Find initial selection
    if (component.initialThemeId == null) {
      _selectedIndex = _autoOptionIndex;
    } else {
      final themeIndex = ThemeOption.all.indexWhere(
        (t) => t.id == component.initialThemeId,
      );
      _selectedIndex = themeIndex >= 0 ? themeIndex + 1 : _autoOptionIndex;
    }
  }

  void _applyPreview() {
    if (_selectedIndex == _autoOptionIndex) {
      // For auto, use the detected theme (dark as fallback)
      component.onPreviewTheme(TuiThemeData.dark);
    } else {
      final option = ThemeOption.all[_selectedIndex - 1];
      component.onPreviewTheme(option.themeData);
    }
  }

  void _moveUp() {
    setState(() {
      _selectedIndex = (_selectedIndex - 1 + _totalOptions) % _totalOptions;
    });
    _applyPreview();
  }

  void _moveDown() {
    setState(() {
      _selectedIndex = (_selectedIndex + 1) % _totalOptions;
    });
    _applyPreview();
  }

  void _confirm() {
    final String? themeId;
    if (_selectedIndex == _autoOptionIndex) {
      themeId = null;
    } else {
      themeId = ThemeOption.all[_selectedIndex - 1].id;
    }
    component.onThemeSelected(themeId);
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    return KeyboardListener(
      autofocus: true,
      onKeyEvent: (key) {
        switch (key) {
          case LogicalKey.arrowUp:
          case LogicalKey.keyK:
            _moveUp();
            return true;
          case LogicalKey.arrowDown:
          case LogicalKey.keyJ:
            _moveDown();
            return true;
          case LogicalKey.enter:
            _confirm();
            return true;
          case LogicalKey.escape:
            if (component.onCancel != null) {
              component.onCancel!();
              return true;
            }
            return false;
          default:
            return false;
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Theme',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.base.primary,
                ),
              ),
              SizedBox(height: 1),
              // Auto option
              _buildOption(
                theme,
                index: _autoOptionIndex,
                displayName: 'Auto',
                description: 'Match terminal brightness',
              ),
              // Theme options
              for (int i = 0; i < ThemeOption.all.length; i++)
                _buildOption(
                  theme,
                  index: i + 1,
                  displayName: ThemeOption.all[i].displayName,
                  description: ThemeOption.all[i].description,
                ),
              SizedBox(height: 1),
              _buildFooter(theme),
            ],
          ),
          SizedBox(width: 4),
          const ThemePreview(),
        ],
      ),
    );
  }

  Component _buildOption(
    VideThemeData theme, {
    required int index,
    required String displayName,
    required String description,
  }) {
    final isSelected = _selectedIndex == index;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isSelected ? '>' : ' ',
          style: TextStyle(
            color: isSelected ? theme.base.primary : theme.base.outline,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(width: 1),
        Text(
          displayName.padRight(12),
          style: TextStyle(
            color: isSelected ? theme.base.onSurface : theme.base.outline,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          description,
          style: TextStyle(
            color: theme.base.onSurface.withOpacity(TextOpacity.secondary),
          ),
        ),
      ],
    );
  }

  Component _buildFooter(VideThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('[', style: TextStyle(color: theme.base.outline)),
        Text('↑↓', style: TextStyle(color: theme.base.warning)),
        Text('] Navigate  ', style: TextStyle(color: theme.base.outline)),
        Text('[', style: TextStyle(color: theme.base.outline)),
        Text('Enter', style: TextStyle(color: theme.base.success)),
        Text('] Select', style: TextStyle(color: theme.base.outline)),
        if (component.onCancel != null) ...[
          Text('  [', style: TextStyle(color: theme.base.outline)),
          Text('Esc', style: TextStyle(color: theme.base.error)),
          Text('] Cancel', style: TextStyle(color: theme.base.outline)),
        ],
      ],
    );
  }
}
