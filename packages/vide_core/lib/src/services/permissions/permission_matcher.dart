import 'bash_command_parser.dart';
import 'safe_commands.dart';
import 'tool_input.dart';

class PermissionMatcher {
  /// Check if a permission pattern matches a tool use
  static bool matches(
    String pattern,
    String toolName,
    ToolInput input, {
    Map<String, dynamic>? context,
  }) {
    // Validate file paths for security (prevent path traversal)
    final filePath = _extractFilePath(input);
    if (filePath != null && _isPathTraversal(filePath)) {
      // Path traversal detected - deny by not matching any pattern
      return false;
    }

    // Extract tool pattern (before parentheses)
    final toolPattern = pattern.split('(').first;

    // Check if tool name matches (supports regex)
    if (!RegExp(toolPattern).hasMatch(toolName)) {
      return false;
    }

    // Check argument pattern (if exists)
    if (pattern.contains('(') && pattern.contains(')')) {
      final argPattern = pattern.substring(
        pattern.indexOf('(') + 1,
        pattern.lastIndexOf(')'),
      );

      // Wildcard matches anything
      if (argPattern == '*') {
        return true;
      }

      // Tool-specific argument matching
      return _matchesArguments(argPattern, input, context);
    }

    return true; // Tool name matched, no argument filter
  }

  /// Extract file path from tool input if applicable
  static String? _extractFilePath(ToolInput input) {
    return switch (input) {
      ReadToolInput(:final filePath) => filePath.isEmpty ? null : filePath,
      WriteToolInput(:final filePath) => filePath.isEmpty ? null : filePath,
      EditToolInput(:final filePath) => filePath.isEmpty ? null : filePath,
      MultiEditToolInput(:final filePath) => filePath.isEmpty ? null : filePath,
      _ => null,
    };
  }

  /// Check for path traversal attempts
  static bool _isPathTraversal(String filePath) {
    // Check for common path traversal patterns
    if (filePath.contains('../') || filePath.contains('..\\')) {
      return true;
    }

    // Check for encoded path traversal
    if (filePath.contains('%2e%2e') || filePath.contains('%2E%2E')) {
      return true;
    }

    // Check for double-encoded path traversal
    if (filePath.contains('%252e%252e') || filePath.contains('%252E%252E')) {
      return true;
    }

    return false;
  }

  static bool _matchesArguments(
    String argPattern,
    ToolInput input,
    Map<String, dynamic>? context,
  ) {
    return switch (input) {
      BashToolInput(:final command) => _matchesBashCommand(
        argPattern,
        command,
        context,
      ),
      ReadToolInput(:final filePath) =>
        filePath.isNotEmpty && _globMatch(argPattern, filePath),
      WriteToolInput(:final filePath) =>
        filePath.isNotEmpty && _globMatch(argPattern, filePath),
      EditToolInput(:final filePath) =>
        filePath.isNotEmpty && _globMatch(argPattern, filePath),
      MultiEditToolInput(:final filePath) =>
        filePath.isNotEmpty && _globMatch(argPattern, filePath),
      WebFetchToolInput(:final url) => _matchesWebFetch(argPattern, url),
      WebSearchToolInput(:final query) => _matchesWebSearch(argPattern, query),
      GrepToolInput() => false, // Grep doesn't need permission patterns
      GlobToolInput() => false, // Glob doesn't need permission patterns
      UnknownToolInput() => false,
    };
  }

  static bool _matchesWebFetch(String argPattern, String url) {
    if (url.isEmpty) return false;

    // Check for domain matching (e.g., "domain:example.com")
    if (argPattern.startsWith('domain:')) {
      final domain = argPattern.substring('domain:'.length);
      return _matchesDomain(url, domain);
    }

    // Otherwise use regex matching on full URL
    return RegExp(argPattern).hasMatch(url);
  }

