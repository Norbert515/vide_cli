import 'dart:ui';

import 'package:flutter/material.dart';

import 'vide_colors.dart';

/// A translucent glass surface using BackdropFilter.
///
/// Used for navigation chrome: app bars, bottom sheets, modals, floating
/// overlays. Never use for content areas (messages, code, inputs).
class GlassSurface extends StatelessWidget {
  final double blur;
  final double? tintOpacity;
  final BorderRadius borderRadius;
  final double? borderOpacity;
  final Widget child;

  const GlassSurface({
    super.key,
    this.blur = 10,
    this.tintOpacity,
    this.borderRadius = BorderRadius.zero,
    this.borderOpacity,
    required this.child,
  });

  /// Light glass for app bars and subtle overlays.
  const GlassSurface.light({
    super.key,
    this.borderRadius = BorderRadius.zero,
    required this.child,
  })  : blur = 10,
        tintOpacity = 0.12,
        borderOpacity = 0.12;

  /// Medium glass for bottom sheets and modals.
  const GlassSurface.medium({
    super.key,
    this.borderRadius = BorderRadius.zero,
    required this.child,
  })  : blur = 14,
        tintOpacity = 0.15,
        borderOpacity = 0.15;

  /// Heavy glass for permission dialogs and important modals.
  const GlassSurface.heavy({
    super.key,
    this.borderRadius = BorderRadius.zero,
    required this.child,
  })  : blur = 14,
        tintOpacity = 0.18,
        borderOpacity = 0.15;

  @override
  Widget build(BuildContext context) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;
    final effectiveTintOpacity = tintOpacity ?? 0.12;
    final effectiveBorderOpacity = borderOpacity ?? 0.12;

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: videColors.glassTint.withValues(alpha: effectiveTintOpacity),
            borderRadius: borderRadius,
            border: Border.all(
              color: videColors.glassBorder.withValues(alpha: effectiveBorderOpacity),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
