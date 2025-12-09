import 'dart:io';
import 'package:path/path.dart' as path;

/// Gitignore pattern matcher for Read permissions
/// Follows gitignore syntax to respect repository security boundaries
class GitignoreMatcher {
  final List<_GitignoreRule> _rules = [];
  final String _rootDirectory;

  GitignoreMatcher(this._rootDirectory);

  /// Load .gitignore file from project root
  static Future<GitignoreMatcher> load(String projectRoot) async {
    final matcher = GitignoreMatcher(projectRoot);
    await matcher._loadGitignore();
    return matcher;
  }

  /// Load .gitignore patterns
  Future<void> _loadGitignore() async {
    final gitignoreFile = File(path.join(_rootDirectory, '.gitignore'));
    if (!await gitignoreFile.exists()) {
      return;
    }

    try {
      final lines = await gitignoreFile.readAsLines();
      for (final line in lines) {
        final trimmed = line.trim();

        // Skip comments and empty lines
        if (trimmed.isEmpty || trimmed.startsWith('#')) {
          continue;
        }

        // Parse negation patterns (starting with !)
        final isNegation = trimmed.startsWith('!');
        final pattern = isNegation ? trimmed.substring(1) : trimmed;

        _rules.add(_GitignoreRule(pattern, isNegation));
      }
    } catch (e) {
      // If we can't read gitignore, fail open (allow reads)
      print('[GitignoreMatcher] Warning: Could not read .gitignore: $e');
    }
  }

  /// Check if a file path should be ignored (blocked from Read)
  bool shouldIgnore(String filePath) {
    // Normalize path relative to root
    final relativePath = _normalizePath(filePath);

    bool ignored = false;

    for (final rule in _rules) {
      if (rule.matches(relativePath)) {
        ignored = !rule.isNegation;
      }
    }

    return ignored;
  }

  /// Normalize path to relative path from root
  String _normalizePath(String filePath) {
    // Make absolute if relative
    final absolutePath = filePath.startsWith('/')
        ? filePath
        : path.join(_rootDirectory, filePath);

    // Get relative path from root
    try {
      return path.relative(absolutePath, from: _rootDirectory);
    } catch (e) {
      // If path is outside root, return as-is
      return filePath;
    }
  }
}

class _GitignoreRule {
  final String pattern;
  final bool isNegation;
  final RegExp? _regex;

  _GitignoreRule(this.pattern, this.isNegation)
    : _regex = _compilePattern(pattern);

  /// Compile gitignore pattern to regex
  static RegExp? _compilePattern(String pattern) {
    try {
      var regex = pattern;

      // Directory patterns (ending with /)
      final isDirectory = regex.endsWith('/');
      if (isDirectory) {
        regex = regex.substring(0, regex.length - 1);
      }

      // Anchored patterns (starting with /)
      final isAnchored = regex.startsWith('/');
      if (isAnchored) {
        regex = regex.substring(1);
      }

      // Convert gitignore glob to regex
      regex = regex
          .replaceAll(r'\', r'\\')
          .replaceAll(r'.', r'\.')
          .replaceAll(r'+', r'\+')
          .replaceAll(r'?', r'\?')
          .replaceAll(r'^', r'\^')
          .replaceAll(r'$', r'\$')
          .replaceAll(r'(', r'\(')
          .replaceAll(r')', r'\)')
          .replaceAll(r'[', r'\[')
          .replaceAll(r']', r'\]')
          .replaceAll(r'{', r'\{')
          .replaceAll(r'}', r'\}')
          .replaceAll('**/', '@@DOUBLESTAR@@')
          .replaceAll('**', '@@DOUBLESTAR@@')
          .replaceAll('*', '[^/]*')
          .replaceAll('@@DOUBLESTAR@@', '.*');

      // Build final pattern
      if (isAnchored) {
        regex = '^$regex';
      } else {
        // Match anywhere in path
        regex = '(^|/)$regex';
      }

      if (isDirectory) {
        regex = '$regex(/|\$)';
      } else {
        regex = '$regex(/|\$)';
      }

      return RegExp(regex);
    } catch (e) {
      print(
        '[GitignoreMatcher] Warning: Could not compile pattern "$pattern": $e',
      );
      return null;
    }
  }

  bool matches(String relativePath) {
    if (_regex == null) return false;
    return _regex.hasMatch(relativePath);
  }
}
