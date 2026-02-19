import '../configuration/claude_settings.dart';
import '../logging/vide_logger.dart';
import '../models/permission_mode.dart';
import '../configuration/local_settings_manager.dart';
import 'gitignore_matcher.dart';
import 'pattern_inference.dart';
import 'permission_matcher.dart';
import 'tool_input.dart';

/// Behavior when PermissionAskUser would normally be returned.
enum AskUserBehavior {
  /// Return PermissionAskUser - let the caller handle UI prompts
  ask,

  /// Return PermissionDeny - for non-interactive contexts
  deny,

  /// Return PermissionAllow - DANGEROUS, only for testing
  allow,
}

/// Configuration for PermissionChecker behavior.
///
/// Different UIs may need different behaviors:
/// - TUI: Interactive prompts, session cache, settings files
class PermissionCheckerConfig {
  /// Whether to enable session cache for remembering approvals.
  /// Default: true
  final bool enableSessionCache;

  /// Whether to load settings from .claude/settings.local.json.
  /// Default: true
  final bool loadSettings;

  /// Whether to respect .gitignore for Read operations.
  /// Default: true
  final bool respectGitignore;

  /// Default behavior when operation requires user approval but UI can't prompt.
  /// - ask: Return PermissionAskUser (let caller handle)
  /// - deny: Return PermissionDeny
  /// - allow: Return PermissionAllow (dangerous, for testing only)
  /// Default: ask
  final AskUserBehavior askUserBehavior;

  const PermissionCheckerConfig({
    this.enableSessionCache = true,
    this.loadSettings = true,
    this.respectGitignore = true,
    this.askUserBehavior = AskUserBehavior.ask,
  });

  /// Default configuration for TUI (interactive mode)
  static const tui = PermissionCheckerConfig();

  /// Configuration for testing (auto-allow everything that would ask user)
  static const testing = PermissionCheckerConfig(
    askUserBehavior: AskUserBehavior.allow,
    loadSettings: false,
    respectGitignore: false,
  );
}

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
  final PermissionCheckerConfig config;
  GitignoreMatcher? _gitignoreMatcher;
  final Set<String> _sessionCache = {};

  /// Cached settings to avoid reading from disk on every permission check.
  String? _cachedSettingsCwd;
  ClaudeSettings? _cachedSettings;

  PermissionChecker({this.config = const PermissionCheckerConfig()});

  /// Check if allowed by session cache
  bool isAllowedBySessionCache(String toolName, ToolInput input) {
    if (!config.enableSessionCache) return false;
    if (!_isWriteOperation(toolName)) return false;

    for (final pattern in _sessionCache) {
      if (PermissionMatcher.matches(pattern, toolName, input)) {
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

  /// Invalidate the cached settings so the next check re-reads from disk.
  ///
  /// Call this after modifying the settings file (e.g., adding to the allow
  /// list via "remember") so subsequent permission checks see the update.
  void invalidateSettingsCache() {
    _cachedSettings = null;
    _cachedSettingsCwd = null;
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
    required ToolInput input,
    required String cwd,
    String? permissionMode,
  }) async {
    // Load settings (if enabled), caching to avoid disk reads on every check.
    // Cache is invalidated when cwd changes (different project).
    ClaudeSettings? settings;
    if (config.loadSettings) {
      if (_cachedSettings != null && _cachedSettingsCwd == cwd) {
        settings = _cachedSettings;
      } else {
        final settingsManager = LocalSettingsManager(
          projectRoot: cwd,
          parrottRoot: cwd,
        );
        settings = await settingsManager.readSettings();
        _cachedSettings = settings;
        _cachedSettingsCwd = cwd;
      }
    }

    // Load gitignore if needed (and enabled)
    if (config.respectGitignore && _gitignoreMatcher == null) {
      try {
        _gitignoreMatcher = await GitignoreMatcher.load(cwd);
      } catch (e) {
        VideLogger.instance.warn(
          'PermissionChecker',
          'Failed to load .gitignore for $cwd: $e',
        );
      }
    }

    // Check gitignore for Read operations (if enabled)
    if (config.respectGitignore) {
      if (input case ReadToolInput(:final filePath)) {
        if (filePath.isNotEmpty &&
            _gitignoreMatcher != null &&
            _gitignoreMatcher!.shouldIgnore(filePath)) {
          VideLogger.instance.info(
            'PermissionChecker',
            'Blocked by .gitignore: tool=$toolName path=$filePath',
          );
          return const PermissionDeny('Blocked by .gitignore');
        }
      }
    }

    // Hardcoded deny list for problematic MCP tools
    const hardcodedDenyList = ['mcp__dart__analyze_files'];

    if (hardcodedDenyList.contains(toolName)) {
      VideLogger.instance.info(
        'PermissionChecker',
        'Blocked by hardcoded deny list: tool=$toolName',
      );
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

    // Auto-approve read-only file operations
    if (toolName == 'Read' || toolName == 'Grep' || toolName == 'Glob') {
      return const PermissionAllow('Auto-approved read-only operation');
    }

    // Check deny list (highest priority, if settings loaded)
    if (settings != null) {
      for (final pattern in settings.permissions.deny) {
        if (PermissionMatcher.matches(
          pattern,
          toolName,
          input,
          context: {'cwd': cwd},
        )) {
          VideLogger.instance.info(
            'PermissionChecker',
            'Blocked by deny list: tool=$toolName pattern=$pattern',
          );
          return const PermissionDeny('Blocked by deny list');
        }
      }
    }

    // Auto-approve write operations in acceptEdits mode
    if (permissionMode == PermissionMode.acceptEdits.value &&
        _isWriteOperation(toolName)) {
      return const PermissionAllow('Auto-approved (acceptEdits mode)');
    }

    // Check safe bash commands (auto-approve read-only)
    if (input case BashToolInput()) {
      if (PermissionMatcher.isSafeBashCommand(input, {'cwd': cwd})) {
        return const PermissionAllow('Auto-approved safe read-only command');
      }
    }

    // Check session cache (for Write/Edit/MultiEdit)
    if (isAllowedBySessionCache(toolName, input)) {
      return const PermissionAllow('Auto-approved from session cache');
    }

    // Check allow list (if settings loaded)
    if (settings != null) {
      for (final pattern in settings.permissions.allow) {
        if (PermissionMatcher.matches(
          pattern,
          toolName,
          input,
          context: {'cwd': cwd},
        )) {
          return const PermissionAllow('Auto-approved from allow list');
        }
      }
    }

    // Need to ask user - handle based on config
    final inferredPattern = PatternInference.inferPattern(toolName, input);
    VideLogger.instance.debug(
      'PermissionChecker',
      'No auto-approve rule matched: tool=$toolName behavior=${config.askUserBehavior.name} '
      'pattern=$inferredPattern',
    );
    return switch (config.askUserBehavior) {
      AskUserBehavior.ask => PermissionAskUser(
        inferredPattern: inferredPattern,
      ),
      AskUserBehavior.deny => const PermissionDeny(
        'Operation requires user approval (not available in current mode)',
      ),
      AskUserBehavior.allow => const PermissionAllow(
        'Auto-approved (testing mode)',
      ),
    };
  }

  /// Dispose resources
  void dispose() {
    _sessionCache.clear();
    _gitignoreMatcher = null;
    _cachedSettings = null;
    _cachedSettingsCwd = null;
  }
}