  static bool _matchesWebSearch(String argPattern, String query) {
    if (query.isEmpty) return false;

    // Check for query matching (e.g., "query:security")
    if (argPattern.startsWith('query:')) {
      final queryPattern = argPattern.substring('query:'.length);
      return RegExp(queryPattern).hasMatch(query);
    }

    // Otherwise use regex matching on full query
    return RegExp(argPattern).hasMatch(query);
  }

  static bool _matchesDomain(String url, String domain) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();
      final targetDomain = domain.toLowerCase();

      // Exact match or subdomain match
      return host == targetDomain || host.endsWith('.$targetDomain');
    } catch (e) {
      return false;
    }
  }

  static bool _globMatch(String pattern, String path) {
    // Convert glob pattern to regex
    // ** → .* (any characters including /)
    // * → [^/]* (any characters except /)
    // ? → . (single character)

    var regex = pattern
        .replaceAll('**', '@@DOUBLE_STAR@@')
        .replaceAll('*', '[^/]*')
        .replaceAll('@@DOUBLE_STAR@@', '.*')
        .replaceAll('?', '.');

    // Escape special regex characters (but preserve our replacements)
    // Note: We've already replaced * and ?, so we need to escape other chars
    final specialChars = [r'\', r'$', r'^', r'+', r'[', r']', r'(', r')'];
    for (final char in specialChars) {
      if (!regex.contains(char)) continue;
      regex = regex.replaceAll(char, '\\$char');
    }

    try {
      return RegExp('^$regex\$').hasMatch(path);
    } catch (e) {
      // If regex is invalid, fall back to exact match
      return pattern == path;
    }
  }

  /// Check if a bash command should be auto-approved as safe
  static bool isSafeBashCommand(
    BashToolInput input,
    Map<String, dynamic>? context,
  ) {
    final command = input.command;
    if (command.trim().isEmpty) return false;

    // Get working directory from context
    final cwd = context?['cwd'] as String?;

    // Parse compound command
    final parsedCommands = BashCommandParser.parse(command);
    if (parsedCommands.isEmpty) return false;

    // Check each sub-command
    for (final parsed in parsedCommands) {
      // Auto-approve cd commands within working directory
      if (parsed.type == CommandType.cd) {
        if (cwd != null &&
            BashCommandParser.isCdWithinWorkingDir(parsed.command, cwd)) {
          continue; // Safe - within working directory
        }
        return false; // cd outside working directory - not safe
      }

      // Auto-approve safe pipeline filters
      if (parsed.type == CommandType.pipelinePart &&
          _isSafeOutputFilter(parsed.command)) {
        continue; // Safe filter
      }

      // Check if this is a safe command
      if (!SafeCommands.isCommandSafe(parsed.command)) {
        return false; // Not safe
      }
    }

    return true; // All commands are safe
  }

  /// Match Bash commands with compound command support
  static bool _matchesBashCommand(
    String argPattern,
    String command,
    Map<String, dynamic>? context,
  ) {
    if (command.trim().isEmpty) return false;

    // Get working directory from context
    final cwd = context?['cwd'] as String?;

    // Parse compound command
    final parsedCommands = BashCommandParser.parse(command);

    // Empty command should not match
    if (parsedCommands.isEmpty) return false;

    // For pipelines with wildcard patterns, use smart matching
    final hasPipeline = parsedCommands.any(
      (cmd) => cmd.type == CommandType.pipelinePart,
    );
    final isWildcardPattern =
        argPattern.contains('*') ||
        argPattern == '' ||
        argPattern.contains('.*');

    if (hasPipeline) {
      if (isWildcardPattern) {
        // Wildcard pattern - use smart matching with safe filters
        return _matchesPipeline(parsedCommands, argPattern, cwd);
      } else {
        // Exact pattern - just check if the whole command matches
        return RegExp(argPattern).hasMatch(command);
      }
    }

    // For non-pipeline commands, check each sub-command
    for (final parsed in parsedCommands) {
      // Auto-approve cd commands within working directory
      if (parsed.type == CommandType.cd) {
        if (cwd != null &&
            BashCommandParser.isCdWithinWorkingDir(parsed.command, cwd)) {
          continue; // Skip to next command - auto-approved
        }
        // cd outside working directory - must check against pattern
      }

      // Check this sub-command against the pattern
      if (!RegExp(argPattern).hasMatch(parsed.command)) {
        return false; // One sub-command doesn't match
      }
    }

    return true; // All sub-commands matched (or were auto-approved cd)
  }

  /// Match pipeline commands with intelligent filtering
  /// In a pipeline, at least one command must match the pattern,
  /// and other commands can be safe filters or data sources being piped
  static bool _matchesPipeline(
    List<ParsedCommand> parsedCommands,
    String argPattern,
    String? cwd,
  ) {
    bool hasMatchingCommand = false;

    for (var i = 0; i < parsedCommands.length; i++) {
      final parsed = parsedCommands[i];

      // Auto-approve cd commands within working directory
      if (parsed.type == CommandType.cd) {
        if (cwd != null &&
            BashCommandParser.isCdWithinWorkingDir(parsed.command, cwd)) {
          continue; // Skip - auto-approved
        }
        // cd outside working directory - must check against pattern
      }

      // Check if this command matches the pattern
      final matches = RegExp(argPattern).hasMatch(parsed.command);
      if (matches) {
        hasMatchingCommand = true;
        continue;
      }

      // If it doesn't match, check if it's a safe filter
      if (_isSafeOutputFilter(parsed.command)) {
        continue; // Safe filter - auto-approved in pipelines
      }

      // If it doesn't match and isn't a safe filter,
      // it could be a data source command (first in pipeline)
      // Allow it if there's a matching command later in the pipeline
      // We'll verify this at the end
    }

    // At least one command in the pipeline must match the pattern
    return hasMatchingCommand;
  }

  /// Check if a command is a safe output filter
  /// These are common utilities used to filter/limit output in pipelines
  static bool _isSafeOutputFilter(String command) {
    final trimmed = command.trim();
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.isEmpty) return false;

    final commandName = parts[0];

    // List of safe output filtering commands
    const safeFilters = {
      'head', // Limit to first N lines
      'tail', // Limit to last N lines
      'grep', // Filter by pattern
      'egrep', // Extended grep
      'fgrep', // Fixed string grep
      'sed', // Stream editor (when used for filtering)
      'awk', // Pattern scanning (when used for filtering)
      'cut', // Cut out columns
      'sort', // Sort lines
      'uniq', // Remove duplicates
      'wc', // Count lines/words/chars
      'tr', // Translate characters
      'less', // Pager
      'more', // Pager
      'cat', // Concatenate (when used as output)
      'tee', // Duplicate output
      'column', // Format into columns
      'nl', // Number lines
      'jq', // JSON processor
    };

    return safeFilters.contains(commandName);
  }

  /// Generate a permission pattern from a tool use
  static String generatePattern(String toolName, ToolInput input) {
    return switch (input) {
      BashToolInput(:final command) =>
        command.isEmpty ? toolName : 'Bash($command)',
      ReadToolInput(:final filePath) =>
        filePath.isEmpty ? toolName : 'Read($filePath)',
      WriteToolInput(:final filePath) =>
        filePath.isEmpty ? toolName : 'Write($filePath)',
      EditToolInput(:final filePath) =>
        filePath.isEmpty ? toolName : 'Edit($filePath)',
      MultiEditToolInput(:final filePath) =>
        filePath.isEmpty ? toolName : 'MultiEdit($filePath)',
      WebFetchToolInput(:final url) =>
        url.isEmpty ? toolName : 'WebFetch($url)',
      WebSearchToolInput(:final query) =>
        query.isEmpty ? toolName : 'WebSearch($query)',
      GrepToolInput() => toolName,
      GlobToolInput() => toolName,
      UnknownToolInput() => toolName,
    };
  }
}
