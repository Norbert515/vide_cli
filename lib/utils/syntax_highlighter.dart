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

class SyntaxHighlighter {
  // VS Code Dark+ inspired color scheme for terminal
  static final Map<String, Color> _colorScheme = {
    'keyword': Color.fromRGB(86, 156, 214), // blue
    'built_in': Color.fromRGB(86, 156, 214), // blue
    'type': Color.fromRGB(78, 201, 176), // cyan
    'class': Color.fromRGB(78, 201, 176), // cyan
    'string': Color.fromRGB(206, 145, 120), // orange
    'number': Color.fromRGB(181, 206, 168), // light green
    'literal': Color.fromRGB(181, 206, 168), // light green
    'comment': Color.fromRGB(106, 153, 85), // green
    'function': Color.fromRGB(220, 220, 170), // yellow
    'title': Color.fromRGB(220, 220, 170), // yellow
    'params': Colors.white,
    'attr': Color.fromRGB(156, 220, 254), // light blue
    'variable': Color.fromRGB(156, 220, 254), // light blue
    'property': Color.fromRGB(156, 220, 254), // light blue
    'tag': Color.fromRGB(86, 156, 214), // blue
    'name': Color.fromRGB(78, 201, 176), // cyan
    'operator': Colors.white,
    'punctuation': Colors.white,
  };

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
    final extension = filePath.substring(lastIndexOfDot + 1);
    return _languageMap[extension.toLowerCase()];
  }

  /// Highlight code and return a TextSpan
  static TextSpan highlightCode(String code, String language, {Color? backgroundColor}) {
    try {
      // Register common languages
      _registerLanguages();

      // Parse the code
      final result = highlight.parse(code, languageId: language);

      // Convert to TextSpan
      return _convertNodesToTextSpan(result.rootNode.children, backgroundColor: backgroundColor);
    } catch (e) {
      // Fallback to plain text if highlighting fails
      return TextSpan(
        text: code,
        style: TextStyle(color: Colors.white, backgroundColor: backgroundColor),
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
  static TextSpan _convertNodesToTextSpan(List<Node> nodes, {Color? backgroundColor}) {
    if (nodes.isEmpty) {
      return TextSpan(
        text: '',
        style: TextStyle(backgroundColor: backgroundColor),
      );
    }

    final children = <TextSpan>[];

    for (final node in nodes) {
      if (node.value != null && node.value!.isNotEmpty) {
        // Leaf node with text content
        final className = node.className;
        final color = className != null ? _getColorForClass(className) : Colors.white;

        children.add(
          TextSpan(
            text: node.value,
            style: TextStyle(color: color, backgroundColor: backgroundColor),
          ),
        );
      }

      if (node.children.isNotEmpty) {
        // Node with children - recursively process them
        final childrenSpans = _convertNodesToTextSpan(node.children, backgroundColor: backgroundColor);

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

  /// Get color for a given class name
  static Color _getColorForClass(String className) {
    // Try exact match first
    if (_colorScheme.containsKey(className)) {
      return _colorScheme[className]!;
    }

    // Try common prefixes/substrings
    for (final key in _colorScheme.keys) {
      if (className.contains(key)) {
        return _colorScheme[key]!;
      }
    }

    // Default to white
    return Colors.white;
  }
}
