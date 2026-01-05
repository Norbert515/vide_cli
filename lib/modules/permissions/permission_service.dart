import 'dart:async';
import 'package:claude_sdk/src/control/control_types.dart';
import 'package:riverpod/riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:vide_core/vide_core.dart';

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

  PermissionResponse({
    required this.decision,
    this.reason,
    required this.remember,
  });

  Map<String, dynamic> toJson() => {
    'decision': decision,
    if (reason != null) 'reason': reason,
    'remember': remember,
  };
}

final permissionServiceProvider = Provider<PermissionService>((ref) {
  final service = PermissionService();
  ref.onDispose(() => service.dispose());
  return service;
});

class PermissionService {
  final PermissionChecker _checker = PermissionChecker();

  final _requestController = StreamController<PermissionRequest>.broadcast();
  final Map<String, Completer<PermissionResponse>> _pendingRequests = {};

  /// Stream of permission requests for the UI
  Stream<PermissionRequest> get requests => _requestController.stream;

  /// Respond to a permission request
  void respondToPermission(String requestId, PermissionResponse response) {
    _pendingRequests[requestId]?.complete(response);
  }

  /// Delegate to checker
  bool isAllowedBySessionCache(
    String toolName,
    Map<String, dynamic> toolInput,
  ) {
    final input = ToolInput.fromJson(toolName, toolInput);
    return _checker.isAllowedBySessionCache(toolName, input);
  }

  void addSessionPattern(String pattern) {
    _checker.addSessionPattern(pattern);
  }

  void clearSessionCache() {
    _checker.clearSessionCache();
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
    // Convert raw map to type-safe ToolInput
    final input = ToolInput.fromJson(toolName, toolInput);

    final result = await _checker.checkPermission(
      toolName: toolName,
      input: input,
      cwd: cwd,
    );

    switch (result) {
      case PermissionAllow():
        return const PermissionResultAllow();
      case PermissionDeny(reason: final reason):
        return PermissionResultDeny(message: reason);
      case PermissionAskUser(inferredPattern: final inferredPattern):
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
    _checker.dispose();
    await _requestController.close();
  }
}
