import 'package:nocterm/nocterm.dart';

import 'colors/diff_colors.dart';
import 'colors/status_colors.dart';
import 'colors/syntax_colors.dart';

/// Theme data for Vide CLI.
///
/// Combines the base [TuiThemeData] with Vide-specific color sets for
/// agent status, diff rendering, and syntax highlighting.
///
/// Use the factory constructors [VideThemeData.dark] and [VideThemeData.light]
/// for built-in themes.
class VideThemeData {
  /// The base theme from nocterm.
  final TuiThemeData base;

  /// Colors for agent and task status.
  final VideStatusColors status;

  /// Colors for diff rendering.
  final VideDiffColors diff;

  /// Colors for syntax highlighting.
  final VideSyntaxColors syntax;

  /// Creates a custom Vide theme.
  const VideThemeData({
    required this.base,
    required this.status,
    required this.diff,
    required this.syntax,
  });

  /// Dark theme for Vide CLI.
  factory VideThemeData.dark() => const VideThemeData(
    base: TuiThemeData.dark,
    status: VideStatusColors.dark,
    diff: VideDiffColors.dark,
    syntax: VideSyntaxColors.dark,
  );

  /// Light theme for Vide CLI.
  factory VideThemeData.light() => const VideThemeData(
    base: TuiThemeData.light,
    status: VideStatusColors.light,
    diff: VideDiffColors.light,
    syntax: VideSyntaxColors.light,
  );

  /// Creates a Vide theme based on the brightness of a [TuiThemeData].
  ///
  /// This is useful for syncing vide-specific colors with the base nocterm
  /// theme's brightness (light or dark).
  factory VideThemeData.fromBrightness(TuiThemeData tuiTheme) {
    if (tuiTheme.brightness == Brightness.light) {
      return VideThemeData(
        base: tuiTheme,
        status: VideStatusColors.light,
        diff: VideDiffColors.light,
        syntax: VideSyntaxColors.light,
      );
    } else {
      return VideThemeData(
        base: tuiTheme,
        status: VideStatusColors.dark,
        diff: VideDiffColors.dark,
        syntax: VideSyntaxColors.dark,
      );
    }
  }

  /// Creates a copy of this theme with the given fields replaced.
  VideThemeData copyWith({
    TuiThemeData? base,
    VideStatusColors? status,
    VideDiffColors? diff,
    VideSyntaxColors? syntax,
  }) {
    return VideThemeData(
      base: base ?? this.base,
      status: status ?? this.status,
      diff: diff ?? this.diff,
      syntax: syntax ?? this.syntax,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VideThemeData &&
        other.base == base &&
        other.status == status &&
        other.diff == diff &&
        other.syntax == syntax;
  }

  @override
  int get hashCode => Object.hash(base, status, diff, syntax);

  @override
  String toString() => 'VideThemeData(brightness: ${base.brightness})';
}
