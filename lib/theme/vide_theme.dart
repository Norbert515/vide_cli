import 'package:nocterm/nocterm.dart';

import 'vide_theme_data.dart';

/// Provides a Vide theme to its descendants.
///
/// Wrap your app in a [VideTheme] to provide Vide-specific theme colors to
/// all descendant components. Components can then access the theme using
/// [VideTheme.of].
///
/// ## Auto-detection
///
/// Use [VideTheme.auto] to automatically select light or dark theme based on
/// the parent [TuiTheme]'s brightness (which [NoctermApp] auto-detects from
/// the terminal):
///
/// ```dart
/// NoctermApp(
///   child: VideTheme.auto(
///     child: MyApp(),
///   ),
/// )
/// ```
///
/// ## Explicit Theme
///
/// Use the default constructor for an explicit theme:
///
/// ```dart
/// VideTheme(
///   data: VideThemeData.dark(),
///   child: MyApp(),
/// )
/// ```
///
/// ## Accessing the Theme
///
/// ```dart
/// final theme = VideTheme.of(context);
/// final workingColor = theme.status.working;
/// ```
class VideTheme extends StatelessComponent {
  /// The theme data for this subtree.
  /// If null, the theme will be auto-detected from the parent [TuiTheme].
  final VideThemeData? _data;

  /// Whether to auto-detect the theme from the parent [TuiTheme].
  final bool _autoDetect;

  /// The child component.
  final Component child;

  /// Creates a Vide theme provider with an explicit theme.
  const VideTheme({super.key, required VideThemeData data, required this.child})
    : _data = data,
      _autoDetect = false;

  /// Creates a Vide theme provider that auto-detects light or dark theme
  /// based on the parent [TuiTheme]'s brightness.
  ///
  /// This requires a [TuiTheme] ancestor (typically provided by [NoctermApp]).
  /// If no [TuiTheme] ancestor exists, defaults to dark theme.
  const VideTheme.auto({super.key, required this.child})
    : _data = null,
      _autoDetect = true;

  /// Returns the [VideThemeData] from the closest [VideTheme] ancestor.
  ///
  /// If no [VideTheme] ancestor exists, returns [VideThemeData.dark] as
  /// the default theme.
  ///
  /// This method registers the calling component as a dependent of the
  /// [VideTheme], so the component will rebuild when the theme changes.
  ///
  /// Example:
  /// ```dart
  /// Component build(BuildContext context) {
  ///   final theme = VideTheme.of(context);
  ///   return Text(
  ///     'Working...',
  ///     style: TextStyle(color: theme.status.working),
  ///   );
  /// }
  /// ```
  static VideThemeData of(BuildContext context) {
    final theme = context
        .dependOnInheritedComponentOfExactType<_VideThemeInherited>();
    return theme?.data ?? VideThemeData.dark();
  }

  /// Returns the [VideThemeData] from the closest [VideTheme] ancestor
  /// without registering a dependency.
  ///
  /// This method does NOT register the calling component as a dependent,
  /// so the component will NOT rebuild when the theme changes. Use this
  /// for one-time reads where you don't want to rebuild on theme changes.
  ///
  /// Returns `null` if no [VideTheme] ancestor exists.
  static VideThemeData? maybeOf(BuildContext context) {
    final element = context
        .getElementForInheritedComponentOfExactType<_VideThemeInherited>();
    return (element?.component as _VideThemeInherited?)?.data;
  }

  @override
  Component build(BuildContext context) {
    VideThemeData effectiveData;

    if (_autoDetect) {
      // Read brightness from parent TuiTheme (provided by NoctermApp)
      final tuiTheme = TuiTheme.maybeOf(context);
      if (tuiTheme != null) {
        effectiveData = VideThemeData.fromBrightness(tuiTheme);
      } else {
        // No TuiTheme ancestor, default to dark
        effectiveData = VideThemeData.dark();
      }
    } else {
      effectiveData = _data!;
    }

    // Only wrap with TuiTheme if we're not auto-detecting
    // (if auto-detecting, TuiTheme is already provided by NoctermApp)
    if (_autoDetect) {
      return _VideThemeInherited(data: effectiveData, child: child);
    } else {
      // Wrap with TuiTheme so nocterm components can access the base theme
      return TuiTheme(
        data: effectiveData.base,
        child: _VideThemeInherited(data: effectiveData, child: child),
      );
    }
  }
}

/// Internal InheritedComponent for VideTheme.
class _VideThemeInherited extends InheritedComponent {
  final VideThemeData data;

  const _VideThemeInherited({required this.data, required super.child});

  @override
  bool updateShouldNotify(_VideThemeInherited oldComponent) {
    return data != oldComponent.data;
  }
}
