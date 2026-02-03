import 'package:flutter/material.dart';
import 'tokens.dart' as tokens;

/// Theme extension providing semantic colors beyond Material's ColorScheme.
///
/// Access via: `Theme.of(context).extension<VideThemeColors>()!`
class VideThemeColors extends ThemeExtension<VideThemeColors> {
  final Color success;
  final Color error;
  final Color warning;
  final Color info;
  final Color successContainer;
  final Color errorContainer;
  final Color warningContainer;
  final Color infoContainer;
  final Color textSecondary;
  final Color textTertiary;
  final Color glassTint;
  final Color glassBorder;
  final Color accent;
  final Color accentSubtle;

  const VideThemeColors({
    required this.success,
    required this.error,
    required this.warning,
    required this.info,
    required this.successContainer,
    required this.errorContainer,
    required this.warningContainer,
    required this.infoContainer,
    required this.textSecondary,
    required this.textTertiary,
    required this.glassTint,
    required this.glassBorder,
    required this.accent,
    required this.accentSubtle,
  });

  static const dark = VideThemeColors(
    success: tokens.VideColors.success,
    error: tokens.VideColors.error,
    warning: tokens.VideColors.warning,
    info: tokens.VideColors.info,
    successContainer: tokens.VideColors.successContainer,
    errorContainer: tokens.VideColors.errorContainer,
    warningContainer: tokens.VideColors.warningContainer,
    infoContainer: tokens.VideColors.infoContainer,
    textSecondary: tokens.VideColors.textSecondary,
    textTertiary: tokens.VideColors.textTertiary,
    glassTint: tokens.VideColors.glassTint,
    glassBorder: tokens.VideColors.glassBorder,
    accent: tokens.VideColors.accent,
    accentSubtle: tokens.VideColors.accentSubtle,
  );

  static const light = VideThemeColors(
    success: tokens.VideColors.success,
    error: tokens.VideColors.error,
    warning: tokens.VideColors.warning,
    info: tokens.VideColors.info,
    successContainer: tokens.VideColors.successContainer,
    errorContainer: tokens.VideColors.errorContainer,
    warningContainer: tokens.VideColors.warningContainer,
    infoContainer: tokens.VideColors.infoContainer,
    textSecondary: tokens.VideColors.lightTextSecondary,
    textTertiary: tokens.VideColors.lightTextTertiary,
    glassTint: tokens.VideColors.lightGlassTint,
    glassBorder: tokens.VideColors.lightGlassBorder,
    accent: tokens.VideColors.accent,
    accentSubtle: tokens.VideColors.accentSubtle,
  );

  @override
  VideThemeColors copyWith({
    Color? success,
    Color? error,
    Color? warning,
    Color? info,
    Color? successContainer,
    Color? errorContainer,
    Color? warningContainer,
    Color? infoContainer,
    Color? textSecondary,
    Color? textTertiary,
    Color? glassTint,
    Color? glassBorder,
    Color? accent,
    Color? accentSubtle,
  }) {
    return VideThemeColors(
      success: success ?? this.success,
      error: error ?? this.error,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      successContainer: successContainer ?? this.successContainer,
      errorContainer: errorContainer ?? this.errorContainer,
      warningContainer: warningContainer ?? this.warningContainer,
      infoContainer: infoContainer ?? this.infoContainer,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      glassTint: glassTint ?? this.glassTint,
      glassBorder: glassBorder ?? this.glassBorder,
      accent: accent ?? this.accent,
      accentSubtle: accentSubtle ?? this.accentSubtle,
    );
  }

  @override
  VideThemeColors lerp(VideThemeColors? other, double t) {
    if (other is! VideThemeColors) return this;
    return VideThemeColors(
      success: Color.lerp(success, other.success, t)!,
      error: Color.lerp(error, other.error, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      errorContainer: Color.lerp(errorContainer, other.errorContainer, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      glassTint: Color.lerp(glassTint, other.glassTint, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSubtle: Color.lerp(accentSubtle, other.accentSubtle, t)!,
    );
  }
}
