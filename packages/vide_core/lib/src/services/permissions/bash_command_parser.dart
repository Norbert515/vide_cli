import 'package:path/path.dart' as path;

/// Type of parsed command
enum CommandType {
  simple, // Regular command
  cd, // cd command (special handling)
  pipelinePart, // Part of a pipeline
}

/// Represents a parsed command component
class ParsedCommand {
  final String command;
  final CommandType type;

  ParsedCommand(this.command, this.type);

  @override
  String toString() => 'ParsedCommand($command, $type)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParsedCommand &&
          runtimeType == other.runtimeType &&
          command == other.command &&
          type == other.type;

  @override
  int get hashCode => Object.hash(command, type);
}

/// Parser for Bash compound commands
class BashCommandParser {
  /// Parse a bash command into its component parts
  /// Handles &&, ||, |, and ; operators
  static List<ParsedCommand> parse(String command) {
    if (command.trim().isEmpty) {
      return [];
    }

    // First check if there are any pipes (they bind tighter than &&/||/;)
    final hasPipes = _hasPipes(command);

    if (hasPipes) {
      return _parseWithPipes(command);
    } else {
      return _parseWithoutPipes(command);
    }
  }

  /// Check if a cd command is within a given working directory
  static bool isCdWithinWorkingDir(String cdCommand, String workingDir) {
    // Extract the target directory from the cd command
    final parts = cdCommand.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0] != 'cd') {
      return false; // Not a cd command
    }

    // Get target directory (if no argument, cd goes to home - treat as outside)
    if (parts.length < 2) {
      return false;
    }

    final targetDir = parts[1];

    // Resolve absolute path
    final String absoluteTarget;
    if (targetDir.startsWith('/')) {
      // Already absolute
      absoluteTarget = path.normalize(targetDir);
    } else if (targetDir.startsWith('~/')) {
      // Home directory - treat as outside working directory
      return false;
    } else {
      // Relative path - resolve from working directory
      absoluteTarget = path.normalize(path.join(workingDir, targetDir));
    }

    // Normalize working directory
    final normalizedWorkingDir = path.normalize(workingDir);

    // Check if target is within working directory
    // It's within if it's equal to or a subdirectory of workingDir
    return absoluteTarget == normalizedWorkingDir ||
        absoluteTarget.startsWith('$normalizedWorkingDir/');
  }

  /// Check if command contains pipes outside of quotes
  static bool _hasPipes(String command) {
    var inSingleQuote = false;
    var inDoubleQuote = false;

    for (var i = 0; i < command.length; i++) {
      final char = command[i];

      // Handle quotes
      if (char == "'" && !inDoubleQuote) {
        inSingleQuote = !inSingleQuote;
      } else if (char == '"' && !inSingleQuote) {
        inDoubleQuote = !inDoubleQuote;
      }

      // Check for pipe outside quotes
      if (!inSingleQuote && !inDoubleQuote && char == '|') {
        // Make sure it's not ||
        if (i + 1 < command.length && command[i + 1] == '|') {
          continue; // This is ||, not a pipe
        }
        return true;
      }
    }

    return false;
  }

  /// Parse command that contains pipes
  static List<ParsedCommand> _parseWithPipes(String command) {
    final result = <ParsedCommand>[];

    // First split by &&, ||, ;
    final segments = _splitByLogicalOperators(command);

    for (final segment in segments) {
      // Now split each segment by pipes
      final pipeCommands = _splitByPipes(segment);

      for (final cmd in pipeCommands) {
        final trimmed = cmd.trim();
        if (trimmed.isEmpty) continue;

        final type = _detectCommandType(
          trimmed,
          hasPipe: pipeCommands.length > 1,
        );
        result.add(ParsedCommand(trimmed, type));
      }
    }

    return result;
  }

  /// Parse command without pipes
  static List<ParsedCommand> _parseWithoutPipes(String command) {
    final result = <ParsedCommand>[];
    final segments = _splitByLogicalOperators(command);

    for (final segment in segments) {
      final trimmed = segment.trim();
      if (trimmed.isEmpty) continue;

      final type = _detectCommandType(trimmed, hasPipe: false);
      result.add(ParsedCommand(trimmed, type));
    }

    return result;
  }

  /// Split command by logical operators (&&, ||, ;, &)
  /// Note: Single & (background operator) is also handled as a separator
  /// to ensure each command part is validated independently.
  static List<String> _splitByLogicalOperators(String command) {
    final parts = <String>[];
    final buffer = StringBuffer();
    var inSingleQuote = false;
    var inDoubleQuote = false;

    for (var i = 0; i < command.length; i++) {
      final char = command[i];

      // Handle quotes
      if (char == "'" && !inDoubleQuote) {
        inSingleQuote = !inSingleQuote;
        buffer.write(char);
      } else if (char == '"' && !inSingleQuote) {
        inDoubleQuote = !inDoubleQuote;
        buffer.write(char);
      } else if (!inSingleQuote && !inDoubleQuote) {
        // Check for operators outside quotes
        if (char == ';') {
          parts.add(buffer.toString());
          buffer.clear();
        } else if (char == '&') {
          if (i + 1 < command.length && command[i + 1] == '&') {
            // Handle && (AND operator)
            parts.add(buffer.toString());
            buffer.clear();
            i++; // Skip next &
          } else if (_isPartOfRedirection(command, i)) {
            // This & is part of a redirection like >&, 2>&1, &>, etc.
            // Not a background operator - keep it in the buffer
            buffer.write(char);
          } else {
            // Handle single & (background operator)
            // SECURITY: Must split here to validate each command independently
            parts.add(buffer.toString());
            buffer.clear();
          }
        } else if (char == '|' &&
            i + 1 < command.length &&
            command[i + 1] == '|') {
          parts.add(buffer.toString());
          buffer.clear();
          i++; // Skip next |
        } else {
          buffer.write(char);
        }
      } else {
        buffer.write(char);
      }
    }

    // Add remaining
    if (buffer.isNotEmpty) {
      parts.add(buffer.toString());
    }

    return parts;
  }

  /// Split command by pipes
  static List<String> _splitByPipes(String command) {
    final parts = <String>[];
    final buffer = StringBuffer();
    var inSingleQuote = false;
    var inDoubleQuote = false;

    for (var i = 0; i < command.length; i++) {
      final char = command[i];

      // Handle quotes
      if (char == "'" && !inDoubleQuote) {
        inSingleQuote = !inSingleQuote;
        buffer.write(char);
      } else if (char == '"' && !inSingleQuote) {
        inDoubleQuote = !inDoubleQuote;
        buffer.write(char);
      } else if (!inSingleQuote && !inDoubleQuote && char == '|') {
        // Make sure it's not ||
        if (i + 1 < command.length && command[i + 1] == '|') {
          buffer.write(char);
          continue;
        }
        parts.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }

    // Add remaining
    if (buffer.isNotEmpty) {
      parts.add(buffer.toString());
    }

    return parts;
  }

  /// Check if the & at position i is part of a redirection operator
  /// Common patterns:
  /// - >&   : redirect stdout (e.g., >&2)
  /// - 2>&1 : redirect stderr to stdout (digit before &)
  /// - &>   : redirect both stdout and stderr
  /// - &>>  : append both stdout and stderr
  static bool _isPartOfRedirection(String command, int i) {
    // Check if preceded by > (part of >&)
    if (i > 0 && command[i - 1] == '>') {
      return true;
    }

    // Check if preceded by digit and > (part of 2>&1, 1>&2, etc.)
    if (i >= 2) {
      final prevChar = command[i - 1];
      final prevPrevChar = command[i - 2];
      if (prevChar == '>' && _isDigit(prevPrevChar)) {
        return true;
      }
    }

    // Check if followed by > (part of &> or &>>)
    if (i + 1 < command.length && command[i + 1] == '>') {
      return true;
    }

    return false;
  }

  /// Check if a character is a digit
  static bool _isDigit(String char) {
    return char.length == 1 &&
        char.codeUnitAt(0) >= 48 &&
        char.codeUnitAt(0) <= 57;
  }

  /// Detect the type of command
  static CommandType _detectCommandType(
    String command, {
    required bool hasPipe,
  }) {
    final trimmed = command.trim();
    final parts = trimmed.split(RegExp(r'\s+'));

    if (parts.isNotEmpty && parts[0] == 'cd') {
      return CommandType.cd;
    }

    if (hasPipe) {
      return CommandType.pipelinePart;
    }

    return CommandType.simple;
  }
}
