/// Semantic opacity levels for text rendering.
///
/// These constants provide consistent visual hierarchy across the UI
/// by using alpha/opacity instead of hardcoded grey colors.
class TextOpacity {
  /// Primary text - full opacity (1.0)
  /// Use for: Main content, active items, focused elements
  static const double primary = 1.0;

  /// Secondary text - 60% opacity (0.6)
  /// Use for: Metadata, timestamps, keyboard shortcuts, helper text
  static const double secondary = 0.6;

  /// Tertiary text - 40% opacity (0.4)
  /// Use for: Hints, placeholders, subtle helpers, unfocused states
  static const double tertiary = 0.4;

  /// Disabled text - 30% opacity (0.3)
  /// Use for: Disabled states, "not started" status, inactive elements
  static const double disabled = 0.3;

  /// Separator text - 20% opacity (0.2)
  /// Use for: Dividers, very subtle separators
  static const double separator = 0.2;
}
