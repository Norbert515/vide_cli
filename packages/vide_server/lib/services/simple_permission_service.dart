import 'package:path/path.dart' as p;
import 'package:claude_sdk/claude_sdk.dart';

/// Localhost addresses for network command validation
const _localhostAddresses = ['localhost', '127.0.0.1', '::1'];

/// Check if a command string targets localhost (for curl/wget commands)
bool _isLocalhostTarget(String command) {
  final lower = command.toLowerCase();
  return _localhostAddresses.any((addr) => lower.contains(addr));
}

/// Check if a URL host is localhost
bool _isLocalhostHost(String host) {
  final lower = host.toLowerCase();
  return _localhostAddresses.contains(lower);
}

/// Creates a CanUseToolCallback for the REST API
///
/// Auto-approves safe operations and auto-denies dangerous ones.
/// For MVP, there's no interactive permission system.
CanUseToolCallback createSimplePermissionCallback(String cwd) {
  // Normalize the working directory for consistent path comparison
  final normalizedCwd = p.canonicalize(cwd);

  return (
    String toolName,
    Map<String, dynamic> input,
    ToolPermissionContext context,
  ) async {
    // Check deny list first
    if (_isDangerous(toolName, input)) {
      return PermissionResultDeny(
        message: 'Dangerous operation blocked by REST API',
      );
    }

    // Auto-approve safe operations (passing cwd for path validation)
    if (_isSafe(toolName, input, normalizedCwd)) {
      return const PermissionResultAllow();
    }

    // Default deny for MVP
    return PermissionResultDeny(
      message: 'Not in safe list - requires user approval',
    );
  };
}

/// Check if operation is dangerous
bool _isDangerous(String toolName, Map<String, dynamic> toolInput) {
  // Check for dangerous bash commands
  if (toolName == 'Bash') {
    final command = toolInput['command'] as String?;
    if (command == null) return false;

    final lower = command.toLowerCase();

    // Dangerous file operations
    if (lower.contains('rm -rf') ||
        lower.contains('rm -fr') ||
        lower.contains('rm -r') && lower.contains('/')) {
      return true;
    }

    // Disk operations
    if (lower.contains('dd ') ||
        lower.contains('mkfs') ||
        lower.contains('fdisk')) {
      return true;
    }

    // System modification
    if (lower.contains('chmod 777') ||
        lower.contains('chown') ||
        lower.startsWith('sudo ') ||
        lower.startsWith('su ')) {
      return true;
    }

    // Network operations to external hosts
    if (lower.contains('curl') || lower.contains('wget')) {
      if (!_isLocalhostTarget(command)) {
        return true; // Deny - external host
      }
    }
  }

  // Check for web requests to non-localhost
  if (toolName == 'WebFetch') {
    final url = toolInput['url'] as String?;
    if (url != null) {
      final uri = Uri.tryParse(url);
      if (uri != null && !_isLocalhostHost(uri.host)) {
        return true;
      }
    }
  }

  return false;
}

/// Check if operation is safe to auto-approve
bool _isSafe(String toolName, Map<String, dynamic> toolInput, String cwd) {
  // Read-only file operations
  if (toolName == 'Read' || toolName == 'Grep' || toolName == 'Glob') {
    return true;
  }

  // Write operations - must be within project directory
  if (toolName == 'Write' || toolName == 'Edit' || toolName == 'MultiEdit') {
    final filePath = toolInput['file_path'] as String?;
    if (filePath != null) {
      // Canonicalize the path to resolve . and .. and symlinks
      final normalizedPath = p.canonicalize(filePath);

      // Only allow writes within the project working directory
      if (!normalizedPath.startsWith(cwd)) {
        return false;
      }
      return true;
    }
  }

  // WebFetch to localhost is safe
  if (toolName == 'WebFetch') {
    final url = toolInput['url'] as String?;
    if (url != null) {
      final uri = Uri.tryParse(url);
      if (uri != null && _isLocalhostHost(uri.host)) {
        return true;
      }
    }
    return false;
  }

  // Safe bash commands
  if (toolName == 'Bash') {
    final command = toolInput['command'] as String?;
    if (command == null) return false;

    return _isSafeBashCommand(command);
  }

  return false;
}

/// Check if a bash command is safe
bool _isSafeBashCommand(String command) {
  final trimmed = command.trim();
  if (trimmed.isEmpty) return false;

  // Check for curl/wget to localhost (safe)
  if (trimmed.toLowerCase().contains('curl') ||
      trimmed.toLowerCase().contains('wget')) {
    return _isLocalhostTarget(trimmed);
  }

  // Extract the base command (before pipes, redirects, etc.)
  final baseCommand = trimmed.split(RegExp(r'[|&><;]')).first.trim();
  final parts = baseCommand.split(RegExp(r'\s+'));
  if (parts.isEmpty) return false;

  final commandName = parts[0];

  // Safe read-only commands
  const safeCommands = {
    'ls',
    'pwd',
    'echo',
    'cat',
    'head',
    'tail',
    'less',
    'more',
    'git status',
    'git log',
    'git diff',
    'git branch',
    'git show',
    'grep',
    'find',
    'wc',
    'sort',
    'uniq',
    'dart',
    'flutter',
    'pub',
    'npm',
    'yarn',
    'pnpm',
    'which',
    'whereis',
    'env',
    'printenv',
  };

  // Check if command starts with any safe command
  for (final safe in safeCommands) {
    if (trimmed.startsWith(safe)) {
      // For git commands, ensure they're read-only
      if (safe.startsWith('git')) {
        // Allow read-only git commands
        final gitSubcommand = safe.split(' ').skip(1).join(' ');
        if ([
          'status',
          'log',
          'diff',
          'branch',
          'show',
        ].contains(gitSubcommand)) {
          return true;
        }
      } else {
        return true;
      }
    }
  }

  // Check base command name
  return safeCommands.contains(commandName);
}
