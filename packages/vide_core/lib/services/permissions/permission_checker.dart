import 'package:vide_core/vide_core.dart';

/// Result of a permission check - pure business logic result
sealed class PermissionCheckResult {
  const PermissionCheckResult();
}

class PermissionAllow extends PermissionCheckResult {
  final String reason;
  const PermissionAllow(this.reason);
}

class PermissionDeny extends PermissionCheckResult {
  final String reason;
  const PermissionDeny(this.reason);
}

class PermissionAskUser extends PermissionCheckResult {
  final String? inferredPattern;
  const PermissionAskUser({this.inferredPattern});
}

/// Pure permission checking logic - no UI dependencies
///
/// This class handles all the business logic for permission checking:
/// - Deny list checking
/// - Allow list checking
/// - Safe command detection
/// - Session cache
/// - Gitignore blocking
class PermissionChecker {
  GitignoreMatcher? _gitignoreMatcher;
  final Set<String> _sessionCache = {};

  /// Check if allowed by session cache
  bool isAllowedBySessionCache(String toolName, Map<String, dynamic> toolInput) {
    if (!_isWriteOperation(toolName)) return false;

    for (final pattern in _sessionCache) {
      if (PermissionMatcher.matches(pattern, toolName, toolInput)) {
        return true;
      }
    }
    return false;
  }

  /// Add a pattern to session cache
  void addSessionPattern(String pattern) {
    _sessionCache.add(pattern);
  }

  /// Clear session cache
  void clearSessionCache() {
    _sessionCache.clear();
  }

  bool _isWriteOperation(String toolName) {
    return toolName == 'Write' || toolName == 'Edit' || toolName == 'MultiEdit';
  }

  /// Check permission for a tool use.
  /// Returns one of:
  /// - PermissionAllow: Auto-approved
  /// - PermissionDeny: Denied
  /// - PermissionAskUser: Needs user approval
  Future<PermissionCheckResult> checkPermission({
    required String toolName,
    required Map<String, dynamic> toolInput,
    required String cwd,
  }) async {
    // Load settings
    final settingsManager = LocalSettingsManager(projectRoot: cwd, parrottRoot: cwd);
    final settings = await settingsManager.readSettings();

    // Load gitignore if needed
    if (_gitignoreMatcher == null) {
      try {
        _gitignoreMatcher = await GitignoreMatcher.load(cwd);
      } catch (e) {
        // Ignore gitignore load errors
      }
    }

    // Check gitignore for Read operations
    if (toolName == 'Read') {
      final filePath = toolInput['file_path'] as String?;
      if (filePath != null && _gitignoreMatcher != null && _gitignoreMatcher!.shouldIgnore(filePath)) {
        return const PermissionDeny('Blocked by .gitignore');
      }
    }

    // Hardcoded deny list for problematic MCP tools
    const hardcodedDenyList = [
      'mcp__dart__analyze_files',
    ];

    if (hardcodedDenyList.contains(toolName)) {
      return PermissionDeny(
        'Blocked: $toolName floods context with too much output. Use `dart analyze` via Bash instead.',
      );
    }

    // Auto-approve all vide MCP tools, TodoWrite, and safe internal tools
    if (toolName.startsWith('mcp__vide-') ||
        toolName.startsWith('mcp__flutter-runtime__') ||
        toolName == 'TodoWrite' ||
        toolName == 'BashOutput' ||
        toolName == 'KillShell' ||
        toolName == 'KillBash') {
      return const PermissionAllow('Auto-approved internal tool');
    }

    // Check deny list (highest priority)
    for (final pattern in settings.permissions.deny) {
      if (PermissionMatcher.matches(
        pattern,
        toolName,
        toolInput,
        context: {'cwd': cwd},
      )) {
        return const PermissionDeny('Blocked by deny list');
      }
    }

    // Check safe bash commands (auto-approve read-only)
    if (toolName == 'Bash') {
      if (PermissionMatcher.isSafeBashCommand(toolInput, {'cwd': cwd})) {
        return const PermissionAllow('Auto-approved safe read-only command');
      }
    }

    // Check session cache (for Write/Edit/MultiEdit)
    if (isAllowedBySessionCache(toolName, toolInput)) {
      return const PermissionAllow('Auto-approved from session cache');
    }

    // Check allow list
    for (final pattern in settings.permissions.allow) {
      if (PermissionMatcher.matches(
        pattern,
        toolName,
        toolInput,
        context: {'cwd': cwd},
      )) {
        return const PermissionAllow('Auto-approved from allow list');
      }
    }

    // Need to ask user
    final inferredPattern = PatternInference.inferPattern(toolName, toolInput);
    return PermissionAskUser(inferredPattern: inferredPattern);
  }

  /// Dispose resources
  void dispose() {
    _sessionCache.clear();
    _gitignoreMatcher = null;
  }
}
