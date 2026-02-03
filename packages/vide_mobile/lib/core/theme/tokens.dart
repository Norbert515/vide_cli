import 'package:flutter/material.dart';

/// Design tokens for the Vide terminal-inspired design system.
///
/// Color palette: dark-first, cyan accent, Linear/Geist inspired.
/// Typography: JetBrains Mono everywhere.
/// Spacing: 8pt grid.
/// Radius: sharp edges (4px) for content, softer for glass chrome.

// ---------------------------------------------------------------------------
// Colors
// ---------------------------------------------------------------------------

abstract final class VideColors {
  // Backgrounds
  static const background = Color(0xFF0A0E14);
  static const surface = Color(0xFF151A23);
  static const surfaceElevated = Color(0xFF1C2230);

  // Glass
  static const glassTint = Color(0x1FB4BED2); // ~12% neutral cool gray
  static const glassBorder = Color(0x1FFFFFFF); // ~12% white

  // Text
  static const textPrimary = Color(0xFFE5E9F0);
  static const textSecondary = Color(0xFF7B8494);
  static const textTertiary = Color(0xFF4A5264);

  // Accent
  static const accent = Color(0xFF00D9FF);
  static const accentDim = Color(0xFF0097A7);
  static const accentSubtle = Color(0x1F00D9FF); // ~12% accent

  // Semantic
  static const success = Color(0xFF7FD962);
  static const error = Color(0xFFFF6B6B);
  static const warning = Color(0xFFFFAB40);
  static const info = Color(0xFF448AFF);

  // Semantic containers (low-opacity backgrounds)
  static const successContainer = Color(0x1A7FD962); // ~10%
  static const errorContainer = Color(0x1AFF6B6B);
  static const warningContainer = Color(0x1AFFAB40);
  static const infoContainer = Color(0x1A448AFF);

  // Syntax highlighting
  static const syntaxKeyword = Color(0xFFC792EA);
  static const syntaxString = Color(0xFFC3E88D);
  static const syntaxFunction = Color(0xFF82AAFF);
  static const syntaxComment = Color(0xFF676E95);
  static const syntaxConstant = Color(0xFFF78C6C);

  // Light theme overrides
  static const lightBackground = Color(0xFFF5F7FA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceElevated = Color(0xFFEDF0F5);
  static const lightTextPrimary = Color(0xFF1A1F2E);
  static const lightTextSecondary = Color(0xFF5A6478);
  static const lightTextTertiary = Color(0xFF8F9BB0);
  static const lightGlassTint = Color(0x33FFFFFF);
  static const lightGlassBorder = Color(0x19000000);
}

// ---------------------------------------------------------------------------
// Spacing (8pt grid)
// ---------------------------------------------------------------------------

abstract final class VideSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

// ---------------------------------------------------------------------------
// Border Radius
// ---------------------------------------------------------------------------

abstract final class VideRadius {
  static const double sm = 4; // Content: cards, blocks, inputs
  static const double md = 8; // Buttons, chips
  static const double lg = 12; // Larger containers
  static const double glass = 20; // Glass overlays, bottom sheets
  static const double pill = 999; // Fully rounded

  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
  static BorderRadius get glassAll => BorderRadius.circular(glass);
}

// ---------------------------------------------------------------------------
// Animation Durations
// ---------------------------------------------------------------------------

abstract final class VideDurations {
  static const instant = Duration(milliseconds: 100);
  static const fast = Duration(milliseconds: 200);
  static const normal = Duration(milliseconds: 300);
  static const slow = Duration(milliseconds: 500);
  static const cursorBlink = Duration(milliseconds: 530);
  static const statusPulse = Duration(milliseconds: 1500);
}
