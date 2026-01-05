import 'package:nocterm/nocterm.dart';

/// Colors for syntax highlighting.
///
/// These colors are used for syntax highlighting in code blocks and
/// code-related UI elements.
class VideSyntaxColors {
  /// Color for language keywords (if, else, class, etc.).
  final Color keyword;

  /// Color for type names (String, int, MyClass, etc.).
  final Color type;

  /// Color for string literals.
  final Color string;

  /// Color for numeric literals.
  final Color number;

  /// Color for comments.
  final Color comment;

  /// Color for function names.
  final Color function;

  /// Color for variable names.
  final Color variable;

  /// Color for plain/unclassified text.
  final Color plain;

  /// Creates a custom syntax color set.
  const VideSyntaxColors({
    required this.keyword,
    required this.type,
    required this.string,
    required this.number,
    required this.comment,
    required this.function,
    required this.variable,
    required this.plain,
  });

  /// Dark theme syntax colors (VS Code Dark+ inspired).
  static const VideSyntaxColors dark = VideSyntaxColors(
    keyword: Color.fromRGB(86, 156, 214),
    type: Color.fromRGB(78, 201, 176),
    string: Color.fromRGB(206, 145, 120),
    number: Color.fromRGB(181, 206, 168),
    comment: Color.fromRGB(106, 153, 85),
    function: Color.fromRGB(220, 220, 170),
    variable: Color.fromRGB(156, 220, 254),
    plain: Colors.white,
  );

  /// Light theme syntax colors (VS Code Light inspired).
  static const VideSyntaxColors light = VideSyntaxColors(
    keyword: Color(0x0000FF),
    type: Color(0x267F99),
    string: Color(0xA31515),
    number: Color(0x098658),
    comment: Color(0x008000),
    function: Color(0x795E26),
    variable: Color(0x001080),
    plain: Colors.black,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VideSyntaxColors &&
        other.keyword == keyword &&
        other.type == type &&
        other.string == string &&
        other.number == number &&
        other.comment == comment &&
        other.function == function &&
        other.variable == variable &&
        other.plain == plain;
  }

  @override
  int get hashCode => Object.hash(
    keyword,
    type,
    string,
    number,
    comment,
    function,
    variable,
    plain,
  );
}
