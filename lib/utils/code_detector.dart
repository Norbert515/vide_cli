/// Detects if text contains code snippets
class CodeDetector {
  /// Check if the text likely contains code
  /// Returns true if code patterns are detected
  static bool containsCode(String text) {
    if (text.length < 20) return false;

    // Check for markdown code blocks
    if (text.contains('```')) return true;

    // Check for common code patterns
    final codePatterns = [
      RegExp(r'function\s+\w+\s*\('),           // JS function declarations
      RegExp(r'def\s+\w+\s*\('),                // Python functions
      RegExp(r'\bvoid\s+\w+\s*\('),             // C/Java/Dart void functions
      RegExp(r'\b(int|string|bool|double|float|char)\s+\w+\s*\('), // typed functions
      RegExp(r'class\s+\w+'),                    // class declarations
      RegExp(r'=>'),                             // arrow functions/expressions
      RegExp(r'\bconst\s+\w+\s*='),             // const declarations
      RegExp(r'\bfinal\s+\w+\s*='),             // Dart final declarations
      RegExp(r'\blet\s+\w+\s*='),               // let declarations
      RegExp(r'\bvar\s+\w+\s*='),               // var declarations
      RegExp(r'''import\s+['"]'''),              // JS/Dart imports
      RegExp(r"import\s+'package:"),            // Dart package imports
      RegExp(r'''from\s+['"].*['"]\s+import'''), // Python imports
      RegExp(r'#include\s*<'),                   // C/C++ includes
      RegExp(r'\bif\s*\('),                      // if statements
      RegExp(r'\bfor\s*\('),                     // for loops
      RegExp(r'\bwhile\s*\('),                   // while loops
      RegExp(r'\breturn\s+'),                    // return statements
      RegExp(r'@\w+', multiLine: true),          // decorators/annotations
      RegExp(r'^\s*}\s*$', multiLine: true),     // closing braces on own line
      RegExp(r'\w+\.\w+\('),                     // method calls
      RegExp(r';\s*$', multiLine: true),         // semicolon line endings
    ];

    int matches = 0;
    for (final pattern in codePatterns) {
      if (pattern.hasMatch(text)) {
        matches++;
        if (matches >= 2) return true; // Need at least 2 patterns
      }
    }

    // Check for high density of special characters common in code
    final codeChars = text.split('').where((c) =>
      ['{', '}', '(', ')', '[', ']', ';', '=', '<', '>', ':'].contains(c)
    ).length;

    if (codeChars > text.length * 0.05) return true; // >5% code chars (lowered threshold)

    return false;
  }

  /// Extract code from markdown code blocks, or return full text if no blocks
  static String extractCode(String text) {
    final codeBlockRegex = RegExp(r'```(?:\w*\n)?([\s\S]*?)```');
    final matches = codeBlockRegex.allMatches(text);

    if (matches.isNotEmpty) {
      return matches.map((m) => m.group(1)?.trim() ?? '').join('\n\n');
    }

    return text;
  }
}
