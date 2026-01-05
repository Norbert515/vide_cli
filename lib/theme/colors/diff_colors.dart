import 'package:nocterm/nocterm.dart';

/// Colors for diff rendering.
///
/// These colors are used when displaying code diffs, such as git diff output
/// or file edit previews.
class VideDiffColors {
  /// Background color for added lines.
  final Color addedBackground;

  /// Background color for removed lines.
  final Color removedBackground;

  /// Color for the '+' prefix on added lines.
  final Color addedPrefix;

  /// Color for the '-' prefix on removed lines.
  final Color removedPrefix;

  /// Color for context line prefixes (unchanged lines).
  final Color contextPrefix;

  /// Color for diff headers (file names, line numbers).
  final Color header;

  /// Creates a custom diff color set.
  const VideDiffColors({
    required this.addedBackground,
    required this.removedBackground,
    required this.addedPrefix,
    required this.removedPrefix,
    required this.contextPrefix,
    required this.header,
  });

  /// Dark theme diff colors.
  static const VideDiffColors dark = VideDiffColors(
    addedBackground: Color(0x0D3D0D),
    removedBackground: Color(0x3D0D0D),
    addedPrefix: Colors.green,
    removedPrefix: Colors.red,
    contextPrefix: Colors.grey,
    header: Colors.cyan,
  );

  /// Light theme diff colors.
  static const VideDiffColors light = VideDiffColors(
    addedBackground: Color(0xD4EDDA),
    removedBackground: Color(0xF8D7DA),
    addedPrefix: Color(0x228B22), // forest green
    removedPrefix: Color(0xDC143C), // crimson
    contextPrefix: Color(0x666666),
    header: Color(0x008B8B), // dark cyan
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VideDiffColors &&
        other.addedBackground == addedBackground &&
        other.removedBackground == removedBackground &&
        other.addedPrefix == addedPrefix &&
        other.removedPrefix == removedPrefix &&
        other.contextPrefix == contextPrefix &&
        other.header == header;
  }

  @override
  int get hashCode => Object.hash(
    addedBackground,
    removedBackground,
    addedPrefix,
    removedPrefix,
    contextPrefix,
    header,
  );
}
