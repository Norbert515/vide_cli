import 'dart:async';
import 'package:claude_api/src/control/control_types.dart';
import 'package:riverpod/riverpod.dart';
import 'package:uuid/uuid.dart';
import '../settings/local_settings_manager.dart';
import '../settings/permission_matcher.dart';
import '../settings/pattern_inference.dart';
import '../settings/gitignore_matcher.dart';

// =============================================================================
// Data Classes
// =============================================================================

/// Permission request from Claude Code hook
class PermissionRequest {
  final String requestId;
  final String toolName;
  final Map<String, dynamic> toolInput;
  final String cwd;
  final DateTime timestamp;
  final String? inferredPattern;

  PermissionRequest({
    required this.requestId,
    required this.toolName,
    required this.toolInput,
    required this.cwd,
    DateTime? timestamp,
    this.inferredPattern,
  }) : timestamp = timestamp ?? DateTime.now();

  PermissionRequest copyWith({String? requestId, String? inferredPattern}) {
    return PermissionRequest(
      requestId: requestId ?? this.requestId,
      toolName: toolName,
      toolInput: toolInput,
      cwd: cwd,
      timestamp: timestamp,
      inferredPattern: inferredPattern ?? this.inferredPattern,
    );
  }

  String get displayAction {
    switch (toolName) {
      case 'Bash':
        return 'Run: ${toolInput['command']}';
      case 'Write':
        return 'Write: ${toolInput['file_path']}';
      case 'Edit':
        return 'Edit: ${toolInput['file_path']}';
      case 'MultiEdit':
        return 'MultiEdit: ${toolInput['file_path']}';
      case 'WebFetch':
        return 'Fetch: ${toolInput['url']}';
      case 'WebSearch':
        return 'Search: ${toolInput['query']}';
      default:
        return 'Use $toolName';
    }
  }
}

/// Permission response to Claude Code hook
class PermissionResponse {
  final String decision;
  final String? reason;
  final bool remember;

  PermissionResponse({required this.decision, this.reason, required this.remember});

  Map<String, dynamic> toJson() => {'decision': decision, if (reason != null) 'reason': reason, 'remember': remember};
}

/// Internal result from permission checks
sealed class _PermissionCheckResult {
  const _PermissionCheckResult();
}

class _PermissionAllow extends _PermissionCheckResult {
  final String reason;
  const _PermissionAllow(this.reason);
}

class _PermissionDeny extends _PermissionCheckResult {
  final String reason;
  const _PermissionDeny(this.reason);
}

class _PermissionAskUser extends _PermissionCheckResult {
  final String? inferredPattern;
  const _PermissionAskUser({this.inferredPattern});
}

final permissionServiceProvider = Provider<PermissionService>((ref) {
  final service = PermissionService();
  ref.onDispose(() => service.dispose());
  return service;
});

class PermissionService {
  GitignoreMatcher? _gitignoreMatcher;

  final _requestController = StreamController<PermissionRequest>.broadcast();
  final Map<String, Completer<PermissionResponse>> _pendingRequests = {};

  // Session cache (patterns approved during execution)
  final Set<String> _sessionCache = {};

  /// Stream of permission requests for the UI
  Stream<PermissionRequest> get requests => _requestController.stream;

  /// Respond to a permission request
  void respondToPermission(String requestId, PermissionResponse response) {
    _pendingRequests[requestId]?.complete(response);
  }

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

  /// Shared permission checking logic.
  /// Returns one of:
  /// - _PermissionAllow: Auto-approved
  /// - _PermissionDeny: Denied
  /// - _PermissionAskUser: Needs user approval
  Future<_PermissionCheckResult> _checkPermission({
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
        return const _PermissionDeny('Blocked by .gitignore');
      }
    }

    // Hardcoded deny list for problematic MCP tools
    const hardcodedDenyList = [
      'mcp__dart__analyze_files', // Floods context with too much output (all lint hints, no filtering)
    ];

    if (hardcodedDenyList.contains(toolName)) {
      return _PermissionDeny(
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
      return const _PermissionAllow('Auto-approved internal tool');
    }

    // Check deny list (highest priority)
    for (final pattern in settings.permissions.deny) {
      if (PermissionMatcher.matches(
        pattern,
        toolName,
        toolInput,
        context: {'cwd': cwd},
      )) {
        return const _PermissionDeny('Blocked by deny list');
      }
    }

    // Check safe bash commands (auto-approve read-only)
    if (toolName == 'Bash') {
      if (PermissionMatcher.isSafeBashCommand(toolInput, {'cwd': cwd})) {
        return const _PermissionAllow('Auto-approved safe read-only command');
      }
    }

    // Check session cache (for Write/Edit/MultiEdit)
    if (isAllowedBySessionCache(toolName, toolInput)) {
      return const _PermissionAllow('Auto-approved from session cache');
    }

    // Check allow list
    for (final pattern in settings.permissions.allow) {
      if (PermissionMatcher.matches(
        pattern,
        toolName,
        toolInput,
        context: {'cwd': cwd},
      )) {
        return const _PermissionAllow('Auto-approved from allow list');
      }
    }

    // Need to ask user
    final inferredPattern = PatternInference.inferPattern(toolName, toolInput);
    return _PermissionAskUser(inferredPattern: inferredPattern);
  }

  /// Check permission for a tool use via control protocol callback.
  /// This method is designed to be passed as the `canUseTool` callback to ClaudeClient.create().
  ///
  /// [toolName] - The name of the tool being invoked
  /// [toolInput] - The input parameters for the tool
  /// [context] - Additional context from the control protocol
  /// [cwd] - The current working directory (needed for settings lookup)
  Future<PermissionResult> checkToolPermission(
    String toolName,
    Map<String, dynamic> toolInput,
    ToolPermissionContext context, {
    required String cwd,
  }) async {
    final result = await _checkPermission(
      toolName: toolName,
      toolInput: toolInput,
      cwd: cwd,
    );

    switch (result) {
      case _PermissionAllow():
        return const PermissionResultAllow();
      case _PermissionDeny(reason: final reason):
        return PermissionResultDeny(message: reason);
      case _PermissionAskUser(inferredPattern: final inferredPattern):
        // Create completer for user response
        final requestId = const Uuid().v4();
        final completer = Completer<PermissionResponse>();
        _pendingRequests[requestId] = completer;

        // Create a PermissionRequest for the UI
        final permissionRequest = PermissionRequest(
          requestId: requestId,
          toolName: toolName,
          toolInput: toolInput,
          cwd: cwd,
          inferredPattern: inferredPattern,
        );

        // Emit request to UI
        _requestController.add(permissionRequest);

        // Wait for user response
        final response = await completer.future;
        _pendingRequests.remove(requestId);

        if (response.decision == 'allow') {
          return const PermissionResultAllow();
        } else {
          return PermissionResultDeny(
            message: response.reason ?? 'Permission denied by user',
          );
        }
    }
  }

  /// Dispose all resources
  Future<void> dispose() async {
    _sessionCache.clear();
    _gitignoreMatcher = null;
    await _requestController.close();
  }
}
