import 'package:nocterm/nocterm.dart';
import 'package:highlighting/highlighting.dart';
import 'package:highlighting/languages/dart.dart';
import 'package:highlighting/languages/javascript.dart';
import 'package:highlighting/languages/typescript.dart';
import 'package:highlighting/languages/python.dart';
import 'package:highlighting/languages/java.dart';
import 'package:highlighting/languages/go.dart';
import 'package:highlighting/languages/rust.dart';
import 'package:highlighting/languages/json.dart';
import 'package:highlighting/languages/yaml.dart';
import 'package:highlighting/languages/markdown.dart';
import 'package:highlighting/languages/bash.dart';
import 'package:highlighting/languages/sql.dart';
import 'package:nocterm/src/painting/text_span.dart';
import 'package:vide_cli/theme/colors/syntax_colors.dart';

class SyntaxHighlighter {
  // Language mapping from file extensions
  static final Map<String, String> _languageMap = {
    '.dart': 'dart',
    '.js': 'javascript',
    '.ts': 'typescript',
    '.tsx': 'typescript',
    '.py': 'python',
    '.java': 'java',
    '.go': 'go',
    '.rs': 'rust',
    '.json': 'json',
    '.yaml': 'yaml',
    '.yml': 'yaml',
    '.md': 'markdown',
    '.sh': 'bash',
    '.sql': 'sql',
  };

  /// Detect language from file path
  static String? detectLanguage(String filePath) {
    final lastIndexOfDot = filePath.lastIndexOf('.');
    if (lastIndexOfDot == -1) {
      return null;
    }
    // Include the dot in the extension to match map keys (e.g., ".dart" not "dart")
    final extension = filePath.substring(lastIndexOfDot);
    return _languageMap[extension.toLowerCase()];
  }

  /// Highlight code and return a TextSpan
  ///
  /// [syntaxColors] provides theme-aware colors for syntax highlighting.
  static TextSpan highlightCode(
    String code,
    String language, {
    Color? backgroundColor,
    required VideSyntaxColors syntaxColors,
  }) {
    try {
      // Register common languages
      _registerLanguages();

      // Parse the code
      final result = highlight.parse(code, languageId: language);

      // Convert to TextSpan
      return _convertNodesToTextSpan(
        result.rootNode.children,
        backgroundColor: backgroundColor,
        syntaxColors: syntaxColors,
      );
    } catch (e) {
      // Fallback to plain text if highlighting fails
      return TextSpan(
        text: code,
        style: TextStyle(
          color: syntaxColors.plain,
          backgroundColor: backgroundColor,
        ),
      );
    }
  }

  static bool _languagesRegistered = false;

  /// Register languages with the highlighting package
  static void _registerLanguages() {
    if (_languagesRegistered) return;

    // Register all supported languages
    highlight.registerLanguage(dart);
    highlight.registerLanguage(javascript);
    highlight.registerLanguage(typescript);
    highlight.registerLanguage(python);
    highlight.registerLanguage(java);
    highlight.registerLanguage(go);
    highlight.registerLanguage(rust);
    highlight.registerLanguage(json);
    highlight.registerLanguage(yaml);
    highlight.registerLanguage(markdown);
    highlight.registerLanguage(bash);
    highlight.registerLanguage(sql);

    _languagesRegistered = true;
  }

  /// Convert highlight.js nodes to nocterm TextSpan
  ///
  /// [parentClassName] is passed down from parent nodes so that child nodes
  /// can inherit the classification when their own className is null or "none".
  static TextSpan _convertNodesToTextSpan(
    List<Node> nodes, {
    Color? backgroundColor,
    required VideSyntaxColors syntaxColors,
    String? parentClassName,
  }) {
    if (nodes.isEmpty) {
      return TextSpan(
        text: '',
        style: TextStyle(backgroundColor: backgroundColor),
      );
    }

    final children = <TextSpan>[];

    for (final node in nodes) {
      // Determine the effective className: use node's className if valid,
      // otherwise fall back to parentClassName
      final nodeClassName = node.className;
      final effectiveClassName =
          (nodeClassName != null && nodeClassName != 'none')
          ? nodeClassName
          : parentClassName;

      if (node.value != null && node.value!.isNotEmpty) {
        // Leaf node with text content
        final color = effectiveClassName != null
            ? _getColorForClass(effectiveClassName, syntaxColors)
            : syntaxColors.plain;

        children.add(
          TextSpan(
            text: node.value,
            style: TextStyle(color: color, backgroundColor: backgroundColor),
          ),
        );
      }

      if (node.children.isNotEmpty) {
        // Node with children - recursively process them, passing down the className
        final childrenSpans = _convertNodesToTextSpan(
          node.children,
          backgroundColor: backgroundColor,
          syntaxColors: syntaxColors,
          parentClassName: effectiveClassName,
        );

        // If childrenSpans has children, add them all
        if (childrenSpans.children != null) {
          children.addAll(childrenSpans.children!.cast<TextSpan>());
        }
      }
    }

    if (children.isEmpty) {
      return TextSpan(
        text: '',
        style: TextStyle(backgroundColor: backgroundColor),
      );
    }

    return TextSpan(
      children: children,
      style: TextStyle(backgroundColor: backgroundColor),
    );
  }

  /// Get color for a given class name using theme-aware syntax colors.
  static Color _getColorForClass(
    String className,
    VideSyntaxColors syntaxColors,
  ) {
    // Map highlight.js class names to theme syntax colors
    if (className.contains('keyword') ||
        className.contains('built_in') ||
        className.contains('tag')) {
      return syntaxColors.keyword;
    }
    if (className.contains('type') ||
        className.contains('class') ||
        className.contains('name')) {
      return syntaxColors.type;
    }
    if (className.contains('string')) {
      return syntaxColors.string;
    }
    if (className.contains('number') || className.contains('literal')) {
      return syntaxColors.number;
    }
    if (className.contains('comment')) {
      return syntaxColors.comment;
    }
    if (className.contains('function') || className.contains('title')) {
      return syntaxColors.function;
    }
    if (className.contains('variable') ||
        className.contains('attr') ||
        className.contains('property')) {
      return syntaxColors.variable;
    }

    // Default to plain text color
    return syntaxColors.plain;
  }
}
