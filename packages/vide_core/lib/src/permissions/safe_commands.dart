/// Safe commands that can be auto-approved without user permission
/// These are read-only commands that cannot modify system state
class SafeCommands {
  /// Check if a bash command is safe to auto-approve
  static bool isSafeBashCommand(String command) {
    final trimmed = command.trim();
    if (trimmed.isEmpty) return false;

    // Extract the command name (first word)
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.isEmpty) return false;

    final commandName = parts[0];

    // Check against safe command list
    return _safeCommandNames.contains(commandName);
  }

  /// List of command names that are considered safe
  /// These commands are read-only and cannot modify system state
  static const Set<String> _safeCommandNames = {
    // Directory and file listing
    'ls',
    'pwd',
    'which',
    'whoami',
    'tree',

    // File reading
    'cat',
    'head',
    'tail',
    'less',
    'more',

    // Search and find
    'find',
    'grep',
    'egrep',
    'fgrep',
    'rg', // ripgrep
    // Git read operations
    'git', // We'll validate the subcommand separately
    // Process inspection
    'ps',
    'top',
    'htop',

    // File metadata
    'stat',
    'file',
    'wc',
    'du',
    'df',

    // Environment
    'env',
    'printenv',
    'echo',

    // Data processing (read-only when used without file modification)
    'sort',
    'uniq',
    'cut',
    'awk',
    'sed',
    'jq',
    'tr',
    'column',
    'nl',

    // Package manager read operations
    'npm', // We'll validate subcommands
    'dart', // We'll validate subcommands
    'pip', // We'll validate subcommands
  };

  /// Check if a git command is safe (read-only)
  static bool isSafeGitCommand(String command) {
    final trimmed = command.trim();
    if (!trimmed.startsWith('git ')) return false;

    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length < 2) return false;

    final gitSubcommand = parts[1];

    return _safeGitSubcommands.contains(gitSubcommand);
  }

  static const Set<String> _safeGitSubcommands = {
    'status',
    'log',
    'diff',
    'show',
    'branch',
    'remote',
    'config',
    'rev-parse',
    'describe',
    'ls-files',
    'ls-tree',
    'ls-remote',
    'blame',
    'shortlog',
    'tag',
    'reflog',
    'cat-file',
    'rev-list',
  };

  /// Check if a package manager command is safe (read-only)
  static bool isSafePackageManagerCommand(String command) {
    final trimmed = command.trim();
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length < 2) return false;

    final manager = parts[0];
    final subcommand = parts[1];

    switch (manager) {
      case 'npm':
        return _safeNpmSubcommands.contains(subcommand);
      case 'dart':
        return _safeDartSubcommands.contains(subcommand);
      case 'pip':
        return _safePipSubcommands.contains(subcommand);
      default:
        return false;
    }
  }

  static const Set<String> _safeNpmSubcommands = {
    'list',
    'ls',
    'view',
    'show',
    'info',
    'search',
    'outdated',
    'doctor',
    'version',
    'help',
  };

  static const Set<String> _safeDartSubcommands = {
    'analyze',
    'doc',
    'info',
    'pub', // pub deps, pub outdated are safe
    'help',
    'version',
  };

  static const Set<String> _safePipSubcommands = {
    'list',
    'show',
    'search',
    'check',
    'help',
  };

  /// Comprehensive check if a bash command is safe
  static bool isCommandSafe(String command) {
    // First check basic command name
    if (!isSafeBashCommand(command)) {
      return false;
    }

    final trimmed = command.trim();
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.isEmpty) return false;

    final commandName = parts[0];

    // Special validation for commands that need subcommand checking
    if (commandName == 'git') {
      return isSafeGitCommand(trimmed);
    }

    if (commandName == 'npm' || commandName == 'dart' || commandName == 'pip') {
      return isSafePackageManagerCommand(trimmed);
    }

    // Check for dangerous flags that could make a safe command unsafe
    if (_hasDangerousFlags(trimmed)) {
      return false;
    }

    return true;
  }

  /// Check for dangerous flags that could make a safe command unsafe
  static bool _hasDangerousFlags(String command) {
    // Look for output redirection that writes files
    // Check for > but exclude stderr redirection (2>, 2>&1)
    if (command.contains('>')) {
      // Allow only stderr redirection patterns: 2>, 2>&1
      // Block stdout redirection: >, >>, 1>, etc.
      final hasStdoutRedirection = RegExp(r'(?<!2)>(?!&1)').hasMatch(command);
      if (hasStdoutRedirection) {
        return true;
      }
    }

    // Look for dangerous rm flags in find commands
    if (command.startsWith('find') && command.contains('-delete')) {
      return true;
    }

    // Look for in-place editing in sed
    if (command.startsWith('sed') && command.contains('-i')) {
      return true;
    }

    return false;
  }
}
