import 'package:path/path.dart' as path;
import 'bash_command_parser.dart';
import 'tool_input.dart';

/// Smart pattern inference for permission rules
/// Generates intelligent wildcard patterns from specific tool uses
class PatternInference {
  /// Generate a smart pattern from a tool use
  static String inferPattern(String toolName, ToolInput input) {
    return switch (input) {
      BashToolInput(:final command) => _inferBashPattern(command),
      WriteToolInput(:final filePath) => _inferFilePattern('Write', filePath),
      EditToolInput(:final filePath) => _inferFilePattern('Edit', filePath),
      MultiEditToolInput(:final filePath) => _inferFilePattern(
        'MultiEdit',
        filePath,
      ),
      WebFetchToolInput(:final url) => _inferWebFetchPattern(url),
      ReadToolInput(:final filePath) => _inferReadPattern(filePath),
      WebSearchToolInput() => _inferWebSearchPattern(),
      GrepToolInput() => toolName,
      GlobToolInput() => toolName,
      UnknownToolInput() => toolName,
    };
  }

  /// Infer pattern for Bash commands
  /// Example: "npm run test" → "Bash(npm run test *)"
  /// Example: "git status" → "Bash(git status *)"
  /// Example: "cd /path && dart pub get" → "Bash(dart pub get *)"
  /// Example: "find /path -name *.dart" → "Bash(find *)"
  /// Example: "dart test 2>&1" → "Bash(dart test *)" (redirects stripped)
  static String _inferBashPattern(String command) {
    if (command.isEmpty) return 'Bash(*)';

    // Parse compound commands
    final parsedCommands = BashCommandParser.parse(command);

    // Find the "main" command:
    // - Skip cd commands (just directory changes)
    // - Skip prefix commands (sleep, timeout, env, etc.)
    // - Skip pipeline filter parts (grep, head, tail after |)
    // - Prefer the last meaningful command (prefix cmds appear first in chains)
    var mainCommand = '';
    for (final cmd in parsedCommands.reversed) {
      if (cmd.type == CommandType.cd) continue;
      if (cmd.type == CommandType.pipelinePart) continue;
      if (_isPrefixCommand(cmd.command)) continue;
      mainCommand = cmd.command;
      break;
    }
    // Fallback: if all non-cd commands are pipeline parts, use the first one
    // (the producer, not the filter)
    if (mainCommand.isEmpty) {
      mainCommand = parsedCommands
          .firstWhere(
            (cmd) => cmd.type != CommandType.cd && !_isPrefixCommand(cmd.command),
            orElse: () => parsedCommands.firstWhere(
              (cmd) => cmd.type != CommandType.cd,
              orElse: () => parsedCommands.isNotEmpty
                  ? parsedCommands.first
                  : ParsedCommand('', CommandType.simple),
            ),
          )
          .command;
    }

    if (mainCommand.isEmpty) return 'Bash(*)';

    // Strip shell redirects from the command before inferring pattern
    // These are implementation details that shouldn't be part of the pattern
    mainCommand = _stripShellRedirects(mainCommand);

    // Split into parts (quote-aware)
    final parts = _splitRespectingQuotes(mainCommand.trim());
    if (parts.isEmpty) return 'Bash(*)';

    // Extract base command (command name only, no path/flag/quoted arguments)
    final baseParts = <String>[];

    for (final part in parts) {
      // Stop at flags
      if (part.startsWith('-')) break;

      // Stop at quoted arguments (these are values, not sub-command names)
      if (part.startsWith('"') || part.startsWith("'")) break;

      // Stop at path-like arguments (starting with / or ./ or ~/ or ..)
      if (part.startsWith('/') ||
          part.startsWith('./') ||
          part.startsWith('~/') ||
          part.startsWith('..')) {
        // If this is the first part, include it (it's the command itself)
        if (baseParts.isEmpty) {
          baseParts.add(part);
        }
        break;
      }

      baseParts.add(part);
    }

    final baseCommand = baseParts.join(' ');
    return baseCommand.isEmpty ? 'Bash(*)' : 'Bash($baseCommand *)';
  }

  /// Split a command string into parts, keeping quoted strings as single tokens.
  static List<String> _splitRespectingQuotes(String command) {
    final parts = <String>[];
    final buffer = StringBuffer();
    var inSingleQuote = false;
    var inDoubleQuote = false;

    for (var i = 0; i < command.length; i++) {
      final char = command[i];

      if (char == "'" && !inDoubleQuote) {
        inSingleQuote = !inSingleQuote;
        buffer.write(char);
      } else if (char == '"' && !inSingleQuote) {
        inDoubleQuote = !inDoubleQuote;
        buffer.write(char);
      } else if (char == ' ' && !inSingleQuote && !inDoubleQuote) {
        if (buffer.isNotEmpty) {
          parts.add(buffer.toString());
          buffer.clear();
        }
      } else {
        buffer.write(char);
      }
    }

    if (buffer.isNotEmpty) {
      parts.add(buffer.toString());
    }

    return parts;
  }

