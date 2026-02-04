import 'package:flutter/material.dart';

/// Design tokens for the Vide terminal-inspired design system.
///
/// Color palette: dark-first, neutral gray accent, Vercel/Linear inspired.
/// Typography: JetBrains Mono everywhere.
/// Spacing: 8pt grid.
/// Radius: sharp edges (4px) for content, softer for glass chrome.

// ---------------------------------------------------------------------------
// Colors
// ---------------------------------------------------------------------------

abstract final class VideColors {
  // Backgrounds
  static const background = Color(0xFF0A0A0A);
  static const surface = Color(0xFF171717);
  static const surfaceElevated = Color(0xFF1E1E1E);

  // Glass
  static const glassTint = Color(0x1FFFFFFF); // ~12% white
  static const glassBorder = Color(0x1FFFFFFF); // ~12% white

  // Text
  static const textPrimary = Color(0xFFEDEDED);
  static const textSecondary = Color(0xFF888888);
  static const textTertiary = Color(0xFF555555);

  // Accent — white/light gray (Vercel style: the "accent" is just brightness)
  static const accent = Color(0xFFEDEDED);
  static const accentDim = Color(0xFFA0A0A0);
  static const accentSubtle = Color(0x1FEDEDED); // ~12% accent

  // Semantic
  static const success = Color(0xFF3FB950);
  static const error = Color(0xFFF85149);
  static const warning = Color(0xFFD29922);
  static const info = Color(0xFF58A6FF);

  // Semantic containers (low-opacity backgrounds)
  static const successContainer = Color(0x1A3FB950);
  static const errorContainer = Color(0x1AF85149);
  static const warningContainer = Color(0x1AD29922);
  static const infoContainer = Color(0x1A58A6FF);

  // Syntax highlighting
  static const syntaxKeyword = Color(0xFFC792EA);
  static const syntaxString = Color(0xFFC3E88D);
  static const syntaxFunction = Color(0xFF82AAFF);
  static const syntaxComment = Color(0xFF555555);
  static const syntaxConstant = Color(0xFFF78C6C);

  // Light theme overrides
  static const lightBackground = Color(0xFFF5F7FA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceElevated = Color(0xFFEDF0F5);
  static const lightTextPrimary = Color(0xFF1A1F2E);
  static const lightTextSecondary = Color(0xFF5A6478);
  static const lightTextTertiary = Color(0xFF8F9BB0);
  static const lightAccent = Color(0xFF171717);
  static const lightAccentDim = Color(0xFF555555);
  static const lightAccentSubtle = Color(0x1F171717);
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
