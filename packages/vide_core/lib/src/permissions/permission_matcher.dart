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

  /// Convert a bash glob pattern to an anchored regex.
  ///
  /// Claude Code uses glob-style matching for Bash patterns:
  /// - `*` matches any characters (like `.*` in regex)
  /// - `Bash(ls *)` matches `ls`, `ls -la` but NOT `lsof` (space enforces
  ///   word boundary: prefix must be followed by space-or-end-of-string)
  /// - `Bash(ls*)` matches both `ls -la` AND `lsof`
  /// - `Bash(git * main)` matches `git checkout main`
  /// - Legacy `:*` suffix is treated as ` *` for backward compatibility
  ///
  /// The pattern is anchored (full-string match), not a substring search.
  static RegExp _bashGlobToRegex(String pattern) {
    // Legacy support: convert trailing `:*` to ` *`
    var normalized = pattern;
    if (normalized.endsWith(':*')) {
      normalized =
          '${normalized.substring(0, normalized.length - 2)} *';
    }

    // Special case: trailing ` *` enforces word boundary.
    // "ls *" matches "ls" (end-of-string) and "ls -la" (space + args)
    // but NOT "lsof" (no boundary).
    // We handle this by converting trailing ` *` to `( .*)?` and then
    // processing the rest normally.
    String? trailingSuffix;
    if (normalized.endsWith(' *')) {
      trailingSuffix = '( .*)?';
      normalized = normalized.substring(0, normalized.length - 2);
    }

    // Escape regex special characters, then convert glob `*` to `.*`
    final buffer = StringBuffer();
    for (var i = 0; i < normalized.length; i++) {
      final char = normalized[i];
      if (char == '*') {
        buffer.write('.*');
      } else if (_regexSpecialChars.contains(char)) {
        buffer.write('\\');
        buffer.write(char);
      } else {
        buffer.write(char);
      }
    }

    if (trailingSuffix != null) {
      buffer.write(trailingSuffix);
    }

    return RegExp('^${buffer.toString()}\$');
  }

  static const _regexSpecialChars = {
    '.', '+', '?', '[', ']', '(', ')', '{', '}', '^', r'$', '|', r'\',
  };

  /// Check if a command matches a bash glob pattern.
  static bool _bashGlobMatches(String pattern, String command) {
    try {
      return _bashGlobToRegex(pattern).hasMatch(command);
    } catch (e) {
      // If pattern is invalid, fall back to exact match
      return pattern == command;
    }
  }

  /// Match Bash commands with compound command support.
  ///
  /// Uses glob-style matching (like Claude Code):
  /// - Each sub-command in `&&`/`||`/`;` chains is matched independently
  /// - `cd` within the working directory is auto-approved
  /// - Pipelines use smart matching with safe filter allowlists
  static bool _matchesBashCommand(
    String argPattern,
    String command,
    Map<String, dynamic>? context,
  ) {
    if (command.trim().isEmpty) return false;

    // SECURITY: Check for command substitution and process substitution
    // These can inject arbitrary commands that bypass pattern matching
    if (_containsCommandSubstitution(command)) {
      return false;
    }

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
        // Exact pattern - check full command string
        return _bashGlobMatches(argPattern, command);
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
      if (!_bashGlobMatches(argPattern, parsed.command)) {
        return false; // One sub-command doesn't match
      }
    }

    return true; // All sub-commands matched (or were auto-approved cd)
  }

  /// Match pipeline commands with intelligent filtering
  /// In a pipeline, at least one command must match the pattern,
  /// and ALL other commands must be safe filters (not dangerous commands)
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
      final matches = _bashGlobMatches(argPattern, parsed.command);
      if (matches) {
        hasMatchingCommand = true;
        continue;
      }

      // If it doesn't match, check if it's a safe filter
      if (_isSafeOutputFilter(parsed.command)) {
        continue; // Safe filter - auto-approved in pipelines
      }

      // SECURITY: If it doesn't match AND isn't a safe filter,
      // it's potentially dangerous - reject the entire pipeline
      // This prevents: allowed_cmd | malicious_cmd
      return false;
    }

    // At least one command in the pipeline must match the pattern
    return hasMatchingCommand;
  }

  /// Check if a command is a safe output filter
  /// These are common utilities used to filter/limit output in pipelines
  ///
  /// SECURITY: Uses an allowlist approach - only commands explicitly listed
  /// are considered safe. Any command not in the list is rejected.
  static bool _isSafeOutputFilter(String command) {
    final trimmed = command.trim();
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.isEmpty) return false;

    final commandName = parts[0];

    // Allowlist of safe output filtering commands
    // SECURITY: Only these specific commands are allowed in pipelines
    // when they don't match the pattern. Any other command is rejected.
    const safeFilters = {
      'head', // Limit to first N lines
      'tail', // Limit to last N lines
      'grep', // Filter by pattern
      'egrep', // Extended grep
      'fgrep', // Fixed string grep
      'sed', // Stream editor (when used for filtering) - but check flags!
      'awk', // Pattern scanning (when used for filtering)
      'cut', // Cut out columns
      'sort', // Sort lines
      'uniq', // Remove duplicates
      'wc', // Count lines/words/chars
      'tr', // Translate characters
      'less', // Pager
      'more', // Pager
      'cat', // Concatenate (when used as output)
      'column', // Format into columns
      'nl', // Number lines
      'jq', // JSON processor
      // NOTE: 'tee' is intentionally NOT included - it writes to files
      // NOTE: 'xargs' is intentionally NOT included - it executes commands
    };

    if (!safeFilters.contains(commandName)) {
      return false;
    }

    // SECURITY: Check for dangerous flags that make safe commands unsafe
    if (_hasDangerousFilterFlags(command, commandName)) {
      return false;
    }

    return true;
  }

  /// Check if a safe filter command has dangerous flags
  static bool _hasDangerousFilterFlags(String command, String commandName) {
    final parts = command.split(RegExp(r'\s+'));

    switch (commandName) {
      case 'sed':
        // sed -i modifies files in place
        for (final part in parts) {
          if (part == '-i' || part.startsWith('-i') && part.length > 2) {
            return true;
          }
          // Also check for --in-place
          if (part == '--in-place' || part.startsWith('--in-place=')) {
            return true;
          }
        }
        break;

      case 'awk':
        // awk can write to files if command contains > (though rare in pipes)
        // We allow awk in pipes but block explicit file redirection
        if (command.contains('>') && !command.contains('2>')) {
          return true;
        }
        break;

      case 'sort':
        // sort -o writes to file
        if (parts.contains('-o') || parts.any((p) => p.startsWith('-o'))) {
          return true;
        }
        break;
    }

    return false;
  }

  /// Check if a command contains command substitution or process substitution
  /// These can inject arbitrary commands that execute before the main command
  ///
  /// Detects:
  /// - $() - command substitution
  /// - `` (backticks) - command substitution
  /// - <() - process substitution (input)
  /// - >() - process substitution (output)
  /// - Subshells with parentheses at the start
  static bool _containsCommandSubstitution(String command) {
    // Track quote state to avoid false positives
    var inSingleQuote = false;
    var inDoubleQuote = false;

    for (var i = 0; i < command.length; i++) {
      final char = command[i];

      // Handle quote state
      if (char == "'" && !inDoubleQuote) {
        inSingleQuote = !inSingleQuote;
        continue;
      }
      if (char == '"' && !inSingleQuote) {
        inDoubleQuote = !inDoubleQuote;
        continue;
      }

      // Single quotes prevent all substitution
      if (inSingleQuote) continue;

      // In double quotes or unquoted, check for substitution patterns

      // Check for $( - command substitution
      if (char == r'$' && i + 1 < command.length && command[i + 1] == '(') {
        return true;
      }

      // Check for backticks - command substitution
      if (char == '`') {
        return true;
      }

      // Check for <( - process substitution (not inside quotes is what matters)
      if (char == '<' &&
          i + 1 < command.length &&
          command[i + 1] == '(' &&
          !inDoubleQuote) {
        return true;
      }

      // Check for >( - process substitution
      if (char == '>' &&
          i + 1 < command.length &&
          command[i + 1] == '(' &&
          !inDoubleQuote) {
        return true;
      }

      // Check for unquoted subshell at the start: (commands)
      // This is tricky - we only want to catch subshells, not arithmetic
      // A leading ( is suspicious when followed by command-like content
      if (char == '(' && !inDoubleQuote && i == 0) {
        // Check if this looks like a subshell (contains command-like characters)
        final rest = command.substring(1);
        if (rest.contains(' ') && !rest.startsWith('(')) {
          return true;
        }
      }
    }

    return false;
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