  /// Commands that are typically used as prefixes before the "real" command.
  /// These are delay/wrapper commands that shouldn't be used for pattern inference.
  static const _prefixCommands = {
    'sleep',
    'timeout',
    'env',
    'nice',
    'nohup',
    'time',
    'watch',
    'retry',
    'wait',
    'true',
    'false',
  };

  /// Check if a command is a prefix/wrapper command like sleep, timeout, etc.
  static bool _isPrefixCommand(String command) {
    final firstWord = command.trim().split(RegExp(r'\s+')).firstOrNull ?? '';
    return _prefixCommands.contains(firstWord);
  }

  /// Strip shell redirects from a command string.
  ///
  /// Removes patterns like:
  /// - `2>&1`, `>&2`, `1>&2` - file descriptor redirects
  /// - `2>/dev/null`, `>/dev/null`, `&>/dev/null` - output to file
  /// - `</path/to/file` - input redirect
  /// - `>>file` - append redirect
  static String _stripShellRedirects(String command) {
    // Pattern to match shell redirects:
    // - [0-9]*>&[0-9]+ : fd redirect (2>&1, >&2, 1>&2)
    // - [0-9]*>>[^\s]+ : append redirect (>>file, 2>>file)
    // - [0-9]*>[^\s]+  : output redirect (>file, 2>/dev/null, &>/dev/null)
    // - <[^\s]+        : input redirect (<file)
    //
    // We need to be careful not to match things like:
    // - Comparison operators in strings
    // - The > in paths like /path/to/file
    //
    // Match redirects at word boundaries (preceded by space or start, followed by space or end)
    final redirectPattern = RegExp(
      r'(?:^|\s)' // Start or preceded by whitespace
      r'(?:'
      r'[0-9]*>&[0-9]+' // fd redirect: 2>&1, >&2
      r'|'
      r'&>>[^\s]*' // append both: &>>file
      r'|'
      r'&>[^\s]*' // redirect both: &>/dev/null
      r'|'
      r'[0-9]*>>[^\s]*' // append: >>file, 2>>file
      r'|'
      r'[0-9]*>[^\s]*' // output: >file, 2>/dev/null
      r'|'
      r'<[^\s]+' // input: <file
      r')'
      r'(?=\s|$)', // Followed by whitespace or end
    );

    // Remove all redirect patterns and clean up extra whitespace
    return command
        .replaceAll(redirectPattern, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Infer pattern for file operations (Write/Edit/MultiEdit)
  /// Example: "/path/to/file.dart" → "Write(/path/to/**)"
  static String _inferFilePattern(String toolName, String filePath) {
    if (filePath.isEmpty) return '$toolName(*)';

    // Extract directory path
    final directory = path.dirname(filePath);

    // If it's just '.', use ** to match anything in current directory
    if (directory == '.') {
      return '$toolName(**)';
    }

    // Use directory with /** to match all files in that directory
    return '$toolName($directory/**)';
  }

  /// Infer pattern for WebFetch
  /// Example: "https://api.github.com/repos/..." → "WebFetch(domain:github.com)"
  static String _inferWebFetchPattern(String url) {
    if (url.isEmpty) return 'WebFetch(*)';

    try {
      final uri = Uri.parse(url);
      final domain = uri.host;

      if (domain.isEmpty) return 'WebFetch(*)';

      return 'WebFetch(domain:$domain)';
    } catch (e) {
      return 'WebFetch(*)';
    }
  }

  /// Infer pattern for Read operations
  /// Example: "/path/to/file.dart" → "Read(/path/to/**)"
  static String _inferReadPattern(String filePath) {
    if (filePath.isEmpty) return 'Read(*)';

    // Extract directory path
    final directory = path.dirname(filePath);

    // If it's just '.', use ** to match anything in current directory
    if (directory == '.') {
      return 'Read(**)';
    }

    // Use directory with /** to match all files in that directory
    return 'Read($directory/**)';
  }

  /// Infer pattern for WebSearch
  /// WebSearch doesn't need wildcards - use exact pattern
  static String _inferWebSearchPattern() {
    // For WebSearch, we just use the tool name without arguments
    // This will allow all web searches (since patterns are too specific)
    return 'WebSearch';
  }
}
