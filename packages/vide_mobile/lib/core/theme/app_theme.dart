import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';
import 'vide_colors.dart';

class AppTheme {
  static ThemeData darkTheme() {
    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: VideColors.accent,
      onPrimary: VideColors.background,
      primaryContainer: VideColors.accentSubtle,
      onPrimaryContainer: VideColors.accent,
      secondary: VideColors.textSecondary,
      onSecondary: VideColors.background,
      secondaryContainer: VideColors.surfaceElevated,
      onSecondaryContainer: VideColors.textPrimary,
      tertiary: VideColors.info,
      onTertiary: VideColors.background,
      tertiaryContainer: VideColors.infoContainer,
      onTertiaryContainer: VideColors.info,
      error: VideColors.error,
      onError: VideColors.background,
      errorContainer: VideColors.errorContainer,
      onErrorContainer: VideColors.error,
      surface: VideColors.surface,
      onSurface: VideColors.textPrimary,
      onSurfaceVariant: VideColors.textSecondary,
      outline: VideColors.textTertiary,
      outlineVariant: Color(0xFF2D2D2D),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: VideColors.textPrimary,
      onInverseSurface: VideColors.background,
      surfaceContainerHighest: VideColors.surfaceElevated,
      surfaceContainerHigh: Color(0xFF1A1A1A),
      surfaceContainerLow: Color(0xFF121212),
      surfaceContainerLowest: VideColors.background,
    );

    final textTheme = GoogleFonts.jetBrainsMonoTextTheme(
      ThemeData.dark().textTheme,
    ).apply(
      bodyColor: VideColors.textPrimary,
      displayColor: VideColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: VideColors.background,
      textTheme: textTheme,
      extensions: const [VideThemeColors.dark],
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: VideColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.jetBrainsMono(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: VideColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: VideColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: VideRadius.smAll,
          side: BorderSide(
            color: Color(0xFF2D2D2D),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: VideColors.surface,
        border: OutlineInputBorder(
          borderRadius: VideRadius.smAll,
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: VideRadius.smAll,
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: VideRadius.smAll,
          borderSide: BorderSide(color: VideColors.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: VideRadius.smAll,
          borderSide: BorderSide(color: VideColors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: VideSpacing.md,
          vertical: 14,
        ),
        hintStyle: TextStyle(color: VideColors.textTertiary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: VideColors.accent,
          foregroundColor: VideColors.background,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: VideRadius.mdAll,
          ),
          textStyle: GoogleFonts.jetBrainsMono(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: VideColors.accent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: VideRadius.mdAll,
          ),
          side: BorderSide(color: VideColors.accent.withValues(alpha: 0.4)),
          textStyle: GoogleFonts.jetBrainsMono(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: VideColors.accent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: VideRadius.mdAll,
          ),
          textStyle: GoogleFonts.jetBrainsMono(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: VideColors.accent,
        foregroundColor: VideColors.background,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: VideRadius.mdAll,
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: VideRadius.smAll,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: VideSpacing.md,
          vertical: VideSpacing.xs,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: VideColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: VideRadius.smAll,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: VideColors.textTertiary.withValues(alpha: 0.2),
        thickness: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(VideRadius.glass),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: VideColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: VideRadius.lgAll,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return VideColors.accentSubtle;
            }
            return VideColors.surface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return VideColors.accent;
            }
            return VideColors.textSecondary;
          }),
          side: WidgetStateProperty.all(
            BorderSide(color: VideColors.textTertiary.withValues(alpha: 0.3)),
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: VideColors.accent,
        linearTrackColor: VideColors.accent.withValues(alpha: 0.1),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return VideColors.accent;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(VideColors.background),
        side: BorderSide(color: VideColors.textTertiary),
      ),
    );
  }

  static ThemeData lightTheme() {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: VideColors.lightAccent,
      onPrimary: Colors.white,
      primaryContainer: VideColors.lightAccentSubtle,
      onPrimaryContainer: VideColors.lightAccentDim,
      secondary: VideColors.lightTextSecondary,
      onSecondary: Colors.white,
      secondaryContainer: VideColors.lightSurfaceElevated,
      onSecondaryContainer: VideColors.lightTextPrimary,
      tertiary: VideColors.info,
      onTertiary: Colors.white,
      tertiaryContainer: VideColors.infoContainer,
      onTertiaryContainer: VideColors.info,
      error: VideColors.error,
      onError: Colors.white,
      errorContainer: VideColors.errorContainer,
      onErrorContainer: VideColors.error,
      surface: VideColors.lightSurface,
      onSurface: VideColors.lightTextPrimary,
      onSurfaceVariant: VideColors.lightTextSecondary,
      outline: VideColors.lightTextTertiary,
      outlineVariant: Color(0xFFDDE1E8),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: VideColors.lightTextPrimary,
      onInverseSurface: VideColors.lightSurface,
      surfaceContainerHighest: VideColors.lightSurfaceElevated,
      surfaceContainerHigh: Color(0xFFE8ECF2),
      surfaceContainerLow: Color(0xFFF8F9FC),
      surfaceContainerLowest: Colors.white,
    );

    final textTheme = GoogleFonts.jetBrainsMonoTextTheme(
      ThemeData.light().textTheme,
    ).apply(
      bodyColor: VideColors.lightTextPrimary,
      displayColor: VideColors.lightTextPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: VideColors.lightBackground,
      textTheme: textTheme,
      extensions: const [VideThemeColors.light],
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: VideColors.lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.jetBrainsMono(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: VideColors.lightTextPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: VideColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: VideRadius.smAll,
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: VideColors.lightSurface,
        border: OutlineInputBorder(
          borderRadius: VideRadius.smAll,
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: VideRadius.smAll,
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: VideRadius.smAll,
          borderSide: BorderSide(color: VideColors.lightAccent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: VideRadius.smAll,
          borderSide: BorderSide(color: VideColors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: VideSpacing.md,
          vertical: 14,
        ),
        hintStyle: TextStyle(color: VideColors.lightTextTertiary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: VideColors.lightAccent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: VideRadius.mdAll,
          ),
          textStyle: GoogleFonts.jetBrainsMono(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: VideColors.lightAccentDim,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: VideRadius.mdAll,
          ),
          side: BorderSide(color: VideColors.lightAccent.withValues(alpha: 0.4)),
          textStyle: GoogleFonts.jetBrainsMono(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: VideColors.lightAccentDim,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: VideRadius.mdAll,
          ),
          textStyle: GoogleFonts.jetBrainsMono(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: VideColors.lightAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: VideRadius.mdAll,
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: VideRadius.smAll,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: VideSpacing.md,
          vertical: VideSpacing.xs,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: VideRadius.smAll,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: VideColors.lightTextTertiary.withValues(alpha: 0.2),
        thickness: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(VideRadius.glass),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: VideColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: VideRadius.lgAll,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return VideColors.lightAccentSubtle;
            }
            return VideColors.lightSurface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return VideColors.lightAccentDim;
            }
            return VideColors.lightTextSecondary;
          }),
          side: WidgetStateProperty.all(
            BorderSide(color: VideColors.lightTextTertiary.withValues(alpha: 0.3)),
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: VideColors.lightAccent,
        linearTrackColor: VideColors.lightAccent.withValues(alpha: 0.1),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return VideColors.lightAccent;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: BorderSide(color: VideColors.lightTextTertiary),
      ),
    );
  }
}
